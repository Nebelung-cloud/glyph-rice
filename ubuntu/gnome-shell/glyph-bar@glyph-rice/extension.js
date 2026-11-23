// Glyph Bar: GNOME's top bar as the Glyph bar in its "top" layout (config/quickshell/glyph/bar/Bar.qml):
// a floating pill 14px off the screen edges, 64px tall. Left: the mark, workspace dots, Spotify while it runs,
// the window title. Centre: the Doto clock. Right: EN, network, bluetooth, sound, bell, battery, power-mode ticks,
// auto-hide pin. Power off / restart live in the quick settings menu.
// stylesheet.css paints it; bar.js holds the widgets. disable() puts GNOME's own pieces back.
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {GlyphMedia} from './media.js';
import {Mark, Workspaces, Title, Clock, Layout, Bell, Battery, Mode, AutoHideToggle, scrollWorkspace} from './bar.js';
import {AutoHide} from './autohide.js';

export default class GlyphBar extends Extension {
    enable() {
        this._made = [];
        this._pinned = [];
        this._classes = [];
        const panel = Main.panel;
        const area = panel.statusArea;

        this._addClass(Main.layoutManager.panelBox, 'glyph-box');
        this._addClass(panel, 'glyph-bar');

        // ---- left: mark · workspaces · media · title; GNOME's Activities button steps aside ----
        if (area.activities)
            this._pin(area.activities.container);
        const mark = this._make(new Mark());
        const ws = this._make(new Workspaces());
        panel._leftBox.insert_child_at_index(mark, 0);
        panel._leftBox.insert_child_at_index(ws, 1);
        this._media = new GlyphMedia();
        panel.addToStatusArea('glyph-media', this._media, 2, 'left');
        const title = this._make(new Title());
        panel._leftBox.insert_child_above(title, this._media.container);

        // ---- centre: the Glyph clock in place of GNOME's text; the bell takes over the unread dot ----
        const dateMenu = area.dateMenu;
        this._addClass(dateMenu, 'glyph-datemenu');
        this._pin(dateMenu._clockDisplay);
        this._pin(dateMenu._indicator);
        const clock = this._make(new Clock());
        dateMenu._clockDisplay.get_parent().insert_child_above(clock, dateMenu._clockDisplay);

        // ---- right: inside quick settings, so a click opens them as in the rice ----
        const qs = area.quickSettings;
        this._addClass(qs, 'glyph-qs');
        this._addClass(qs._indicators, 'glyph-tray');
        if (area.keyboard)
            this._pin(area.keyboard.container); // EN sits in the tray

        // after quick settings: ticks and the auto-hide pin, last in the bar
        panel._rightBox.add_child(this._make(new Mode()));
        this._autohide = new AutoHide();
        panel._rightBox.add_child(this._make(new AutoHideToggle(this._autohide)));

        // GNOME fills the tray asynchronously: at login the network, sound and battery icons arrive after enable().
        // Bell and battery go in once the battery indicator (always the last one) is there, so they come last too
        this._trayTries = 0;
        this._trayWait = 0;
        if (!this._fillTray()) {
            this._trayWait = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
                if (this._fillTray() || ++this._trayTries > 300) {
                    this._trayWait = 0;
                    return GLib.SOURCE_REMOVE;
                }
                return GLib.SOURCE_CONTINUE;
            });
        }

        // scrolling anywhere on the pill switches workspace (the sound icon keeps its own scroll for volume)
        this._scrollId = panel.connect('scroll-event', (_a, e) => scrollWorkspace(e));
    }

    _fillTray() {
        const qs = Main.panel.statusArea.quickSettings;
        if (!qs._system)
            return false;
        qs._indicators.insert_child_at_index(this._make(new Layout()), 0);   // EN first, ahead of the privacy icons
        this._pin(qs._system);                  // GNOME's battery icon + percentage → our pill
        if (qs._powerProfiles)
            this._pin(qs._powerProfiles);       // shown as ticks instead
        qs._indicators.add_child(this._make(new Bell()));
        qs._indicators.add_child(this._make(new Battery()));
        return true;
    }

    _make(actor) {
        this._made.push(actor);
        return actor;
    }

    _addClass(actor, name) {
        actor.add_style_class_name(name);
        this._classes.push([actor, name]);
    }

    // hide one of GNOME's actors and keep it hidden whatever GNOME decides; disable() gives it its old state back
    _pin(actor) {
        const was = actor.visible;
        actor.hide();
        const id = actor.connect('notify::visible', () => {
            if (actor.visible)
                actor.hide();
        });
        this._pinned.push([actor, id, was]);
    }

    disable() {
        if (this._trayWait)
            GLib.source_remove(this._trayWait);
        this._trayWait = 0;
        if (this._scrollId)
            Main.panel.disconnect(this._scrollId);
        this._scrollId = 0;
        this._made?.reverse().forEach(a => a.destroy());
        this._made = [];
        this._autohide?.destroy();
        this._autohide = null;
        this._media?.destroy();
        this._media = null;
        this._pinned?.forEach(([actor, id, was]) => {
            actor.disconnect(id);
            actor.visible = was;
        });
        this._pinned = [];
        this._classes?.forEach(([actor, name]) => actor.remove_style_class_name(name));
        this._classes = [];
        // let GNOME recount what it shows: the system indicator and power-profile icons sync on their own signals
        const qs = Main.panel.statusArea.quickSettings;
        qs?._system?._sync?.();
    }
}
