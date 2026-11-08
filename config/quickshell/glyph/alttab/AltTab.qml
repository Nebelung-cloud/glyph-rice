import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs
import qs.components
import qs.settings

// AltTab: переключатель открытых приложений Nothing OS на весь экран
// Отображает все запущенные программы (включая свёрнутые), переключает фокус
// и раскрывает выбранное приложение во весь экран (fullscreen 1 / maximized)
PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "glyph-alttab"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore

    property bool open: false
    visible: open

    property var windowList: []
    property int selectedIndex: 0

    // Автоматическое подтверждение при задержке без отпускания клавиши
    Timer {
        id: autoCommitTimer
        interval: 1000
        onTriggered: if (root.open) root.commit()
    }

    readonly property var glyphs: [
        ["whatsapp", "\u{F232}"], ["telegram", "\u{F2C6}"], ["discord", "\u{F066F}"], ["vesktop", "\u{F066F}"],
        ["kitty", "\u{F018D}"], ["terminal", "\u{F018D}"], ["ptyxis", "\u{F018D}"], ["foot", "\u{F018D}"],
        ["antigravity", "\u{F0A1E}"], ["code", "\u{F0A1E}"], ["cursor", "\u{F0A1E}"], ["vscode", "\u{F0A1E}"],
        ["calc", "\u{F00EC}"], ["sheet", "\u{F00EC}"], ["calculator", "\u{F00EC}"], ["writer", "\u{F0219}"],
        ["files", "\u{F024B}"], ["nautilus", "\u{F024B}"], ["dolphin", "\u{F024B}"],
        ["spotify", "\u{F04C7}"], ["music", "\u{F04C7}"], ["vlc", "\u{F040A}"], ["steam", "\u{F04D3}"],
        ["brave", "\u{F0239}"], ["firefox", "\u{F0239}"], ["zen", "\u{F0239}"], ["chrom", "\u{F059F}"], ["browser", "\u{F0239}"]
    ]

    function findGlyph(key) {
        if (!key) return "";
        const k = key.toLowerCase();
        return glyphs.find(g => k.includes(g[0]))?.[1] ?? "";
    }

    function resolveIcon(cls, initCls) {
        if (!cls && !initCls) return "";
        const c = (cls || "").toLowerCase();
        const ic = (initCls || "").toLowerCase();
        const entry = DesktopEntries.heuristicLookup(cls) || (initCls ? DesktopEntries.heuristicLookup(initCls) : null);
        if (entry?.icon) {
            const p = Quickshell.iconPath(entry.icon, true);
            if (p) return p;
            return "image://icon/" + entry.icon;
        }
        if (c.includes("brave")) return Quickshell.iconPath("brave-browser", true) || "file:///usr/share/icons/hicolor/48x48/apps/brave-browser.png";
        if (c.includes("antigravity")) return Quickshell.iconPath("antigravity-ide", true) || "";
        if (c.includes("terminal") || c.includes("kitty")) return Quickshell.iconPath("org.gnome.Terminal", true) || "";
        if (c.includes("nautilus")) return Quickshell.iconPath("org.gnome.Nautilus", true) || "";
        if (c.includes("calc")) return Quickshell.iconPath("libreoffice-calc", true) || "";
        return "image://icon/" + (cls || initCls);
    }

    function scanWindows() {
        Hyprland.refreshToplevels();
        const toplevels = Hyprland.toplevels.values;
        const res = [];
        for (const t of toplevels) {
            const ipc = t.lastIpcObject;
            const cls = (ipc?.class || t.title || "").trim();
            if (!cls) continue;
            const initCls = (ipc?.initialClass || "").trim();
            const wsName = t.workspace?.name || ipc?.workspace?.name || "";
            const isMin = wsName.startsWith("special:minimized") || (t.workspace?.id < 0) || (ipc?.workspace?.id < 0);
            const addr = ipc?.address || t.address;
            if (!addr) continue;

            let name = "";
            const entry = DesktopEntries.heuristicLookup(cls) || (initCls ? DesktopEntries.heuristicLookup(initCls) : null);
            if (entry?.name) name = entry.name;
            else if (t.title) name = t.title.split(" - ").pop().split(" — ").pop().trim();
            if (!name) name = cls;

            let g = findGlyph(name);
            if (!g && t.title) g = findGlyph(t.title);
            if (!g) g = findGlyph(cls + " " + initCls);
            const ico = resolveIcon(cls, initCls);

            res.push({
                address: addr,
                cls: cls,
                name: name,
                title: t.title || name,
                workspace: wsName,
                minimized: isMin,
                focusHistoryID: ipc?.focusHistoryID ?? 999,
                glyph: g,
                icon: ico
            });
        }
        res.sort((a, b) => a.focusHistoryID - b.focusHistoryID);
        root.windowList = res;
    }

    function next() {
        if (!root.open) {
            scanWindows();
            if (root.windowList.length === 0) return;
            root.selectedIndex = root.windowList.length > 1 ? 1 : 0;
            root.open = true;
        } else {
            if (root.windowList.length > 0) {
                root.selectedIndex = (root.selectedIndex + 1) % root.windowList.length;
            }
        }
        autoCommitTimer.restart();
    }

    function prev() {
        if (root.open && root.windowList.length > 0) {
            root.selectedIndex = (root.selectedIndex - 1 + root.windowList.length) % root.windowList.length;
            autoCommitTimer.restart();
        }
    }

    function commit() {
        autoCommitTimer.stop();
        if (!root.open) return;
        root.open = false;

        const target = root.windowList[root.selectedIndex];
        if (!target) return;

        // Если окно в special:minimized, возвращаем на текущий воркспейс
        if (target.minimized) {
            const curWs = Hyprland.focusedWorkspace?.id ?? 1;
            Hyprland.dispatch(`movetoworkspace ${curWs},address:${target.address}`);
        }

        // Переводим фокус на выбранное окно и поднимаем на передний план (модель Ubuntu)
        Hyprland.dispatch(`focuswindow address:${target.address}`);
        Hyprland.dispatch("bringactivetotop");
    }

    function cancel() {
        autoCommitTimer.stop();
        root.open = false;
    }

    // Задний фон (scrim) — клик мимо закрывает без изменений
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea {
            anchors.fill: parent
            onClicked: root.cancel()
        }
    }

    // Центрированная карточка переключателя Nothing OS
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.max(380, Math.min(root.width - 60, cardsRow.implicitWidth + 48))
        height: 180
        radius: Theme.corner(24)
        color: Theme.s1
        border { width: 1.5; color: Theme.s2 }

        Column {
            anchors.centerIn: parent
            spacing: 16

            // Заголовок Nothing OS
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.nothingRed
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "APPLICATIONS"
                    font { family: Theme.mono; pixelSize: 11; bold: true; letterSpacing: 2 }
                    color: Theme.grey
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.windowList.length > 0 ? `${root.selectedIndex + 1}/${root.windowList.length}` : ""
                    font { family: Theme.mono; pixelSize: 11 }
                    color: Theme.mute
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Список приложений
            Row {
                id: cardsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: root.windowList

                    Rectangle {
                        id: appCard
                        required property var modelData
                        required property int index

                        readonly property bool isSel: root.selectedIndex === index
                        width: 76
                        height: 84
                        radius: Theme.corner(16)
                        color: isSel ? Theme.s2 : "transparent"
                        border.width: isSel ? 1.5 : 1
                        border.color: isSel ? Theme.fg : Theme.s3
                        scale: isSel ? 1.06 : 1.0

                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selectedIndex = appCard.index
                            onClicked: {
                                root.selectedIndex = appCard.index;
                                root.commit();
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            // Контейнер иконки
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 44
                                height: 44
                                radius: 22
                                color: appCard.isSel && !!appCard.modelData.glyph ? Theme.fg : Theme.s2
                                border.width: 1
                                border.color: appCard.isSel ? Theme.fg : Theme.s3

                                Icon {
                                    anchors.centerIn: parent
                                    visible: !!appCard.modelData.glyph
                                    text: appCard.modelData.glyph
                                    font.pixelSize: 22
                                    color: appCard.isSel ? Theme.ink : Theme.fg
                                }

                                Image {
                                    anchors.centerIn: parent
                                    visible: !appCard.modelData.glyph && status === Image.Ready
                                    width: 26
                                    height: 26
                                    source: appCard.modelData.icon || ""
                                    sourceSize: Qt.size(26, 26)
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        saturation: -1.0
                                        contrast: 0.35
                                        brightness: 0.2
                                    }
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    visible: !appCard.modelData.glyph && (!appCard.modelData.icon || status !== Image.Ready)
                                    text: "\u{EA85}"
                                    font.pixelSize: 20
                                    color: Theme.fg
                                }
                            }

                            // Название приложения
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 68
                                text: appCard.modelData.name
                                font { family: Theme.mono; pixelSize: 10 }
                                color: appCard.isSel ? Theme.fg : Theme.grey
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        // Индикатор свёрнутого окна
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 4
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.grey
                            visible: appCard.modelData.minimized
                        }
                    }
                }
            }

            // Подвал с заголовком активного окна и подсказкой
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(card.width - 32, 600)
                    text: root.windowList[root.selectedIndex]?.title ?? ""
                    font { family: Theme.ui; pixelSize: 13; bold: true }
                    color: Theme.fg
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Alt + Tab to cycle • Release Alt to switch • Click to select"
                    font { family: Theme.mono; pixelSize: 10 }
                    color: Theme.mute
                }
            }
        }
    }
}
