use std::io::{ErrorKind, Read, Write};
use std::time::Duration;

use anyhow::{Context, Result};
use serialport::{SerialPort, SerialPortInfo, available_ports};

use crate::keyboard::KeyEvent;

pub struct XtmaxLink {
    port: Box<dyn SerialPort>,
    read_buffer: Vec<u8>,
}

impl XtmaxLink {
    pub fn open(path: &str, baud: u32) -> Result<Self> {
        let mut port = serialport::new(path, baud)
            .timeout(Duration::from_millis(250))
            .open()
            .with_context(|| format!("failed to open serial port {path}"))?;
        port.write_data_terminal_ready(true)
            .context("failed to assert DTR on serial port")?;
        Ok(Self {
            port,
            read_buffer: Vec::new(),
        })
    }

    pub fn write_line(&mut self, line: &str) -> Result<()> {
        self.port
            .write_all(line.as_bytes())
            .with_context(|| format!("failed to write command {line:?}"))?;
        self.port
            .write_all(b"\n")
            .context("failed to terminate command with newline")?;
        self.port
            .flush()
            .context("failed to flush serial command")?;
        Ok(())
    }

    pub fn reset_aux(&mut self) -> Result<()> {
        self.write_line("R")
    }

    pub fn set_mirror_enabled(&mut self, enabled: bool) -> Result<()> {
        self.write_line(&format!("M {}", if enabled { 1 } else { 0 }))
    }

    pub fn record_mirror_drop(&mut self, count: u16) -> Result<()> {
        self.write_line(&format!("D {count}"))
    }

    pub fn queue_key(&mut self, event: KeyEvent) -> Result<()> {
        self.write_line(&format!(
            "K {} {} {}",
            event.ascii, event.scancode, event.flags
        ))
    }

    pub fn read_line(&mut self) -> Result<Option<String>> {
        let mut byte = [0u8; 1];
        loop {
            match self.port.read(&mut byte) {
                Ok(0) => return Ok(None),
                Ok(_) => {
                    if byte[0] == b'\n' {
                        let line = String::from_utf8_lossy(&self.read_buffer).into_owned();
                        self.read_buffer.clear();
                        return Ok(Some(line));
                    }
                    if byte[0] != b'\r' {
                        self.read_buffer.push(byte[0]);
                    }
                }
                Err(error) if error.kind() == ErrorKind::TimedOut => {
                    return Ok(None);
                }
                Err(error) => return Err(error).context("failed to read from serial port"),
            }
        }
    }
}

pub fn list_serial_ports() -> Result<Vec<SerialPortInfo>> {
    available_ports().context("failed to enumerate serial ports")
}
