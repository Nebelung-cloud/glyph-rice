.pragma library

// one layout for every keyboard. grp:alt_shift_toggle switches only the keyboard it was pressed on, and a keyboard
// plugged in later starts on the first layout — then the bar showed one layout while a key typed another (#27).
// ks — hyprctl devices -j .keyboards; seen — { address: layout index } from the last call ({} at start); cur — the current index.
// Returns { cur, name: the layout's name or "" to keep the old one, sync: some keyboard is off cur, seen }
function decide(ks, seen, cur) {
    const start = !Object.keys(seen).length;
    // at start — the main keyboard; later — a known keyboard whose layout moved since last time: that one was switched
    const lead = start ? ks.find(k => k.main) ?? ks[0] : ks.find(k => k.address in seen && seen[k.address] !== k.active_layout_index);
    if (lead) cur = lead.active_layout_index;
    const next = {}; // not Object.fromEntries: Quickshell's JS engine doesn't have it
    for (const k of ks) next[k.address] = cur; // by address: a keyboard that reconnects gets a new one, so it joins like a new keyboard
    return { cur, name: lead ? lead.active_keymap : "", sync: ks.some(k => k.active_layout_index !== cur), seen: next };
}
