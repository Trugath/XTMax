import pathlib
import subprocess
import tempfile
import textwrap
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
XTMAX_CORE_CPP = REPO_ROOT / "firmware" / "teensy" / "xtmax_core.cpp"


class XtmaxCoreTests(unittest.TestCase):
    def test_shared_core_compiles_and_passes_behavior_checks(self) -> None:
        harness = textwrap.dedent(
            r"""
            #include <cassert>
            #include <cstdint>
            #include "xtmax_core.h"

            int main() {
              XtmaxState state{};

              XTMax_InitState(&state, true, false, 0xCE000, 0x2000);
              assert(XTMax_GetRegion(&state, 0x0000) == Unused);
              assert(XTMax_GetRegion(&state, 0xCE000) == BootRom);
              assert(XTMax_GetRegion(&state, 0xD0000) == SdCard);
              assert(state.mem_response[0] == AutoDetect);
              assert(state.mem_response[10] == Respond);
              assert(state.mem_response[15] == DontRespond);

              XTMax_WriteMmanRegister(&state, 0x260 + 10, 0x00);
              XTMax_WriteMmanRegister(&state, 0x260 + 11, 0xE0);
              XTMax_WriteMmanRegister(&state, 0x260 + 12, 0x02);
              assert(XTMax_GetRegion(&state, 0xE0000) == EmsWindow);
              assert(XTMax_GetRegion(&state, 0xE7FFF) == EmsWindow);
              assert(XTMax_GetRegion(&state, 0xE8000) == Unused);

              XTMax_WriteMmanRegister(&state, 0x260 + 0, 0x34);
              XTMax_WriteMmanRegister(&state, 0x260 + 1, 0x12);
              XTMax_WriteMmanRegister(&state, 0x260 + 2, 0x78);
              XTMax_WriteMmanRegister(&state, 0x260 + 3, 0x56);

              uint32_t psram_address = 0;
              assert(XTMax_ResolveEmsAddress(&state, 0xE0123, &psram_address));
              assert(psram_address == ((0x1234u << 14) | 0x0123u));
              assert(XTMax_ResolveEmsAddress(&state, 0xE4567, &psram_address));
              assert(psram_address == ((0x5678u << 14) | 0x0567u));
              assert(!XTMax_ResolveEmsAddress(&state, 0xDFFFF, &psram_address));

              XTMax_WriteMmanRegister(&state, 0x260 + 13, 0x00);
              XTMax_WriteMmanRegister(&state, 0x260 + 14, 0xD0);
              XTMax_WriteMmanRegister(&state, 0x260 + 15, 0x02);
              assert(XTMax_GetRegion(&state, 0xD0000) == Ram);
              assert(XTMax_GetRegion(&state, 0xD0FFF) == Ram);
              assert(XTMax_ReadMmanRegister(&state, 0x260 + 0) == 0x34);
              assert(XTMax_ReadMmanRegister(&state, 0x260 + 1) == 0x12);
              assert(XTMax_ReadMmanRegister(&state, 0x260 + 15) == Ram);

              XtmaxState no_rom{};
              XTMax_InitState(&no_rom, false, true, 0xCE000, 0x2000);
              assert(XTMax_GetRegion(&no_rom, 0x0000) == Ram);
              assert(XTMax_GetRegion(&no_rom, 0xCE000) == Unused);

              return 0;
            }
            """
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = pathlib.Path(tmpdir)
            harness_path = tmpdir_path / "xtmax_core_harness.cpp"
            binary_path = tmpdir_path / "xtmax_core_harness"
            harness_path.write_text(harness)

            subprocess.run(
                [
                    "g++",
                    "-std=c++17",
                    "-I",
                    str(XTMAX_CORE_CPP.parent),
                    str(XTMAX_CORE_CPP),
                    str(harness_path),
                    "-o",
                    str(binary_path),
                ],
                check=True,
                cwd=REPO_ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            subprocess.run(
                [str(binary_path)],
                check=True,
                cwd=REPO_ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )


if __name__ == "__main__":
    unittest.main()
