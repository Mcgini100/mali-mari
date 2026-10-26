// Mari message parser — JavaScript reference implementation.
//
// lib/capture/parser/message_parser.dart mirrors this file step for step.
// It exists so the parsing *algorithm* and the regex templates can be
// exercised with plain Node (`node tool/test_parser.mjs`) and so the design
// prototype can run the exact same logic in the browser.
//
// Works as a browser global (window.MariParser) and as a CommonJS module.
(function (root) {
  'use strict';

  var CUR = '(?<cur>ZiG|ZWG|USD|US\\$|\\$)';
  var AMT = '(?<amt>\\d{1,3}(?:,\\d{3})+(?:\\.\\d{1,2})?|\\d+(?:\\.\\d{1,2})?)';

  function expand(p) {
    return p.split('{CUR}').join(CUR).split('{AMT}').join(AMT);
  }

  function compile(cfg) {
    return {
      templates: cfg.templates.map(function (t) {
        return {
          id: t.id,
          direction: t.direction,
          category: t.category || null,
          re: new RegExp(expand(t.pattern), 'i'),
        };
      }),
      balance: cfg.balancePatterns.map(function (p) { return new RegExp(expand(p), 'gi'); }),
      fee: cfg.feePatterns.map(function (p) { return new RegExp(expand(p), 'gi'); }),
      ref: new RegExp(cfg.referencePattern, 'i'),
      prefixAmount: new RegExp(CUR + '\\s?' + AMT, 'i'),
      suffixAmount: new RegExp(expand(cfg.suffixAmountPattern), 'i'),
      heuristicCp: new RegExp(cfg.heuristicCounterpartyPattern), // case-sensitive
      directionKeywords: cfg.directionKeywords,
      categoryKeywords: cfg.categoryKeywords,
    };
  }

  function currencyOf(token) {
    var t = token.toUpperCase();
    if (t === 'ZIG' || t === 'ZWG') return 'zig';
    return 'usd'; // USD, US$, $
  }

  function toMinor(amount) {
    var clean = amount.replace(/,/g, '');
    var parts = clean.split('.');
    var whole = parseInt(parts[0], 10);
    var frac = parts.length > 1 ? (parts[1] + '00').substring(0, 2) : '00';
    return whole * 100 + parseInt(frac, 10);
  }

  function cleanCounterparty(cp) {
    if (!cp) return null;
    var c = cp.replace(/\s+/g, ' ').replace(/^[\s,.:;-]+|[\s,.:;-]+$/g, '');
    return c.length ? c : null;
  }

  function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function keywordIndex(text, keyword) {
    var re = new RegExp('(?:^|[^A-Za-z])' + escapeRe(keyword) + '(?![A-Za-z])', 'i');
    var m = re.exec(text);
    if (!m) return -1;
    return m.index + (m[0].length - keyword.length);
  }

  function detectDirection(text, kw) {
    var best = null;
    var bestAt = Infinity;
    ['in', 'out'].forEach(function (dir) {
      kw[dir].forEach(function (k) {
        var at = keywordIndex(text, k);
        if (at >= 0 && at < bestAt) { bestAt = at; best = dir; }
      });
    });
    return best;
  }

  function categorize(counterparty, kw) {
    if (!counterparty) return null;
    var hay = ' ' + counterparty.toLowerCase() + ' ';
    var ids = Object.keys(kw);
    for (var i = 0; i < ids.length; i++) {
      var words = kw[ids[i]];
      for (var j = 0; j < words.length; j++) {
        if (hay.indexOf(words[j].toLowerCase()) >= 0) return ids[i];
      }
    }
    return null;
  }

  function extractFee(text, c) {
    var total = 0;
    c.fee.forEach(function (re) {
      re.lastIndex = 0;
      var m;
      while ((m = re.exec(text)) !== null) total += toMinor(m.groups.amt);
    });
    return total;
  }

  function extractReference(text, c) {
    var m = c.ref.exec(text);
    if (!m) return null;
    return m.groups.ref.replace(/[.\-/]+$/, '');
  }

  // Returns null when the text is not a transaction at all, otherwise:
  // { amountMinor, currency, direction ('in'|'out'|null), counterparty,
  //   category, feeMinor, reference, confidence ('high'|'medium'|'low'), templateId }
  function parse(text, c) {
    if (!text) return null;
    var norm = text.replace(/\s+/g, ' ').trim();
    if (!norm) return null;

    var feeMinor = extractFee(norm, c);
    var reference = extractReference(norm, c);

    for (var i = 0; i < c.templates.length; i++) {
      var t = c.templates[i];
      var m = t.re.exec(norm);
      if (m) {
        var cp = cleanCounterparty(m.groups.cp);
        return {
          amountMinor: toMinor(m.groups.amt),
          currency: currencyOf(m.groups.cur),
          direction: t.direction,
          counterparty: cp,
          category: t.category || categorize(cp, c.categoryKeywords),
          feeMinor: feeMinor,
          reference: reference,
          confidence: 'high',
          templateId: t.id,
        };
      }
    }

    // Generic heuristic: drop balance and fee phrases so their amounts are
    // never mistaken for the transaction amount.
    var stripped = norm;
    c.balance.concat(c.fee).forEach(function (re) {
      re.lastIndex = 0;
      stripped = stripped.replace(re, ' ');
    });

    var a = c.prefixAmount.exec(stripped) || c.suffixAmount.exec(stripped);
    if (!a) return null;

    var direction = detectDirection(stripped, c.directionKeywords);
    var cpMatch = c.heuristicCp.exec(stripped);
    var counterparty = cpMatch ? cleanCounterparty(cpMatch.groups.cp) : null;

    return {
      amountMinor: toMinor(a.groups.amt),
      currency: currencyOf(a.groups.cur),
      direction: direction,
      counterparty: counterparty,
      category: categorize(counterparty, c.categoryKeywords),
      feeMinor: feeMinor,
      reference: reference,
      confidence: direction ? 'medium' : 'low',
      templateId: null,
    };
  }

  var api = { compile: compile, parse: parse, toMinor: toMinor };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.MariParser = api;
})(typeof window !== 'undefined' ? window : this);
