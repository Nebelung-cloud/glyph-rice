#version 440
// обои: картинка матрицей точек-светодиодов (dots 1) или фото (dots 0), mono — в тон темы (lo…hi), иначе цвет.
// Смена — волна от origin: клетка решает целиком, перед фронтом srcA, за ним srcB. На гребне клетка всегда точка,
// вспухает и светлеет — фото рассыпается в матрицу и собирается уже новым. Сторона без картинки прозрачная (под ней сетка
// и шар дома), гребень по ней всё равно бежит
// собрать: qsb --qt6 -o wall.frag.qsb wall.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;   // px
    vec2 origin; // px, откуда волна
    vec2 cropA;  // видимая доля текстуры по x/y (PreserveAspectCrop)
    vec2 cropB;
    vec4 lo;     // тёмный конец тона
    vec4 hi;     // светлый
    vec4 bg;
    float pitch;  // шаг точек, px
    float dots;   // 0 фото … 1 точки
    float mono;   // 0 цвет … 1 тон
    float bright; // 0 … 1: от фона до картинки
    float wave;   // 0 … 1
    float hasA;
    float hasB;
};
layout(binding = 1) uniform sampler2D srcA;
layout(binding = 2) uniform sampler2D srcB;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;

    // фронт шириной band идёт от origin до дальнего угла; k — 0 ещё старая … 1 уже новая
    float band = pitch * 14.0;
    float far = length(max(origin, size - origin)) + band;
    float k = clamp((wave * far - distance(c, origin)) / band, 0.0, 1.0);
    float crest = 1.0 - abs(2.0 * k - 1.0);
    bool isB = k > 0.5;
    float has = isB ? hasB : hasA;

    // d 0 — свой пиксель, 1 — центр клетки: между ними картинка в клетке сжимается к центру (плавная пикселизация)
    float d = max(dots, crest);
    vec2 uv = mix(p, c, d) / size - 0.5;
    vec4 t = isB ? texture(srcB, uv * cropB + 0.5) : texture(srcA, uv * cropA + 0.5);
    vec3 rgb = t.rgb + bg.rgb * (1.0 - t.a); // прозрачное в картинке — на фон
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));
    vec3 col = has > 0.5 ? mix(bg.rgb, mix(rgb, mix(lo.rgb, hi.rgb, l), mono), bright) : bg.rgb;
    col = mix(col, hi.rgb, 0.4 * crest);

    // точка: радиус от «вся клетка» (фото) до .3 шага (как Dm), на гребне вспухает
    float r = pitch * mix(0.75, 0.3, d) * (1.0 + 0.55 * crest);
    float m = 1.0 - smoothstep(r - 0.6, r + 0.6, distance(p, c));
    float a = has > 0.5 ? 1.0 : m * crest;
    fragColor = vec4(mix(bg.rgb, col, m) * a, a) * qt_Opacity;
}
