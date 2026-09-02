# json package regression tests — UTF-8 byte-exact serialization.
#
# Regression focus: the double-encoding bug where multibyte UTF-8 was
# re-encoded per byte (em dash E2 80 94 -> C3 A2 C3 80 C3 94). Every
# escape/format path must copy non-ASCII bytes through as verbatim runs.

from std.collections import List

from json import loads, dumps, Value, SerializerConfig


def _check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error("ASSERT FAILED: " + msg)


def _eq(actual: String, expected: String, label: String) raises:
    if actual != expected:
        raise Error(
            "MISMATCH [" + label + "]\n  actual:   " + actual + "\n  expected: " + expected
        )


def main() raises:
    # 1. Chinese round trip through loads -> dumps.
    var doc = loads('{"msg": "中文测试"}')
    _eq(dumps(doc), '{"msg":"中文测试"}', "chinese round trip")

    # 2. Em dash (the original double-encoding trigger).
    var em = loads('{"t": "a\u2014b"}')
    _eq(dumps(em), '{"t":"a\u2014b"}', "em dash round trip")

    # 3. Emoji (4-byte UTF-8, surrogate pair territory when escaped).
    var emoji = loads('{"e": "\U0001F600"}')
    _eq(dumps(emoji), '{"e":"\U0001F600"}', "emoji round trip")

    # 4. Mixed CJK + latin + digits + punctuation.
    var mixed = loads('{"s": "Hello 世界, mix 123 — ok"}')
    _eq(dumps(mixed), '{"s":"Hello 世界, mix 123 — ok"}', "mixed utf8 round trip")

    # 5. Direct Value string construction (exercises _escape_string hot path).
    _eq(dumps(Value("中文")), '"中文"', "value chinese")
    _eq(dumps(Value("\U0001F600")), '"\U0001F600"', "value emoji")

    # 6. ASCII escaping still intact.
    _eq(dumps(Value('a"b\\c\nd\te')), '"a\\"b\\\\c\\nd\\te"', "ascii escapes")
    _eq(dumps(Value("\u0001")), '"\\u0001"', "control char escape")

    # 7. Pretty print keeps UTF-8 byte-exact.
    var pretty = dumps(loads('{"msg": "中文"}'), indent="  ")
    _eq(pretty, '{\n  "msg": "中文"\n}', "pretty chinese")

    # 8. Pretty print nested with emoji.
    var nested = dumps(loads('{"a": {"b": ["x", "\U0001F600"]}}'), indent="  ")
    _eq(
        nested,
        '{\n  "a": {\n    "b": [\n      "x",\n      "\U0001F600"\n    ]\n  }\n}',
        "pretty nested emoji",
    )

    # 9. escape_unicode config: CJK -> \uXXXX, emoji -> surrogate pair.
    var cfg = SerializerConfig(escape_unicode=True)
    var esc_cjk = dumps(loads('{"msg": "中"}'), cfg)
    _eq(esc_cjk, '{"msg":"\\u4e2d"}', "escape_unicode cjk")
    var esc_emoji = dumps(loads('{"e": "\U0001F600"}'), cfg)
    _eq(esc_emoji, '{"e":"\\ud83d\\ude00"}', "escape_unicode surrogate pair")

    # 10. escape_forward_slash config.
    var slash_cfg = SerializerConfig(escape_forward_slash=True)
    _eq(dumps(loads('{"u": "a/b"}'), slash_cfg), '{"u":"a\\/b"}', "escape forward slash")

    # 10b. indent + escape_unicode combined (pretty output escaped).
    var both_cfg = SerializerConfig(indent="  ", escape_unicode=True)
    var both = dumps(loads('{"msg": "中😀"}'), both_cfg)
    _eq(both, '{\n  "msg": "\\u4e2d\\ud83d\\ude00"\n}', "indent + escape_unicode")

    # 11. Round trip stability across object/array nesting.
    var big = loads('{"user": {"name": "张三", "tags": ["重要", "emoji \U0001F680"], "note": "v1.2 — final"}}')
    var big_out = dumps(big)
    _eq(loads(big_out).raw_json(), big.raw_json(), "nested utf8 stability")

    # 12. NDJSON serialization keeps UTF-8.
    var nd = List[Value]()
    nd.append(loads('{"a": "中文"}'))
    nd.append(loads('{"a": "\U0001F600"}'))
    var nd_out = dumps[format="ndjson"](nd)
    _eq(nd_out, '{"a":"中文"}\n{"a":"\U0001F600"}', "ndjson utf8")

    # 13. float_value() must accept INT tape entries: previously the INT
    # payload (a 60-bit integer) was read as a float_pool index, which
    # goes out of bounds and aborts. INT -> Float64 conversion, FLOAT as
    # before, and other types raise Error.
    var fi = loads('{"x": 10}')
    _check(fi["x"].float_value() == 10.0, "float_value on INT entry")
    var fneg = loads('{"x": -7}')
    _check(fneg["x"].float_value() == -7.0, "float_value on negative INT")
    var ff = loads('{"x": 10.5}')
    _check(ff["x"].float_value() == 10.5, "float_value on FLOAT entry")
    var raised = False
    try:
        var _ = loads('{"x": "s"}')["x"].float_value()
    except:
        raised = True
    _check(raised, "float_value on string raises")

    print("json tests: ALL PASSED")
