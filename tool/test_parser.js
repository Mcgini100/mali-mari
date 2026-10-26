// Runs the reference parser against test/fixtures/messages.json.
// Usage: node tool/test_parser.js
const fs = require('fs');
const path = require('path');
const P = require('./parser_reference.js');

const root = path.join(__dirname, '..');
const cfg = JSON.parse(fs.readFileSync(path.join(root, 'assets/parser/templates.json'), 'utf8'));
const fixtures = JSON.parse(fs.readFileSync(path.join(root, 'test/fixtures/messages.json'), 'utf8'));
const c = P.compile(cfg);

const fmt = (minor) => (minor / 100).toFixed(2);
let failures = 0;

for (const kase of fixtures.cases) {
  const r = P.parse(kase.text, c);
  const problems = [];
  if (kase.expect === null) {
    if (r !== null) problems.push(`expected null, got ${JSON.stringify(r)}`);
  } else if (r === null) {
    problems.push('expected a transaction, got null');
  } else {
    const e = kase.expect;
    const check = (k, actual) => {
      if (k in e && e[k] !== actual) problems.push(`${k}: expected ${JSON.stringify(e[k])}, got ${JSON.stringify(actual)}`);
    };
    check('amount', fmt(r.amountMinor));
    check('currency', r.currency);
    check('direction', r.direction);
    check('counterparty', r.counterparty);
    check('category', r.category);
    check('reference', r.reference);
    check('confidence', r.confidence);
    if ('fee' in e) check('fee', fmt(r.feeMinor));
  }
  if (problems.length) {
    failures++;
    console.log(`FAIL  ${kase.name}\n      ${problems.join('\n      ')}`);
  } else {
    console.log(`ok    ${kase.name}`);
  }
}
console.log(`\n${fixtures.cases.length - failures}/${fixtures.cases.length} passed`);
process.exit(failures ? 1 : 0);
