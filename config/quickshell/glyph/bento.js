.pragma library

// the home bento: a 3 × 3 grid of cells 0–8 (reading order). ids — which widgets, in list order (Theme.state.widgets); at — where some
// of them sit, id → the cell of their left end (Theme.state.widgetAt); kinds — id → width in cells. Shared by home and settings.
// Placed first: `first` (the one being moved), then the others with a valid free cell, in list order. The rest flow in reading order
// from where the last flowing one ended, a widget too wide for what's left of a row starts the next one (the hole stays) — with no
// `at` this is exactly the old order-only layout. No room — fits: false (shown off grid in settings, not on home)
function layout(ids, at, kinds, first) {
    const grid = Array(9).fill(null);
    const out = ids.filter(id => kinds[id]).map(id => ({ id, i: ids.indexOf(id), span: kinds[id], row: -1, col: -1, fits: false }));
    const free = (c, w) => c >= 0 && c < 9 && c % 3 + w <= 3 && grid.slice(c, c + w).every(x => x === null);
    const put = (o, c) => {
        for (let k = 0; k < o.span; k++) grid[c + k] = o.id;
        o.row = Math.floor(c / 3);
        o.col = c % 3;
        o.fits = true;
    };
    const pinned = out.filter(o => Number.isInteger(at?.[o.id]));
    pinned.sort((a, b) => (b.id === first) - (a.id === first));
    for (const o of pinned) if (free(at[o.id], o.span)) put(o, at[o.id]);
    let k = 0;
    for (const o of out) {
        if (o.fits) continue;
        let c = k;
        while (c < 9 && !free(c, o.span)) c = c % 3 + o.span > 3 ? (Math.floor(c / 3) + 1) * 3 : c + 1;
        if (c < 9) {
            put(o, c);
            k = c + o.span;
        }
    }
    return out;
}

// where everything that fits sits now: id → cell. Saved after every edit, so nothing reflows later
function cellsOf(cells) {
    const at = {};
    for (const o of cells) if (o.fits) at[o.id] = o.row * 3 + o.col;
    return at;
}

// move id so its left end is at cell c (pulled left if it would stick out of the row). The one it lands on swaps into its old cell;
// what can't stay flows to the next free place. Returns the new `at`
function move(ids, at, kinds, id, c) {
    const span = kinds[id] ?? 1, row = Math.max(0, Math.min(2, Math.floor(c / 3)));
    c = row * 3 + Math.max(0, Math.min(3 - span, c % 3));
    const now = layout(ids, at, kinds), me = now.find(o => o.id === id);
    const old = me?.fits ? me.row * 3 + me.col : undefined;
    const hit = now.filter(o => o.fits && o.id !== id && o.row * 3 + o.col < c + span && c < o.row * 3 + o.col + o.span);
    const next = Object.assign(cellsOf(now), { [id]: c });
    for (const o of hit) delete next[o.id];
    if (hit.length === 1 && old !== undefined) next[hit[0].id] = old;
    return cellsOf(layout(ids, next, kinds, id));
}
