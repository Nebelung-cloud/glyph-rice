#!/usr/bin/env python3
"""Draw the Glyph app tiles: a Tabler outline glyph glowing in its app's colour
(GLOW) on a dark disc with a hairline ring. One SVG per icon name, written next to this script; mono-icons.py
copies them into the Glyph-Mono theme, where they beat the greyscale copies.

Add an app: put "<its Icon= name>": "<tabler glyph>" in TILES, re-run this, then
mono-icons.py. Glyph names: https://tabler.io/icons (outline set).
Glyphs: Tabler Icons, MIT. view-app-grid-ubuntu-symbolic.svg is hand-written.
"""
import os, re, sys, urllib.request

TABLER = 'https://cdn.jsdelivr.net/npm/@tabler/icons@3.24.0/icons/outline/{}.svg'
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.expanduser('~/.cache/glyph-tabler')

TILES = {
    # dock
    'glyph-mono-firefox_firefox': 'brand-firefox',
    'org.gnome.Nautilus': 'folder',
    'glyph-mono-snap-store_snap-store': 'shopping-bag',
    'claude-desktop': 'asterisk',
    'glyph-mono-ghostty_ghostty': 'ghost-2',
    'glyph-mono-spotify_spotify': 'brand-spotify',
    'org.gnome.Yelp': 'help-circle',
    'user-trash': 'trash',
    'user-trash-full': 'trash',
    # app grid
    'jockey': 'steering-wheel',
    'preferences-system-network': 'network',
    'btop': 'gauge',
    'org.gnome.Calculator': 'calculator',
    'org.gnome.Characters': 'letter-case',
    'org.gnome.clocks': 'clock',
    'org.gnome.baobab': 'chart-pie',
    'org.gnome.DiskUtility': 'database',
    'org.gnome.Evince': 'file-text',
    'echomixer': 'adjustments-horizontal',
    'envy24control': 'adjustments',
    'glyph-mono-firmware-updater_firmware-updater': 'cpu',
    'fish': 'fish',
    'org.gnome.font-viewer': 'typography',
    'hdajackretask': 'plug-connected',
    'hdspconf': 'tool',
    'hdspmixer': 'adjustments-alt',
    'org.gnome.eog': 'photo',
    'display-im6.q16': 'wand',
    'preferences-desktop-locale': 'language',
    'org.gnome.Logs': 'list-details',
    'org.gnome.seahorse.Application': 'key',
    'org.gnome.PowerStats': 'battery-charging',
    'multimedia-volume-control': 'volume',
    'alsa-tools': 'wave-sine',
    'org.gnome.Settings': 'settings',
    'software-properties': 'package',
    'system-software-update': 'refresh',
    'session-properties': 'rocket',
    'org.gnome.SystemMonitor': 'activity',
    'org.gnome.Terminal': 'terminal-2',
    'org.gnome.TextEditor': 'notes',
}

# Each glyph glows in its app's own colour (sampled from the original icon, then
# brightened so it reads on the dark disc). Apps with grey icons glow white.
GLOW = {
    'glyph-mono-firefox_firefox': '#FF7139',
    'org.gnome.Nautilus': '#F0566A',
    'glyph-mono-snap-store_snap-store': '#F0672E',
    'claude-desktop': '#D9704E',
    'glyph-mono-ghostty_ghostty': '#4D6BFF',
    'glyph-mono-spotify_spotify': '#1ED760',
    'org.gnome.Yelp': '#3BA3F0',
    'user-trash': '#4CC23F',
    'user-trash-full': '#4CC23F',
    'jockey': '#3FC28C',
    'preferences-system-network': '#A98BF0',
    'btop': '#FF3B3B',
    'org.gnome.Calculator': '#FBBE29',
    'org.gnome.Characters': '#4C95F0',
    'org.gnome.clocks': '#F04A5C',
    'org.gnome.baobab': '#F57E7E',
    'org.gnome.Evince': '#F66555',
    'echomixer': '#33CC55',
    'envy24control': '#33CC55',
    'glyph-mono-firmware-updater_firmware-updater': '#3FC28C',
    'fish': '#5CC25A',
    'hdajackretask': '#F03A4A',
    'hdspconf': '#E08A6A',
    'hdspmixer': '#55C244',
    'display-im6.q16': '#FF5E5E',
    'preferences-desktop-locale': '#4C95F0',
    'org.gnome.PowerStats': '#83B5F0',
    'software-properties': '#3A9BE0',
    'system-software-update': '#F06A80',
    'session-properties': '#7499F6',
    'org.gnome.SystemMonitor': '#9EB7F6',
    'org.gnome.TextEditor': '#4C95F0',
}
WHITE = '#E8E8E8'


def glyph(name):
    os.makedirs(CACHE, exist_ok=True)
    path = f'{CACHE}/{name}.svg'
    if not os.path.exists(path):
        with urllib.request.urlopen(TABLER.format(name), timeout=20) as r:
            open(path, 'wb').write(r.read())
    body = open(path).read()
    inner = re.search(r'<svg[^>]*>(.*)</svg>', body, re.S).group(1)
    return re.sub(r'<path stroke="none"[^>]*/>', '', inner).strip()


def tile(inner, colour=WHITE, dot=False):
    red = '\n  <circle cx="190" cy="66" r="9" fill="#D71921"/>' if dot else ''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <filter id="glow" filterUnits="userSpaceOnUse" x="-12" y="-12" width="48" height="48">
      <feGaussianBlur in="SourceGraphic" stdDeviation="1.4" result="wide"/>
      <feGaussianBlur in="SourceGraphic" stdDeviation="0.5" result="tight"/>
      <feMerge><feMergeNode in="wide"/><feMergeNode in="tight"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <circle cx="128" cy="128" r="120" fill="#000000"/>
  <circle cx="128" cy="128" r="119.25" fill="none" stroke="{colour}" stroke-opacity="0.35" stroke-width="1.5"/>
  <g transform="translate(68 68) scale(5)" filter="url(#glow)" fill="none" stroke="{colour}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    {inner}
  </g>{red}
</svg>
'''


def main():
    bad = []
    for name, g in TILES.items():
        try:
            svg = tile(glyph(g), GLOW.get(name, WHITE), dot=name == 'user-trash-full')
        except Exception as e:
            bad.append(f'{name} ({g}: {e})')
            continue
        open(f'{HERE}/{name}.svg', 'w').write(svg)
    print(f'{len(TILES) - len(bad)} tiles')
    for b in bad:
        print('  failed', b)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
