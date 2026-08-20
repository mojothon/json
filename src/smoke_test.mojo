# Lightweight publish gate: verify the packaged json.mojoc loads and works.
# Built against ${PREFIX}/lib/mojo during `rattler-build` test stage.
from json import loads, dumps

def main() raises:
    var data = loads('{"name": "Alice", "scores": [95, 87, 92]}')
    if data["name"].string_value() != "Alice":
        raise Error("smoke: name mismatch")
    if data["scores"][0].int_value() != 95:
        raise Error("smoke: score mismatch")
    var out = dumps(data)
    if out.byte_length() == 0:
        raise Error("smoke: empty dumps output")
    print("json smoke OK")
