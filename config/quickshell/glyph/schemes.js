.pragma library

// palettes for «color → palette» (Theme.pal). c — greys by Theme's roles: bg, s1, s2, s3, mute, grey, fg (s1 — the palette's main
// background, kitty takes it too; bg — darker on dark ones, denser on light ones). accent — «live», red — alarm, ansi — 16 terminal
// colors from kovidgoyal/kitty-themes. group — a block in the launcher and settings; theme ←→ swaps the palette for its pair from the same group
const ALL = [
    { id: "mocha", name: "mocha", group: "catppuccin", light: false,
      c: ["#181825", "#1E1E2E", "#313244", "#45475A", "#585B70", "#7F849C", "#CDD6F4"], accent: "#CBA6F7", red: "#F38BA8",
      ansi: ["#45475A", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#BAC2DE", "#585B70", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#A6ADC8"] },
    { id: "macchiato", name: "macchiato", group: "catppuccin", light: false,
      c: ["#1E2030", "#24273A", "#363A4F", "#494D64", "#5B6078", "#8087A2", "#CAD3F5"], accent: "#C6A0F6", red: "#ED8796",
      ansi: ["#494D64", "#ED8796", "#A6DA95", "#EED49F", "#8AADF4", "#F5BDE6", "#8BD5CA", "#B8C0E0", "#5B6078", "#ED8796", "#A6DA95", "#EED49F", "#8AADF4", "#F5BDE6", "#8BD5CA", "#A5ADCB"] },
    { id: "frappe", name: "frappé", group: "catppuccin", light: false,
      c: ["#292C3C", "#303446", "#414559", "#51576D", "#626880", "#838BA7", "#C6D0F5"], accent: "#CA9EE6", red: "#E78284",
      ansi: ["#51576D", "#E78284", "#A6D189", "#E5C890", "#8CAAEE", "#F4B8E4", "#81C8BE", "#B5BFE2", "#626880", "#E78284", "#A6D189", "#E5C890", "#8CAAEE", "#F4B8E4", "#81C8BE", "#A5ADCE"] },
    { id: "latte", name: "latte", group: "catppuccin", light: true,
      c: ["#DCE0E8", "#EFF1F5", "#E6E9EF", "#CCD0DA", "#ACB0BE", "#6C6F85", "#4C4F69"], accent: "#8839EF", red: "#D20F39",
      ansi: ["#5C5F77", "#D20F39", "#40A02B", "#DF8E1D", "#1E66F5", "#EA76CB", "#179299", "#ACB0BE", "#6C6F85", "#D20F39", "#40A02B", "#DF8E1D", "#1E66F5", "#EA76CB", "#179299", "#BCC0CC"] },
    { id: "rosepine", name: "main", group: "rosé pine", light: false,
      c: ["#191724", "#1F1D2E", "#26233A", "#403D52", "#524F67", "#908CAA", "#E0DEF4"], accent: "#EBBCBA", red: "#EB6F92",
      ansi: ["#26233A", "#EB6F92", "#31748F", "#F6C177", "#9CCFD8", "#C4A7E7", "#EBBCBA", "#E0DEF4", "#6E6A86", "#EB6F92", "#31748F", "#F6C177", "#9CCFD8", "#C4A7E7", "#EBBCBA", "#E0DEF4"] },
    { id: "rosepine-moon", name: "moon", group: "rosé pine", light: false,
      c: ["#232136", "#2A273F", "#393552", "#44415A", "#56526E", "#908CAA", "#E0DEF4"], accent: "#EA9A97", red: "#EB6F92",
      ansi: ["#393552", "#EB6F92", "#3E8FB0", "#F6C177", "#9CCFD8", "#C4A7E7", "#EA9A97", "#E0DEF4", "#6E6A86", "#EB6F92", "#3E8FB0", "#F6C177", "#9CCFD8", "#C4A7E7", "#EA9A97", "#E0DEF4"] },
    { id: "rosepine-dawn", name: "dawn", group: "rosé pine", light: true,
      c: ["#F2E9E1", "#FFFAF3", "#FAF4ED", "#DFDAD9", "#CECACD", "#797593", "#575279"], accent: "#D7827E", red: "#B4637A",
      ansi: ["#F2E9E1", "#B4637A", "#286983", "#EA9D34", "#56949F", "#907AA9", "#D7827E", "#575279", "#9893A5", "#B4637A", "#286983", "#EA9D34", "#56949F", "#907AA9", "#D7827E", "#575279"] },
    { id: "gruvbox", name: "dark", group: "gruvbox", light: false,
      c: ["#1D2021", "#282828", "#3C3836", "#504945", "#665C54", "#928374", "#EBDBB2"], accent: "#FE8019", red: "#FB4934",
      ansi: ["#3C3836", "#CC241D", "#98971A", "#D79921", "#458588", "#B16286", "#689D6A", "#A89984", "#928374", "#FB4934", "#B8BB26", "#FABD2F", "#83A598", "#D3869B", "#8EC07C", "#FBF1C7"] },
    { id: "gruvbox-light", name: "light", group: "gruvbox", light: true,
      c: ["#EBDBB2", "#FBF1C7", "#F2E5BC", "#D5C4A1", "#BDAE93", "#7C6F64", "#3C3836"], accent: "#AF3A03", red: "#9D0006",
      ansi: ["#EBDBB2", "#CC241D", "#98971A", "#D79921", "#458588", "#B16286", "#689D6A", "#7C6F64", "#928374", "#9D0006", "#79740E", "#B57614", "#076678", "#8F3F71", "#427B58", "#282828"] },
    { id: "nord", name: "nord", group: "more", light: false,
      c: ["#242933", "#2E3440", "#3B4252", "#434C5E", "#4C566A", "#616E88", "#D8DEE9"], accent: "#88C0D0", red: "#BF616A",
      ansi: ["#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0", "#4C566A", "#BF616A", "#A3BE8C", "#D08770", "#5E81AC", "#B48EAD", "#8FBCBB", "#ECEFF4"] },
    { id: "dracula", name: "dracula", group: "more", light: false,
      c: ["#191A21", "#282A36", "#343746", "#44475A", "#505877", "#6272A4", "#F8F8F2"], accent: "#BD93F9", red: "#FF5555",
      ansi: ["#21222C", "#FF5555", "#50FA7B", "#F1FA8C", "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2", "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5", "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF"] },
    { id: "tokyonight", name: "tokyo night", group: "more", light: false,
      c: ["#16161E", "#1A1B26", "#292E42", "#3B4261", "#545C7E", "#737AA2", "#C0CAF5"], accent: "#7AA2F7", red: "#F7768E",
      ansi: ["#15161E", "#F7768E", "#9ECE6A", "#E0AF68", "#7AA2F7", "#BB9AF7", "#7DCFFF", "#A9B1D6", "#414868", "#FF899D", "#9FE044", "#FABA4A", "#8DB0FF", "#C7A9FF", "#A4DAFF", "#C0CAF5"] },
    { id: "everforest", name: "everforest", group: "more", light: false,
      c: ["#232A2E", "#2D353B", "#343F44", "#475258", "#56635F", "#859289", "#D3C6AA"], accent: "#A7C080", red: "#E67E80",
      ansi: ["#343F44", "#E67E80", "#A7C080", "#DBBC7F", "#7FBBB3", "#D699B6", "#83C092", "#859289", "#868D80", "#E67E80", "#A7C080", "#DBBC7F", "#7FBBB3", "#D699B6", "#83C092", "#9DA9A0"] },
    { id: "kanagawa", name: "kanagawa", group: "more", light: false,
      c: ["#16161D", "#1F1F28", "#2A2A37", "#363646", "#54546D", "#727169", "#DCD7BA"], accent: "#7E9CD8", red: "#E82424",
      ansi: ["#16161D", "#C34043", "#76946A", "#C0A36E", "#7E9CD8", "#957FB8", "#6A9589", "#C8C093", "#727169", "#E82424", "#98BB6C", "#E6C384", "#7FB4CA", "#938AA9", "#7AA89F", "#DCD7BA"] }
];
const GROUPS = ["catppuccin", "rosé pine", "gruvbox", "more"];

// ---- wallpaper → palette, like dynamic in caelestia (material you). A wallpaper tone is the source color, the variant decides how far to turn the accent's
// hue and how much color it and the greys get. The layout comes from base (the nothing palette of the same theme): greys of the same lightness, the accent at
// red's lightness (lighter in dark: a dull accent gets lost on black), the terminal — glyph's pastel, turned toward the accent
// by at most 15° (harmonize in material). ponytail: not hct but oklch — greys keep their lightness (L oklab = ∛Y), chroma ≈ hct / 360,
// hues slightly different; content and fidelity — without dislike and temperatures. Outside sRGB — chroma down until it fits ----
// a — the accent (primary), n — the surfaces bg, s1, s2, fg (neutral), v — lines and labels s3, mute, grey (neutral variant):
// [hue turn°, hct chroma]. src — chroma as a share of the tone's chroma; keep — the accent is the tone itself, with its lightness (but no
// darker than 0.6 on black and no lighter than red on white — otherwise it's unreadable).
// In order of how much color
const VARIANTS = [
    { id: "monochrome", name: "monochrome", a: [0, 0], n: [0, 0], v: [0, 0] },
    { id: "neutral", name: "neutral", a: [0, 12], n: [0, 2], v: [0, 2] },
    { id: "tonalspot", name: "tonal spot", a: [0, 36], n: [0, 6], v: [0, 8] },
    { id: "rainbow", name: "rainbow", a: [0, 48], n: [0, 0], v: [0, 0] },
    { id: "content", name: "content", a: [0, 1], n: [0, 1 / 8], v: [0, 1 / 6], src: true },
    { id: "fidelity", name: "fidelity", a: [0, 1], n: [0, 1 / 8], v: [0, 1 / 6], src: true, keep: true },
    { id: "fruitsalad", name: "fruit salad", a: [-50, 48], n: [0, 10], v: [0, 16] },
    { id: "expressive", name: "expressive", a: [240, 40], n: [15, 8], v: [15, 12] },
    { id: "vibrant", name: "vibrant", a: [0, 200], n: [0, 10], v: [0, 12] }
];

function lin(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
function gam(v) { return v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(v, 1 / 2.4) - 0.055; }
// "#rrggbb" → [L, C, h°] oklch
function lch(x) {
    const n = parseInt(String(x).slice(1, 7), 16), r = lin((n >> 16 & 255) / 255), g = lin((n >> 8 & 255) / 255), b = lin((n & 255) / 255);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    const A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    return [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, Math.hypot(A, B), (Math.atan2(B, A) * 180 / Math.PI + 360) % 360];
}
// oklch → linear sRGB
function rgb(L, C, h) {
    const A = C * Math.cos(h * Math.PI / 180), B = C * Math.sin(h * Math.PI / 180);
    const l = Math.pow(L + 0.3963377774 * A + 0.2158037573 * B, 3), m = Math.pow(L - 0.1055613458 * A - 0.0638541728 * B, 3);
    const s = Math.pow(L - 0.0894841775 * A - 1.2914855480 * B, 3);
    return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
}
// oklch → "#RRGGBB"; outside sRGB — halve the chroma, 12 steps
function hex(L, C, h) {
    const ok = c => rgb(L, c, h).every(v => v > -1e-4 && v < 1 + 1e-4);
    if (!ok(C)) {
        let lo = 0, hi = C;
        for (let i = 0; i < 12; i++) { const m = (lo + hi) / 2; if (ok(m)) lo = m; else hi = m; }
        C = lo;
    }
    return "#" + rgb(L, C, h).map(v => Math.round(gam(Math.min(1, Math.max(0, v))) * 255).toString(16).padStart(2, "0")).join("").toUpperCase();
}

// Extra Dark (like in Nothing OS 4): a dark palette with a pure black background and surfaces a quarter darker; hue and accent stay
function extraDark(p) {
    const d = (x, k) => { const [l, c, h] = lch(x); return hex(l * k, c * k, h); };
    return Object.assign({}, p, { c: ["#000000", d(p.c[1], 0.7), d(p.c[2], 0.75), d(p.c[3], 0.8), p.c[4], p.c[5], p.c[6]] });
}

// a palette from tone src by variant id; base — { light, c, red, ansi } of nothing in the same theme; sat — %, the saturation dial
function dynamic(src, id, base, sat) {
    const v = VARIANTS.find(x => x.id === id) ?? VARIANTS[2], [sl, sc, sh] = lch(src);
    const amount = (sat ?? 100) / 100; // the saturation dial
    const at = ([d, k]) => [(sh + d + 360) % 360, (v.src ? sc * k : k / 360) * amount];
    const [nh, nc] = at(v.n), [vh, vc] = at(v.v), [ah, ac] = at(v.a);
    // light: at the edges of lightness the hue has nowhere to live, so white is lowered and the near-black text lifted into a deep tone
    const grey = (x, i) => {
        const l = lch(x)[0];
        if (i >= 3 && i < 6) return hex(l, vc, vh);
        if (base.light && nc > 0) return i === 6 ? hex(Math.max(l, 0.22), nc * 2.5, nh) : hex(Math.min(l, 1 - nc), nc, nh);
        return hex(l, nc, nh);
    };
    const c = base.c.map(grey), rl = lch(base.red)[0];
    const al = base.light ? (v.keep ? Math.min(sl, rl) : rl) : v.keep ? Math.max(sl, 0.6) : Math.max(rl, 0.7);
    const accent = !ac ? c[6] : hex(al, ac, ah);
    // terminal: greys — like the surfaces, colored ones — toward the accent, chroma by the accent (monochrome — greys)
    const ansi = base.ansi.map(x => {
        const [l, cc, h] = lch(x);
        if (cc < 0.03) return hex(l, nc, nh);
        const d = (ah - h + 540) % 360 - 180;
        return hex(l, cc * Math.min(1, ac * 10), h + Math.sign(d) * Math.min(Math.abs(d) / 2, 15));
    });
    return { id: "wall", name: v.name, light: base.light, c, accent, red: base.red, ansi };
}
