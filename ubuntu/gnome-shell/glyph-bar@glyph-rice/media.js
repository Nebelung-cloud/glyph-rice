// Glyph Media: Spotify in the bar. A dot (red = playing), the track, play/pause;
// the menu adds cover art, artist and prev/next. Spotify not running → launches it.
import St from 'gi://St';
import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import Clutter from 'gi://Clutter';
import Pango from 'gi://Pango';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {track} from './bar.js';

const BUS_NAME = 'org.mpris.MediaPlayer2.spotify';
const DESKTOP_IDS = ['spotify_spotify.desktop', 'spotify.desktop', 'com.spotify.Client.desktop'];
const PlayerIface = `
<node><interface name="org.mpris.MediaPlayer2.Player">
  <method name="PlayPause"/><method name="Next"/><method name="Previous"/>
  <property name="PlaybackStatus" type="s" access="read"/>
  <property name="Metadata" type="a{sv}" access="read"/>
</interface></node>`;
const PlayerProxy = Gio.DBusProxy.makeProxyWrapper(PlayerIface);

function iconButton(iconName, styleClass, onClick) {
    const icon = new St.Icon({icon_name: iconName, style_class: 'glyph-media-icon'});
    const button = new St.Button({style_class: styleClass, child: icon, can_focus: true,
        y_align: Clutter.ActorAlign.CENTER});
    button.connect('clicked', onClick);
    return [button, icon];
}

export const GlyphMedia = GObject.registerClass(
class GlyphMedia extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Glyph Media');
        this.add_style_class_name('glyph-media');
        this._proxy = null;

        // ---- bar: dot · title · play/pause ----
        const box = new St.BoxLayout({style_class: 'glyph-media-box', y_align: Clutter.ActorAlign.CENTER});
        this._dot = new St.Widget({style_class: 'glyph-media-dot', y_align: Clutter.ActorAlign.CENTER});
        this._barLabel = new St.Label({style_class: 'glyph-media-label', y_align: Clutter.ActorAlign.CENTER});
        track(this._barLabel, 1);                     // measured tracking; CSS letter-spacing cut "SPOTIFY" to "SPOTIF…"
        this._barLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        [this._barPlay, this._barPlayIcon] = iconButton('media-playback-start-symbolic',
            'glyph-media-bar-play', () => this._call('PlayPauseAsync'));
        box.add_child(this._dot);
        box.add_child(this._barLabel);
        box.add_child(this._barPlay);
        this.add_child(box);

        // ---- menu: art, title, artist, controls, open ----
        const card = new PopupMenu.PopupBaseMenuItem({reactive: false, style_class: 'glyph-media-card'});
        const col = new St.BoxLayout({vertical: true, x_expand: true, style_class: 'glyph-media-col'});
        this._art = new St.Icon({style_class: 'glyph-media-art', icon_size: 240,
            icon_name: 'glyph-mono-spotify_spotify', x_align: Clutter.ActorAlign.CENTER});
        this._title = new St.Label({style_class: 'glyph-media-title'});
        this._artist = new St.Label({style_class: 'glyph-media-artist'});
        this._title.clutter_text.ellipsize = this._artist.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        const controls = new St.BoxLayout({style_class: 'glyph-media-controls', x_align: Clutter.ActorAlign.CENTER});
        const [prev] = iconButton('media-skip-backward-symbolic', 'glyph-media-btn', () => this._call('PreviousAsync'));
        [this._play, this._playIcon] = iconButton('media-playback-start-symbolic', 'glyph-media-btn glyph-media-btn-main',
            () => this._call('PlayPauseAsync'));
        const [next] = iconButton('media-skip-forward-symbolic', 'glyph-media-btn', () => this._call('NextAsync'));
        controls.add_child(prev);
        controls.add_child(this._play);
        controls.add_child(next);
        col.add_child(this._art);
        col.add_child(this._title);
        col.add_child(this._artist);
        col.add_child(controls);
        card.add_child(col);
        this.menu.addMenuItem(card);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._openItem = this.menu.addAction('Open Spotify', () => this._openSpotify());
        this.menu.actor.add_style_class_name('glyph-media-menu');

        this._watchId = Gio.bus_watch_name(Gio.BusType.SESSION, BUS_NAME, Gio.BusNameWatcherFlags.NONE,
            () => this._connect(), () => this._disconnect());
        this._sync();
    }

    // not running: a click launches Spotify instead of opening an empty menu
    vfunc_event(event) {
        const t = event.type();
        if (!this._proxy && (t === Clutter.EventType.BUTTON_PRESS || t === Clutter.EventType.TOUCH_BEGIN)) {
            this._openSpotify();
            return Clutter.EVENT_STOP;
        }
        return super.vfunc_event(event);
    }

    _app() {
        const sys = Shell.AppSystem.get_default();
        for (const id of DESKTOP_IDS) {
            const app = sys.lookup_app(id);
            if (app)
                return app;
        }
        return null;
    }

    _openSpotify() {
        this.menu.close();
        const app = this._app();
        if (app)
            app.activate();
        else
            Main.notify('Glyph Media', 'Spotify is not installed');
    }

    _connect() {
        this._cancel = new Gio.Cancellable();
        new PlayerProxy(Gio.DBus.session, BUS_NAME, '/org/mpris/MediaPlayer2', (proxy, error) => {
            if (error) {
                if (!error.matches(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                    console.warn(`Glyph Media: ${error.message}`);
                return;
            }
            this._proxy = proxy;
            this._propsId = proxy.connect('g-properties-changed', () => this._sync());
            this._sync();
        }, this._cancel);
    }

    _disconnect() {
        this._cancel?.cancel();
        this._cancel = null;
        if (this._proxy && this._propsId)
            this._proxy.disconnect(this._propsId);
        this._proxy = null;
        this._propsId = 0;
        this._sync();
    }

    _call(method) {
        this._proxy?.[method]?.().catch(e => console.warn(`Glyph Media: ${e.message}`));
    }

    _sync() {
        const p = this._proxy;
        let meta = {};
        try {
            meta = p?.get_cached_property('Metadata')?.recursiveUnpack() ?? {};
        } catch (e) {}
        const status = p?.PlaybackStatus ?? 'Stopped';
        const playing = status === 'Playing';
        const title = meta['xesam:title'] || '';
        const artist = (meta['xesam:artist'] || []).join(', ');

        this._dot.style_class = playing ? 'glyph-media-dot playing' : 'glyph-media-dot';
        this._barLabel.text = !p ? 'SPOTIFY' : title ? title : 'SPOTIFY';
        this._barPlay.visible = !!p && !!title;
        const icon = playing ? 'media-playback-pause-symbolic' : 'media-playback-start-symbolic';
        this._barPlayIcon.icon_name = this._playIcon.icon_name = icon;

        this._title.text = title || 'Nothing playing';
        this._artist.text = artist ? artist.toUpperCase() : '';
        const art = meta['mpris:artUrl'];
        if (art && art !== this._artUrl) {
            this._artUrl = art;
            this._art.gicon = new Gio.FileIcon({file: Gio.File.new_for_uri(art)});
        } else if (!art) {
            this._artUrl = null;
            this._art.gicon = null;
            this._art.icon_name = 'glyph-mono-spotify_spotify';
        }
    }

    destroy() {
        if (this._watchId)
            Gio.bus_unwatch_name(this._watchId);
        this._watchId = 0;
        this._disconnect();
        super.destroy();
    }
});
