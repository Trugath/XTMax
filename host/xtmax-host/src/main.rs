mod keyboard;
mod mirror;
mod serial_link;

use anyhow::{Context, Result};
use clap::{Args, Parser, Subcommand};

use keyboard::{KeyEvent, char_to_event, text_to_events};
use mirror::TextMirror;
use serial_link::{XtmaxLink, list_serial_ports};

#[derive(Parser, Debug)]
#[command(name = "xtmax-host")]
#[command(about = "Host-side utility for the XTMax USB link foundation")]
struct Cli {
    #[arg(long, default_value_t = 115_200)]
    baud: u32,

    #[arg(long, global = true)]
    port: Option<String>,

    #[command(subcommand)]
    command: Command,
}

#[derive(Debug)]
struct ConnectionOptions {
    baud: u32,
    port: Option<String>,
}

#[derive(Subcommand, Debug)]
enum Command {
    Ports,
    ResetAux,
    Mirror(MirrorArgs),
    MirrorText,
    DropCount(DropCountArgs),
    SendKey(SendKeyArgs),
    Type(TypeArgs),
    Raw(RawArgs),
}

#[derive(Args, Debug)]
struct MirrorArgs {
    #[arg(value_parser = clap::value_parser!(bool))]
    enabled: bool,
}

#[derive(Args, Debug)]
struct DropCountArgs {
    count: u16,
}

#[derive(Args, Debug)]
struct SendKeyArgs {
    #[arg(long)]
    ascii: u8,
    #[arg(long)]
    scancode: u8,
    #[arg(long, default_value_t = 0)]
    flags: u8,
}

#[derive(Args, Debug)]
struct TypeArgs {
    text: String,
}

#[derive(Args, Debug)]
struct RawArgs {
    line: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let connection = ConnectionOptions {
        baud: cli.baud,
        port: cli.port.clone(),
    };

    match cli.command {
        Command::Ports => cmd_ports(),
        Command::ResetAux => with_link(&connection, |link| link.reset_aux()),
        Command::Mirror(args) => {
            with_link(&connection, |link| link.set_mirror_enabled(args.enabled))
        }
        Command::MirrorText => cmd_mirror_text(&connection),
        Command::DropCount(args) => {
            with_link(&connection, |link| link.record_mirror_drop(args.count))
        }
        Command::SendKey(args) => with_link(&connection, |link| {
            link.queue_key(KeyEvent {
                ascii: args.ascii,
                scancode: args.scancode,
                flags: args.flags,
            })
        }),
        Command::Type(args) => with_link(&connection, |link| {
            for event in text_to_events(&args.text)? {
                link.queue_key(event)?;
            }
            Ok(())
        }),
        Command::Raw(args) => with_link(&connection, |link| link.write_line(&args.line)),
    }
}

fn cmd_mirror_text(connection: &ConnectionOptions) -> Result<()> {
    let port = connection
        .port
        .as_deref()
        .context("missing --port; use `xtmax-host ports` to discover candidate devices")?;
    let mut link = XtmaxLink::open(port, connection.baud)?;
    link.reset_aux()?;
    link.set_mirror_enabled(true)?;

    let mut mirror = TextMirror::new();
    loop {
        if let Some(line) = link.read_line()? {
            if let Err(error) = mirror.apply_line(&line) {
                eprintln!("ignoring malformed mirror event {line:?}: {error}");
            }
            mirror.render_if_due(false)?;
        } else {
            mirror.render_if_due(false)?;
        }
    }
}

fn with_link<F>(connection: &ConnectionOptions, f: F) -> Result<()>
where
    F: FnOnce(&mut XtmaxLink) -> Result<()>,
{
    let port = connection
        .port
        .as_deref()
        .context("missing --port; use `xtmax-host ports` to discover candidate devices")?;
    let mut link = XtmaxLink::open(port, connection.baud)?;
    f(&mut link)
}

fn cmd_ports() -> Result<()> {
    for port in list_serial_ports()? {
        println!("{}", describe_port(&port));
    }
    Ok(())
}

fn describe_port(info: &serialport::SerialPortInfo) -> String {
    let mut description = info.port_name.clone();
    if let serialport::SerialPortType::UsbPort(usb) = &info.port_type {
        let product = usb.product.as_deref().unwrap_or("unknown");
        let manufacturer = usb.manufacturer.as_deref().unwrap_or("unknown");
        description.push_str(&format!(
            " [USB vid={:04x} pid={:04x} manufacturer={manufacturer} product={product}]",
            usb.vid, usb.pid
        ));
    }
    description
}

#[allow(dead_code)]
fn _single_char_key(ch: char) -> Result<KeyEvent> {
    char_to_event(ch)
}
