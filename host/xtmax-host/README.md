# xtmax-host

`xtmax-host` is the first host-side Rust utility for the XTMax USB link.

Current scope:

- enumerate serial ports
- reset the XTMax auxiliary host-link state
- toggle the mirror-enabled feature flag
- render a live terminal mirror of MDA/CGA text writes
- queue keyboard events
- inject plain text through BIOS-friendly ASCII/scancode pairs
- send raw protocol lines for bring-up

This is the host companion to the firmware-side auxiliary register block at `0x290-0x297`.

## Build

```bash
cargo build --manifest-path host/xtmax-host/Cargo.toml
```

## Example Usage

List candidate serial devices:

```bash
cargo run --manifest-path host/xtmax-host/Cargo.toml -- ports
```

Reset auxiliary state:

```bash
cargo run --manifest-path host/xtmax-host/Cargo.toml -- --port /dev/ttyACM0 reset-aux
```

Enable the mirror feature flag:

```bash
cargo run --manifest-path host/xtmax-host/Cargo.toml -- --port /dev/ttyACM0 mirror true
```

Run the live text-mode mirror:

```bash
cargo run --manifest-path host/xtmax-host/Cargo.toml -- --port /dev/ttyACM0 mirror-text
```

Inject a line of text:

```bash
cargo run --manifest-path host/xtmax-host/Cargo.toml -- --port /dev/ttyACM0 type "DIR\r"
```

Queue one explicit key event:

```bash
cargo run --manifest-path host/xtmax-host/Cargo.toml -- --port /dev/ttyACM0 send-key --ascii 13 --scancode 28 --flags 0
```

## Current Limitation

Current limitations:

- only text-mode CGA/MDA mirroring is implemented
- graphics modes are detected but not rendered yet
- the mirror uses the current bootstrap line protocol rather than the future framed transport
