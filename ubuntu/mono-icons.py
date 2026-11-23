#!/usr/bin/env python3
"""Glyph-Mono: a greyscale copy of every installed app's icon, as an icon theme.

Resolves each .desktop file's Icon= through the current base theme (Yaru-red),
renders it at 256px, drops the colour and writes it to
~/.local/share/icons/Glyph-Mono. Everything that isn't an app icon (folders,
status icons, mimetypes) is inherited from the base theme.

Snaps point Icon= at an absolute path, which no theme can override, so those
.desktop files get a copy in ~/.local/share/applications that names the
greyscale icon instead (listed in overrides.txt so --undo can remove them).

Re-run after installing apps.  --undo removes the theme and the overrides.
"""
import configparser, os, shutil, sys
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import Gtk, GdkPixbuf
from PIL import Image, ImageEnhance

BASE = 'Yaru-red'
HOME = os.path.expanduser('~')
THEME = f'{HOME}/.local/share/icons/Glyph-Mono'
LOCAL_APPS = f'{HOME}/.local/share/applications'
OVERRIDES = f'{THEME}/overrides.txt'
APP_DIRS = ['/usr/share/applications', '/usr/local/share/applications',
            '/var/lib/snapd/desktop/applications', f'{HOME}/.local/share/applications',
            '/var/lib/flatpak/exports/share/applications',
            f'{HOME}/.local/share/flatpak/exports/share/applications']
SIZES = (256, 48)


def undo():
    if os.path.exists(OVERRIDES):
        for path in open(OVERRIDES).read().split():
            if os.path.exists(path):
                os.remove(path)
    shutil.rmtree(THEME, ignore_errors=True)
    print('removed Glyph-Mono')


def mono(src, size):
    try:
        pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(src, size, size, True)
        if not pb.get_has_alpha():
            pb = pb.add_alpha(False, 0, 0, 0)
        img = Image.frombytes('RGBA', (pb.get_width(), pb.get_height()),
                              pb.get_pixels(), 'raw', 'RGBA', pb.get_rowstride())
    except Exception:  # e.g. old .xpm pixmaps
        img = Image.open(src).convert('RGBA')
        img.thumbnail((size, size), Image.LANCZOS)
    alpha = img.getchannel('A')
    grey = ImageEnhance.Contrast(img.convert('L')).enhance(1.15)
    out = Image.merge('RGBA', (grey, grey, grey, alpha))
    if out.size != (size, size):  # centre non-square icons
        canvas = Image.new('RGBA', (size, size))
        canvas.paste(out, ((size - out.width) // 2, (size - out.height) // 2))
        out = canvas
    return out


def main():
    if '--undo' in sys.argv:
        return undo()
    shutil.rmtree(THEME, ignore_errors=True)
    for s in SIZES:
        os.makedirs(f'{THEME}/{s}x{s}/apps', exist_ok=True)
    os.makedirs(LOCAL_APPS, exist_ok=True)

    theme = Gtk.IconTheme()
    theme.set_custom_theme(BASE)
    done, overrides, missed = set(), [], []

    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if not f.endswith('.desktop'):
                continue
            path = f'{d}/{f}'
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            cp.optionxform = str
            try:
                cp.read(path, encoding='utf-8')
                icon = cp['Desktop Entry'].get('Icon', '').strip()
            except Exception:
                continue
            if not icon or icon.startswith('glyph-mono-'):
                continue

            if os.path.isabs(icon):
                src, name = icon, 'glyph-mono-' + f[:-len('.desktop')]
            else:
                info = theme.lookup_icon(icon, 256, Gtk.IconLookupFlags.FORCE_SIZE)
                src, name = (info.get_filename() if info else None), icon
            if not src or not os.path.exists(src):
                missed.append(f)
                continue

            if name not in done:
                try:
                    for s in SIZES:
                        mono(src, s).save(f'{THEME}/{s}x{s}/apps/{name}.png')
                except Exception as e:
                    missed.append(f'{f} ({e})')
                    continue
                done.add(name)

            # absolute Icon= path: shadow the .desktop with one naming our icon
            if os.path.isabs(icon) and d != LOCAL_APPS:
                dst = f'{LOCAL_APPS}/{f}'
                if os.path.exists(dst) and 'Icon=glyph-mono-' not in open(dst).read():
                    continue  # the user's own override; leave it
                text = open(path, encoding='utf-8').read()
                text = '\n'.join(f'Icon={name}' if l.strip() == f'Icon={icon}' else l
                                 for l in text.splitlines()) + '\n'
                open(dst, 'w', encoding='utf-8').write(text)
                overrides.append(dst)

    # Glyph tiles (tiles/make-tiles.py) win over the greyscale copies
    dock = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tiles')
    os.makedirs(f'{THEME}/scalable/apps', exist_ok=True)
    for f in sorted(os.listdir(dock)) if os.path.isdir(dock) else []:
        if f.endswith('.svg'):
            shutil.copy(f'{dock}/{f}', f'{THEME}/scalable/apps/{f}')
            for s in SIZES:
                png = f'{THEME}/{s}x{s}/apps/{f[:-4]}.png'
                if os.path.exists(png):
                    os.remove(png)

    dirs = ','.join(['scalable/apps'] + [f'{s}x{s}/apps' for s in SIZES])
    sections = '\n[scalable/apps]\nSize=256\nMinSize=16\nMaxSize=512\nContext=Applications\nType=Scalable\n'
    sections += ''.join(f'\n[{s}x{s}/apps]\nSize={s}\nContext=Applications\nType=Fixed\n'
                        for s in SIZES)
    with open(f'{THEME}/index.theme', 'w') as t:
        t.write(f'[Icon Theme]\nName=Glyph-Mono\nComment=Greyscale app icons for Glyph\n'
                f'Inherits={BASE},Yaru,hicolor\nDirectories={dirs}\n{sections}')
    with open(OVERRIDES, 'w') as o:
        o.write('\n'.join(overrides) + '\n')
    os.system(f'update-desktop-database -q {LOCAL_APPS} 2>/dev/null')
    print(f'{len(done)} icons, {len(overrides)} snap overrides, {len(missed)} skipped')
    for m in missed:
        print('  skipped', m)


if __name__ == '__main__':
    main()
