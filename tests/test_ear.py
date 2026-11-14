"""Exercise the ear helper without connecting to Bluetooth hardware."""
import contextlib
import io
import json
from pathlib import Path
import runpy
import struct
import unittest
from unittest.mock import MagicMock, patch


HELPER = Path(__file__).resolve().parents[1] / "config/quickshell/glyph/ear"


def frame(cmd, data):
    # Responses without the optional CRC flag.
    return struct.pack("<BHHHB", 0x55, 0x100, cmd, len(data), 0) + data


class EarTest(unittest.TestCase):
    def invoke(self, responses):
        rfcomm, sdp = MagicMock(), MagicMock()
        rfcomm.__enter__.return_value = rfcomm
        sdp.__enter__.return_value = sdp
        sdp.recv.return_value = b"\x19\x00\x03\x08\x01"
        rfcomm.recv.side_effect = responses
        output = io.StringIO()
        with patch("socket.socket", side_effect=[rfcomm, sdp]), \
                patch("sys.argv", [str(HELPER), "00:11:22:33:44:55"]), \
                contextlib.redirect_stdout(output):
            runpy.run_path(str(HELPER), run_name="__main__")
        return json.loads(output.getvalue())

    def test_earbuds_fragmented_frames(self):
        data = frame(0x4007, bytes([3, 2, 100, 3, 95, 4, 80])) + frame(0x401E, bytes([1, 4, 0]))
        self.assertEqual(self.invoke([data[:5], data[5:11], data[11:]]),
                         {"l": 100, "r": 95, "case": 80, "mode": 4})

    def test_single_battery_without_anc(self):
        self.assertEqual(self.invoke([frame(0x4007, bytes([1, 6, 85])), TimeoutError()]), {"bat": 85})

    def test_battery_charging_bit(self):
        self.assertEqual(self.invoke([frame(0x4007, bytes([1, 2, 0x80 | 70])), TimeoutError()]), {"l": 70})

    def test_empty_anc_reply(self):
        self.assertEqual(self.invoke([frame(0x4007, bytes([1, 6, 50])) + frame(0x401E, b"")]), {"bat": 50})

    def test_no_battery_reply(self):
        with self.assertRaisesRegex(SystemExit, "no battery"):
            self.invoke([TimeoutError()])

    def test_invalid_battery_payload(self):
        for battery in (b"", bytes([2, 2, 100])):
            with self.subTest(battery=battery), self.assertRaisesRegex(SystemExit, "invalid battery"):
                self.invoke([frame(0x4007, battery), TimeoutError()])

    def test_device_disconnect(self):
        with self.assertRaisesRegex(SystemExit, "closed"):
            self.invoke([b""])


if __name__ == "__main__":
    unittest.main()
