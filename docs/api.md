# API 参考

本文档列出 `json` 的完整公开 API 面。所有领域专用接口按模块导入;日常最常用名字可用 `from json.prelude import *` 一次性引入。

## 导入方式

```mojo
from json import loads, dumps, load, dump          # 核心入口
from json import Value, Null                       # 值类型
from json import ParserConfig, SerializerConfig    # 配置
from json import serialize_json, deserialize_json, try_deserialize_json   # 反射 serde
from json.prelude import *                         # 上述常用名字的统一入口
```

领域专用模块:

| 模块 | 内容 |
| --- | --- |
| `json.jsonpath` | `jsonpath_query`, `jsonpath_one` |
| `json.patch` | `apply_patch`, `merge_patch`, `create_merge_patch` |
| `json.schema` | `validate`, `is_valid`, `ValidationResult`, `ValidationError` |
| `json.ndjson` | `parse_ndjson`, `parse_ndjson_lazy`, `dumps_ndjson` |
| `json.lazy` | `loads_lazy`, `LazyValue` |
| `json.streaming` | `StreamingParser`, `ArrayStreamingParser` |
| `json.serialize` | `Serializable`, `to_json_value`, `to_json_string`, `serialize` |
| `json.deserialize` | `Deserializable`, `deserialize`, `get_string`, `get_int`, `get_bool`, `get_float` |
| `json.cpu.simdjson_ffi` | `SimdjsonFFI` |
| `json.gpu` | GPU 后端内核(经 `target='gpu'` 使用) |

## 解析(parser.mojo)

```mojo
def loads[target: StaticString = "cpu"](s: String) raises -> Value
def loads(s: String, config: ParserConfig) raises -> Value
def loads[lazy: Bool](s: String) raises -> LazyValue
def load[target: StaticString = "cpu"](path: String) raises -> Value
def load[target: StaticString = "cpu"](mut f: FileHandle) raises -> Value
def load[format: StaticString](path: String) raises -> List[Value]   # format="ndjson"
def load[streaming: Bool](path: String) raises -> StreamingParser    # streaming=True
```

- `loads(s)` 解析字符串为 `Value`;`target` 支持 `"cpu"`(默认)、`"cpu-simdjson"`、`"gpu"`。
- `load(path)` / `load(file)` 从文件解析;`load[format="ndjson"]` 按行解析 NDJSON 文件返回 `List[Value]`;`load[streaming=True]` 返回流式解析器。
- 惰性解析:`loads_lazy(s) -> LazyValue`(见 `json.lazy`)。

## 序列化(serialize.mojo)

```mojo
def dumps(v: Value, indent: String = "") -> String
def dumps(v: Value, config: SerializerConfig) -> String
def dumps[format: StaticString = "json"](values: List[Value]) -> String   # format="ndjson"
def dump(v: Value, mut f: FileHandle) raises
def dump(v: Value, mut f: FileHandle, indent: String) raises
def to_json_value(val: String | Int | Int64 | Float64 | Bool) -> String
def to_json_string(s: String) -> String
def serialize[T: Serializable](obj: T) -> String
```

- `dumps(v)` 紧凑输出;`dumps(v, indent="  ")` 缩进输出;`dumps(v, config)` 使用完整配置。
- `dumps[format="ndjson"](values)` 把 `List[Value]` 序列化为 NDJSON。
- `to_json_value` / `to_json_string` 把标量转成 JSON 片段;`serialize[T]` 需要类型实现 `Serializable` trait。

## 配置(config.mojo)

```mojo
struct ParserConfig:
    var max_depth: Int            # 最大嵌套深度,0 = 不限(默认)
    var allow_comments: Bool      # 允许 // 与 /* */ 注释(默认 False)
    var allow_trailing_comma: Bool  # 允许尾逗号(默认 False)

    def __init__(out self, max_depth: Int = 0, allow_comments: Bool = False,
                  allow_trailing_comma: Bool = False)
    @staticmethod
    def default() -> Self         # 严格模式
    @staticmethod
    def lenient() -> Self         # 宽松模式(注释 + 尾逗号)

struct SerializerConfig:
    var indent: String             # 缩进串,空 = 紧凑(默认)
    var sort_keys: Bool            # 对象键按字母序排序(默认 False)
    var escape_unicode: Bool       # 非 ASCII 转义为 \uXXXX(默认 False)
    var escape_forward_slash: Bool # / 转义为 \/(默认 False)

    def __init__(out self, indent: String = "", sort_keys: Bool = False,
                  escape_unicode: Bool = False, escape_forward_slash: Bool = False)
```

## Value 类型(value.mojo)

`Value` 是 tape-backed `Document` 上的视图:数据驻留于共享文档,子视图(如 `array_items()` 返回的项)通过引用计数共享而非克隆。修改走 copy-on-write(`OwnedValue` 树),因此嵌套修改对父视图可见。

构造:`Value(Null())`、`Value(None)`、`Value(Bool)`、`Value(Int)`、`Value(Int64)`、`Value(Float64)`、`Value(String)`。

类型谓词:

| 方法 | 说明 |
| --- | --- |
| `is_null() -> Bool` | 是否为 null |
| `is_bool() -> Bool` | 是否为布尔 |
| `is_int() -> Bool` | 是否为整数 |
| `is_float() -> Bool` | 是否为浮点 |
| `is_string() -> Bool` | 是否为字符串 |
| `is_array() -> Bool` | 是否为数组 |
| `is_object() -> Bool` | 是否为对象 |
| `is_number() -> Bool` | 是否为数字(int 或 float) |

取值:

| 方法 | 说明 |
| --- | --- |
| `bool_value() -> Bool` | 取布尔值 |
| `int_value() -> Int64` | 取整数值 |
| `float_value() -> Float64` | 取浮点值 |
| `string_value() -> String` | 取字符串值 |
| `raw_json() -> String` | 原始 JSON 片段 |
| `array_count() -> Int` | 数组元素个数 |
| `object_count() -> Int` | 对象键值对个数 |
| `object_keys() -> List[String]` | 对象键列表 |

访问:

| 方法 | 说明 |
| --- | --- |
| `get(key: String) -> String` | 取对象字段(返回原始 JSON 字符串) |
| `__getitem__(index: Int) -> Value` | 数组下标访问 |
| `__getitem__(key: String) -> Value` | 对象键访问 |
| `array_items() -> List[Value]` | 数组元素列表 |
| `object_items() -> List[Tuple[String, Value]]` | 对象 (key, value) 列表 |
| `at(pointer: String) -> Value` | JSON Pointer 导航(RFC 6901) |

修改:

| 方法 | 说明 |
| --- | --- |
| `set(key: String, value: Value)` | 设置/更新对象字段 |
| `set(index: Int, value: Value)` | 设置数组元素 |
| `append(value: Value)` | 数组追加 |
| `set_at(pointer: String, value: Value)` | JSON Pointer 写入,沿父链传播 |
| `copy() -> Value` / `clone() -> Value` | 复制(ArcPointer 引用计数,廉价) |

其他:`__str__() -> String`(序列化形式)、`__eq__` / `__ne__`(按序列化 JSON 比较)、`Null` 结构体(JSON null 哨兵)。

## 反射序列化(reflection.mojo)

零样板 serde:编译期反射结构体字段自动映射为 JSON 对象。序列化任意 struct 无需 trait;反序列化要求 `Defaultable` + `Movable`。

```mojo
def serialize_json[T: AnyType, pretty: Bool = False](value: T) raises -> String
def serialize_value[T: AnyType](value: T) raises -> Value
def deserialize_json[T: Defaultable & Movable](json: String) raises -> T
def deserialize_value[T: Defaultable & Movable](value: Value) raises -> T
def try_deserialize_json[T: Defaultable & Movable](json: String) -> Optional[T]
```

支持字段类型:标量(`Int` / `Int64` / `Bool` / `Float64` / `Float32` / `String`)、容器(`List[...]` / `Optional[...]` / `Dict[String, ...]`)、嵌套结构体(递归反射)、`Value`(原样透传)。

自定义覆写:

```mojo
trait JsonSerializable:      # 实现 to_json_value(self) raises -> Value 覆写序列化
trait JsonDeserializable:    # 实现 from_json 覆写反序列化
```

## 手动 serde trait

```mojo
trait Serializable:          # to_json_value(self) raises -> Value / to_json_string
trait Deserializable:        # @staticmethod from_json(json: Value) raises -> Self

def deserialize[T: Deserializable, target: StaticString = "cpu"](json_str: String) raises -> T

def get_string(value: Value, key: String) raises -> String
def get_int(value: Value, key: String) raises -> Int
def get_bool(value: Value, key: String) raises -> Bool
def get_float(value: Value, key: String) raises -> Float64
```

`get_*` 系列从对象 `Value` 提取字段并做类型检查,配合 `Deserializable.from_json` 手工映射。

## JSONPath(jsonpath.mojo, RFC 9535)

```mojo
def jsonpath_query(document: Value, path: String) raises -> List[Value]
def jsonpath_one(document: Value, path: String) raises -> Value
```

支持语法:`$`(根)、`.key` / `['key']`(子元素)、`[n]`(下标)、`[*]`(全部)、`..`(递归下降)、`[start:end]`(切片)、`[?expr]`(过滤)。

## JSON Patch / Merge Patch(patch.mojo)

```mojo
def apply_patch(document: Value, patch: Value) raises -> Value      # RFC 6902
def merge_patch(document: Value, patch: Value) raises -> Value      # RFC 7396
def create_merge_patch(a: Value, b: Value) raises -> Value
```

`apply_patch` 支持操作:`add` / `remove` / `replace` / `move` / `copy` / `test`。

## JSON Schema 校验(schema.mojo)

```mojo
struct ValidationError:       # path: String, message: String
struct ValidationResult:      # valid: Bool, errors: List[ValidationError]

def validate(document: Value, schema: Value) raises -> ValidationResult
def is_valid(document: Value, schema: Value) raises -> Bool
```

支持关键字:`type` / `enum` / `const` / `minimum` / `maximum` / `minLength` / `maxLength` / `pattern` / `minItems` / `maxItems` / `items` / `minProperties` / `maxProperties` / `properties` / `required` / `additionalProperties` / `anyOf` / `oneOf` / `allOf` / `not`。

## NDJSON(ndjson.mojo)

```mojo
def parse_ndjson[target: StaticString = "cpu"](s: String) raises -> List[Value]
def parse_ndjson_lazy[target: StaticString = "cpu"](s: String) raises -> NDJSONIterator[target]
def dumps_ndjson(values: List[Value]) -> String
```

`parse_ndjson` 解析每行一个 JSON 值的字符串;`parse_ndjson_lazy` 逐行惰性迭代,内存占用更低。

## 惰性与流式解析

```mojo
# lazy.mojo
def loads_lazy(s: String) -> LazyValue
struct LazyValue:   # 按需解析,只解析访问到的路径
    # get(pointer) / 类型谓词等,类似 Value 的常用子集

# streaming.mojo
struct StreamingParser:        # 分块读取文件,逐条 yield 完整 JSON 值
    def __init__(out self, path: String, chunk_size: Int = 65536) raises
    def has_next(mut self) -> Bool
    def next(mut self) raises -> Value
    def close(mut self) raises
```

## 后端选择

`loads` / `load` / `parse_ndjson` 等解析入口都接受编译期参数 `target`:

| target | 说明 |
| --- | --- |
| `"cpu"`(默认) | 64 字节无分支 SIMD 两趟 walker,零 FFI |
| `"cpu-simdjson"` | 选择加入的 simdjson FFI 垫片 |
| `"gpu"` | 融合结构位图内核,支持 NVIDIA / AMD / Apple Metal |

GPU 路径在 GPU 上产出原始结构位图,并在 CPU 侧应用 in-string 过滤(`gpu/tape_adapter.mojo`);只对 >100 MB 的离散显卡场景有价值。
