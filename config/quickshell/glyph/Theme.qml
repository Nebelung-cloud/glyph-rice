pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings
import "schemes.js" as Schemes

// glyph: чёрный, белые точки, один красный. Палитра, шрифты, движение, состояние (тема, тишина) и вид hypr/kitty — здесь
Singleton {
    id: root

    // состояние переживает перезапуск, его же читает лок (отдельный процесс)
    readonly property alias state: st
    // цвет — откуда (лаунчер → style, настройки → STYLE), как scheme в caelestia: nothing — чёрный, белый и красный; wall —
    // из тона обоев по варианту, как dynamic в caelestia (tonal spot, fruit salad… — schemes.js); scheme — готовая палитра, тема
    // у неё своя. Палитра — { light, c: серые по ролям ниже, accent, red, ansi: 16 цветов kitty }
    readonly property var pal: make({})
    readonly property bool light: pal.light

    // светлая тема — та же раскладка, серые наоборот; красный не меняется
    readonly property var glyphDark: ["#000000", "#0E0E0E", "#1A1A1A", "#2A2A2A", "#4A4A4A", "#8C8C8C", "#F2F2F2"]
    readonly property var glyphLight: ["#E9E9E9", "#FFFFFF", "#F1F1F1", "#D9D9D9", "#B8B8B8", "#6E6E6E", "#0B0B0B"]
    readonly property var greys: pal.c
    readonly property color bg: greys[0]   // фон, обои
    readonly property color s1: greys[1]   // бар, панели
    readonly property color s2: greys[2]   // плитки, выкл.
    readonly property color s3: greys[3]   // линии, погасшие точки
    readonly property color mute: greys[4] // неактивное
    readonly property color grey: greys[5] // метки, вторичное
    readonly property color fg: greys[6]   // текст, вкл., фокус
    readonly property color ink: light ? s1 : bg // текст на белой плитке
    readonly property color accent: pal.accent // максимум одна вещь на экране, и только «живое»
    readonly property color red: pal.red       // тревога: батарея, критическое, не тот пароль
    readonly property color nothingRed: "#D71921"
    readonly property color glow: light ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrim: fade(bg, light ? 0.8 : 0.74)

    readonly property string dot: "Doto"                   // цифры и короткие слова, не мельче 26px
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "Space Mono"            // метки капсом
    readonly property string nf: "JetBrainsMono Nerd Font" // иконки

    // холст макета 1920×1080 → экран. ponytail: по первому экрану; мониторы разного размера — считать от screen окна
    readonly property real s: {
        const sc = Quickshell.screens[0];
        return sc ? Math.min(sc.width / 1920, sc.height / 1080) : 1;
    }

    // glide: ease-out-quart, без перелёта — как bezier glide в hypr
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    // обои рисуются из копии под экран (её делает пикер, magick): оригинал бывает png на 40 МБ, грузился бы секунды.
    // ponytail: копии нет (кэш стёрли, путь вписан руками) — пусто, сетка и шар, пока не открыть пикер
    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/glyph/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : ""; }

    // ---- тона обоев: до четырёх на выбор, как в android. Они в glyph.json: лок (отдельный процесс) берёт готовые и не мигает
    // красным ----
    readonly property var tones: st.wall ? st.tones : []
    function hueName(c) {
        const h = Qt.color(c).hslHue * 360;
        return ["red", "orange", "yellow", "green", "teal", "blue", "violet", "pink", "red"][[15, 40, 65, 160, 195, 250, 290, 335, 361].findIndex(x => h < x)];
    }
    // палитра, какой она была бы при st с заменой o ({ paint, scheme, at, variant, light }): ею живёт шелл (o пустое), её же
    // показывают образцы STYLE. Тонов нет (серые обои, нет картинки) — nothing
    function make(o) {
        const k = Object.assign({ paint: st.paint, scheme: st.scheme, at: st.paintAt, variant: st.variant, light: st.light }, o);
        if (k.paint === "scheme") return Schemes.ALL.find(p => p.id === k.scheme) ?? Schemes.ALL[0];
        // 16 ANSI glyph: в светлой 0↔15 и 7↔8, чтобы белое не терялось на белом
        const base = { light: k.light, c: k.light ? glyphLight : glyphDark, accent: nothingRed, red: nothingRed,
                       ansi: k.light ? [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => ansi[i]) : ansi };
        const src = tones[Math.min(k.at, tones.length - 1)];
        return k.paint === "wall" && src ? Schemes.dynamic(src, k.variant, base) : base;
    }
    // тема: у палитры — она сама или пара из её группы (mocha → latte, dawn → main); пары нет (nord, dracula…) — темы не
    // меняем, иначе st.light разошёлся бы с экраном и всплыл при смене источника
    function pair(l) { return st.paint !== "scheme" ? null : pal.light === l ? pal : Schemes.ALL.find(x => x.group === pal.group && x.light === l) ?? null; }
    function setLight(l) {
        const p = pair(l);
        if (st.paint === "scheme" && !p) return;
        if (p) st.scheme = p.id;
        st.light = l;
    }
    // выбор для лаунчера (style) и настроек (STYLE): блоки { head, items: [{ name, pal, fill, dot, now, run }] }; pal — палитра,
    // если выбрать, fill — круг-образец, dot — круг поменьше в нём (акцент), now — стоит сейчас. Сначала откуда цвет, под ним —
    // что у этого источника: тона обоев и варианты или палитры по группам; в конце тема
    readonly property var styles: {
        const set = (k, v) => () => st[k] = v, at = Math.min(st.paintAt, tones.length - 1);
        const it = (name, p, now, run, fill) => ({ name, pal: p, fill: fill ?? p.c[1], dot: p.accent, now, run });
        const own = st.paint === "wall" ? [
            { head: "tones", items: tones.map((t, i) => it(hueName(t), make({ at: i }), at === i, set("paintAt", i), t)) },
            // круг — серый mute варианта (видно, в какой цвет ушли серые), в нём акцент; amount — доля цвета, по порядку
            { head: "variant", items: tones.length ? Schemes.VARIANTS.map((v, i) => {
                const p = make({ variant: v.id });
                return Object.assign(it(v.name, p, st.variant === v.id, set("variant", v.id), p.c[4]), { amount: i / (Schemes.VARIANTS.length - 1) });
            }) : [] }
        ] : st.paint === "scheme" ? Schemes.GROUPS.map(g => ({ head: g, items: Schemes.ALL.filter(p => p.group === g).map(p =>
            Object.assign(it(p.name, p, st.scheme === p.id, () => { st.scheme = p.id; st.light = p.light; }), { extra: g })) })) : [];
        return [{ head: "source", items: [
            it("nothing", make({ paint: "" }), !st.paint || st.paint === "wall" && !tones.length, set("paint", ""), nothingRed),
            it("wallpaper", make({ paint: "wall" }), st.paint === "wall" && !!tones.length, set("paint", "wall"), tones[0]),
            it("palette", make({ paint: "scheme" }), st.paint === "scheme", set("paint", "scheme"))
        ] }].concat(own.filter(b => b.items.length), [
            { head: "theme", items: [["dark", false], ["light", true]].map(([n, l]) => it(n, make({ light: l, scheme: pair(l)?.id ?? st.scheme }),
                light === l, () => setLight(l))) }
        ]);
    }
    // как score в material you, только проще: квантайзер режет картинку на 16 равных по площади кусков и отдаёт средний цвет
    // каждого. Голосуют сочные (цветность — max − min каналов — больше 0.12; ниже побеждают большие блёклые заливки, а не цвет
    // картинки): впереди оттенок, которого больше (±15°), среди своих — самый сочный. Дальше — до трёх других, не ближе 30°
    // друг к другу. Сочных нет — тонов нет, остаётся красный. Зовёт квантайзер в shell.qml (не здесь: Theme грузит и лок)
    function pick(cols) {
        const ch = c => c.hsvSaturation * c.hsvValue, d = (a, b) => Math.abs((a.hsvHue - b.hsvHue + 1.5) % 1 - 0.5);
        const all = Array.from(cols), live = all.filter(c => ch(c) > 0.12);
        const score = c => 0.7 * live.filter(o => d(o, c) < 1 / 24).length / all.length + 0.3 * ch(c);
        const out = [];
        for (const c of live.sort((a, b) => score(b) - score(a)))
            if (out.length < 4 && out.every(o => d(o, c) >= 1 / 12)) out.push(c);
        return out.map(c => c.toString());
    }
    // яркость, относительная, как в WCAG
    function lum(c) { c = Qt.lighter(c, 1); const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); }
    // что писать поверх цвета c: чёрное или белое, где контраст больше (порог яркости 0.18 — по WCAG)
    function on(c) { return lum(c) > 0.18 ? "#000000" : "#FFFFFF"; }

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    // радиус угла панели, плитки, пилюли — по настройке corners (prefs → WINDOWS → panels): 0 прямые, 100 как задумано
    function corner(px) { return px * st.corners / 100; }
    // часы по настройке 12/24: «09» или «9»
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    readonly property string riceState: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice"
    // как в Rules: apply() на старте должен видеть glyph.json, а не умолчания
    Component.onCompleted: stateFile.waitForJob()

    FileView {
        id: stateFile
        path: root.riceState + "/glyph.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // запись — раз в конце хода: writeAdapter() на каждое поле подряд путает соседние
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property string paint: ""     // откуда цвет: пусто — nothing, wall — обои, scheme — палитра
            property string scheme: "mocha" // какая палитра, id из schemes.js
            property int paintAt: 0       // какой из тонов обоев
            property var tones: []        // тона обоев, их пишет квантайзер; пусто — серые обои или нет картинки
            property string variant: "tonalspot" // как тон обоев становится палитрой, id из schemes.js (VARIANTS)
            property bool dnd: false  // новые не показываются, критические — всегда
            property int unread: 0    // для лока
            // ---- то, что крутят настройки (prefs) ----
            property var widgets: ["weather", "calendar", "cpu", "player", "buds", "system"] // бенто дома по порядку, см. kinds
            property bool clock24: true
            property bool blink: true      // двоеточие часов мигает
            property string name: ""       // в приветствии; пусто — $USER
            property bool grid: true       // сетка точек на обоях
            property bool orb: true        // полутоновый шар
            // обои (пикер wall/Walls, рисует components/Wall): путь к картинке; пусто — сетка и шар. Папку пикера можно сменить здесь
            property string wall: ""
            property string wallDir: ""    // пусто — ~/Pictures/Wallpapers
            property int wallLook: 0       // 0 точки, 1 серое фото, 2 цвет, 3 цветные точки
            property int wallPitch: 10     // шаг точек, px
            property int wallBright: 85    // %, от фона до картинки
            property string gif: ""        // гифка плитки-кота (services/Gifs), путь; пусто — первая в папке
            property string gifDir: ""     // пусто — ~/Pictures/Gifs
            property int rounding: 20      // окна hypr
            property int corners: 100      // углы панелей шелла, % от своих; круги остаются кругами (Theme.corner)
            property bool edges: true      // Glyph-полосы по краям (громкость/яркость, вспышки, прогресс)
            property int briSteps: 20      // яркость с клавиш: делений на шкалу, 40/20/10 — шаг 2.5/5/10 %
            property bool quickHover: true // быстрые настройки по наведению на правый край
            property bool deckHover: true  // deck — панель снизу по центру, вылезает по наведению на край
            property var deck: ["clock", "weather", "perf", "net", "media"] // её секции по порядку, см. decks
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"] // трей бара сверху вниз, см. bars
            property bool barTitle: true   // заголовок окна столбиком в баре
            property string barAt: "left" // left или top; за баром едут календарь, карточка батареи, дом, остров и вспышка Glyph
            // запись (quick/Rec, Sys.recArgs)
            property int recArea: 0        // 0 весь монитор, 1 область (slurp)
            property int recAudio: 0       // 0 без звука, 1 система, 2 микрофон, 3 оба одной дорожкой
            property int recFps: 60
            property int recQuality: 2     // medium, high, very_high, ultra
            property bool recCursor: true
        }
    }

    // виджеты бенто: id → ширина в ячейках (сетка 3 колонки × 3 ряда по 220). Не влезло — не показывается
    readonly property var kinds: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, gpu: 1, disk: 1, battery: 1, buds: 1, player: 2, system: 3, cat: 1, cava: 1 })
    // секции deck
    readonly property var decks: ["clock", "weather", "perf", "net", "media"]
    // трей бара
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power", "cat"]

    // ---- вид всего, что вне шелла. Зовёт только shell.qml: на старте, при смене темы и цвета ----
    // hypr наследует demonshot: монитор, ввод, простой, ночник и движение ставит его же Rules (shell.qml), анимации — из
    // конфига hypr. Отсюда — зазоры/рамка/blur/тени из его rules.json, а свои у glyph — цвета рамок, тени, групп, фон и
    // скругление 20 (без них остались бы красные свечение и группы demonshot из hypr/variables.lua).
    // Обратно к demonshot: `rice switch` делает hyprctl reload, его applyAll перекрасит
    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // kitty подключает этот файл после своих цветов (include в kitty.conf); demonshot пишет туда же свою палитру
    FileView { id: kitty; path: Quickshell.env("HOME") + "/.config/demonshot/kitty.conf"; printErrors: false }
    // 16 ANSI из концепта: пастель только терминалу. Светлая тема их переставляет (make)
    readonly property var ansi: ["#0E0E0E", "#D71921", "#9BB59A", "#D9C38A", "#8EA3C2", "#B79BC2", "#8FB8B8", "#C9C9C9",
                                 "#4A4A4A", "#F0434B", "#B5CCB4", "#E8D6A8", "#AABBD4", "#CDB6D6", "#ABCDCD", "#F2F2F2"]

    function apply() {
        // игровой режим (Rules.store.game) — поверх настроек, как ultra: рамка 1, без зазоров и скругления, tearing для
        // окон с immediate (игры, hyprland/rules.lua). Вышли — свои значения вернутся, allow_tearing — false, как в general.lua
        const r = Rules.store, g = r.game;
        const c = x => `"rgb(${hex(x)})"`;
        // тень: в тёмной — еле заметное белое свечение, в светлой — мягкая чёрная
        const shadow = light ? "rgba(0000002E)" : `rgba(${hex(fg)}1A)`;
        hypr(`hl.config({ general = { gaps_in = ${g ? 0 : r.gapsIn}, gaps_out = ${g ? 0 : r.gapsOut}, border_size = ${g ? 1 : r.border}, allow_tearing = ${g}, `
           + `col = { active_border = ${c(fg)}, inactive_border = ${c(s3)} } }, `
           + `decoration = { rounding = ${g ? 0 : st.rounding}, blur = { enabled = ${Rules.blurOn} }, shadow = { enabled = ${Rules.shadowOn}, color = "${shadow}" } }, `
           + `group = { col = { border_active = ${c(fg)}, border_inactive = ${c(s3)}, border_locked_active = ${c(fg)}, border_locked_inactive = ${c(mute)} }, `
           + `groupbar = { font_family = "${mono}", text_color = ${c(fg)}, col = { active = ${c(s3)}, inactive = ${c(s1)}, locked_active = ${c(s3)}, locked_inactive = ${c(s1)} } } }, `
           + `misc = { background_color = ${c(bg)} } })`);

        kitty.setText("# glyph: пишет Theme.apply(), руками не править\n" + [
            ["font_family", "Space Mono"], ["window_padding_width", "26 30"], ["cursor_trail", "0"],
            ["foreground", fg], ["background", s1], ["cursor", fg], ["cursor_text_color", s1],
            ["selection_foreground", fg], ["selection_background", s3], ["url_color", grey],
            ["active_border_color", fg], ["inactive_border_color", s3],
            ["active_tab_foreground", ink], ["active_tab_background", fg],
            ["inactive_tab_foreground", grey], ["inactive_tab_background", s1], ["tab_bar_background", bg]
        ].concat(pal.ansi.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
    }

    // gtk и qt — только при смене цвета (shell.qml): apply() зовут и на каждый шаг кольца скругления. Шаблоны — свои term/
    // (тёмная палитра glyph): её цвета в них меняются на цвета тех же ролей в палитре (серые, красный, у qt ещё
    // зелёный/жёлтый/синий… из ansi), копии — в riceState/glyph, ссылки ~/.config/… — на копии. Менять нечего — обратно на
    // term/, как ставит rice. Настоящий файл (не ссылку) не трогаем, как rice. Подмена в два прохода через @n@: цвет палитры
    // может совпасть с цветом glyph, что заменяется следом. gtk и qt берут цвета при следующем запуске: свой gtk.css gtk читает
    // один раз, дёрнуть тему не помогает (проверено на gtk 3 и 4).
    // ponytail: светлая тема здесь тёмная — база gtk тёмная (adw-gtk3-dark): у обоев — тот же вариант в тёмной, у палитр —
    // тёмная пара (latte → mocha), у nothing — glyph; светлой — менять ещё gtk-theme и color-scheme. btop не красим — его папка
    // ссылкой целиком в репо, копию некуда деть; понадобится — color_theme путём до копии
    function apps() {
        const from = glyphDark.concat(ansi.slice(1, 7));
        const p = pal.light ? pair(false) ?? make({ light: false }) : pal;
        const to = p.c.concat([p.red], p.ansi.slice(2, 7));
        const pairs = from.map((c, i) => [c, "#" + hex(Qt.lighter(to[i], 1))]).filter(([a, b]) => a !== b);
        const sed = pairs.map(([a], i) => ["-e", `s/${a}/@${i}@/gI`]).concat(pairs.map(([, b], i) => ["-e", `s/@${i}@/${b}/g`])).reduce((x, y) => x.concat(y), []);
        Quickshell.execDetached(["bash", "-c", `t=$1 o=$2; shift 2
for f in gtk-3.0/gtk.css gtk-4.0/gtk.css qtengine.colors; do
    l=$HOME/.config/$f
    [ -L "$l" ] || [ ! -e "$l" ] || continue
    if [ $# -gt 0 ]; then mkdir -p "$(dirname "$o/$f")" && sed "$@" "$t/$f" > "$o/$f" && ln -sfn "$o/$f" "$l"; else ln -sfn "$t/$f" "$l"; fi
done`,
            "bash", Quickshell.shellPath("term"), riceState + "/glyph"].concat(sed));
    }
}
