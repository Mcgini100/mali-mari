// Builds design/prototype.html from design/prototype.src.html by inlining the
// reference parser, the parser templates and the month-tree generator, so the
// prototype runs the same logic and data the app ships with.
// Usage: node tool/build_prototype.js
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'design/prototype.src.html'), 'utf8');
const parser = fs.readFileSync(path.join(__dirname, 'parser_reference.js'), 'utf8');
const tree = fs.readFileSync(path.join(__dirname, 'month_tree.js'), 'utf8');
const templates = JSON.stringify(JSON.parse(fs.readFileSync(path.join(root, 'assets/parser/templates.json'), 'utf8')));

if (!src.includes('/*@@PARSER@@*/') || !src.includes('/*@@TEMPLATES@@*/') || !src.includes('/*@@TREE@@*/')) {
  throw new Error('placeholders missing from prototype.src.html');
}
const out = src.replace('/*@@PARSER@@*/', () => parser).replace('/*@@TEMPLATES@@*/', () => templates).replace('/*@@TREE@@*/', () => tree);
fs.writeFileSync(path.join(root, 'design/prototype.html'), out);
console.log(`design/prototype.html written (${(out.length / 1024).toFixed(1)} KB)`);
