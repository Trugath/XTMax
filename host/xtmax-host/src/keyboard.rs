use anyhow::{Result, bail};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct KeyEvent {
    pub ascii: u8,
    pub scancode: u8,
    pub flags: u8,
}

const FLAG_SHIFT: u8 = 0x01;

pub fn text_to_events(text: &str) -> Result<Vec<KeyEvent>> {
    let mut events = Vec::with_capacity(text.len());
    for ch in text.chars() {
        events.push(char_to_event(ch)?);
    }
    Ok(events)
}

pub fn char_to_event(ch: char) -> Result<KeyEvent> {
    let event = match ch {
        'a'..='z' => alpha_event(ch as u8 - b'a', false),
        'A'..='Z' => alpha_event(ch as u8 - b'A', true),
        '1'..='9' => digit_event(ch),
        '0' => KeyEvent {
            ascii: b'0',
            scancode: 0x0b,
            flags: 0,
        },
        '!' => shifted_digit_event(b'!', 0x02),
        '@' => shifted_digit_event(b'@', 0x03),
        '#' => shifted_digit_event(b'#', 0x04),
        '$' => shifted_digit_event(b'$', 0x05),
        '%' => shifted_digit_event(b'%', 0x06),
        '^' => shifted_digit_event(b'^', 0x07),
        '&' => shifted_digit_event(b'&', 0x08),
        '*' => shifted_digit_event(b'*', 0x09),
        '(' => shifted_digit_event(b'(', 0x0a),
        ')' => shifted_digit_event(b')', 0x0b),
        ' ' => KeyEvent {
            ascii: b' ',
            scancode: 0x39,
            flags: 0,
        },
        '\n' | '\r' => KeyEvent {
            ascii: 0x0d,
            scancode: 0x1c,
            flags: 0,
        },
        '\u{1b}' => KeyEvent {
            ascii: 0x1b,
            scancode: 0x01,
            flags: 0,
        },
        '\u{8}' => KeyEvent {
            ascii: 0x08,
            scancode: 0x0e,
            flags: 0,
        },
        '-' => punctuation_event(b'-', 0x0c, 0),
        '_' => punctuation_event(b'_', 0x0c, FLAG_SHIFT),
        '=' => punctuation_event(b'=', 0x0d, 0),
        '+' => punctuation_event(b'+', 0x0d, FLAG_SHIFT),
        '[' => punctuation_event(b'[', 0x1a, 0),
        '{' => punctuation_event(b'{', 0x1a, FLAG_SHIFT),
        ']' => punctuation_event(b']', 0x1b, 0),
        '}' => punctuation_event(b'}', 0x1b, FLAG_SHIFT),
        ';' => punctuation_event(b';', 0x27, 0),
        ':' => punctuation_event(b':', 0x27, FLAG_SHIFT),
        '\'' => punctuation_event(b'\'', 0x28, 0),
        '"' => punctuation_event(b'"', 0x28, FLAG_SHIFT),
        '`' => punctuation_event(b'`', 0x29, 0),
        '~' => punctuation_event(b'~', 0x29, FLAG_SHIFT),
        '\\' => punctuation_event(b'\\', 0x2b, 0),
        '|' => punctuation_event(b'|', 0x2b, FLAG_SHIFT),
        ',' => punctuation_event(b',', 0x33, 0),
        '<' => punctuation_event(b'<', 0x33, FLAG_SHIFT),
        '.' => punctuation_event(b'.', 0x34, 0),
        '>' => punctuation_event(b'>', 0x34, FLAG_SHIFT),
        '/' => punctuation_event(b'/', 0x35, 0),
        '?' => punctuation_event(b'?', 0x35, FLAG_SHIFT),
        _ => bail!("unsupported character for XT keyboard injection: {ch:?}"),
    };

    Ok(event)
}

fn alpha_event(index: u8, shifted: bool) -> KeyEvent {
    const SCANCODES: [u8; 26] = [
        0x1e, 0x30, 0x2e, 0x20, 0x12, 0x21, 0x22, 0x23, 0x17, 0x24, 0x25, 0x26, 0x32, 0x31, 0x18,
        0x19, 0x10, 0x13, 0x1f, 0x14, 0x16, 0x2f, 0x11, 0x2d, 0x15, 0x2c,
    ];

    KeyEvent {
        ascii: if shifted { b'A' + index } else { b'a' + index },
        scancode: SCANCODES[index as usize],
        flags: if shifted { FLAG_SHIFT } else { 0 },
    }
}

fn digit_event(ch: char) -> KeyEvent {
    let ascii = ch as u8;
    let scancode = 0x01 + (ascii - b'0');
    let scancode = if ascii == b'0' { 0x0b } else { scancode + 1 };
    KeyEvent {
        ascii,
        scancode,
        flags: 0,
    }
}

fn shifted_digit_event(ascii: u8, scancode: u8) -> KeyEvent {
    KeyEvent {
        ascii,
        scancode,
        flags: FLAG_SHIFT,
    }
}

fn punctuation_event(ascii: u8, scancode: u8, flags: u8) -> KeyEvent {
    KeyEvent {
        ascii,
        scancode,
        flags,
    }
}
