pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs

// gifs for the home cat tile (home/Gif) and its picker in settings → home: all *.gif from Theme.state.gifDir
// (empty — ~/Pictures/Gifs); none there — the built-in cat. The pick — Theme.state.gif, a path; empty — the first
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
    readonly property bool ready: folder.status === FolderListModel.Ready // the folder is read asynchronously: until then the list holds one cat
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
    // the crop for wall.frag that fits a gif of any shape whole in a square: past the edge the texture stretches its edge pixels
    function fit(img) {
        const w = img.implicitWidth, h = img.implicitHeight;
        return w && h ? (w > h ? Qt.size(1, w / h) : Qt.size(h / w, 1)) : Qt.size(1, 1);
    }
}
