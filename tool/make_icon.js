// Draws Mari's app icon: the month tree in mist on Kariba teal, with one
// amber leaf (today's). Writes the source images flutter_launcher_icons uses:
//   assets/icon/icon.png        1024 full icon (iOS, legacy Android, Play Store)
//   assets/icon/foreground.png  1024 adaptive-icon foreground (transparent)
//   assets/icon/monochrome.png  1024 Android 13 themed-icon layer
//   assets/icon/play-store-512.png  the Play Console listing icon
// Usage: npm i --no-save sharp && node tool/make_icon.js
// (then `dart run flutter_launcher_icons`, which tool/setup.sh also runs)
const fs = require('fs');
const path = require('path');
let sharp;
try { sharp = require('sharp'); } catch (_) { sharp = require('/opt/npm-tools/node_modules/sharp'); }

const TEAL = '#11756B';
const TEAL_DEEP = '#0B5F57';
const MIST = '#F3F5F2';
const AMBER = '#F0A54C';

// The tree on Android's 108-unit adaptive-icon grid; everything sits inside
// the 66-unit safe circle around (54, 54).
function tree({ leaf = MIST, accent = AMBER, mono = false } = {}) {
  const ink = mono ? '#FFFFFF' : MIST;
  const e = (cx, cy, rot, fill) =>
    `<ellipse cx="${cx}" cy="${cy}" rx="7.2" ry="4.9" transform="rotate(${rot} ${cx} ${cy})" fill="${fill}"/>`;
  return `
  <g>
    ${mono ? '' : `<ellipse cx="54" cy="80.5" rx="15" ry="2.4" fill="${ink}" opacity="0.16"/>`}
    ${mono ? '' : `<ellipse cx="54" cy="42" rx="28" ry="13.5" fill="${ink}" opacity="0.10"/>`}
    <g stroke="${ink}" stroke-linecap="round" stroke-linejoin="round" fill="none">
      <path d="M54 80.5 L54 60" stroke-width="6.2"/>
      <path d="M54 61 L38 47" stroke-width="3.8"/>
      <path d="M54 61 L47 41" stroke-width="3.6"/>
      <path d="M54 60 L61 40" stroke-width="3.6"/>
      <path d="M54 61 L70 46" stroke-width="3.8"/>
    </g>
    ${e(31.5, 46, -15, mono ? ink : leaf)}
    ${e(39.5, 39, 12, mono ? ink : leaf)}
    ${e(48.5, 35, -6, mono ? ink : leaf)}
    ${e(58, 34.5, 8, mono ? ink : leaf)}
    ${e(67, 37.5, -14, mono ? ink : accent)}
    ${e(75.5, 44, 18, mono ? ink : leaf)}
  </g>`;
}

function svg(body, { size = 1024, view = 108, bg = null } = {}) {
  const background = bg
    ? `<defs><radialGradient id="g" cx="50%" cy="85%" r="85%"><stop offset="0" stop-color="${TEAL}"/><stop offset="1" stop-color="${TEAL_DEEP}"/></radialGradient></defs><rect width="${view}" height="${view}" fill="url(#g)"/>`
    : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${view} ${view}">${background}${body}</svg>`;
}

// The full icon frames the tree a little larger than the adaptive grid does,
// since nothing is masked away on iOS or the Play Store.
function fullIcon() {
  return svg(`<g transform="translate(54 54) scale(1.2) translate(-54 -57)">${tree()}</g>`, { bg: true });
}

async function main() {
  const out = path.join(__dirname, '..', 'assets', 'icon');
  fs.mkdirSync(out, { recursive: true });
  const write = (name, s) => sharp(Buffer.from(s)).png().toFile(path.join(out, name));
  await write('icon.png', fullIcon());
  // Launchers mask to circles or squircles: fill most of the 66-unit safe zone.
  const adaptive = (body) => svg(`<g transform="translate(54 54) scale(1.08) translate(-54 -56)">${body}</g>`);
  await write('foreground.png', adaptive(tree()));
  await write('monochrome.png', adaptive(tree({ mono: true })));
  await sharp(Buffer.from(fullIcon())).resize(512, 512).png().toFile(path.join(out, 'play-store-512.png'));
  fs.writeFileSync(path.join(out, 'icon.svg'), fullIcon());
  console.log('assets/icon: icon.png, foreground.png, monochrome.png, play-store-512.png, icon.svg');
}

module.exports = { fullIcon, tree, svg, TEAL };
if (require.main === module) main();
