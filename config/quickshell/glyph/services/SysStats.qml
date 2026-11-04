pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// the system from /proc and sysfs every 2 s while the altar is open (detailed); perf — the Performance tab: also processes and frequency;
// cat — a cat runs in the bar tray (RunCat): it gets the cpu, the same step, but without detailed — only /proc/stat, meminfo and uptime
Singleton {
    id: root

    property bool detailed: false
    property bool perf: false
    property bool cat: false

    property real cpu: 0          // 0…1
    property var cores: []        // 0…1 per core
    property real cpuTemp: 0      // °C
    property real cpuFreq: 0      // GHz, average
    property string load: ""
    property real mem: 0          // 0…1
    property real memUsed: 0      // GiB
    property real memTotal: 0
    property real swapUsed: 0
    property real cache: 0
    property real gpu: 0          // 0…1
    property real gpuTemp: 0
    property real vramUsed: 0     // GiB
    property real vramTotal: 0
    property var disks: []        // [{ mount, used 0…1, size }]
    property string iface: ""
    property real rx: 0           // bytes/s
    property real tx: 0
    property var procs: []        // [[name, %cpu], …]
    property real uptime: 0       // s

    property var prev: ({})
    property var prevNet: [[0, 0], 0] // [[rx, tx], ms]

    function read(f) { f.reload(); return f.text(); }
    function num(f) { return parseFloat(read(f)) || 0; }

    FileView { id: stat; path: "/proc/stat"; blockAllReads: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockAllReads: true }
    FileView { id: loadavg; path: "/proc/loadavg"; blockAllReads: true }
    FileView { id: up; path: "/proc/uptime"; blockAllReads: true }
    FileView { id: cpuinfo; path: "/proc/cpuinfo"; blockAllReads: true }
    FileView { id: netdev; path: "/proc/net/dev"; blockAllReads: true }
    FileView { id: route; path: "/proc/net/route"; blockAllReads: true }
    // the gpu and sensors aren't hard-coded, like in caelestia: there's nvidia-smi — take it from there; otherwise the first drm card with gpu_busy_percent
    // (amdgpu), its vram and its hwmon. The cpu temperature — the first of the known sensors. Nothing found — zeros
    property string gpuType: ""   // "nvidia" | "drm" | ""
    property string card: ""      // /sys/class/drm/cardN/device
    property string gpuDev: ""    // the card's pci device in sysfs: power/runtime_status — whether it's asleep
    property string gpuHwmon: ""
    property var hwmons: ({})     // hwmonN by sensor name
    function hwmon(names) { const n = names.find(n => root.hwmons[n]); return n ? root.hwmons[n] + "/temp1_input" : ""; }

    FileView { id: gpuBusy; path: root.card ? root.card + "/gpu_busy_percent" : ""; blockAllReads: true; printErrors: false }
    FileView { id: vramUsedF; path: root.card ? root.card + "/mem_info_vram_used" : ""; blockAllReads: true; printErrors: false }
    FileView { id: vramTotalF; path: root.card ? root.card + "/mem_info_vram_total" : ""; blockAllReads: true; printErrors: false }
    FileView { id: gpuTempF; path: root.gpuHwmon ? root.gpuHwmon + "/temp1_input" : ""; blockAllReads: true; printErrors: false }
    FileView { id: cpuTempF; path: root.hwmon(["k10temp", "coretemp", "zenpower", "cpu_thermal"]); blockAllReads: true; printErrors: false }
    FileView { id: gpuPm; path: root.gpuDev ? root.gpuDev + "/power/runtime_status" : ""; blockAllReads: true; printErrors: false }

    Process {
        running: true
        command: ["sh", "-c", `for h in /sys/class/hwmon/hwmon*; do echo "hwmon $(cat $h/name) $h"; done
command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1 && echo "nvidia $(ls -d /sys/bus/pci/drivers/nvidia/*:* 2>/dev/null | head -1)"
for c in /sys/class/drm/card*/device; do [ -e "$c/gpu_busy_percent" ] && { echo "card $c $(ls -d $c/hwmon/hwmon* 2>/dev/null | head -1)"; break; }; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.trim().split("\n")) {
                    const [k, a, b] = l.split(" ");
                    if (k === "hwmon") m[a] = b;
                    else if (k === "nvidia") { root.gpuType = "nvidia"; root.gpuDev = a ?? ""; }
                    else if (k === "card" && root.gpuType !== "nvidia") { root.gpuType = "drm"; root.card = root.gpuDev = a; root.gpuHwmon = b ?? ""; }
                }
                root.hwmons = m;
            }
        }
    }
    Process {
        id: nvidia
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [u, t, used, total] = text.trim().split("\n")[0].split(",").map(Number);
                root.gpu = u / 100;
                root.gpuTemp = t;
                root.vramUsed = used / 1024;
                root.vramTotal = total / 1024;
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=target,used,size", "/", "/home"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                root.disks = text.trim().split("\n").slice(1).map(l => l.trim().split(/\s+/))
                    .filter(([m, u, s]) => !seen[u + s] && (seen[u + s] = true))
                    .map(([m, u, s]) => ({ mount: m === "/" ? "root" : m.slice(1), used: u / s, size: +s }));
            }
        }
    }

    Process {
        id: ps
        command: ["ps", "-eo", "comm,%cpu", "--sort=-%cpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: root.procs = text.trim().split("\n").map(l => {
                const m = l.trim().match(/^(.*?)\s+([\d.]+)$/);
                return m ? [m[1], +m[2]] : [l, 0];
            }).filter(p => p[0] !== "ps").slice(0, 4)
        }
    }

    // disks change slowly — once per opening
    onDetailedChanged: if (detailed) df.running = true
    // startup: the first cpu snapshot, so on the first opening the difference isn't from zero
    Component.onCompleted: sample()

    Timer {
        interval: 2000
        running: root.detailed || root.cat
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    function sample() {
        // cpu: the total line and per core
        const next = {}, cores = [];
        for (const l of root.read(stat).split("\n")) {
            if (!l.startsWith("cpu")) break;
            const p = l.trim().split(/\s+/), f = p.slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            const o = root.prev[p[0]] ?? [idle, total];
            const u = total > o[1] ? 1 - (idle - o[0]) / (total - o[1]) : 0;
            next[p[0]] = [idle, total];
            if (p[0] === "cpu") root.cpu = u; else cores.push(u);
        }
        root.prev = next;
        root.cores = cores;

        const kv = {};
        for (const l of root.read(meminfo).split("\n")) {
            const m = l.match(/^(\w+):\s+(\d+)/);
            if (m) kv[m[1]] = +m[2] / 1048576;
        }
        root.memTotal = kv.MemTotal;
        root.memUsed = kv.MemTotal - kv.MemAvailable;
        root.mem = root.memUsed / kv.MemTotal;
        root.swapUsed = kv.SwapTotal - kv.SwapFree;
        root.cache = kv.Cached;

        root.uptime = parseFloat(root.read(up));
        if (!root.detailed) return;

        root.load = root.read(loadavg).split(" ").slice(0, 3).join(" ");
        root.cpuTemp = root.num(cpuTempF) / 1000;
        // polling wakes a sleeping hybrid laptop dGPU, and with polling every 2 s it never falls asleep again (nvidia-smi — definitely).
        // Asleep — means idle: 0, the card isn't touched
        if (root.read(gpuPm).startsWith("suspend")) { root.gpu = 0; root.gpuTemp = 0; }
        else if (root.gpuType === "nvidia") nvidia.running = true;
        else {
            root.gpu = root.num(gpuBusy) / 100;
            root.gpuTemp = root.num(gpuTempF) / 1000;
            root.vramUsed = root.num(vramUsedF) / 1073741824;
            root.vramTotal = root.num(vramTotalF) / 1073741824;
        }

        // network: the default route's interface
        const r = root.read(route).split("\n").find(l => l.split("\t")[1] === "00000000");
        root.iface = r ? r.split("\t")[0] : "";
        const line = root.read(netdev).split("\n").find(l => l.trim().startsWith(root.iface + ":"));
        if (line) {
            const f = line.split(":")[1].trim().split(/\s+/).map(Number), now = Date.now();
            const [px, pt] = root.prevNet, dt = (now - pt) / 1000;
            if (pt && dt > 0) { root.rx = (f[0] - px[0]) / dt; root.tx = (f[8] - px[1]) / dt; }
            root.prevNet = [[f[0], f[8]], now];
        }

        if (root.perf) top();
    }

    // frequency and processes — only Performance; the tab opened — at once, don't wait for a tick
    onPerfChanged: if (perf) top()
    function top() {
        const mhz = root.read(cpuinfo).match(/cpu MHz\s*:\s*[\d.]+/g) ?? [];
        root.cpuFreq = mhz.reduce((a, l) => a + parseFloat(l.split(":")[1]), 0) / Math.max(1, mhz.length) / 1000;
        ps.running = true;
    }

    function rate(b) {
        return b > 1048576 ? (b / 1048576).toFixed(1) + " mb/s" : Math.round(b / 1024) + " kb/s";
    }
}
