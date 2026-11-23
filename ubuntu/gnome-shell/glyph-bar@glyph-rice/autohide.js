// Glyph Bar auto-hide: the pill slides up off the screen and windows get the full height. It comes back while the
// pointer touches the top edge (or is over the bar), while the overview is open and while one of its menus is open.
// The choice is kept in ~/.config/glyph-rice/bar-autohide ("1" on, "0" off) so it survives logouts.
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const FILE = GLib.build_filenamev([GLib.get_user_config_dir(), 'glyph-rice', 'bar-autohide']);
const POLL_MS = 120;      // pointer check while auto-hide is on
const EDGE = 2;           // px at the top of the screen that reveal the bar
const LEAVE_DELAY = 400;  // ms the pointer must be away before the bar hides
const SLIDE_MS = 220;

function readSaved() {
    try {
        const [ok, bytes] = GLib.file_get_contents(FILE);
        return ok && new TextDecoder().decode(bytes).trim() === '1';
    } catch {
        return false;
    }
}

function save(on) {
    try {
        GLib.mkdir_with_parents(GLib.path_get_dirname(FILE), 0o755);
        GLib.file_set_contents(FILE, on ? '1\n' : '0\n');
    } catch (e) {
        console.warn(`Glyph Bar: auto-hide: ${e.message}`);
    }
}

export class AutoHide {
    constructor() {
        this._box = Main.layoutManager.panelBox;
        this._on = false;
        this._shown = true;
        this._poll = 0;
        this._awaySince = 0;
        this._listeners = new Set();
        this._overview = [
            Main.overview.connect('showing', () => this._update()),
            Main.overview.connect('hidden', () => this._update()),
        ];
        if (readSaved())
            this.set(true, false);
    }

    get enabled() {
        return this._on;
    }

    // fn(on) runs whenever auto-hide is switched; returns a function that stops it
    watch(fn) {
        this._listeners.add(fn);
        return () => this._listeners.delete(fn);
    }

    toggle() {
        this.set(!this._on);
    }

    set(on, persist = true) {
        if (on === this._on)
            return;
        this._on = on;
        if (persist)
            save(on);
        // re-track the bar so it stops (or starts again) reserving space at the top
        Main.layoutManager.untrackChrome(this._box);
        Main.layoutManager.trackChrome(this._box, {affectsStruts: !on, trackFullscreen: true});
        if (on) {
            this._awaySince = GLib.get_monotonic_time();
            this._poll = GLib.timeout_add(GLib.PRIORITY_DEFAULT, POLL_MS, () => {
                this._update();
                return GLib.SOURCE_CONTINUE;
            });
        } else {
            this._stopPoll();
            this._slide(true);
        }
        this._listeners.forEach(fn => fn(on));
    }

    _stopPoll() {
        if (this._poll)
            GLib.source_remove(this._poll);
        this._poll = 0;
    }

    _wanted() {
        if (!this._on || Main.overview.visible || Main.panel.menuManager.activeMenu)
            return true;
        const [x, y] = global.get_pointer();
        const mon = Main.layoutManager.primaryMonitor;
        if (!mon || x < mon.x || x >= mon.x + mon.width)
            return false;
        if (y <= mon.y + EDGE)
            return true;
        // keep it while the pointer is on the shown bar
        return this._shown && y <= mon.y + this._box.height;
    }

    _update() {
        const now = GLib.get_monotonic_time();
        if (this._wanted()) {
            this._awaySince = 0;
            this._slide(true);
        } else {
            this._awaySince ||= now;
            if (!this._shown || now - this._awaySince >= LEAVE_DELAY * 1000)
                this._slide(false);
        }
    }

    _slide(show) {
        if (show === this._shown)
            return;
        this._shown = show;
        this._box.remove_transition('translation-y');
        this._box.ease({
            translation_y: show ? 0 : -this._box.height,
            duration: SLIDE_MS,
            mode: show ? Clutter.AnimationMode.EASE_OUT_QUAD : Clutter.AnimationMode.EASE_IN_QUAD,
            // the input region follows the bar only when the layout manager recounts it
            onStopped: () => Main.layoutManager._queueUpdateRegions(),
        });
    }

    destroy() {
        this._stopPoll();
        this._overview.forEach(id => Main.overview.disconnect(id));
        this._overview = [];
        this._listeners.clear();
        this._box.remove_transition('translation-y');
        this._box.translation_y = 0;
        if (this._on) {
            Main.layoutManager.untrackChrome(this._box);
            Main.layoutManager.trackChrome(this._box, {affectsStruts: true, trackFullscreen: true});
        }
        this._on = false;
        Main.layoutManager._queueUpdateRegions();
    }
}
