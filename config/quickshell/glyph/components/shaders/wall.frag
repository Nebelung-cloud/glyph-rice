#version 440
// wallpaper: the image as a matrix of LED dots (dots 1) or a photo (dots 0), mono — in the theme's tone (lo…hi), otherwise color; glass — ribbed glass.
// The change — a wave from origin: a cell decides as a whole, ahead of the front srcA, behind it srcB. On the crest a cell is always a dot,
// it swells and brightens — the photo crumbles into the matrix and reassembles as the new one. A side without an image is transparent (the grid
// and the home orb are under it), the crest runs over it anyway
// build: qsb --qt6 -o wall.frag.qsb wall.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;   // px
    vec2 origin; // px, where the wave starts
    vec2 cropA;  // the visible part of the texture in x/y (PreserveAspectCrop)
    vec2 cropB;
    vec4 lo;     // the dark end of the tone
    vec4 hi;     // the light one
    vec4 bg;
    float pitch;  // dot spacing, px
    float dots;   // 0 photo … 1 dots
    float mono;   // 0 color … 1 tone
    float bright; // 0 … 1: from the background to the image
    float wave;   // 0 … 1
    float hasA;
    float hasB;
    float glass;  // 0 … 1: Nothing's ribbed glass over any look
    float rib;    // rib width, px
    float bend;   // 0 … 1: how much a rib bends the image
    float beat;   // 0 … 1: the music's bass
};
layout(binding = 1) uniform sampler2D srcA;
layout(binding = 2) uniform sampler2D srcB;

// glass: vertical ribs of width rib. u — the position within the rib, -1 … 1. A rib is a lens: it pulls the image under it sideways along a sine
// (a break at the rib joints, like real fluting) and blurs slightly along x. For dots the cell center bends — every dot
// shows what's already refracted
float ribU(float x) { return fract(x / rib) * 2.0 - 1.0; }
vec4 pick(bool isB, vec2 sp) {
    vec2 uv = sp / size - 0.5;
    return isB ? texture(srcB, uv * cropB + 0.5) : texture(srcA, uv * cropA + 0.5);
}
vec4 look(bool isB, vec2 sp) {
    if (glass < 0.5) return pick(isB, sp);
    float x = sp.x + sin(ribU(sp.x) * 1.5708) * bend * rib;
    float s = rib * 0.07 * bend; // blur: five samples across the ribs
    return (pick(isB, vec2(x - 2.0 * s, sp.y)) + pick(isB, vec2(x - s, sp.y)) + pick(isB, vec2(x, sp.y))
          + pick(isB, vec2(x + s, sp.y)) + pick(isB, vec2(x + 2.0 * s, sp.y))) / 5.0;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;

    // a front of width band goes from origin to the far corner; k — 0 still the old … 1 already the new
    float band = pitch * 14.0;
    float far = length(max(origin, size - origin)) + band;
    float k = clamp((wave * far - distance(c, origin)) / band, 0.0, 1.0);
    float crest = 1.0 - abs(2.0 * k - 1.0);
    bool isB = k > 0.5;
    float has = isB ? hasB : hasA;

    // d 0 — the pixel itself, 1 — the cell center: in between, the image in the cell shrinks toward the center (smooth pixelation)
    float d = max(dots, crest);
    vec4 t = look(isB, mix(p, c, d));
    vec3 rgb = t.rgb + bg.rgb * (1.0 - t.a); // transparency in the image — onto the background
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));
    vec3 col = has > 0.5 ? mix(bg.rgb, mix(rgb, mix(lo.rgb, hi.rgb, l), mono), bright) : bg.rgb;
    // glass in the light: the rib edges darken toward the background, a thin highlight at the left edge. Computed per pixel — the ribs are visible
    // over the dots too
    if (glass > 0.5 && has > 0.5) {
        float u = ribU(p.x);
        col = mix(col, bg.rgb, 0.35 * pow(abs(u), 6.0));
        col = mix(col, hi.rgb, 0.10 * exp(-pow((u + 0.7) * 9.0, 2.0)));
    }
    col = mix(col, hi.rgb, 0.4 * crest);
    col = mix(col, hi.rgb, 0.3 * beat * l); // the bright parts of the picture lift on the beat

    // a dot: the radius from «the whole cell» (photo) to .3 of the step (like Dm), it swells on the crest
    float r = pitch * mix(0.75, 0.3, d) * (1.0 + 0.55 * crest);
    // beat: dots swell up to ~75 %, light ones most, but stop short of touching their neighbours
    r = mix(r, min(r * (1.0 + 0.85 * beat * (0.6 + 0.4 * l)), pitch * 0.48), d);
    float m = 1.0 - smoothstep(r - 0.6, r + 0.6, distance(p, c));
    float a = has > 0.5 ? 1.0 : m * crest;
    fragColor = vec4(mix(bg.rgb, col, m) * a, a) * qt_Opacity;
}
