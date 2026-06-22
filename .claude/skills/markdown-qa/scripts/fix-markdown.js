#!/usr/bin/env node
/**
 * Deterministic Markdown QA for generated artifact folders.
 * Ported from herman-documenter lib/markdown-processor.js (fixListFormatting,
 * fixBoldFormatting); Docusaurus/admonition conversion dropped; link validation added.
 *
 * Usage: node fix-markdown.js <folder> [--check-links] [--dry-run]
 *   - Recursively processes every .md file in <folder>.
 *   - Fixes are idempotent and never touch fenced code blocks or YAML frontmatter.
 *   - --check-links reports relative links whose targets don't exist.
 *   - Exit 0 even when broken links are found (findings, not failures); exit 1 on usage/IO errors.
 */
const fs = require('fs');
const path = require('path');

function fixBoldFormatting(content) {
    // "** text**" / "**text **" -> "**text**". One sequential left-to-right pass:
    // the regex pairs each opening ** (line start or preceded by whitespace/bracket)
    // with the nearest closing **, so a closing delimiter can never be re-paired
    // with the NEXT span's opener ("a** and **b" stays untouched).
    return content.replace(/(^|[\s>([])\*\*([^*\n]+?)\*\*/gm,
        (match, prefix, inner) => prefix + '**' + inner.trim() + '**');
}

/** Split off YAML frontmatter so fixes never touch it. Returns [frontmatter, body]. */
function splitFrontmatter(content) {
    if (content.startsWith('---\n') || content.startsWith('---\r\n')) {
        const m = content.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n/);
        if (m) return [m[0], content.slice(m[0].length)];
    }
    return ['', content];
}

function fixListFormatting(content) {
    const lines = content.split('\n');
    const fixedLines = [];
    let lastLineWasListItem = false;
    let inCodeBlock = false;
    let codeBlockDelimiter = '';

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const trimmedLine = line.trim();

        // Track fenced code blocks; never reformat their contents.
        if (trimmedLine.startsWith('```') || trimmedLine.startsWith('~~~')) {
            if (!inCodeBlock) {
                inCodeBlock = true;
                codeBlockDelimiter = trimmedLine.substring(0, 3);
            } else if (trimmedLine.startsWith(codeBlockDelimiter)) {
                inCodeBlock = false;
                codeBlockDelimiter = '';
            }
            fixedLines.push(line);
            lastLineWasListItem = false;
            continue;
        }
        if (inCodeBlock) {
            fixedLines.push(line);
            continue;
        }

        const listItemMatch = line.match(/^(\s*)[-*+]\s+(.*)$/);
        const numberedListMatch = line.match(/^(\s*)(\d+)\.\s+(.*)$/);

        if (listItemMatch || numberedListMatch) {
            const indent = listItemMatch ? listItemMatch[1] : numberedListMatch[1];
            const itemText = listItemMatch ? listItemMatch[2] : numberedListMatch[3];

            // Blank line before a list that directly follows text.
            if (!lastLineWasListItem && fixedLines.length > 0 &&
                fixedLines[fixedLines.length - 1].trim() !== '') {
                fixedLines.push('');
            }

            // Normalize indentation to 2 spaces per level; bullets to '*'.
            const indentLevel = Math.floor(indent.replace(/\t/g, '  ').length / 2);
            const properIndent = '  '.repeat(indentLevel);
            if (listItemMatch) {
                fixedLines.push(properIndent + '* ' + itemText);
            } else {
                fixedLines.push(properIndent + numberedListMatch[2] + '. ' + itemText);
            }
            lastLineWasListItem = true;
        } else {
            fixedLines.push(line);
            // A blank line or indented continuation keeps list context alive
            // (so wrapped list items don't get a blank line wedged in on the next bullet).
            lastLineWasListItem = trimmedLine === '' ? lastLineWasListItem : /^\s{2,}/.test(line);
        }
    }
    return fixedLines.join('\n');
}

function processContent(content) {
    const [frontmatter, body] = splitFrontmatter(content);
    let fixed = fixBoldFormatting(body);
    fixed = fixListFormatting(fixed);
    return frontmatter + fixed;
}

function collectMarkdownFiles(dir) {
    const files = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) files.push(...collectMarkdownFiles(fullPath));
        else if (entry.isFile() && entry.name.toLowerCase().endsWith('.md')) files.push(fullPath);
    }
    return files;
}

function validateLinks(files, rootDir) {
    const broken = [];
    const linkRe = /!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;
    for (const file of files) {
        const content = fs.readFileSync(file, 'utf8');
        // Strip fenced code blocks so example links aren't validated.
        const withoutCode = content.replace(/```[\s\S]*?```|~~~[\s\S]*?~~~/g, '');
        let m;
        while ((m = linkRe.exec(withoutCode)) !== null) {
            const target = m[1];
            if (/^(https?:|mailto:|#)/i.test(target)) continue;
            const targetPath = decodeURI(target.split('#')[0]);
            if (targetPath === '') continue;
            const resolved = path.resolve(path.dirname(file), targetPath);
            if (!fs.existsSync(resolved)) {
                broken.push({ file: path.relative(rootDir, file), target });
            }
        }
    }
    return broken;
}

function main() {
    const args = process.argv.slice(2);
    const folder = args.find(a => !a.startsWith('--'));
    const checkLinks = args.includes('--check-links');
    const dryRun = args.includes('--dry-run');

    if (!folder) {
        console.error('Usage: node fix-markdown.js <folder> [--check-links] [--dry-run]');
        process.exit(1);
    }
    const rootDir = path.resolve(folder);
    if (!fs.existsSync(rootDir) || !fs.statSync(rootDir).isDirectory()) {
        console.error(`Not a directory: ${rootDir}`);
        process.exit(1);
    }

    const files = collectMarkdownFiles(rootDir);
    const changed = [];
    for (const file of files) {
        const content = fs.readFileSync(file, 'utf8');
        const fixed = processContent(content);
        if (fixed !== content) {
            if (!dryRun) fs.writeFileSync(file, fixed, 'utf8');
            changed.push(path.relative(rootDir, file));
        }
    }

    console.log(`Scanned: ${files.length} file(s) under ${rootDir}`);
    console.log(changed.length
        ? `Fixed${dryRun ? ' (dry-run, not written)' : ''}: ${changed.length}\n${changed.map(f => '  - ' + f).join('\n')}`
        : 'Fixed: 0 (all files already clean)');

    if (checkLinks) {
        const broken = validateLinks(files, rootDir);
        console.log(broken.length
            ? `Broken links: ${broken.length}\n${broken.map(b => `  - ${b.file} → ${b.target}`).join('\n')}`
            : 'Broken links: 0');
    }
}

main();
