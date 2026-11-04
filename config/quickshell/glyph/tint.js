.pragma library
// color from the wallpaper (Theme.state.match): glyph's greys keep their lightness (OKLCH L), take the wallpaper's hue; red — its accent.
// Pure functions: Theme gives the mono palette, seeds from ColorQuantizer and settings, gets back a palette of hex strings

// styles: saturation (OKLCH chroma) of the grey surfaces n, secondary g, text f; a — the accent multiplier;
// lift — in dark the background rises from black to this lightness (otherwise the hue has nothing to show on); duo — accent from the seed
// farthest in hue
const styles = [
    { name: "tint",   n: 0.012, g: 0.010, f: 0.006, a: 1,    lift: 0 },
    { name: "tonal",  n: 0.028, g: 0.022, f: 0.012, a: 1,    lift: 0.10 },
    { name: "vivid",  n: 0.050, g: 0.040, f: 0.020, a: 1.25, lift: 0.15 },
    { name: "accent", n: 0,     g: 0,     f: 0,     a: 1,    lift: 0 },
    { name: "duo",    n: 0.028, g: 0.022, f: 0.012, a: 1,    lift: 0.10, duo: true }
];
const names = styles.map(s => s.name);

function lin(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
function gam(c) { return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055; }

// "#RRGGBB" or color (r, g, b in 0..1) → { l, c, h }
function oklch(x) {
    if (typeof x === "string") x = { r: parseInt(x.slice(1, 3), 16) / 255, g: parseInt(x.slice(3, 5), 16) / 255, b: parseInt(x.slice(5, 7), 16) / 255 };
    const r = lin(x.r), g = lin(x.g), b = lin(x.b);
    const l_ = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m_ = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s_ = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    const A = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    const B = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;
    return { l: 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_, c: Math.hypot(A, B), h: (Math.atan2(B, A) * 180 / Math.PI + 360) % 360 };
}

function srgb(l, c, h) {
    const a = c * Math.cos(h * Math.PI / 180), b = c * Math.sin(h * Math.PI / 180);
    const L = Math.pow(l + 0.3963377774 * a + 0.2158037573 * b, 3);
    const M = Math.pow(l - 0.1055613458 * a - 0.0638541728 * b, 3);
    const S = Math.pow(l - 0.0894841775 * a - 1.2914855480 * b, 3);
    return [4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S,
            -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S,
            -0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S];
}

// OKLCH → "#RRGGBB"; outside sRGB — cut the saturation, lightness and hue stay
function hex(l, c, h) {
    let v = srgb(l, c, h);
    for (let i = 0; i < 16 && v.some(x => x < -0.001 || x > 1.001); i++) v = srgb(l, c *= 0.8, h);
    return "#" + v.map(x => Math.round(gam(Math.min(1, Math.max(0, x))) * 255).toString(16).padStart(2, "0")).join("").toUpperCase();
}

function hueDist(a, b) { const d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d; }

// ColorQuantizer colors (buckets of roughly equal area) → up to 5 seeds: only noticeably colorful ones, the juiciest first,
// close in hue (< 30°) — one. A grey wallpaper — empty, the palette stays mono
function seeds(colors) {
    const out = [];
    Array.from(colors).map(oklch).filter(x => x.c > 0.035 && x.l > 0.15).sort((a, b) => b.c - a.c)
        .forEach(x => { if (out.length < 5 && out.every(o => hueDist(o.h, x.h) > 30)) out.push(Object.assign(x, { hex: hex(x.l, x.c, x.h) })); });
    return out;
}

// Extra Dark (like in Nothing OS 4): dark theme only. The background — pure black, surfaces a quarter darker; hue and style
// stay, so it works both with and without color from the wallpaper
function extraDark(p) {
    const d = (h, k) => { const x = oklch(h); return hex(x.l * k, x.c * k, x.h); };
    return Object.assign({}, p, { bg: "#000000", ink: "#000000", s1: d(p.s1, 0.7), s2: d(p.s2, 0.75), s3: d(p.s3, 0.8) });
}

// Theme's mono palette ({ bg … ink, red } hex) → tinted. sat — percent, 100 — as the style intends
function paint(mono, light, list, i, style, sat) {
    const s = styles[style] ?? styles[0], k = sat / 100, seed = list[Math.min(i, list.length - 1)];
    const acc = s.duo ? list.reduce((best, x) => hueDist(x.h, seed.h) > hueDist(best.h, seed.h) ? x : best, seed) : seed;
    const t = (role, c, lift) => { const x = oklch(mono[role]); return hex(light ? x.l : Math.max(x.l, lift ?? 0), c * k, seed.h); };
    // light: at the edges of lightness the hue has nowhere to live — white (L 1) and the near-black fg would stay pure. The whites are lowered slightly,
    // so they take on the tint; fg — the wallpaper's deep tone: lifted from black and more saturated, the wallpaper's dots are drawn with it in light
    const lightK = Math.min(1, k);
    const white = (role) => { const x = oklch(mono[role]); return hex(Math.min(x.l, 1 - s.n * 0.6 * lightK), s.n * k, seed.h); };
    const deep = (role, l, c) => { const x = oklch(mono[role]); return hex(Math.max(x.l, l * lightK + x.l * (1 - lightK)), c * k, seed.h); };
    if (light) return {
        bg: t("bg", s.n), s1: white("s1"), s2: t("s2", s.n), s3: t("s3", s.n), mute: t("mute", s.n * 1.2),
        grey: t("grey", s.g * 1.5), fg: deep("fg", s.n ? 0.16 + s.lift * 0.6 : 0, s.n * 2.5), ink: white("ink"),
        red: hex(0.56, Math.min(0.26, Math.max(0.08, acc.c * s.a) * k), acc.h)
    };
    return {
        bg: t("bg", s.n, s.lift), s1: t("s1", s.n, s.lift * 1.25), s2: t("s2", s.n, s.lift * 1.5), s3: t("s3", s.n, s.lift * 1.8),
        mute: t("mute", s.n), grey: t("grey", s.g), fg: t("fg", s.f), ink: t("ink", s.f, s.lift),
        // accent: its own lightness for the theme (something live must read both on the background and under a white icon), saturation — from the seed
        red: hex(0.66, Math.min(0.26, Math.max(0.08, acc.c * s.a) * k), acc.h)
    };
}
