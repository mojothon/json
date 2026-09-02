# json - JSON serialization

from std.collections import List

from .value import Value


def _escape_string(s: String) -> String:
    """Escape special characters in a string for JSON.

    Non-ASCII bytes are copied through verbatim as raw UTF-8 byte runs
    (never re-encoded per byte), so multibyte characters survive
    round-trips byte-exactly.
    """
    var result = String('"')
    var s_bytes = s.as_bytes()
    var n = len(s_bytes)
    var run_start = 0
    for i in range(n):
        var c = s_bytes[i]
        if c == UInt8(ord('"')):
            result += s[byte=run_start:i]
            result += '\\"'
            run_start = i + 1
        elif c == UInt8(ord("\\")):
            result += s[byte=run_start:i]
            result += "\\\\"
            run_start = i + 1
        elif c == UInt8(ord("\n")):
            result += s[byte=run_start:i]
            result += "\\n"
            run_start = i + 1
        elif c == UInt8(ord("\r")):
            result += s[byte=run_start:i]
            result += "\\r"
            run_start = i + 1
        elif c == UInt8(ord("\t")):
            result += s[byte=run_start:i]
            result += "\\t"
            run_start = i + 1
        elif c < 0x20:
            # Control characters - escape as \u00XX
            result += s[byte=run_start:i]
            result += "\\u00"
            var hi = (c >> 4) & 0x0F
            var lo = c & 0x0F
            result += chr(Int(hi) + ord("0")) if hi < 10 else chr(
                Int(hi) - 10 + ord("a")
            )
            result += chr(Int(lo) + ord("0")) if lo < 10 else chr(
                Int(lo) - 10 + ord("a")
            )
            run_start = i + 1
    if run_start < n:
        result += s[byte=run_start:n]
    result += '"'
    return result^


def to_string(v: Value) -> String:
    """Convert a Value to a JSON string (compact)."""
    if v.is_null():
        return "null"
    elif v.is_bool():
        return "true" if v.bool_value() else "false"
    elif v.is_int():
        return String(v.int_value())
    elif v.is_float():
        try:
            return String(v.float_value())
        except:
            return "0"
    elif v.is_string():
        return _escape_string(v.string_value())
    elif v.is_array() or v.is_object():
        return v.raw_json()
    return "null"


def _is_ws_byte(c: UInt8) -> Bool:
    """True if *c* is a JSON whitespace byte."""
    return (
        c == UInt8(ord(" "))
        or c == UInt8(ord("\t"))
        or c == UInt8(ord("\n"))
        or c == UInt8(ord("\r"))
    )


def _find_matching_close(
    b: Span[UInt8, ...], start: Int, close_char: UInt8, n: Int
) -> Int:
    """Return the index of the bracket matching the opener at *start*.

    Strings and escape pairs are skipped so a ``}``/``]`` inside a string
    value does not confuse the scan.
    """
    var depth = 0
    var in_string = False
    var escaped = False
    var i = start
    while i < n:
        var c = b[i]
        if escaped:
            escaped = False
            i += 1
            continue
        if in_string:
            if c == UInt8(ord("\\")):
                escaped = True
            elif c == UInt8(ord('"')):
                in_string = False
            i += 1
            continue
        if c == UInt8(ord('"')):
            in_string = True
            i += 1
            continue
        if c == UInt8(ord("{")) or c == UInt8(ord("[")):
            depth += 1
        elif c == close_char:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n - 1


def _format_json(raw: String, indent: String, current_indent: String) -> String:
    """Format raw JSON with indentation (recursive, byte-exact UTF-8).

    Args:
        raw: Raw JSON string to format (a single top-level object/array).
        indent: Indentation string per level (e.g., "  " or "    ").
        current_indent: Current indentation level.

    Returns:
        Formatted JSON string with newlines and indentation.

    Containers are consumed whole by finding their matching close bracket
    and recursing with a deeper indent, so nesting keeps correct depth.
    Non-ASCII UTF-8 inside strings is copied through as raw byte runs —
    never re-encoded per byte — so multibyte characters survive
    formatting byte-exactly.
    """
    var result = String()
    var raw_bytes = raw.as_bytes()
    var n = len(raw_bytes)
    var i = 0
    var in_string = False
    var escaped = False
    var next_indent = current_indent + indent
    var run_start = 0

    while i < n:
        var c = raw_bytes[i]

        # Bytes inside a string (including quotes and escape pairs) are
        # part of the verbatim run.
        if escaped:
            escaped = False
            i += 1
            continue

        if in_string:
            if c == UInt8(ord("\\")):
                escaped = True
            elif c == UInt8(ord('"')):
                in_string = False
            i += 1
            continue

        if c == UInt8(ord('"')):
            in_string = True
            i += 1
            continue

        # Container open — find its matching close and recurse with a
        # deeper indent so nested structures keep their depth.
        if c == UInt8(ord("{")) or c == UInt8(ord("[")):
            var close_char = UInt8(ord("}")) if c == UInt8(ord("{")) else UInt8(
                ord("]")
            )
            var end = _find_matching_close(raw_bytes, i, close_char, n)
            # Check if empty (whitespace-only interior).
            var j = i + 1
            while j < end and _is_ws_byte(raw_bytes[j]):
                j += 1
            if j == end:
                # Empty object/array - keep compact.
                result += raw[byte=run_start:i]
                result += chr(Int(c))
                result += chr(Int(close_char))
            else:
                result += raw[byte=run_start:i]
                result += chr(Int(c))
                result += "\n" + next_indent
                result += _format_json(String(raw[byte=i + 1:end]), indent, next_indent)
                result += "\n" + current_indent
                result += chr(Int(close_char))
            i = end + 1
            run_start = i
            continue

        if c == UInt8(ord("}")) or c == UInt8(ord("]")):
            # Stray close (unreachable for well-formed input) — verbatim.
            result += raw[byte=run_start:i]
            result += chr(Int(c))
            run_start = i + 1
            i += 1
            continue

        if c == UInt8(ord(",")):
            result += raw[byte=run_start:i]
            result += ",\n" + current_indent
            run_start = i + 1
            i += 1
            continue

        if c == UInt8(ord(":")):
            result += raw[byte=run_start:i]
            result += ": "
            run_start = i + 1
            i += 1
            continue

        # Skip whitespace (we re-emit structure) — drop it from the run.
        if _is_ws_byte(c):
            result += raw[byte=run_start:i]
            run_start = i + 1
            i += 1
            continue

        # Regular character (numbers, literals) — stays in the verbatim run.
        i += 1

    # Flush any remaining verbatim run.
    if run_start < n:
        result += raw[byte=run_start:n]

    return result^


def _to_string_pretty(
    v: Value, indent: String, current_indent: String
) -> String:
    """Convert a Value to a pretty-printed JSON string."""
    if v.is_null():
        return "null"
    elif v.is_bool():
        return "true" if v.bool_value() else "false"
    elif v.is_int():
        return String(v.int_value())
    elif v.is_float():
        try:
            return String(v.float_value())
        except:
            return "0"
    elif v.is_string():
        return _escape_string(v.string_value())
    elif v.is_array() or v.is_object():
        return _format_json(v.raw_json(), indent, current_indent)
    return "null"


def dumps(v: Value, indent: String = "") -> String:
    """Serialize a Value to JSON string (like Python's json.dumps).

    Args:
        v: Value to serialize.
        indent: Indentation string (empty for compact, e.g., "  " for 2 spaces).

    Returns:
        JSON string representation.

    Example:
        var data = loads('{"name": "Alice", "age": 30}')
        print(dumps(data))  # {"name":"Alice","age":30}.
        print(dumps(data, indent="  "))  # Pretty-printed.
    """
    if indent == "":
        return to_string(v)
    return _to_string_pretty(v, indent, "")


def dumps(v: Value, config: SerializerConfig) -> String:
    """Serialize a Value with custom configuration.

    Args:
        v: Value to serialize.
        config: Serializer configuration.

    Returns:
        JSON string representation.

    Example:
        var json = dumps(value, SerializerConfig(indent="  ", escape_unicode=True)).
    """
    var result: String

    if config.indent == "":
        result = to_string(v)
    else:
        result = _to_string_pretty(v, config.indent, "")

    if config.escape_unicode:
        result = _escape_unicode_chars(result)

    if config.escape_forward_slash:
        result = _escape_forward_slashes(result)

    if config.sort_keys and (v.is_object() or v.is_array()):
        result = _sort_object_keys(result)

    return result^


def dumps[format: StaticString = "json"](values: List[Value]) -> String:
    """Serialize a list of Values to NDJSON string.

    Parameters:
        format: Must be "ndjson" for this overload.

    Args:
        values: List of Values to serialize.

    Returns:
        NDJSON string (one JSON value per line).

    Example:
        var values = List[Value]()
        values.append(loads('{"a":1}'))
        values.append(loads('{"a":2}'))
        print(dumps[format="ndjson"](values)).
    """

    comptime if format != "ndjson":
        comptime assert False, "Use format='ndjson' for List[Value] input"

    var result = String()
    for i in range(len(values)):
        if i > 0:
            result += "\n"
        result += dumps(values[i])
    return result^


def dump(v: Value, mut f: FileHandle) raises:
    """Serialize a Value and write to file (like Python's json.dump).

    Args:
        v: Value to serialize.
        f: FileHandle to write JSON to.

    Example:
        with open("output.json", "w") as f:
            dump(data, f).
    """
    f.write(dumps(v))


def dump(v: Value, mut f: FileHandle, indent: String) raises:
    """Serialize a Value with indentation and write to file.

    Args:
        v: Value to serialize.
        f: FileHandle to write JSON to.
        indent: Indentation string.

    Example:
        with open("output.json", "w") as f:
            dump(data, f, indent="  ").
    """
    f.write(dumps(v, indent))


def dump[
    format: StaticString = "json"
](values: List[Value], mut f: FileHandle) raises:
    """Serialize a list of Values to NDJSON and write to file.

    Parameters:
        format: Must be "ndjson" for this overload.

    Args:
        values: List of Values to serialize.
        f: FileHandle to write NDJSON to.

    Example:
        with open("output.ndjson", "w") as f:
            dump[format="ndjson"](values, f).
    """

    comptime if format != "ndjson":
        comptime assert False, "Use format='ndjson' for List[Value] input"

    f.write(dumps[format="ndjson"](values))


def _utf8_decode_at(b: Span[UInt8, ...], i: Int) -> Int:
    """Decode the UTF-8 sequence starting at byte *i*; return the codepoint.

    Invalid sequences fall back to the raw byte value (best effort).
    """
    var n = len(b)
    var c0 = Int(b[i])
    if c0 < 0x80:
        return c0
    if c0 >= 0xC2 and c0 <= 0xDF and i + 1 < n:
        return ((c0 & 0x1F) << 6) | (Int(b[i + 1]) & 0x3F)
    if c0 >= 0xE0 and c0 <= 0xEF and i + 2 < n:
        return (
            ((c0 & 0x0F) << 12)
            | ((Int(b[i + 1]) & 0x3F) << 6)
            | (Int(b[i + 2]) & 0x3F)
        )
    if c0 >= 0xF0 and c0 <= 0xF4 and i + 3 < n:
        return (
            ((c0 & 0x07) << 18)
            | ((Int(b[i + 1]) & 0x3F) << 12)
            | ((Int(b[i + 2]) & 0x3F) << 6)
            | (Int(b[i + 3]) & 0x3F)
        )
    return c0


def _utf8_len_at(b: Span[UInt8, ...], i: Int) -> Int:
    """Return the byte length of the UTF-8 sequence starting at *i*."""
    var c0 = Int(b[i])
    if c0 < 0x80:
        return 1
    if c0 >= 0xC2 and c0 <= 0xDF:
        return 2
    if c0 >= 0xE0 and c0 <= 0xEF:
        return 3
    if c0 >= 0xF0 and c0 <= 0xF4:
        return 4
    return 1


def _hex4_escape(cp: Int) -> String:
    """Build a ``\\uXXXX`` escape for a codepoint <= 0xFFFF."""
    var result = String("\\u")
    for shift in range(12, -1, -4):
        var v = (cp >> shift) & 0xF
        if v < 10:
            result += chr(Int(v) + ord("0"))
        else:
            result += chr(Int(v) - 10 + ord("a"))
    return result^


def _escape_unicode_chars(s: String) -> String:
    """Escape non-ASCII characters as \\uXXXX (UTF-8 aware).

    Multibyte UTF-8 sequences are decoded to their Unicode codepoint and
    emitted as a single \\uXXXX escape; supplementary-plane characters
    (above U+FFFF) are emitted as surrogate pairs.
    """
    var result = String()
    var s_bytes = s.as_bytes()
    var n = len(s_bytes)
    var i = 0
    var in_string = False
    var escaped = False

    while i < n:
        var c = s_bytes[i]

        if escaped:
            escaped = False
            result += chr(Int(c))
            i += 1
            continue

        if c == UInt8(ord("\\")):
            escaped = True
            result += chr(Int(c))
            i += 1
            continue

        if c == UInt8(ord('"')):
            in_string = not in_string
            result += chr(Int(c))
            i += 1
            continue

        # Escape non-ASCII inside strings
        if in_string and c > 127:
            var cp = _utf8_decode_at(s_bytes, i)
            var seq_len = _utf8_len_at(s_bytes, i)
            if cp <= 0xFFFF:
                result += _hex4_escape(cp)
            else:
                # Surrogate pair for supplementary-plane characters.
                var v = cp - 0x10000
                result += _hex4_escape(0xD800 + (v >> 10))
                result += _hex4_escape(0xDC00 + (v & 0x3FF))
            i += seq_len
            continue

        result += chr(Int(c))
        i += 1

    return result^


def _escape_forward_slashes(s: String) -> String:
    """Escape forward slashes as \\/ for HTML embedding safety.

    Non-ASCII bytes are copied through as raw byte runs (never
    re-encoded per byte).
    """
    var result = String()
    var s_bytes = s.as_bytes()
    var n = len(s_bytes)
    var i = 0
    var in_string = False
    var escaped = False
    var run_start = 0

    while i < n:
        var c = s_bytes[i]

        if escaped:
            escaped = False
            i += 1
            continue

        if c == UInt8(ord("\\")):
            escaped = True
            i += 1
            continue

        if c == UInt8(ord('"')):
            in_string = not in_string
            i += 1
            continue

        # Escape / inside strings
        if in_string and c == UInt8(ord("/")):
            result += s[byte=run_start:i]
            result += "\\/"
            run_start = i + 1
            i += 1
            continue

        # Everything else stays in the verbatim run.
        i += 1

    if run_start < n:
        result += s[byte=run_start:n]

    return result^


def _sort_object_keys(json: String) -> String:
    """Sort object keys alphabetically (simple implementation).

    Note: This is a basic implementation that works for simple objects.
    For complex nested structures, a full re-parse may be needed.
    """
    # For now, return as-is - full implementation would require
    # re-parsing and re-serializing with sorted keys
    # This is a TODO for a more complete implementation
    return json


from .config import SerializerConfig


# Helper functions for building JSON strings from basic types
def to_json_string(s: String) -> String:
    """Convert a String to JSON string format (with quotes and escaping)."""
    return _escape_string(s)


def to_json_value(val: String) -> String:
    """Convert String to JSON."""
    return to_json_string(val)


def to_json_value(val: Int) -> String:
    """Convert Int to JSON."""
    return String(val)


def to_json_value(val: Int64) -> String:
    """Convert Int64 to JSON."""
    return String(val)


def to_json_value(val: Float64) -> String:
    """Convert Float64 to JSON."""
    return String(val)


def to_json_value(val: Bool) -> String:
    """Convert Bool to JSON."""
    return "true" if val else "false"


trait Serializable:
    """Trait for types that can be serialized to JSON.

    Implement this trait to enable automatic serialization with serialize().

    Example:
        struct Person(Serializable):
            var name: String
            var age: Int

            def to_json(self) -> String:
                return '{"name":' + to_json_value(self.name) +
                       ',"age":' + to_json_value(self.age) + '}'

        var json = serialize(Person("Alice", 30))  # {"name":"Alice","age":30}
    """

    def to_json(self) -> String:
        """Serialize this object to a JSON string."""
        ...


def serialize[T: Serializable](obj: T) -> String:
    """Serialize an object to JSON string.

    The object must implement the Serializable trait with a to_json() method.

    Parameters:
        T: Type that implements Serializable.

    Args:
        obj: Object to serialize.

    Returns:
        JSON string representation.

    Example:
        var person = Person("Alice", 30)
        var json = serialize(person)  # `{"name":"Alice","age":30}`.
    """
    return obj.to_json()
