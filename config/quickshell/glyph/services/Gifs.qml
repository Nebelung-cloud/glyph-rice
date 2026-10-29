pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs

// гифки для плитки-кота дома (home/Gif) и её выбора в настройках → home: все *.gif из Theme.state.gifDir
// (пусто — ~/Pictures/Gifs); там ни одной — встроенный кот. Выбор — Theme.state.gif, путь; пусто — первая
Singleton {
    id: root

    readonly property string dir: Theme.state.gifDir || Quickshell.env("HOME") + "/Pictures/Gifs"
    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        nameFilters: ["*.gif"]
        caseSensitive: false
        showDirs: false
    }
    readonly property bool ready: folder.status === FolderListModel.Ready // папку читают асинхронно: до того в списке один кот
    readonly property var list: {
        const a = [];
        for (let i = 0; i < folder.count; i++) a.push(folder.get(i, "filePath"));
        return a.length ? a : [""];
    }
    readonly property int sel: Math.max(0, list.indexOf(Theme.state.gif))
    readonly property string cur: list[sel]

    function pick(p) { Theme.state.gif = p; }
    function step(d) { if (list.length > 1) pick(list[(sel + d + list.length) % list.length]); }
    function name(p) { return p ? p.slice(p.lastIndexOf("/") + 1).replace(/\.gif$/i, "") : "cat"; }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : Qt.resolvedUrl("../home/cat.gif"); }
    // обрезка для wall.frag, при которой гифка любой формы целиком в квадрате: за краем текстура тянет крайние пиксели
    function fit(img) {
        const w = img.implicitWidth, h = img.implicitHeight;
        return w && h ? (w > h ? Qt.size(1, w / h) : Qt.size(h / w, 1)) : Qt.size(1, 1);
    }
}
