// SPDX-License-Identifier: Apache-2.0
//
// Fails if any tracked text file contains emoji. RAKIA uses professional
// icons (Material Symbols in the app) and words in documentation instead.
// Flags characters that render as emoji by default (Emoji_Presentation) and
// the emoji variation selector U+FE0F, which turns text symbols into emoji.
// Typographic symbols such as arrows, box drawing and the geometric status
// shapes in the design system are allowed.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const binary = /\.(png|jpe?g|gif|webp|ico|ttf|otf|woff2?|jar|wasm|pdf|zip)$/i;
const emoji = /\p{Emoji_Presentation}|\uFE0F/u;

const files = execFileSync('git', ['ls-files', '-z'], { encoding: 'utf8' })
  .split('\0')
  .filter((f) => f && !binary.test(f));

let found = 0;
for (const file of files) {
  let text;
  try {
    text = readFileSync(file, 'utf8');
  } catch {
    continue; // deleted in the working tree, or unreadable
  }
  text.split('\n').forEach((line, i) => {
    const m = line.match(emoji);
    if (m) {
      const cp = m[0].codePointAt(0).toString(16).toUpperCase();
      console.log(`::error file=${file},line=${i + 1}::emoji U+${cp} is not allowed; use an icon or words`);
      found++;
    }
  });
}
console.log(found === 0 ? `No emoji in ${files.length} tracked text files.` : `${found} emoji found.`);
process.exit(found === 0 ? 0 : 1);
