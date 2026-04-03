use std::io::{self, Write};
use std::time::{Duration, Instant};

use anyhow::{Context, Result, bail};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum MirrorRegion {
    Mda,
    Cga,
}

impl MirrorRegion {
    fn from_token(token: &str) -> Result<Self> {
        match token {
            "B000" => Ok(Self::Mda),
            "B800" => Ok(Self::Cga),
            _ => bail!("unknown mirror region {token}"),
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::Mda => "MDA",
            Self::Cga => "CGA",
        }
    }
}

#[derive(Debug)]
pub struct TextMirror {
    cga_vram: Vec<u8>,
    mda_vram: Vec<u8>,
    cga_crtc: [u8; 32],
    mda_crtc: [u8; 32],
    cga_index: u8,
    mda_index: u8,
    cga_mode_control: u8,
    last_region: MirrorRegion,
    dirty: bool,
    last_render: Instant,
    first_render: bool,
}

impl TextMirror {
    pub fn new() -> Self {
        Self {
            cga_vram: vec![0; 0x8000],
            mda_vram: vec![0; 0x8000],
            cga_crtc: [0; 32],
            mda_crtc: [0; 32],
            cga_index: 0,
            mda_index: 0,
            cga_mode_control: 0x01,
            last_region: MirrorRegion::Cga,
            dirty: true,
            last_render: Instant::now(),
            first_render: true,
        }
    }

    pub fn apply_line(&mut self, line: &str) -> Result<()> {
        if line.is_empty() {
            return Ok(());
        }

        let mut parts = line.split_whitespace();
        match parts.next() {
            Some("VM") => {
                let region =
                    MirrorRegion::from_token(parts.next().context("missing mirror region")?)?;
                let offset = u16::from_str_radix(parts.next().context("missing mirror offset")?, 16)
                    .context("invalid mirror offset")? as usize;
                let value = u8::from_str_radix(parts.next().context("missing mirror value")?, 16)
                    .context("invalid mirror value")?;
                self.write_vram(region, offset, value);
            }
            Some("VI") => {
                let port = u16::from_str_radix(parts.next().context("missing mirror port")?, 16)
                    .context("invalid mirror port")?;
                let value = u8::from_str_radix(parts.next().context("missing mirror value")?, 16)
                    .context("invalid mirror value")?;
                self.write_port(port, value);
            }
            Some(other) => bail!("unknown mirror event {other}"),
            None => {}
        }
        Ok(())
    }

    pub fn render_if_due(&mut self, force: bool) -> Result<()> {
        let now = Instant::now();
        if !self.dirty && !force {
            return Ok(());
        }
        if !force && now.duration_since(self.last_render) < Duration::from_millis(66) {
            return Ok(());
        }

        let mut stdout = io::stdout().lock();
        if self.first_render {
            write!(stdout, "\x1b[2J\x1b[?25l").context("failed to initialize terminal")?;
            self.first_render = false;
        }
        write!(stdout, "\x1b[H").context("failed to home cursor")?;

        let status = self.status_line();
        writeln!(stdout, "{status:<80}").context("failed to write status line")?;
        for line in self.render_lines() {
            writeln!(stdout, "{line:<80}").context("failed to write mirrored text line")?;
        }
        stdout.flush().context("failed to flush mirror output")?;

        self.dirty = false;
        self.last_render = now;
        Ok(())
    }

    pub fn restore_terminal(&self) -> Result<()> {
        let mut stdout = io::stdout().lock();
        write!(stdout, "\x1b[?25h\n").context("failed to restore terminal state")?;
        stdout.flush().context("failed to flush terminal restore")?;
        Ok(())
    }

    fn write_vram(&mut self, region: MirrorRegion, offset: usize, value: u8) {
        let buffer = match region {
            MirrorRegion::Mda => &mut self.mda_vram,
            MirrorRegion::Cga => &mut self.cga_vram,
        };
        if offset < buffer.len() {
            buffer[offset] = value;
            self.last_region = region;
            self.dirty = true;
        }
    }

    fn write_port(&mut self, port: u16, value: u8) {
        match port {
            0x3B4 => self.mda_index = value,
            0x3B5 => {
                self.mda_crtc[(self.mda_index & 0x1F) as usize] = value;
                self.last_region = MirrorRegion::Mda;
                self.dirty = true;
            }
            0x3D4 => self.cga_index = value,
            0x3D5 => {
                self.cga_crtc[(self.cga_index & 0x1F) as usize] = value;
                self.last_region = MirrorRegion::Cga;
                self.dirty = true;
            }
            0x3D8 => {
                self.cga_mode_control = value;
                self.last_region = MirrorRegion::Cga;
                self.dirty = true;
            }
            _ => {}
        }
    }

    fn status_line(&self) -> String {
        let region = self.active_region();
        let mode = match self.region_layout(region) {
            Some((cols, rows, _)) => format!("{cols}x{rows} text"),
            None => "graphics/unsupported".to_string(),
        };
        format!(
            "XTMax mirror | adapter={} | mode={} | Ctrl-C to exit",
            region.label(),
            mode
        )
    }

    fn render_lines(&self) -> Vec<String> {
        let region = self.active_region();
        let Some((cols, rows, start_address)) = self.region_layout(region) else {
            return vec!["graphics mode not yet supported".to_string()];
        };

        let buffer = match region {
            MirrorRegion::Mda => &self.mda_vram,
            MirrorRegion::Cga => &self.cga_vram,
        };
        let mut lines = Vec::with_capacity(rows);
        let bytes_per_row = cols * 2;
        for row in 0..rows {
            let mut rendered = String::with_capacity(cols);
            let row_base = (start_address + row * bytes_per_row) % buffer.len();
            for col in 0..cols {
                let index = (row_base + col * 2) % buffer.len();
                rendered.push(render_char(buffer[index]));
            }
            lines.push(rendered);
        }
        lines
    }

    fn active_region(&self) -> MirrorRegion {
        self.last_region
    }

    fn region_layout(&self, region: MirrorRegion) -> Option<(usize, usize, usize)> {
        match region {
            MirrorRegion::Mda => {
                let start = crtc_start_address(&self.mda_crtc);
                Some((80, 25, start * 2))
            }
            MirrorRegion::Cga => {
                if (self.cga_mode_control & 0x02) != 0 {
                    return None;
                }
                let cols = if (self.cga_mode_control & 0x01) != 0 {
                    80
                } else {
                    40
                };
                let start = crtc_start_address(&self.cga_crtc);
                Some((cols, 25, start * 2))
            }
        }
    }
}

impl Drop for TextMirror {
    fn drop(&mut self) {
        let _ = self.restore_terminal();
    }
}

fn crtc_start_address(registers: &[u8; 32]) -> usize {
    (((registers[0x0C] as usize) << 8) | registers[0x0D] as usize) & 0x3FFF
}

fn render_char(byte: u8) -> char {
    match byte {
        0 => ' ',
        0x20..=0x7E => byte as char,
        _ => '.',
    }
}

#[cfg(test)]
mod tests {
    use super::TextMirror;

    #[test]
    fn applies_cga_text_write() {
        let mut mirror = TextMirror::new();
        mirror.apply_line("VM B800 0000 41").unwrap();
        let lines = mirror.render_lines();
        assert!(lines[0].starts_with('A'));
    }

    #[test]
    fn applies_cga_mode_switch_to_40_columns() {
        let mut mirror = TextMirror::new();
        mirror.apply_line("VI 03D8 00").unwrap();
        let lines = mirror.render_lines();
        assert_eq!(lines[0].len(), 40);
    }
}
