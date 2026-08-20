# json

基于 Mojo 编程语言的高性能 JSON 库,纯 Mojo 实现,零 FFI 依赖(可选 simdjson FFI),CPU 与 GPU 统一流水线。

## 特性

- **Python 风格 API**:`loads` / `dumps` / `load` / `dump`,上手即用。
- **纯 Mojo、热路径零 FFI**:默认 CPU 解析器是 64 字节无分支 SIMD 两趟 walker(PSHUFB 风格分类器 + 前缀 XOR 转义跟踪),输出紧凑的 `Document` tape。simdjson FFI 垫片可通过 `target='cpu-simdjson'` 选择加入。
- **CPU / GPU 同一表示**:每个后端都写入同一个 tape-backed `Document`。`Value` 是指向 tape 的稳定索引,迭代是 tape 遍历而非重新解析;嵌套修改会沿父链传播(`doc["a"]["b"].set(...)` 对 `doc` 可见)。
- **GPU 加速**:`target='gpu'` 在 NVIDIA、AMD、Apple Metal 上原生运行,共享同一条精简流水线(融合结构位图内核 + 仅位置流压缩)。仅对离散显卡上 >100 MB 的文件值得。
- **零样板反射序列化**:`serialize_json(struct)` 和 `deserialize_json[T](json)` 在编译期遍历结构体字段;可用 `JsonSerializable` / `JsonDeserializable` 覆写单个类型,而不放弃其余部分的反射。
- **RFC 合规查询**:JSONPath (RFC 9535)、JSON Patch (RFC 6902)、JSON Merge Patch (RFC 7396)、JSON Schema 校验(draft-07 子集)。
- **NDJSON / 惰性 / 流式解析**:按行解析、按需惰性取值、超大文件分块流式处理。

## 快速开始

### 安装

`json` 0.1.0 已发布到 `mojo-force` 渠道,可直接通过 pixi 安装:

```bash
pixi add json --platform linux-64 -c https://prefix.dev/mojo-force -c https://conda.modular.com/max/
```

### 基本用法

```mojo
from json import loads, dumps, load, dump

def main() raises:
    # 解析
    var data = loads('{"name": "Alice", "scores": [95, 87, 92]}')
    print(data["name"].string_value())      # Alice
    print(data["scores"][0].int_value())    # 95

    # 选择后端
    var fast = loads[target="cpu-simdjson"]('{"x": 1}')   # simdjson FFI
    var big  = load[target="gpu"]("huge.json")            # GPU (>100 MB)

    # 序列化
    print(dumps(data, indent="  "))         # pretty print
```

## 核心用法

### 解析与序列化

```mojo
from json import loads, dumps, load, dump, Value
from json.config import ParserConfig, SerializerConfig

# 解析字符串
var v = loads('{"a": 1, "b": [true, null, "x"]}')

# 带配置解析(最大深度、注释、尾逗号)
var config = ParserConfig(max_depth=10, allow_comments=True)
var v2 = loads('{"a": 1} // 注释', config)
var v3 = loads('{"a": 1,}', ParserConfig.lenient())

# 序列化(紧凑 / 缩进 / 完整配置)
print(dumps(v))                                   # 紧凑
print(dumps(v, indent="  "))                      # 缩进
var scfg = SerializerConfig(sort_keys=True, indent="  ", escape_unicode=True)
print(dumps(v, scfg))

# 文件读写
dump(v, open("out.json", "w"))
var loaded = load("out.json")
```

### 访问与修改 Value

```mojo
var doc = loads('{"users": [{"name": "Alice"}, {"name": "Bob"}]}')

# 类型检查
doc.is_object()          # True
doc["users"].is_array()  # True

# 取值
doc["users"][0]["name"].string_value()   # "Alice"
doc["users"][0]["name"].raw_json()       # "\"Alice\""

# 遍历
for item in doc["users"].array_items():
    print(item["name"].string_value())

for pair in doc.object_items():
    print(pair[0], pair[1])   # key, value

# JSON Pointer 导航
doc.at("/users/0/name").string_value()   # "Alice"

# 修改(嵌套修改沿父链传播)
doc["users"].append(loads('{"name": "Carol"}'))
doc["users"][0]["name"].set(Value("Alicia"))     # set 对 doc 可见
doc.set_at("/users/1/age", Value(30))
```

### 类型检查与取值方法

`Value` 提供完整的类型谓词与访问器:`is_null()` / `is_bool()` / `is_int()` / `is_float()` / `is_string()` / `is_array()` / `is_object()` / `is_number()`,以及 `bool_value()` / `int_value()` / `float_value()` / `string_value()` / `raw_json()`。构造原生值:`Value(42)`、`Value(3.14)`、`Value("hi")`、`Value(True)`、`Value(Null())`。

## 进阶功能

### JSONPath (RFC 9535)

```mojo
from json.jsonpath import jsonpath_query, jsonpath_one

var doc = loads('{"store": {"book": [{"title": "A", "price": 8}, {"title": "B", "price": 12}]}}')

jsonpath_query(doc, "$.store.book[*].title")        # 所有书名
jsonpath_one(doc, "$.store.book[0].title")          # 第一个匹配
jsonpath_query(doc, "$..price")                     # 递归下降
jsonpath_query(doc, "$.store.book[?@.price<10]")    # 过滤
```

### JSON Patch / Merge Patch

```mojo
from json.patch import apply_patch, merge_patch, create_merge_patch

var doc = loads('{"name": "Alice"}')
var patch = loads('[{"op": "add", "path": "/age", "value": 30}]')
var result = apply_patch(doc, patch)   # {"name":"Alice","age":30}

var merged = merge_patch(loads('{"a": 1, "b": 2}'), loads('{"b": 3}'))  # {"a":1,"b":3}
```

### JSON Schema 校验

```mojo
from json.schema import validate, is_valid

var schema = loads('{"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}}}')
var result = validate(loads('{"name": "Alice"}'), schema)
result.valid            # True
# result.errors: List[ValidationError],每个含 path 与 message
```

支持关键字:`type` / `enum` / `const` / `minimum` / `maximum` / `minLength` / `maxLength` / `pattern` / `minItems` / `maxItems` / `items` / `minProperties` / `maxProperties` / `properties` / `required` / `additionalProperties` / `anyOf` / `oneOf` / `allOf` / `not`。

### 反射序列化(零样板)

```mojo
from json import loads
from json.reflection import serialize_json, deserialize_json, try_deserialize_json

@fieldwise_init
struct Point:
    var x: Int
    var y: Int

def main() raises:
    print(serialize_json(Point(1, 2)))          # {"x":1,"y":2}
    print(serialize_json(Point(1, 2), pretty=True))

    # 反序列化需要 Defaultable + Movable
    @fieldwise_init
    struct Point2(Defaultable, Movable):
        var x: Int
        var y: Int
        def __init__(out self):
            self.x = 0
            self.y = 0

    var p = deserialize_json[Point2]('{"x":1,"y":2}')
    var maybe = try_deserialize_json[Point2]('{"x":1}')   # Optional[Point2]
```

支持字段类型:标量(`Int` / `Int64` / `Bool` / `Float64` / `Float32` / `String`)、容器(`List[...]` / `Optional[...]` / `Dict[String, ...]`)、嵌套结构体(递归反射)、`Value`(原样透传)。用 `JsonSerializable` / `JsonDeserializable` trait 可覆写单个类型的序列化/反序列化。

### 手动 serde trait

```mojo
from json import loads
from json.deserialize import Deserializable, deserialize, get_string, get_int

struct Person(Deserializable):
    var name: String
    var age: Int

    @staticmethod
    def from_json(json: Value) raises -> Self:
        return Self(name=get_string(json, "name"), age=get_int(json, "age"))

var person = deserialize[Person]('{"name":"Alice","age":30}')
```

### NDJSON

```mojo
from json import load
from json.ndjson import parse_ndjson, parse_ndjson_lazy, dumps_ndjson

var lines = parse_ndjson('{"a":1}\n{"a":2}\n{"a":3}')   # List[Value],3 个元素
var text = dumps_ndjson(lines)                          # 重新拼回 NDJSON

# 惰性逐行迭代,内存占用更低
var iter = parse_ndjson_lazy('{"a":1}\n{"a":2}')
while iter.has_next():
    var value = iter.next()

# 直接加载 NDJSON 文件
var from_file = load[format="ndjson"]("data.ndjson")
```

### 惰性与流式解析

```mojo
from json.lazy import loads_lazy
from json.streaming import StreamingParser

# 惰性:只解析访问到的路径,适合大文档取少量字段
var lazy = loads_lazy(huge_json_string)
var name = lazy.get("/users/0/name")   # 只解析该路径

# 流式:分块读取超大文件,逐条 yield 完整 JSON 值(适合 NDJSON)
var parser = StreamingParser("large.ndjson")
while parser.has_next():
    var value = parser.next()
    process(value)
parser.close()
```

### 统一入口 prelude

`from json.prelude import *` 一次性导入日常最常用的名字:`loads` / `dumps` / `load` / `dump`、`Value` / `Null`、`ParserConfig` / `SerializerConfig`,以及反射 serde 全家(`serialize_json` / `serialize_value` / `deserialize_json` / `deserialize_value` / `try_deserialize_json`)。领域专用面(JSONPath / Patch / Schema / 流式 / 手动 trait)按需从对应模块导入,保持 prelude 精简。

## 后端与性能

- **cpu(默认)**:两趟 stage1 + stage2 walker(`json.cpu.parse_cpu_native_tape`),64 字节无分支 SIMD 分类,无 FFI。
- **cpu-simdjson**:选择加入的 simdjson FFI 垫片(`json.cpu.simdjson_ffi`)。
- **gpu**:融合结构位图内核 + CPU 侧 in-string 过滤(`gpu/tape_adapter.mojo`),NVIDIA / AMD / Apple Metal 共享一条流水线;对 >100 MB 文件才有收益。

`loads[target='gpu']` 在 GPU 上产出原始结构位图,并在 `gpu/tape_adapter.mojo` 中于 CPU 侧应用 in-string 过滤器。

## 构建与测试

项目使用 pixi 管理环境(Mojo >= 1.0.0,<2,含 max 依赖):

```bash
pixi install          # 安装环境
make package          # 预编译:mojo precompile src/json/ -o json.mojoc
make test             # 运行测试
```

等价命令:

```bash
pixi run mojo precompile src/json/ -o json.mojoc
pixi run test
```

## 发布

```bash
make build            # rattler-build 构建 conda 包
make upload           # 上传到 mojo-force 渠道(需 PREFIX_API_KEY)
make publish          # 等同 upload
```

`publish` 通过 `scripts/publish.sh` 将 `output/**/*.conda` 产物逐个上传到 `mojo-force` 渠道。包名即 `json`,用户通过 `pixi add json -c https://prefix.dev/mojo-force` 安装。

## 文档

完整文档见 [mkdocs 站点](https://github.com/mojothon/json)(本地预览:`make doc`,即 `mkdocs serve`),包含快速开始、API 参考与进阶指南。

## 版本

当前版本 **0.1.0**(参见 [docs/version.md](docs/version.md) 版本记录)。

## 许可证

[MIT](LICENSE)
