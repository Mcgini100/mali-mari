// Mari month tree — JavaScript reference implementation.
//
// Every month grows one msasa-shaped tree. Its shape comes only from the year
// and month (a seeded generator), so a given October always looks the same on
// every phone, and the Dart port (lib/features/tree/month_tree.dart) draws the
// exact same tree. test/fixtures/tree_2026_10.json pins the output;
// `node tool/month_tree.js --fixture` regenerates it.
//
// Leaves: one slot per day of the month. A day's leaf colour comes from how
// that day went (dayTone below). Every tone is a real msasa leaf colour, so no
// day ever looks like a failure.
(function (root) {
  'use strict';

  var TAU = Math.PI * 2;
  var MAX_DAYS = 31;

  // Park–Miller minimal standard generator. Products stay below 2^53, so
  // JavaScript doubles and Dart ints produce identical sequences.
  function rng(seed) {
    var s = seed % 2147483647;
    if (s <= 0) s += 2147483646;
    return function () {
      s = (s * 48271) % 2147483647;
      return (s - 1) / 2147483646;
    };
  }

  function add(a, b) { return [a[0] + b[0], a[1] + b[1], a[2] + b[2]]; }
  function scale(a, k) { return [a[0] * k, a[1] * k, a[2] * k]; }
  function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
  function norm(a) { var l = Math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]); return [a[0] / l, a[1] / l, a[2] / l]; }

  function generate(year, month) {
    var r = rng((year * 100 + month) * 7919);
    var segments = []; // {a, b, w, depth}
    var tips = [];

    function grow(start, dir, len, w, depth) {
      var end = add(start, scale(dir, len));
      segments.push({ a: start, b: end, w: w, depth: depth });
      if (depth === 3) { tips.push(end); return; }
      var n = depth === 0 ? 3 : 2;
      var ref = Math.abs(dir[1]) < 0.9 ? [0, 1, 0] : [1, 0, 0];
      var u = norm(cross(dir, ref));
      var v = cross(dir, u);
      var az0 = r() * TAU;
      for (var i = 0; i < n; i++) {
        var az = az0 + (i * TAU) / n + (r() - 0.5) * 0.6;
        var tilt = (depth === 0 ? 0.88 : 0.62) + (r() - 0.5) * 0.25;
        var side = add(scale(u, Math.cos(az)), scale(v, Math.sin(az)));
        var child = norm(add(scale(dir, Math.cos(tilt)), scale(side, Math.sin(tilt))));
        // Msasa crowns spread wide and flat: damp upward growth near the top.
        if (depth >= 1) child = norm([child[0], child[1] * 0.6, child[2]]);
        grow(end, child, len * (0.74 + r() * 0.1), w * 0.64, depth + 1);
      }
    }

    var trunkDir = norm([(r() - 0.5) * 0.25, 1, (r() - 0.5) * 0.25]);
    grow([0, 0, 0], trunkDir, 1.25, 0.24, 0);

    var leaves = [];
    for (var i = 0; i < MAX_DAYS; i++) {
      var tip = tips[i % tips.length];
      var offset = [(r() - 0.5) * 0.8, (r() - 0.3) * 0.45, (r() - 0.5) * 0.8];
      leaves.push({
        pos: add(tip, offset),
        size: 0.2 + r() * 0.07,
        rot: r() * Math.PI,
        phase: r() * TAU,
        day: 0,
      });
    }
    // Days take slots in a shuffled order so the crown fills evenly.
    var order = [];
    for (var k = 0; k < MAX_DAYS; k++) order.push(k);
    for (var j = MAX_DAYS - 1; j > 0; j--) {
      var x = Math.floor(r() * (j + 1));
      var tmp = order[j]; order[j] = order[x]; order[x] = tmp;
    }
    for (var d = 0; d < MAX_DAYS; d++) leaves[order[d]].day = d + 1;

    return { segments: segments, leaves: leaves, tips: tips };
  }

  // How a day went, as a leaf. pace = the month's budget per day (or, with no
  // budget, the average spend on days that had any). Amounts in minor units.
  //   bud    nothing logged that day
  //   gold   more money came in than went out
  //   light  spent at most half the daily pace
  //   steady up to the pace
  //   full   up to 1.6 × pace
  //   heavy  more than that
  function dayTone(spend, income, pace, hasEntries) {
    if (!hasEntries) return 'bud';
    if (income > 0 && income > spend) return 'gold';
    if (spend <= 0) return 'light';
    if (pace <= 0) return 'steady';
    var ratio = spend / pace;
    if (ratio <= 0.5) return 'light';
    if (ratio <= 1.0) return 'steady';
    if (ratio <= 1.6) return 'full';
    return 'heavy';
  }

  // Orthographic view: turn the tree by yaw around its trunk, tip it toward the
  // viewer by tilt, drop z. Returns [x, y, depth] with y up.
  function project(p, yaw, tilt) {
    var cy = Math.cos(yaw), sy = Math.sin(yaw);
    var x = p[0] * cy + p[2] * sy;
    var z = -p[0] * sy + p[2] * cy;
    var ct = Math.cos(tilt), st = Math.sin(tilt);
    var y = p[1] * ct - z * st;
    var depth = p[1] * st + z * ct;
    return [x, y, depth];
  }

  var api = { generate: generate, dayTone: dayTone, project: project, rng: rng, MAX_DAYS: MAX_DAYS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.MariTree = api;

  // node tool/month_tree.js --fixture  → writes the parity fixture for the Dart test
  if (typeof require !== 'undefined' && typeof process !== 'undefined' && require.main === module && process.argv.indexOf('--fixture') !== -1) {
    var fs = require('fs');
    var path = require('path');
    var out = { year: 2026, month: 10, tree: generate(2026, 10), projected: generate(2026, 10).leaves.slice(0, 5).map(function (l) { return project(l.pos, 0.4, 0.18); }) };
    var file = path.join(__dirname, '..', 'test', 'fixtures', 'tree_2026_10.json');
    fs.writeFileSync(file, JSON.stringify(out, null, 1) + '\n');
    console.log('wrote ' + file + ' (' + out.tree.segments.length + ' segments, ' + out.tree.leaves.length + ' leaves)');
  }
})(typeof window !== 'undefined' ? window : this);
