# Getting started with XTMax

This guide lists **dependencies**, a **minimal setup order**, and **assumptions** the maintainers make about your machine and legal constraints. For a map of directories and generated artifacts, see [docs/REPO_LAYOUT.md](./docs/REPO_LAYOUT.md). For agent-oriented commands, see [AGENTS.md](./AGENTS.md).

---

## Assumptions

These are intentional boundaries; if one of them is false on your side, expect extra steps or failures.

1. **Host OS**  
   Instructions are written for a **Unix-like** environment (Linux, macOS, or WSL with typical developer tools). Windows-native paths and shells are not documented here.

2. **You have legal ROMs and media where required**  
   The MAME harness needs **machine BIOS ROMs** you are entitled to use (for example `ibm5160.zip` or equivalent loose files MAME recognizes). The repo may ship **some** helper ROM aliases under `harness/mame/roms/`; it does **not** ship full commercial BIOS sets or DOS boot disks.  
   **DOS driver automation** (`harness/mame/run-driver-tests.sh`) needs a **bootable DOS floppy image** you supply (`DOS_BOOT_FLOPPY`).

3. **Hardware is optional for most automated tests**  
   Firmware timing, ISA electrical behavior, and real USB-serial bring-up still need a **physical XT-class machine and XTMax card**. Automated tests in `tests/` and `host/xtmax-host` do not replace that.

4. **Rust toolchain is recent**  
   `host/xtmax-host` uses **Cargo `edition = "2024"`**. You need a **current stable Rust** release that supports the 2024 edition (older installs will fail to compile).

5. **Patched MAME is local and large**  
   XTMax device regressions use a **separately built** MAME tree under `harness/mame/artifacts/` (gitignored). The repo ships a **patch**, not a prebuilt emulator binary. Building MAME requires substantial disk, CPU time, and build dependencies (see below).

6. **Serial port access on Linux**  
   Using `xtmax-host` against a real Teensy may require **dialout/uucp group** membership or udev rules so `/dev/ttyACM0` (or similar) is readable and writable.

7. **Display or offscreen video for MAME**  
   MAME is normally built **with a UI/video backend**. Headless or CI setups may need your distro’s documented offscreen/SDL options; the harness does not enforce a single graphics stack.

8. **License mixing**  
   The repo is **mostly MIT** at the root; some bundled trees (for example under `software/sd/`) retain **their own licenses**. Do not assume one license applies to every file.

---

## Dependencies by what you want to do

### Clone, read, and edit only

- **None** beyond a text editor and Git.

### Python tests (`tests/`)

- **Python 3** (stdlib `unittest`).
- **`g++`** with **C++17** support (compiles a small harness against `firmware/teensy/xtmax_core.cpp`).
- **`nasm`** (assembles `software/bootrom/bootrom.asm` in a temp directory).

Run:

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

### Rust host tool (`host/xtmax-host`)

- **Rust** (cargo + rustc), stable channel, **2024 edition** support.
- System headers/libs for **`serialport`** (often `pkg-config` + `libudev` on Linux).

Run:

```bash
cargo build --manifest-path host/xtmax-host/Cargo.toml
cargo test --manifest-path host/xtmax-host/Cargo.toml
```

### Boot ROM assembly and header refresh

- **`nasm`** (produce raw binary from `software/bootrom/bootrom.asm`).
- **Python 3** (`checksum.py`, `generate_header.py` in `software/bootrom/`).

See [README.md](./README.md) for the usual command sequence.

### Floppy image rebuild (`scripts/build_xtmax_floppy.py`)

- **Python 3** and **pip**.
- Packages in [scripts/requirements-floppy.txt](./scripts/requirements-floppy.txt) (`pyfatfs`, `fs`).

```bash
pip install -r scripts/requirements-floppy.txt
python3 scripts/build_xtmax_floppy.py
```

### Teensy firmware

- **Arduino IDE** with **Teensyduino**, *or* **`arduino-cli`** plus the Teensy **board package** (`teensy:avr`).
- USB drivers as required by PJRC for your OS.

Typical CLI compile from repo root:

```bash
arduino-cli compile --fqbn teensy:avr:teensy41 firmware/teensy
```

Details and troubleshooting: [firmware/teensy/AGENTS.md](./firmware/teensy/AGENTS.md).

### Stock MAME smoke harness (`harness/mame/run-smoke.sh`)

- **MAME** on `PATH` (or set **`MAME_BIN`**).
- **ROM files** for the machine you select (default targets and layout: [harness/mame/README.md](./harness/mame/README.md)).
- **`bash`**, **`curl`** (bootstrap/fetch paths), **`sed`**.

Initial setup:

```bash
./harness/mame/bootstrap.sh
```

`bootstrap.sh` may invoke `sudo` on some distros to install MAME via the package manager; you can skip that and install MAME yourself.

### Patched MAME + XTMax device regressions

- Everything for **stock MAME**, plus:
- **`patch`**, **`tar`**, **`curl`**, **`make`**, a **C++ toolchain**, and MAME’s usual build dependencies (the script leans on **`pkg-config`** and may bootstrap **fontconfig** on Debian-style systems).
- **Network** for the first **download** of upstream MAME `mame0264` source (URL is pinned in the harness scripts).

Build (long-running):

```bash
./harness/mame/build-mame-xtmax.sh
```

The binary is expected at:

`harness/mame/artifacts/mame-src-mame0264/mame`

Device tests also need **`nasm`** for generated boot images.

### Full automated suite (repo script)

From the repo root, after dependencies above are satisfied:

```bash
./scripts/run_all_tests.sh
```

This runs Python tests, Rust tests, **all** `run-xtmax-*.sh` flows **if** the patched MAME binary exists, a short **`run-smoke.sh`**, and **`run-driver-tests.sh` only if** `DOS_BOOT_FLOPPY` is set. See [AGENTS.md](./AGENTS.md) for environment variables (`MAME_SECONDS_TO_RUN`, `MAME_SMOKE_SECONDS`, etc.).

---

## Suggested first-time setup order

1. Install **Rust** (current stable), **Python 3**, **`g++`**, **`nasm`**, **`git`**.
2. Run **Python** and **Rust** tests to confirm the toolchain.
3. If you want MAME: run **`./harness/mame/bootstrap.sh`**, install or place **ROMs**, run **`./harness/mame/run-smoke.sh`**.
4. If you want **XTMax-in-MAME** regressions: run **`./harness/mame/build-mame-xtmax.sh`**, then **`./scripts/run_all_tests.sh`** (or individual `harness/mame/run-xtmax-*.sh` scripts).
5. For **hardware**: install **Arduino/Teensyduino**, read **[firmware/teensy/AGENTS.md](./firmware/teensy/AGENTS.md)**, and use **[firmware/teensy/IO_PORTS.md](./firmware/teensy/IO_PORTS.md)** for I/O and coexistence.

---

## Where to go next

| Goal | Document |
|------|-----------|
| Project overview and layout | [README.md](./README.md) |
| Maintainer / CI-style commands | [AGENTS.md](./AGENTS.md) |
| Firmware flash and 5155 notes | [firmware/teensy/AGENTS.md](./firmware/teensy/AGENTS.md) |
| I/O map | [firmware/teensy/IO_PORTS.md](./firmware/teensy/IO_PORTS.md) |
| DOS drivers | [software/README.md](./software/README.md) |
| MAME harness details | [harness/mame/README.md](./harness/mame/README.md) |
| Mirror / USB key-injection design | [docs/SCREEN_MIRROR_AND_KEY_INJECTION.md](./docs/SCREEN_MIRROR_AND_KEY_INJECTION.md) |
