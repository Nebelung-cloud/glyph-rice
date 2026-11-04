import QtQuick
import Quickshell.Io
import qs
import qs.components
import "../prefs"

// default apps, like xdg-mime in the terminal: each row lists those that say they can handle that type themselves
// (MimeType= in .desktop), picking one sets it for all the row's types. Hidden ones (NoDisplay) — only if already chosen
Page {
    id: root
    property bool live
    caption: "default apps · xdg-mime"

    // a row: the label and the types; by the first one we find who can handle it and who's set now
    readonly property var kinds: [
        ["web browser", "x-scheme-handler/https x-scheme-handler/http text/html application/xhtml+xml"],
        ["files", "inode/directory"],
        ["email", "x-scheme-handler/mailto"],
        ["text", "text/plain"],
        ["images", "image/png image/jpeg image/gif image/webp image/bmp image/svg+xml image/tiff"],
        ["video", "video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo"],
        ["music", "audio/mpeg audio/flac audio/ogg audio/x-wav audio/mp4 audio/aac"],
        ["pdf", "application/pdf"],
        ["archives", "application/zip application/x-tar application/x-7z-compressed application/vnd.rar application/x-compressed-tar"]
    ]
    // per row: { cur, apps: [[file, name]] }
    property var found: []
    function read() { scan.running = true; }
    onLiveChanged: if (live) read()
    Process {
        id: scan
        command: ["bash", "-c", `dirs=("\${XDG_DATA_HOME:-$HOME/.local/share}/applications")
IFS=: read -ra sys <<< "\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for d in "\${sys[@]}"; do dirs+=("$d/applications"); done
for mime in "$@"; do
  cur=$(xdg-mime query default "$mime" 2>/dev/null)
  printf '%s\\t' "$cur"
  re="^MimeType=(.*;)?$(printf %s "$mime" | sed 's/[.+]/\\\\&/g')(;|$)"
  for d in "\${dirs[@]}"; do
    for f in "$d"/*.desktop; do
      [ -f "$f" ] && grep -qE "$re" "$f" || continue
      b=\${f##*/}
      grep -q '^NoDisplay=true' "$f" && [ "$b" != "$cur" ] && continue
      printf '%s=%s|' "$b" "$(grep -m1 '^Name=' "$f" | cut -d= -f2-)"
    done
  done
  echo
done`, "bash"].concat(kinds.map(k => k[1].split(" ")[0]))
        stdout: StdioCollector {
            onStreamFinished: root.found = text.split("\n").slice(0, root.kinds.length).map(l => {
                const [cur, rest] = l.split("\t");
                const seen = {}, apps = [];
                // your own ~/.local/share/applications comes first and overrides a system one with the same name
                for (const p of (rest ?? "").split("|").filter(Boolean)) {
                    const i = p.indexOf("="), f = p.slice(0, i);
                    if (!seen[f]) apps.push([f, p.slice(i + 1) || f.replace(/\.desktop$/, "")]);
                    seen[f] = true;
                }
                // two «Google Chrome» (the package and the flatpak) — tell them apart by the file
                const n = {};
                apps.forEach(a => n[a[1]] = (n[a[1]] ?? 0) + 1);
                for (const a of apps)
                    if (n[a[1]] > 1) a[1] = `${a[1]} · ${a[0].replace(/\.desktop$/, "")}`;
                return { cur: cur ?? "", apps };
            })
        }
    }
    Process { id: set; onExited: root.read() }

    Flow {
        width: 950
        spacing: 14
        Repeater {
            model: root.kinds
            Choose {
                required property var modelData
                required property int index
                readonly property var f: root.found[index] ?? { cur: "", apps: [] }
                label: modelData[0]
                names: f.apps.length ? f.apps.map(a => a[1]) : ["nothing installed"]
                cur: f.apps.findIndex(a => a[0] === f.cur)
                onPicked: i => {
                    if (!f.apps.length) return;
                    set.command = ["xdg-mime", "default", f.apps[i][0]].concat(modelData[1].split(" "));
                    set.running = true;
                }
            }
        }
    }
    Lb { text: "only apps that say they can open the type are listed" }
}
