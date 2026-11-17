// node tests/test_kbd.mjs — kbd.js decide(): a switch on one keyboard moves all, a new keyboard is pulled in quietly
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

const src = readFileSync(new URL("../config/quickshell/glyph/kbd.js", import.meta.url), "utf8").replace(".pragma library", "");
const { decide } = new Function(src + "; return { decide };")();
const names = ["English (US)", "Russian"];
const kb = (name, i, main = false, address = "0x" + name) => ({ name, address, active_layout_index: i, active_keymap: names[i], main });

// start: devices disagree (as after old per-keyboard switches) — the main one wins, the rest follow
let r = decide([kb("laptop", 1, true), kb("video-bus", 0)], {}, -1);
assert.deepEqual([r.cur, r.name, r.sync], [1, "Russian", true]);

// Alt+Shift on the laptop keyboard: only it moved — that's the new layout for all
r = decide([kb("laptop", 0, true), kb("video-bus", 1)], r.seen, r.cur);
assert.deepEqual([r.cur, r.name, r.sync], [0, "English (US)", true]);

// after the sync everyone agrees: nothing to do, no name (no pill)
r = decide([kb("laptop", 0, true), kb("video-bus", 0)], r.seen, r.cur);
assert.deepEqual([r.cur, r.name, r.sync], [0, "", false]);

// on Russian, a keyboard is plugged in on English and becomes main: keep Russian, pull it in, say nothing
r = decide([kb("laptop", 1), kb("video-bus", 1)], { "0xlaptop": 1, "0xvideo-bus": 1 }, 1);
r = decide([kb("laptop", 1), kb("video-bus", 1), kb("usb", 0, true)], r.seen, r.cur);
assert.deepEqual([r.cur, r.name, r.sync], [1, "", true]);
assert.equal(r.seen["0xusb"], 1);

// the same keyboard reconnects (ydotoold restart, bluetooth): same name, new address, back on English — pulled in, no pill
r = decide([kb("laptop", 1), kb("video-bus", 1), kb("usb", 0, true, "0xusb-again")], r.seen, r.cur);
assert.deepEqual([r.cur, r.name, r.sync], [1, "", true]);
console.log("kbd: 5 cases pass");
