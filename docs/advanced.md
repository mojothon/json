# 进阶指南

本文档覆盖 `json` 的进阶能力:JSONPath 查询、JSON Patch / Merge Patch、JSON Schema 校验、反射零样板序列化、手动 serde trait、NDJSON、惰性与流式解析,以及 GPU 后端。

## JSONPath (RFC 9535)

JSONPath 是从 JSON 文档中提取数据的查询语言,类似 XML 的 XPath。

```mojo
from json import loads
from json.jsonpath import jsonpath_query, jsonpath_one

var doc = loads('''
{
  "store": {
    "book": [
      {"title": "A", "price": 8, "tags": ["tech"]},
      {"title": "B", "price": 12},
      {"title": "C", "price": 5}
    ]
  }
}
''')

# 查询全部
var titles = jsonpath_query(doc, "$.store.book[*].title")   # 3 个书名
var prices = jsonpath_query(doc, "$..price")                # 递归下降

# 取单个(第一个匹配,无匹配则报错)
var first = jsonpath_one(doc, "$.store.book[0].title")

# 过滤
var cheap = jsonpath_query(doc, "$.store.book[?@.price<10]")   # A 和 C
```

支持语法:

| 语法 | 含义 |
| --- | --- |
| `$` | 根元素 |
| `.key` / `['key']` | 子元素 |
| `[n]` | 数组下标(0 基) |
| `[*]` | 全部元素 |
| `..` | 递归下降 |
| `[start:end]` | 数组切片 |
| `[?expr]` | 过滤表达式 |

## JSON Patch (RFC 6902) 与 Merge Patch (RFC 7396)

### JSON Patch

`apply_patch` 把一组操作按序应用到文档上,返回新文档。每个操作是 `{op, path, value?/from?}` 形式的对象。

```mojo
from json import loads
from json.patch import apply_patch

var doc = loads('{"name": "Alice", "age": 25}')

var patch = loads('''
[
  {"op": "replace", "path": "/age", "value": 26},
  {"op": "add",     "path": "/city", "value": "Shanghai"},
  {"op": "remove",  "path": "/age"}
]
''')

var result = apply_patch(doc, patch)
# {"name":"Alice","city":"Shanghai"}
```

支持操作:`add` / `remove` / `replace` / `move`(带 `from`)/ `copy`(带 `from`)/ `test`(带 `value`,校验失败报错)。

### JSON Merge Patch

`merge_patch` 以整个 JSON 对象作为补丁,递归合并到目标;`null` 值表示删除键。

```mojo
from json.patch import merge_patch, create_merge_patch

var base = loads('{"a": 1, "b": {"x": 1, "y": 2}, "c": 3}')
var patch = loads('{"b": {"y": 9}, "c": null}')

var merged = merge_patch(base, patch)
# {"a":1,"b":{"x":1,"y":9}}

# 反向生成补丁
var diff = create_merge_patch(base, merged)
```

## JSON Schema 校验

`json` 实现了 JSON Schema draft-07 的一个实用子集。

```mojo
from json import loads
from json.schema import validate, is_valid

var schema = loads('''
{
  "type": "object",
  "required": ["name", "age"],
  "properties": {
    "name": {"type": "string", "minLength": 1, "maxLength": 64},
    "age":  {"type": "integer", "minimum": 0, "maximum": 150},
    "tags": {"type": "array", "items": {"type": "string"}}
  },
  "additionalProperties": false
}
''')

var doc = loads('{"name": "Alice", "age": 30, "tags": ["a", "b"]}')

var result = validate(doc, schema)
if result.valid:
    print("valid")
else:
    for err in result.errors:
        print(err.path, ":", err.message)

if is_valid(doc, schema):   # 布尔快捷方式
    print("valid")
```

支持关键字:`type` / `enum` / `const` / `minimum` / `maximum` / `minLength` / `maxLength` / `pattern` / `minItems` / `maxItems` / `items` / `minProperties` / `maxProperties` / `properties` / `required` / `additionalProperties` / `anyOf` / `oneOf` / `allOf` / `not`。

## 反射序列化(零样板)

反射 serde 在编译期遍历结构体字段,自动映射为 JSON 对象。序列化任意 struct 无需实现 trait;反序列化要求 `Defaultable` + `Movable`。

```mojo
from json import loads
from json.reflection import serialize_json, deserialize_json, try_deserialize_json

# 序列化:任何 struct 都可以
@fieldwise_init
struct Point:
    var x: Int
    var y: Int

@fieldwise_init
struct Shape:
    var name: String
    var points: List[Point]
    var tags: Optional[List[String]]

def main() raises:
    var s = Shape(name="poly", points=List[Point](Point(0, 0), Point(1, 1)), tags=None)
    print(serialize_json(s))                 # 紧凑
    print(serialize_json(s, pretty=True))    # 缩进

    # 反序列化
    @fieldwise_init
    struct Shape2(Defaultable, Movable):
        var name: String
        var points: List[Point2]
        var tags: Optional[List[String]]

        def __init__(out self):
            self.name = ""
            self.points = List[Point2]()
            self.tags = None

    var p = deserialize_json[Shape2]('{"name":"poly","points":[{"x":0,"y":0}]}')
    var maybe = try_deserialize_json[Shape2]('{"name":"x"}')   # Optional[Shape2]
```

支持字段类型:标量(`Int` / `Int64` / `Bool` / `Float64` / `Float32` / `String`)、容器(`List[...]` / `Optional[...]` / `Dict[String, ...]`)、嵌套结构体(递归反射)、`Value`(原样透传)。

### 覆写单个类型

对序列化/反序列化不满足需求的类型,实现 `JsonSerializable` / `JsonDeserializable` trait,其余字段仍走反射:

```mojo
from json import loads
from json.reflection import JsonSerializable, serialize_json

@fieldwise_init
struct Color(JsonSerializable, Defaultable, Movable):
    var r: Int
    var g: Int
    var b: Int

    def __init__(out self):
        self.r = 0
        self.g = 0
        self.b = 0

    def to_json_value(self) raises -> Value:
        return loads(
            '"rgb(' + String(self.r) + "," + String(self.g) + "," + String(self.b) + ')"'
        )

def main() raises:
    var c = Color(255, 128, 0)
    print(serialize_json(c))   # "rgb(255,128,0)"
```

## 手动 serde trait

反射不适用时(如需要自定义校验、兼容旧类型),实现 `Serializable` / `Deserializable` trait:

```mojo
from json import loads, Value
from json.serialize import Serializable, to_json_value
from json.deserialize import Deserializable, deserialize, get_string, get_int

struct Person(Deserializable):
    var name: String
    var age: Int

    @staticmethod
    def from_json(json: Value) raises -> Self:
        return Self(name=get_string(json, "name"), age=get_int(json, "age"))

struct Timestamp(Serializable):
    var epoch: Int

    def to_json_value(self) raises -> Value:
        return Value(self.epoch)

def main() raises:
    var p = deserialize[Person]('{"name":"Alice","age":30}')
    print(p.name, p.age)
```

`get_string` / `get_int` / `get_bool` / `get_float` 从对象 `Value` 提取字段并做类型检查,配合 `from_json` 手工映射。

## NDJSON

NDJSON(Newline-Delimited JSON)每行一个独立 JSON 值,适合日志、批量数据流。

```mojo
from json import load
from json.ndjson import parse_ndjson, parse_ndjson_lazy, dumps_ndjson

var text = '{"id": 1, "name": "Alice"}\n{"id": 2, "name": "Bob"}\n'

# 一次解析成列表
var values = parse_ndjson(text)          # List[Value],2 个元素

# 惰性逐行迭代,内存占用更低
var iter = parse_ndjson_lazy(text)
while iter.has_next():
    var value = iter.next()
    print(value["id"].int_value())

# 序列化回 NDJSON
var out = dumps_ndjson(values)

# 直接加载 NDJSON 文件
var from_file = load[format="ndjson"]("data.ndjson")   # List[Value]
```

## 惰性解析(LazyValue)

`loads_lazy` 返回 `LazyValue`:它保存原始 JSON,只在访问特定字段/元素时才解析对应路径。大文档只取少量字段时效率显著。

```mojo
from json.lazy import loads_lazy

var lazy = loads_lazy(huge_json_string)
var name = lazy.get("/users/0/name")    # 只解析该路径,不解析整个文档
```

## 流式解析(StreamingParser)

`StreamingParser` 分块读取文件(chunk 默认 64 KB),逐条 yield 完整的 JSON 值,适合比内存还大的文件。最适合每行独立的 NDJSON。

```mojo
from json.streaming import StreamingParser

var parser = StreamingParser("large.ndjson")          # chunk_size 默认 65536
while parser.has_next():
    var value = parser.next()
    process(value)
parser.close()
```

`ArrayStreamingParser` 面向超大数组文件(`[item, item, ...]`),逐元素 yield。

## GPU 后端

`loads[target="gpu"]` / `load[target="gpu"]` 把解析放到 GPU:融合结构位图内核在 GPU 上产出原始结构位图,CPU 侧(`gpu/tape_adapter.mojo`)应用 in-string 过滤,最终仍是同一个 tape-backed `Document`。NVIDIA、AMD、Apple Metal 共享同一条流水线。

适用场景:

- 文件大于 100 MB(小文件 GPU 启动与传输开销不划算);
- 批量解析多个大文件,复用 GPU 上下文。

选择 CPU 的默认 SIMD 两趟 walker 时,解析全程零 FFI;如需兼容 simdjson 生态,可用 `target="cpu-simdjson"` 选择加入 FFI 垫片。
