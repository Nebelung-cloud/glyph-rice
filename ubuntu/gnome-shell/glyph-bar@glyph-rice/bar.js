// Glyph Bar widgets: GNOME's top bar rebuilt after config/quickshell/glyph/bar/Bar.qml in its "top" layout.
// mark (ring of 16 dots) · workspace dots · window title · Doto clock · EN · status icons · bell · battery · power-mode ticks · auto-hide pin.
// Everything that should look like Doto is drawn with cairo: St can't set Doto's ROND axis, and Doto in St labels
// is what made the bar vanish (cogl viewport errors).
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Clutter from 'gi://Clutter';
import Pango from 'gi://Pango';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {getInputSourceManager} from 'resource:///org/gnome/shell/ui/status/keyboard.js';
import {loadInterfaceXML} from 'resource:///org/gnome/shell/misc/fileUtils.js';

// Theme.qml glyphDark
export const C = {
    bg: [0x00, 0x00, 0x00], s1: [0x0E, 0x0E, 0x0E], s2: [0x1A, 0x1A, 0x1A], s3: [0x2A, 0x2A, 0x2A],
    mute: [0x4A, 0x4A, 0x4A], grey: [0x8C, 0x8C, 0x8C], fg: [0xF2, 0xF2, 0xF2], red: [0xD7, 0x19, 0x21],
};

function ink(cr, c, a = 1) {
    cr.setSourceRGBA(c[0] / 255, c[1] / 255, c[2] / 255, a);
}

function dot(cr, x, y, r) {
    cr.arc(x, y, r, 0, 2 * Math.PI);
    cr.fill();
}

function roundRect(cr, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    cr.newSubPath();
    cr.arc(x + w - r, y + r, r, -Math.PI / 2, 0);
    cr.arc(x + w - r, y + h - r, r, 0, Math.PI / 2);
    cr.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI);
    cr.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI);
    cr.closePath();
}

// letter-spacing from CSS isn't counted in St.Label's width, so tracked labels came out ellipsized ("E…", "SUN 2…").
// Tracking set as a Pango attribute is measured; St rewrites the attributes on every style change, so it goes back on after
export function track(label, px) {
    label.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
    const apply = () => {
        const attrs = new Pango.AttrList();
        attrs.insert(Pango.attr_letter_spacing_new(Math.round(px * Pango.SCALE)));
        label.clutter_text.set_attributes(attrs);
    };
    label.connect('style-changed', apply);
    apply();
    return label;
}

// ---- dot-matrix digits, 5×7, drawn after Doto ----
const GLYPHS = {
    '0': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    '1': ['..#..', '.##..', '#.#..', '..#..', '..#..', '..#..', '#####'],
    '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
    '3': ['.###.', '#...#', '....#', '..##.', '....#', '#...#', '.###.'],
    '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
    '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
    '6': ['..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.'],
    '7': ['#####', '....#', '...#.', '...#.', '..#..', '.#...', '.#...'],
    '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
    '9': ['.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..'],
    ':': ['.', '.', '#', '.', '#', '.', '.'],
};
const PITCH = 3.6;           // Num at 30px: seven rows ≈ .84em
const DOT_R = 1.55;
const GAP = 2;               // columns between characters

function textWidth(text) {
    let cols = 0;
    for (const ch of text)
        cols += (GLYPHS[ch]?.[0].length ?? 3) + GAP;
    return Math.ceil((cols - GAP) * PITCH);
}

export const DotText = GObject.registerClass(
class DotText extends St.DrawingArea {
    _init() {
        super._init({style_class: 'glyph-dots', y_align: Clutter.ActorAlign.CENTER});
        this._text = '';
        this._dim = false;       // colon off (blink)
        this.set_size(1, Math.ceil(7 * PITCH));
    }

    set text(t) {
        if (t === this._text)
            return;
        this._text = t;
        this.set_width(Math.max(1, textWidth(t)));
        this.queue_repaint();
    }

    set dim(d) {
        if (d === this._dim)
            return;
        this._dim = d;
        this.queue_repaint();
    }

    vfunc_repaint() {
        const cr = this.get_context();
        let x0 = 0;
        for (const ch of this._text) {
            const g = GLYPHS[ch];
            if (!g) {
                x0 += (3 + GAP) * PITCH;
                continue;
            }
            ink(cr, ch === ':' && this._dim ? C.s3 : C.fg);
            g.forEach((row, r) => [...row].forEach((b, c) => {
                if (b === '#')
                    dot(cr, x0 + (c + 0.5) * PITCH, (r + 0.5) * PITCH, DOT_R);
            }));
            x0 += (g[0].length + GAP) * PITCH;
        }
        cr.$dispose();
    }
});

// ---- mark: ring of 16 dots, the centre is the launcher ----
export const Mark = GObject.registerClass(
class Mark extends St.Button {
    _init() {
        super._init({style_class: 'glyph-mark', can_focus: true, y_align: Clutter.ActorAlign.CENTER,
            accessible_name: 'Apps'});
        this._area = new St.DrawingArea({width: 37, height: 37});
        this._area.connect('repaint', a => this._draw(a));
        this.set_child(this._area);
        this.connect('clicked', () => {
            if (Main.overview.visible)
                Main.overview.hide();
            else
                Main.overview.showApps();
        });
    }

    _draw(area) {
        const cr = area.get_context();
        const [w, h] = area.get_surface_size();
        const cx = w / 2, cy = h / 2, R = 17;
        ink(cr, C.fg);
        for (let i = 0; i < 16; i++) {
            const a = i / 16 * 2 * Math.PI - Math.PI / 2;
            dot(cr, cx + R * Math.cos(a), cy + R * Math.sin(a), 1.5);
        }
        dot(cr, cx, cy, 4.5);
        cr.$dispose();
    }
});

// ---- workspaces: the current one stretches into a white pill, occupied grey, empty a dim dot ----
export const Workspaces = GObject.registerClass(
class Workspaces extends St.BoxLayout {
    _init() {
        super._init({style_class: 'glyph-ws', reactive: true, y_align: Clutter.ActorAlign.CENTER});
        this._wm = global.workspace_manager;
        this._wsIds = [];
        this._wm.connectObject(
            'notify::n-workspaces', () => this._rewire(),
            'active-workspace-changed', () => this._sync(),
            'workspaces-reordered', () => this._sync(), this);
        global.display.connectObject('restacked', () => this._sync(), this);
        this._rewire();   // scrolling bubbles up to the panel-wide handler in extension.js
    }

    _rewire() {
        for (const [ws, ids] of this._wsIds)
            ids.forEach(id => ws.disconnect(id));
        this._wsIds = [];
        for (let i = 0; i < this._wm.n_workspaces; i++) {
            const ws = this._wm.get_workspace_by_index(i);
            this._wsIds.push([ws, [
                ws.connect('window-added', () => this._sync()),
                ws.connect('window-removed', () => this._sync()),
            ]]);
        }
        this._sync();
    }

    _sync() {
        const n = this._wm.n_workspaces;
        const active = this._wm.get_active_workspace_index();
        const count = Math.min(10, Math.max(6, n));
        while (this.get_n_children() < count) {
            const i = this.get_n_children();
            const d = new St.Button({style_class: 'glyph-ws-dot', y_align: Clutter.ActorAlign.CENTER});
            d.set_size(8, 8);
            d.connect('clicked', () => {
                const last = this._wm.n_workspaces - 1;
                this._wm.get_workspace_by_index(Math.min(i, last))?.activate(global.get_current_time());
            });
            this.add_child(d);
        }
        while (this.get_n_children() > count)
            this.get_last_child().destroy();

        this.get_children().forEach((d, i) => {
            const ws = i < n ? this._wm.get_workspace_by_index(i) : null;
            const occ = ws?.list_windows().some(w => !w.skip_taskbar) ?? false;
            const on = i === active;
            d.style_class = `glyph-ws-dot${on ? ' on' : occ ? ' occ' : ''}`;
            const len = on ? 28 : 8;
            if (d.width !== len)
                d.ease({width: len, duration: 250, mode: Clutter.AnimationMode.EASE_OUT_CUBIC});
        });
    }

    destroy() {
        for (const [ws, ids] of this._wsIds)
            ids.forEach(id => ws.disconnect(id));
        this._wsIds = [];
        super.destroy();
    }
});

export function scrollWorkspace(event) {
    const dir = event.get_scroll_direction();
    let d = 0;
    if (dir === Clutter.ScrollDirection.UP || dir === Clutter.ScrollDirection.LEFT)
        d = -1;
    else if (dir === Clutter.ScrollDirection.DOWN || dir === Clutter.ScrollDirection.RIGHT)
        d = 1;
    else if (dir === Clutter.ScrollDirection.SMOOTH) {
        // one step per notch: smooth scrolling fires a stream of small deltas
        const [dx, dy] = event.get_scroll_delta();
        const now = GLib.get_monotonic_time();
        if (now - (scrollWorkspace._t ?? 0) < 250000)
            return Clutter.EVENT_STOP;
        d = Math.abs(dy) >= Math.abs(dx) ? Math.sign(dy) : Math.sign(dx);
        if (d)
            scrollWorkspace._t = now;
    }
    if (!d)
        return Clutter.EVENT_PROPAGATE;
    const wm = global.workspace_manager;
    const i = Math.max(0, Math.min(wm.n_workspaces - 1, wm.get_active_workspace_index() + d));
    wm.get_workspace_by_index(i).activate(global.get_current_time());
    return Clutter.EVENT_STOP;
}

// ---- window title: "app · title", grey Space Mono caps ----
export const Title = GObject.registerClass(
class Title extends St.Label {
    _init() {
        super._init({style_class: 'glyph-title', y_align: Clutter.ActorAlign.CENTER, x_expand: true});
        track(this, 1.5);
        this.clutter_text.ellipsize = Pango.EllipsizeMode.END;   // the title may run long: it, alone, elides
        this._tracker = Shell.WindowTracker.get_default();
        this._win = null;
        global.display.connectObject('notify::focus-window', () => this._watch(), this);
        global.workspace_manager.connectObject('active-workspace-changed', () => this._sync(), this);
        this._watch();
    }

    _watch() {
        this._win?.disconnectObject(this);
        this._win = global.display.focus_window;
        this._win?.connectObject('notify::title', () => this._sync(), this);
        this._sync();
    }

    _sync() {
        const w = this._win;
        if (!w || w.skip_taskbar || w.get_workspace() !== global.workspace_manager.get_active_workspace()) {
            this.text = '';
            return;
        }
        const app = this._tracker.get_window_app(w);
        const id = (app?.get_id() ?? w.get_wm_class() ?? '').replace(/\.desktop$/, '');
        const name = id.split('.').pop().replace(/_.*$/, '');   // snaps: firefox_firefox → firefox
        this.text = name ? `${name} · ${w.title ?? ''}` : (w.title ?? '');
    }

    destroy() {
        this._win?.disconnectObject(this);
        this._win = null;
        super.destroy();
    }
});

// ---- clock: Doto HH:MM, then "SUN 22"; the colon blinks ----
export const Clock = GObject.registerClass(
class Clock extends St.BoxLayout {
    _init() {
        super._init({style_class: 'glyph-clock', y_align: Clutter.ActorAlign.CENTER});
        this._time = new DotText();
        this._date = track(new St.Label({style_class: 'glyph-clock-date', y_align: Clutter.ActorAlign.CENTER}), 1.4);
        this.add_child(this._time);
        this.add_child(this._date);
        this._settings = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
        this._settings.connectObject('changed::clock-format', () => this._tick(), this);
        this._tick();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._tick();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _tick() {
        const now = GLib.DateTime.new_now_local();
        const twelve = this._settings.get_string('clock-format') === '12h';
        const h = now.get_hour();
        const hh = twelve ? String(h % 12 || 12) : String(h).padStart(2, '0');
        this._time.text = `${hh}:${now.format('%M')}`;
        this._time.dim = now.get_second() % 2 === 1;
        this._date.text = (twelve ? `${h < 12 ? 'AM' : 'PM'} · ` : '') + now.format('%a %-d').toUpperCase();
    }

    destroy() {
        if (this._timer)
            GLib.source_remove(this._timer);
        this._timer = 0;
        this._settings?.disconnectObject(this);
        super.destroy();
    }
});

// ---- keyboard layout: "EN"; hidden with a single layout, where it would never change ----
export const Layout = GObject.registerClass(
class Layout extends St.Label {
    _init() {
        super._init({style_class: 'glyph-label glyph-layout', y_align: Clutter.ActorAlign.CENTER});
        track(this, 1.4);
        this._ism = getInputSourceManager();
        this._ism.connectObject(
            'current-source-changed', () => this._sync(),
            'sources-changed', () => this._sync(), this);
        this._sync();
    }

    _sync() {
        this.visible = Object.keys(this._ism.inputSources ?? {}).length > 1;
        const s = this._ism.currentSource;
        const short = s?.shortName ?? s?.id ?? 'en';
        this.text = (short === 'us' ? 'en' : short).toUpperCase();   // xkb "us" reads as EN, like the rice
    }

    destroy() {
        this._ism?.disconnectObject(this);
        super.destroy();
    }
});

// ---- bell: white when something is waiting, grey when not; crossed out in do-not-disturb. Opens the notification list ----
export const Bell = GObject.registerClass(
class Bell extends St.Button {
    _init() {
        super._init({style_class: 'glyph-bell', y_align: Clutter.ActorAlign.CENTER, can_focus: true,
            accessible_name: 'Notifications'});
        this._icon = new St.Icon({style_class: 'system-status-icon glyph-icon'});
        this.set_child(this._icon);
        this.connect('clicked', () => Main.panel.statusArea.dateMenu?.menu.toggle());
        this._settings = new Gio.Settings({schema_id: 'org.gnome.desktop.notifications'});
        this._settings.connectObject('changed::show-banners', () => this._sync(), this);
        this._sources = new Set();
        Main.messageTray.connectObject(
            'source-added', (_t, s) => this._add(s),
            'source-removed', (_t, s) => {
                s.disconnectObject(this);
                this._sources.delete(s);
                this._sync();
            }, this);
        Main.messageTray.getSources().forEach(s => this._add(s));
        this._sync();
    }

    _add(s) {
        this._sources.add(s);
        s.connectObject('notify::count', () => this._sync(), this);
        this._sync();
    }

    _sync() {
        const dnd = !this._settings.get_boolean('show-banners');
        const n = [...this._sources].reduce((a, s) => a + (s.count ?? 0), 0);
        this._icon.icon_name = dnd ? 'notifications-disabled-symbolic' : 'preferences-system-notifications-symbolic';
        this._icon.style_class = `system-status-icon glyph-icon${n ? '' : ' off'}`;
    }

    destroy() {
        this._sources.forEach(s => s.disconnectObject(this));
        this._sources.clear();
        Main.messageTray.disconnectObject(this);
        this._settings?.disconnectObject(this);
        super.destroy();
    }
});

// ---- battery: a lying pill that fills from the left, bolt first on AC, breathes while charging, red under 15% ----
const DeviceProxy = Gio.DBusProxy.makeProxyWrapper(loadInterfaceXML('org.freedesktop.UPower.Device'));
const CHARGING = 1, FULL = 4, PENDING_CHARGE = 5;

export const Battery = GObject.registerClass(
class Battery extends St.BoxLayout {
    _init() {
        super._init({style_class: 'glyph-battery', y_align: Clutter.ActorAlign.CENTER, visible: false});
        this._bolt = new St.DrawingArea({width: 9, height: 14, y_align: Clutter.ActorAlign.CENTER, visible: false});
        this._bolt.connect('repaint', a => {
            const cr = a.get_context();
            ink(cr, C.fg);
            cr.moveTo(5.5, 0); cr.lineTo(0.5, 8); cr.lineTo(4, 8); cr.lineTo(3, 14);
            cr.lineTo(8.5, 5.5); cr.lineTo(5, 5.5); cr.lineTo(6.5, 0); cr.closePath();
            cr.fill();
            cr.$dispose();
        });
        this._cell = new St.DrawingArea({width: 26, height: 14, y_align: Clutter.ActorAlign.CENTER});
        this._cell.connect('repaint', a => this._drawCell(a));
        this._pct = track(new St.Label({style_class: 'glyph-label glyph-battery-pct', y_align: Clutter.ActorAlign.CENTER}), 1.4);
        this.add_child(this._bolt);
        this.add_child(this._cell);
        this.add_child(this._pct);
        this._p = 0;
        this._low = false;
        this._pulse = 1;
        this._phase = 0;
        this._timer = 0;
        this._proxy = new DeviceProxy(Gio.DBus.system, 'org.freedesktop.UPower',
            '/org/freedesktop/UPower/devices/DisplayDevice', (proxy, error) => {
                if (error) {
                    console.warn(`Glyph Bar: battery: ${error.message}`);
                    return;
                }
                this._propsId = proxy.connect('g-properties-changed', () => this._sync());
                this._sync();
            });
    }

    _sync() {
        const p = this._proxy;
        if (!p || !p.IsPresent || p.Type !== 2) {   // 2 = battery
            this.visible = false;
            return;
        }
        this.visible = true;
        const state = p.State;
        const ac = state === CHARGING || state === FULL || state === PENDING_CHARGE;
        this._p = Math.max(0, Math.min(1, p.Percentage / 100));
        this._low = !ac && this._p < 0.15;
        this._bolt.visible = ac;
        this._pct.text = String(Math.round(p.Percentage));
        this._breathe(state === CHARGING);
        this._cell.queue_repaint();
    }

    // cosine with a 2.2 s period, 20 steps a second: the same breath as the rice, without redrawing on every vsync
    _breathe(on) {
        if (on && !this._timer) {
            this._phase = 0;
            this._timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
                this._phase = (this._phase + 0.05) % 2.2;
                this._pulse = 0.675 + 0.325 * Math.cos(this._phase * Math.PI / 1.1);
                this._cell.queue_repaint();
                return GLib.SOURCE_CONTINUE;
            });
        } else if (!on && this._timer) {
            GLib.source_remove(this._timer);
            this._timer = 0;
            this._pulse = 1;
        }
    }

    _drawCell(area) {
        const cr = area.get_context();
        ink(cr, C.grey);
        cr.setLineWidth(1.5);
        roundRect(cr, 0.75, 0.75, 24.5, 12.5, 6.25);
        cr.stroke();
        const w = 20 * this._p;
        if (w > 0.5) {
            ink(cr, this._low ? C.red : C.fg, this._pulse);
            roundRect(cr, 3, 3, Math.max(w, 8), 8, 4);
            cr.fill();
        }
        cr.$dispose();
    }

    destroy() {
        this._breathe(false);
        if (this._proxy && this._propsId)
            this._proxy.disconnect(this._propsId);
        this._proxy = null;
        super.destroy();
    }
});

// ---- power mode as ticks: power-saver one, balanced two, performance three. Click: the next one ----
const ProfilesProxy = Gio.DBusProxy.makeProxyWrapper(loadInterfaceXML('net.hadess.PowerProfiles'));
const ORDER = ['power-saver', 'balanced', 'performance'];

export const Mode = GObject.registerClass(
class Mode extends St.Button {
    _init() {
        super._init({style_class: 'glyph-mode', y_align: Clutter.ActorAlign.CENTER, can_focus: true,
            accessible_name: 'Power mode', visible: false});
        this._area = new St.DrawingArea({width: 40, height: 22});
        this._area.connect('repaint', a => this._draw(a));
        this.set_child(this._area);
        this._modes = [];
        this._i = 0;
        this.connect('clicked', () => {
            if (this._modes.length && this._proxy)
                this._proxy.ActiveProfile = this._modes[(this._i + 1) % this._modes.length];
        });
        this._proxy = new ProfilesProxy(Gio.DBus.system, 'net.hadess.PowerProfiles', '/net/hadess/PowerProfiles',
            (proxy, error) => {
                if (error) {
                    console.warn(`Glyph Bar: power profiles: ${error.message}`);
                    return;
                }
                this._propsId = proxy.connect('g-properties-changed', () => this._sync());
                this._sync();
            });
    }

    _sync() {
        const p = this._proxy;
        const have = (p?.Profiles ?? []).map(d => d.Profile?.unpack?.() ?? d.Profile);
        this._modes = ORDER.filter(m => have.includes(m));
        this._i = Math.max(0, this._modes.indexOf(p?.ActiveProfile));
        this.visible = !!p?.g_name_owner && this._modes.length > 1;
        this._area.queue_repaint();
    }

    _draw(area) {
        const cr = area.get_context();
        const n = this._modes.length || 3;
        const w = 3, sp = 2, total = n * w + (n - 1) * sp;
        let x = (40 - total) / 2;
        for (let i = 0; i < n; i++) {
            const h = 5 + i * 3;
            ink(cr, i <= this._i ? C.fg : C.s3);
            roundRect(cr, x, (22 + (5 + (n - 1) * 3)) / 2 - h, w, h, 1.5);
            cr.fill();
            x += w + sp;
        }
        cr.$dispose();
    }

    destroy() {
        if (this._proxy && this._propsId)
            this._proxy.disconnect(this._propsId);
        this._proxy = null;
        super.destroy();
    }
});

// auto-hide toggle: a pin. White pin = the bar stays put; grey crossed pin = it slides away (autohide.js)
export const AutoHideToggle = GObject.registerClass(
class AutoHideToggle extends St.Button {
    _init(autohide) {
        super._init({style_class: 'glyph-autohide', y_align: Clutter.ActorAlign.CENTER, can_focus: true});
        this._autohide = autohide;
        this._icon = new St.Icon({style_class: 'system-status-icon glyph-icon'});
        this.set_child(this._icon);
        this.connect('clicked', () => autohide.toggle());
        this._unwatch = autohide.watch(() => this._sync());
        this.connect('destroy', () => this._unwatch());
        this._sync();
    }

    _sync() {
        const on = this._autohide.enabled;
        this._icon.icon_name = on ? 'adw-tab-unpin-symbolic' : 'view-pin-symbolic';
        this.accessible_name = on ? 'Keep the bar shown' : 'Auto-hide the bar';
        if (on)
            this.add_style_pseudo_class('checked');
        else
            this.remove_style_pseudo_class('checked');
    }
});
