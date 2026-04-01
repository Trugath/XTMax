import pathlib
import re
import subprocess
import tempfile
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
FIRMWARE = REPO_ROOT / "Code" / "XTMax" / "XTMax.ino"
BOOTROM = REPO_ROOT / "Drivers" / "BootROM" / "bootrom.asm"


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
            "sd_flags        db 0",
            "adjust_sd_command_address:",
            "call adjust_sd_command_address",
            "test byte [sd_flags], SD_FLAG_BLOCK_ADDRESSING",
        ):
            self.assertIn(needle, text)


if __name__ == "__main__":
    unittest.main()
