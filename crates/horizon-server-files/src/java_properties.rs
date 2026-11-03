fn save_convert(s: &str, escape_space: bool, esc_unicode: bool) -> String {
    // Built as UTF-16 units and decoded once at the end: `encode_utf16` splits a
    // character outside the BMP into two surrogates, and nothing else in the
    // output may be mistaken for one (a value can hold any character, U+0000
    // included).
    let mut out: Vec<u16> = Vec::with_capacity(s.len() * 2);
    for (index, c) in s.encode_utf16().enumerate() {
        if c > 61 && c < 127 {
            if c == u16::from(b'\\') {
                out.push(u16::from(b'\\'));
                out.push(u16::from(b'\\'));
            } else {
                out.push(c);
            }
            continue;
        }
        match c {
            0x20 => {
                if index == 0 || escape_space {
                    out.push(u16::from(b'\\'));
                }
                out.push(u16::from(b' '));
            }
            0x09 => out.extend("\\t".encode_utf16()),
            0x0a => out.extend("\\n".encode_utf16()),
            0x0d => out.extend("\\r".encode_utf16()),
            0x0c => out.extend("\\f".encode_utf16()),
            0x3d | 0x3a | 0x23 | 0x21 => {
                out.push(u16::from(b'\\'));
                out.push(c);
            }
            _ if esc_unicode && !(0x20..=0x7e).contains(&c) => {
                out.extend(format!("\\u{c:04X}").encode_utf16());
            }
            _ => out.push(c),
        }
    }
    String::from_utf16_lossy(&out)
}
