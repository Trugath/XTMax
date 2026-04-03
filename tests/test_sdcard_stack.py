import pathlib
import re
import subprocess
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
FIRMWARE = REPO_ROOT / "firmware" / "teensy" / "teensy.ino"
BOOTROM = REPO_ROOT / "software" / "bootrom" / "bootrom.asm"
BOOTROM_UTILS = REPO_ROOT / "software" / "bootrom" / "utils.inc"


class SDCardStackTests(unittest.TestCase):
    def test_bootrom_assembles(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            output = pathlib.Path(tmpdir) / "bootrom.bin"
            subprocess.run(
                ["nasm", "-f", "bin", "-o", str(output), str(BOOTROM)],
                check=True,
                cwd=BOOTROM.parent,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            self.assertTrue(output.exists())
            self.assertGreater(output.stat().st_size, 0)

    def test_firmware_samples_sd_after_clock_high_delay(self) -> None:
        text = FIRMWARE.read_text()
        match = re.search(
            r"inline void SD_SPI_TXRXBit\(\)\s*\{(?P<body>.*?)\n\}",
            text,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        body = match.group("body")
        high_section = body.split("// Drive CLK and MOSI low", 1)[0]
        delay_index = high_section.find("delayNanoseconds(SD_SPI_BIT_TIME_NS);")
        sample_index = high_section.find("sd_spi_datain = sd_spi_datain << 1;")
        self.assertNotEqual(delay_index, -1)
        self.assertNotEqual(sample_index, -1)
        self.assertLess(delay_index, sample_index)

    def test_bootrom_has_legacy_and_block_addressing_support(self) -> None:
        text = BOOTROM.read_text()
        for needle in (
            "cmd1        db",
            "cmd16       db",
            "cmd58       db",
            "acmd41_legacy db",
            "XTMAX_WORK_SD_FLAGS",
            "XTMAX_WORK_SD_RESPONSE",
            "adjust_sd_command_address:",
            "call adjust_sd_command_address",
            "test byte [XTMAX_WORK_SD_FLAGS], SD_FLAG_BLOCK_ADDRESSING",
        ):
            self.assertIn(needle, text)

    def test_bootrom_uses_direct_text_output_on_active_page(self) -> None:
        bootrom_text = BOOTROM.read_text()
        utils_text = BOOTROM_UTILS.read_text()
        self.assertNotIn("QUIET_VIDEO_OUTPUT", bootrom_text)
        self.assertIn("call print_char", utils_text)
        self.assertNotIn("int 0x10", utils_text)
        self.assertIn("mov bl, [0x62]", utils_text)
        self.assertIn("mov cx, [0x4e]", utils_text)
        self.assertIn("mov [bx+0x50], dx", utils_text)

    def test_bootrom_has_service_stage_loader(self) -> None:
        text = BOOTROM.read_text()
        for needle in (
            "maybe_launch_service_stage:",
            "load_service_stage:",
            "poll_service_hotkey:",
            "service_hint_msg",
            "service_fail_msg",
            "XTMAX_SERVICE_HEADER_SECTOR",
            "XTMAX_SERVICE_PAYLOAD_SECTOR",
            "XTMAX_SERVICE_LOAD_SEG",
        ):
            self.assertIn(needle, text)


if __name__ == "__main__":
    unittest.main()
