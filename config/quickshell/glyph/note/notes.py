"""File operations for the Glyph quick-notes panel."""

import contextlib
import datetime
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import uuid


class ChangedNote(Exception):
    pass


class TrashUnavailable(Exception):
    pass


def documents():
    home = Path.home()
    try:
        docs = Path(subprocess.check_output(
            ["xdg-user-dir", "DOCUMENTS"], text=True, timeout=2
        ).removesuffix("\n"))
        if docs.is_absolute() and docs != home:
            return docs
    except (OSError, subprocess.SubprocessError, UnicodeError):
        pass
    return home / "Documents"


@contextlib.contextmanager
def open_directory(path, create=False):
    if create:
        path.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        yield fd
    finally:
        os.close(fd)


def check_name(name):
    if "/" in name or not name.endswith(".md"):
        raise ValueError("Expected a Markdown filename")
    name.encode("utf-8")


def version(info):
    return f"{info.st_dev}:{info.st_ino}:{info.st_mtime_ns}:{info.st_ctime_ns}:{info.st_size}"


def file_info(directory, name):
    check_name(name)
    info = os.stat(name, dir_fd=directory, follow_symlinks=False)
    if not stat.S_ISREG(info.st_mode):
        raise ChangedNote
    return info


@contextlib.contextmanager
def open_note(directory, name):
    file_info(directory, name)
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
    with os.fdopen(fd, encoding="utf-8", newline="") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode):
            raise ChangedNote
        yield stream, info


def scan(directory, query):
    notes = []
    query = query.casefold()
    for name in os.listdir(directory):
        if not name.endswith(".md"):
            continue
        try:
            with open_note(directory, name) as (stream, info):
                title = ""
                matched = not query or query in name.casefold()
                for line in stream:
                    if not title:
                        title = line.strip()
                    matched = matched or query in line.casefold()
                    if title and matched:
                        break
                if title and matched:
                    notes.append({
                        "name": name, "title": title[:90], "mtime": info.st_mtime,
                        "version": version(info),
                    })
        except (OSError, UnicodeError, ChangedNote):
            # A Documents folder can contain unreadable files or entries removed by another app.
            continue
    return sorted(notes, key=lambda note: (note["mtime"], note["name"]), reverse=True)


def require_version(directory, name, expected):
    try:
        if version(file_info(directory, name)) == expected:
            return
    except FileNotFoundError:
        pass
    raise ChangedNote


def save(directory, name, expected, text):
    token = uuid.uuid4().hex
    temporary = ".glyph-" + token
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        if name:
            require_version(directory, name, expected)
            os.replace(temporary, name, src_dir_fd=directory, dst_dir_fd=directory)
        else:
            timestamp = datetime.datetime.now().isoformat(sep="_", timespec="milliseconds")
            stem = timestamp.replace(":", "-").replace(".", "-")
            name = f"{stem}-{token[:8]}.md"
            # Reserve the name exclusively, including on filesystems without hard links.
            claim = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=directory)
            os.close(claim)
            try:
                os.replace(temporary, name, src_dir_fd=directory, dst_dir_fd=directory)
            except OSError:
                os.unlink(name, dir_fd=directory)
                raise
        return {"name": name, "version": version(file_info(directory, name))}
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temporary, dir_fd=directory)


def send_reminders(directory, names):
    for name in names:
        try:
            with open_note(directory, name) as (stream, _):
                title = next((line.strip() for line in stream if line.strip()), "")
            if title:
                subprocess.run(
                    ["notify-send", "-a", "Notes", "-i", "alarm-symbolic",
                     "--", title[:120].replace("\x00", ""), "Note reminder"],
                    check=True, timeout=5,
                )
        except (OSError, ValueError, ChangedNote, subprocess.SubprocessError):
            # One removed or unreadable note should not affect other reminders.
            continue


def dispatch(action, path, args):
    if action == "list" and not path.exists() and not path.is_symlink():
        return []
    with open_directory(path, create=action == "save" and not args[0]) as directory:
        if action == "list":
            return scan(directory, args[0])
        if action == "remind":
            send_reminders(directory, args)
            return None
        if action in ("read", "copy"):
            with open_note(directory, args[0]) as (stream, info):
                text = stream.read()
                require_version(directory, args[0], version(info))
                return {"text": text, "version": version(info)}
        if action == "save":
            text = sys.stdin.buffer.read().decode("utf-8")
            return save(directory, args[0], args[1], text)
        if action == "trash":
            name, expected = args
            require_version(directory, name, expected)
            if not os.path.samestat(os.fstat(directory), path.lstat()):
                raise ChangedNote
            try:
                subprocess.run(["gio", "trash", "--", str(path / name)],
                               check=True, stderr=subprocess.DEVNULL)
            except FileNotFoundError as exc:
                raise TrashUnavailable from exc
            return None
        raise ValueError("Unknown note operation")


def main():
    action, *args = sys.argv[1:]
    try:
        if action == "directory":
            result = str(documents() / "Notes")
        else:
            path, *arguments = args
            result = dispatch(action, Path(path), arguments)
        # ASCII JSON preserves unusual filenames and newlines across QML process output.
        print(json.dumps(result))
    except ChangedNote:
        return 3
    except TrashUnavailable:
        return 4
    except (OSError, ValueError, subprocess.SubprocessError):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
