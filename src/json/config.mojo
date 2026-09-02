# json - Parser and Serializer configuration

from std.collections import List


struct ParserConfig:
    """Configuration options for JSON parsing.

    Example:
        var config = ParserConfig(max_depth=10, allow_comments=True)
        var data = loads(json_str, config).
    """

    var max_depth: Int
    """Maximum nesting depth allowed. 0 = unlimited (default)."""

    var allow_comments: Bool
    """Allow JavaScript-style comments (// and /* */). Default: False."""

    var allow_trailing_comma: Bool
    """Allow trailing commas in arrays and objects. Default: False."""

    def __init__(
        out self,
        max_depth: Int = 0,
        allow_comments: Bool = False,
        allow_trailing_comma: Bool = False,
    ):
        """Create parser configuration.

        Args:
            max_depth: Maximum nesting depth (0 = unlimited).
            allow_comments: Allow // and /* */ comments.
            allow_trailing_comma: Allow trailing commas.
        """
        self.max_depth = max_depth
        self.allow_comments = allow_comments
        self.allow_trailing_comma = allow_trailing_comma

    @staticmethod
    def default() -> Self:
        """Create default (strict) parser configuration."""
        return Self()

    @staticmethod
    def lenient() -> Self:
        """Create lenient parser configuration allowing common extensions."""
        return Self(
            max_depth=0,
            allow_comments=True,
            allow_trailing_comma=True,
        )


struct SerializerConfig:
    """Configuration options for JSON serialization.

    Example:
        var config = SerializerConfig(sort_keys=True, indent="  ")
        var json = dumps(value, config).
    """

    var indent: String
    """Indentation string. Empty = compact output (default)."""

    var sort_keys: Bool
    """Sort object keys alphabetically. Default: False."""

    var escape_unicode: Bool
    """Escape non-ASCII characters as \\uXXXX. Default: False."""

    var escape_forward_slash: Bool
    """Escape forward slashes as \\/. Default: False (for HTML safety)."""

    def __init__(
        out self,
        indent: String = "",
        sort_keys: Bool = False,
        escape_unicode: Bool = False,
        escape_forward_slash: Bool = False,
    ):
        """Create serializer configuration.

        Args:
            indent: Indentation string (empty = compact).
            sort_keys: Sort object keys alphabetically.
            escape_unicode: Escape non-ASCII as \\uXXXX.
            escape_forward_slash: Escape / as \\/ (for HTML embedding).
        """
        self.indent = indent
        self.sort_keys = sort_keys
        self.escape_unicode = escape_unicode
        self.escape_forward_slash = escape_forward_slash

    @staticmethod
    def default() -> Self:
        """Create default serializer configuration (compact output)."""
        return Self()

    @staticmethod
    def pretty(indent: String = "  ") -> Self:
        """Create pretty-print configuration with given indent."""
        return Self(indent=indent)


# Preprocessing functions for parser config


def preprocess_json(json: String, config: ParserConfig) raises -> String:
    """Preprocess JSON according to config options.

    This handles:
    - Stripping comments if allow_comments is True.
    - Removing trailing commas if allow_trailing_comma is True.
    - Checking max_depth if specified.

    Args:
        json: Input JSON string.
        config: Parser configuration.

    Returns:
        Preprocessed JSON string.
    """
    var result = json

    if config.allow_comments:
        result = _strip_comments(result)

    if config.allow_trailing_comma:
        result = _remove_trailing_commas(result)

    if config.max_depth > 0:
        _check_depth(result, config.max_depth)

    return result^


def _strip_comments(json: String) -> String:
    """Remove JavaScript-style comments from JSON.

    Handles:
    - // single-line comments.
    - /* multi-line comments */.
    """
    var result = String()
    var json_bytes = json.as_bytes()
    var n = len(json_bytes)
    var i = 0
    var in_string = False
    var escaped = False
    var run_start = 0

    while i < n:
        var c = json_bytes[i]

        # Bytes inside strings (incl. quotes and escape pairs) are part
        # of the verbatim run.
        if escaped:
            escaped = False
            i += 1
            continue

        if c == UInt8(ord("\\")) and in_string:
            escaped = True
            i += 1
            continue

        if c == UInt8(ord('"')):
            in_string = not in_string
            i += 1
            continue

        # Skip comments outside strings
        if not in_string and c == UInt8(ord("/")) and i + 1 < n:
            var next_c = json_bytes[i + 1]

            # Single-line comment
            if next_c == UInt8(ord("/")):
                result += json[byte=run_start:i]
                i += 2
                while i < n and json_bytes[i] != UInt8(ord("\n")):
                    i += 1
                run_start = i
                continue

            # Multi-line comment
            if next_c == UInt8(ord("*")):
                result += json[byte=run_start:i]
                i += 2
                while i + 1 < n:
                    if json_bytes[i] == UInt8(ord("*")) and json_bytes[
                        i + 1
                    ] == UInt8(ord("/")):
                        i += 2
                        break
                    i += 1
                run_start = i
                continue

        # Everything else stays in the verbatim run.
        i += 1

    if run_start < n:
        result += json[byte=run_start:n]

    return result^


def _remove_trailing_commas(json: String) -> String:
    """Remove trailing commas from arrays and objects."""
    var result = String()
    var json_bytes = json.as_bytes()
    var n = len(json_bytes)
    var i = 0
    var in_string = False
    var escaped = False
    var last_comma_pos = -1
    var run_start = 0

    while i < n:
        var c = json_bytes[i]

        # Bytes inside strings (incl. quotes and escape pairs) are part
        # of the verbatim run.
        if escaped:
            escaped = False
            i += 1
            continue

        if c == UInt8(ord("\\")) and in_string:
            escaped = True
            i += 1
            continue

        if c == UInt8(ord('"')):
            in_string = not in_string
            last_comma_pos = -1
            i += 1
            continue

        if in_string:
            i += 1
            continue

        # Track comma position (comma is emitted on its own).
        if c == UInt8(ord(",")):
            result += json[byte=run_start:i]
            last_comma_pos = result.byte_length()
            result += ","
            run_start = i + 1
            i += 1
            continue

        # Skip whitespace when checking for trailing comma (stays in run)
        if (
            c == UInt8(ord(" "))
            or c == UInt8(ord("\t"))
            or c == UInt8(ord("\n"))
            or c == UInt8(ord("\r"))
        ):
            i += 1
            continue

        # Check if this closes an array/object after a comma
        if (
            c == UInt8(ord("]")) or c == UInt8(ord("}"))
        ) and last_comma_pos >= 0:
            result += json[byte=run_start:i]
            # Remove the trailing comma
            var before_comma = String(
                unsafe_from_utf8=result.as_bytes()[:last_comma_pos]
            )
            var after_comma = String(
                unsafe_from_utf8=result.as_bytes()[last_comma_pos + 1 :]
            )
            result = before_comma + after_comma
            result += chr(Int(c))
            run_start = i + 1
            last_comma_pos = -1
            i += 1
            continue

        # Regular character (numbers, literals) — stays in the verbatim run.
        last_comma_pos = -1
        i += 1

    if run_start < n:
        result += json[byte=run_start:n]

    return result^


def _check_depth(json: String, max_depth: Int) raises:
    """Check that JSON doesn't exceed max nesting depth."""
    var json_bytes = json.as_bytes()
    var n = len(json_bytes)
    var depth = 0
    var in_string = False
    var escaped = False

    for i in range(n):
        var c = json_bytes[i]

        if escaped:
            escaped = False
            continue

        if c == UInt8(ord("\\")) and in_string:
            escaped = True
            continue

        if c == UInt8(ord('"')):
            in_string = not in_string
            continue

        if in_string:
            continue

        if c == UInt8(ord("{")) or c == UInt8(ord("[")):
            depth += 1
            if depth > max_depth:
                raise Error(
                    "JSON exceeds maximum depth of " + String(max_depth)
                )
        elif c == UInt8(ord("}")) or c == UInt8(ord("]")):
            depth -= 1
