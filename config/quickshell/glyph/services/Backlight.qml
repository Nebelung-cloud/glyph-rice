pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// подсветка экрана, как в caelestia — устройство не зашито: то, что берёт brightnessctl по умолчанию (первое backlight).
// Значение — из sysfs: inotify на нём молчит, но запись в brightness шлёт uevent change — ждём его от udev, а не опрашиваем.
// Нет подсветки (настольный ПК) — dev пустой, value 0. ponytail: внешние мониторы по DDC (ddcutil, как у caelestia) — нет
Singleton {
    id: root

    property string dev: ""       // /sys/class/backlight/<имя>
    property real value: 0        // 0…1
    property int steps: 20        // делений шкалы для клавиш; glyph ставит из настроек (Sys)
    signal moved()                // каждый uevent, даже если значение то же (клавиша на максимуме) — для OSD

    function read() {
        cur.reload();
        const v = parseInt(cur.text());
        if (!isNaN(v)) value = v / (parseInt(max.text()) || 1);
    }
    // value ставим сразу, не ждём brightnessctl и uevent; пока свои записи в пути, их uevent'ы не читаем — sync сверит потом
    // сырым числом, не процентом: округление до % сбивало бы сетку step() (81 % → вверх → 99, не 100)
    function set(v) {
        const m = parseInt(max.text()) || 0;
        if (!m) return;
        const raw = Math.round(Math.max(0.01, Math.min(1, v)) * m);
        value = raw / m;
        sync.restart();
        const devName = dev.slice(dev.lastIndexOf("/") + 1);
        Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", devName, String(raw)]);
        Quickshell.execDetached(["brightnessctl", "-q", "-d", devName, "set", String(raw)]);
    }
    // клавиши: steps делений по корню 4-й степени (20 — как у brightnessctl -e4 5%), внизу шкалы мельче. Шаг от ближайшего
    // деления, а не от value: иначе дробная ошибка копится (вверх до 399998 вместо 400000)
    function step(d) {
        set(Math.pow(Math.max(0, Math.min(steps, Math.round(Math.pow(value, 0.25) * steps) + d)) / steps, 4));
        moved();
    }
    Timer { id: sync; interval: 300; onTriggered: root.read() }
    GlobalShortcut { appid: "shell"; name: "briUp"; description: "яркость +"; onPressed: root.step(1) }
    GlobalShortcut { appid: "shell"; name: "briDown"; description: "яркость −"; onPressed: root.step(-1) }

    FileView { id: cur; path: root.dev ? root.dev + "/brightness" : ""; blockAllReads: true; printErrors: false }
    FileView { id: max; path: root.dev ? root.dev + "/max_brightness" : ""; blockLoading: true; printErrors: false }

    // brightnessctl -m: «имя,класс,текущее,процент,максимум»
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim().split(",")[0];
                if (!name) return;
                root.dev = "/sys/class/backlight/" + name;
                root.read();
            }
        }
    }
    Process {
        running: !!root.dev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser { onRead: l => { if (l.includes(" change ")) { if (!sync.running) root.read(); root.moved(); } } }
    }
}
