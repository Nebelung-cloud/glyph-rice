// the home bento layout (config/quickshell/glyph/bento.js): node tests/test_bento.mjs
import fs from "fs"; import assert from "assert";
const src = fs.readFileSync(new URL("../config/quickshell/glyph/bento.js", import.meta.url), "utf8").replace(".pragma library", "");
const B = new Function(src + "; return { layout, cellsOf, move };")();
const K = { weather: 1, calendar: 1, cpu: 1, ram: 1, player: 2, buds: 1, system: 3, cat: 1 };
const pos = (ids, at) => B.cellsOf(B.layout(ids, at, K));
// no `at`: the old order-only layout, holes included
const old = ["weather", "calendar", "cpu", "player", "buds", "system"];
assert.deepStrictEqual(pos(old, {}), { weather: 0, calendar: 1, cpu: 2, player: 3, buds: 5, system: 6 });
assert.deepStrictEqual(pos(["weather", "calendar", "player", "cpu"], {}), { weather: 0, calendar: 1, player: 3, cpu: 5 }); // the hole at 2 stays
// free placement: anywhere, with empty cells around
assert.deepStrictEqual(pos(["cat", "cpu"], { cat: 8, cpu: 4 }), { cat: 8, cpu: 4 });
// an invalid or clashing cell flows instead
assert.deepStrictEqual(pos(["player"], { player: 2 }), { player: 0 });
assert.deepStrictEqual(pos(["cpu", "ram"], { cpu: 4, ram: 4 }), { cpu: 4, ram: 0 });
// too many: off grid
const L = B.layout(["system", "system2", "player", "cat"].filter(x => K[x]), {}, K);
assert.deepStrictEqual(L.map(o => o.fits), [true, true, true]);
assert.strictEqual(B.layout(["system", "player", "cat", "weather", "cpu", "ram", "buds"], {}, K).filter(o => !o.fits).length, 1);
// move into an empty cell
assert.deepStrictEqual(B.move(["cat", "cpu"], { cat: 0, cpu: 1 }, K, "cat", 8), { cpu: 1, cat: 8 });
// onto another: swap
assert.deepStrictEqual(B.move(["cat", "cpu"], { cat: 0, cpu: 4 }, K, "cat", 4), { cpu: 0, cat: 4 });
// a wide one, pulled into its row and swapping with a 1-wide
assert.deepStrictEqual(B.move(["player", "cpu"], { player: 3, cpu: 5 }, K, "player", 5), { player: 4, cpu: 3 });
// a 1-wide onto a wide one that can't take its old cell beside a neighbour: the wide one flows to free room
const m = B.move(["cat", "ram", "player"], { cat: 0, ram: 1, player: 6 }, K, "cat", 7);
assert.strictEqual(m.cat, 7); assert.strictEqual(m.ram, 1); assert.ok(m.player !== undefined && m.player !== 6 && m.player !== 7);
// off-grid one dragged onto the grid
const full = ["system", "player", "weather", "calendar", "cpu", "ram", "cat"];
const at0 = B.cellsOf(B.layout(full, {}, K));
assert.strictEqual(at0.cat, undefined);
const at1 = B.move(full, at0, K, "cat", 8);
assert.strictEqual(at1.cat, 8);
console.log("ok");
