// Builds design/prototype.html from design/prototype.src.html by inlining the
// reference parser and the parser templates, so the prototype runs the same
// parsing logic and data the app ships with.
// Usage: node tool/build_prototype.js
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'design/prototype.src.html'), 'utf8');
const parser = fs.readFileSync(path.join(__dirname, 'parser_reference.js'), 'utf8');
const templates = JSON.stringify(JSON.parse(fs.readFileSync(path.join(root, 'assets/parser/templates.json'), 'utf8')));

if (!src.includes('/*@@PARSER@@*/') || !src.includes('/*@@TEMPLATES@@*/')) {
  throw new Error('placeholders missing from prototype.src.html');
}
const out = src.replace('/*@@PARSER@@*/', () => parser).replace('/*@@TEMPLATES@@*/', () => templates);
fs.writeFileSync(path.join(root, 'design/prototype.html'), out);
console.log(`design/prototype.html written (${(out.length / 1024).toFixed(1)} KB)`);
