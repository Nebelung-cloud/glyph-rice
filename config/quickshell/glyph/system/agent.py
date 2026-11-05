#!/usr/bin/env python3
# glyph agent: answers for the user to BlueZ (a code when pairing) and NetworkManager (a network password, vpn).
# A question — a json line on stdout, the answer — a json line from stdin: {"id": n, "ok": true, "values": {...}}.
# system/Agent.qml draws the window. No bluez or NetworkManager — that agent simply doesn't start
import json
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
loop = GLib.MainLoop()
pending = {}  # id → (ok, fail, key); key — whose question, for cancelling
seq = 0


def say(msg):
    print(json.dumps(msg), flush=True)


def ask(kind, data, ok, fail, key):
    global seq
    seq += 1
    pending[seq] = (ok, fail, key)
    say(dict(data, id=seq, kind=kind))


def answer(src, cond):
    line = sys.stdin.readline()
    if not line:  # the shell closed — time for us to go too
        loop.quit()
        return False
    try:
        m = json.loads(line)
        ok, fail, _ = pending.pop(m["id"])
    except (ValueError, KeyError, TypeError):
        return True
    try:
        ok(m.get("values") or {}) if m.get("ok") else fail()
    except (ValueError, dbus.DBusException):  # not a number in passkey, the call was already withdrawn
        fail()
    return True


def drop(match):
    """the question was withdrawn on the other side: refuse and remove the window"""
    for i in [i for i, p in pending.items() if match(p[2])]:
        _, fail, _ = pending.pop(i)
        say({"kind": "cancel", "id": i})
        try:
            fail()
        except dbus.DBusException:
            pass


# ---- bluetooth: org.bluez.Agent1, KeyboardDisplay — we can both show a code and ask for one ----
BT = "org.bluez.Agent1"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


def device(path, prop="Alias"):
    try:
        props = dbus.Interface(bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
        return props.Get("org.bluez.Device1", prop)
    except dbus.DBusException:
        return str(path).rsplit("/dev_", 1)[-1].replace("_", ":") if prop == "Alias" else None


class BtAgent(dbus.service.Object):
    def _ask(self, kind, dev, ok, err, **extra):
        ask(kind, dict(extra, device=str(device(dev))), ok, lambda: err(Rejected("rejected")), ("bt", str(dev)))

    @dbus.service.method(BT, in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method(BT, in_signature="o", out_signature="s", async_callbacks=("ok", "err"))
    def RequestPinCode(self, dev, ok, err):
        self._ask("pin", dev, lambda v: ok(str(v["pin"])), err)

    @dbus.service.method(BT, in_signature="o", out_signature="u", async_callbacks=("ok", "err"))
    def RequestPasskey(self, dev, ok, err):
        self._ask("passkey", dev, lambda v: ok(dbus.UInt32(int(v["pin"]))), err)

    @dbus.service.method(BT, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, dev, passkey, entered):
        say({"kind": "show", "device": str(device(dev)), "code": "%06d" % passkey})

    @dbus.service.method(BT, in_signature="os", out_signature="")
    def DisplayPinCode(self, dev, pin):
        say({"kind": "show", "device": str(device(dev)), "code": str(pin)})

    @dbus.service.method(BT, in_signature="ou", out_signature="", async_callbacks=("ok", "err"))
    def RequestConfirmation(self, dev, passkey, ok, err):
        self._ask("confirm", dev, lambda v: ok(), err, code="%06d" % passkey)

    @dbus.service.method(BT, in_signature="o", out_signature="", async_callbacks=("ok", "err"))
    def RequestAuthorization(self, dev, ok, err):
        self._ask("authorize", dev, lambda v: ok(), err)

    @dbus.service.method(BT, in_signature="os", out_signature="", async_callbacks=("ok", "err"))
    def AuthorizeService(self, dev, uuid, ok, err):
        if device(dev, "Trusted"):  # a trusted one — without asking
            return ok()
        self._ask("service", dev, lambda v: ok(), err, service=str(uuid))

    @dbus.service.method(BT, in_signature="", out_signature="")
    def Cancel(self):
        drop(lambda k: k[0] == "bt")


BT_PATH = "/io/glyph/agent"
bt = BtAgent(bus, BT_PATH)


def bt_up(owner):
    if not owner:
        return
    try:
        m = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
        m.RegisterAgent(BT_PATH, "KeyboardDisplay")
        m.RequestDefaultAgent(BT_PATH)
    except dbus.DBusException as e:
        print(f"bluetooth agent: {e}", file=sys.stderr)


# ---- NetworkManager: SecretAgent, always at this path. We only ask for what's needed to connect ----
NM = "org.freedesktop.NetworkManager.SecretAgent"
ALLOW_INTERACTION, REQUEST_NEW = 0x1, 0x2


class NoSecrets(dbus.DBusException):
    _dbus_error_name = "org.freedesktop.NetworkManager.SecretAgent.NoSecrets"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.freedesktop.NetworkManager.SecretAgent.UserCanceled"


def wanted(con, setting, hints):
    """[(key, label)] of the secrets for the setting"""
    c = con.get(setting, {})
    if setting == "802-11-wireless-security":
        km = str(c.get("key-mgmt", ""))
        if km in ("wpa-psk", "sae"):
            return [("psk", "password")]
        if km == "none":
            return [("wep-key%d" % int(c.get("wep-tx-keyidx", 0)), "wep key")]
        if km == "ieee8021x" and str(c.get("auth-alg", "")) == "leap":
            return [("leap-password", "password")]
        return []
    if setting == "802-1x":
        return [("private-key-password", "key password")] if "tls" in [str(x) for x in c.get("eap", [])] else [("password", "password")]
    if setting in ("pppoe", "gsm", "cdma"):
        return [("password", "password")]
    if setting == "vpn":
        return [(str(h), str(h).replace("-", " ")) for h in hints if not str(h).startswith("x-")] or [("password", "password")]
    if setting == "wireguard":
        return [("private-key", "private key")]
    return []


def save_secret(path, setting, vals):
    """write what was typed into the profile itself, so the next boot connects without asking. NetworkManager only keeps
    a password from an agent when it trusts that agent, and our SaveSecrets is empty, so otherwise it asks at every boot.
    Not for a password set to «ask every time» (flag 2) or a vpn: its plugin owns those"""
    con = dbus.Interface(bus.get_object("org.freedesktop.NetworkManager", path), "org.freedesktop.NetworkManager.Settings.Connection")
    settings = con.GetSettings()
    part = settings.setdefault(setting, dbus.Dictionary({}, signature="sv"))
    for k, v in vals.items():
        if not v or int(part.get(k + "-flags", 0)) & 2:
            continue
        part[k] = v
        part[k + "-flags"] = dbus.UInt32(0)
    con.Update2(settings, dbus.UInt32(1), dbus.Dictionary({}, signature="sv"),  # 1 — to disk
                reply_handler=lambda *a: None, error_handler=lambda e: say({"kind": "log", "text": str(e)}))


class NmAgent(dbus.service.Object):
    @dbus.service.method(NM, in_signature="a{sa{sv}}osasu", out_signature="a{sa{sv}}", async_callbacks=("ok", "err"))
    def GetSecrets(self, con, path, setting, hints, flags, ok, err):
        keys = wanted(con, setting, hints)
        if not keys or not flags & ALLOW_INTERACTION:
            return err(NoSecrets("no secrets"))
        cn = con.get("connection", {})

        def give(v):
            vals = {k: str(v.get(k, "")) for k, _ in keys}
            if setting == "vpn":
                return ok({"vpn": {"secrets": dbus.Dictionary(vals, signature="ss")}})
            ok({setting: dbus.Dictionary(vals, signature="sv")})
            try:
                save_secret(path, setting, vals)
            except dbus.DBusException as e:  # no permission: it still connects, it just asks again next boot
                say({"kind": "log", "text": str(e)})

        ask("secret", {"title": str(cn.get("id", "")), "type": str(cn.get("type", "")), "setting": str(setting),
                       "user": str(con.get("802-1x", {}).get("identity", "")), "retry": bool(flags & REQUEST_NEW),
                       "fields": [{"key": k, "label": l} for k, l in keys]},
            give, lambda: err(Canceled("canceled")), ("nm", str(path), str(setting)))

    @dbus.service.method(NM, in_signature="os", out_signature="")
    def CancelGetSecrets(self, path, setting):
        drop(lambda k: k == ("nm", str(path), str(setting)))

    @dbus.service.method(NM, in_signature="a{sa{sv}}o", out_signature="")
    def SaveSecrets(self, con, path):
        pass  # NetworkManager stores the passwords itself

    @dbus.service.method(NM, in_signature="a{sa{sv}}o", out_signature="")
    def DeleteSecrets(self, con, path):
        pass


nm = NmAgent(bus, "/org/freedesktop/NetworkManager/SecretAgent")


def nm_up(owner):
    if not owner:
        return
    try:
        m = dbus.Interface(bus.get_object("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager/AgentManager"),
                           "org.freedesktop.NetworkManager.AgentManager")
        m.RegisterWithCapabilities("io.glyph.agent", dbus.UInt32(1))  # 1 — we support vpn hints
    except dbus.DBusException as e:
        print(f"network agent: {e}", file=sys.stderr)


# the service was restarted — register again; the first call — right away, with the current owner
bus.watch_name_owner("org.bluez", bt_up)
bus.watch_name_owner("org.freedesktop.NetworkManager", nm_up)
GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, answer)
loop.run()
