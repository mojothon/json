# 快速开始

## 安装

`json` 0.1.0 已发布到 `mojo-force` 渠道,通过 pixi 即可安装:

```bash
pixi add json --platform linux-64 -c https://prefix.dev/mojo-force -c https://conda.modular.com/max/
```

等价地,在已有项目的 `pixi.toml` 中加入渠道与依赖:

```toml
[workspace]
channels = [
    "https://prefix.dev/mojo-force",
    "https://conda.modular.com/max/",
    "conda-forge",
]
platforms = ["linux-64"]

[dependencies]
json = ">=0.1.0,<0.2"
```

## 首个程序

```mojo
from json import loads, dumps, load, dump, Value

def main() raises:
    # 解析 JSON 字符串
    var data = loads('{"name": "Alice", "scores": [95, 87, 92]}')

    # 访问字段
    print(data["name"].string_value())       # Alice
    print(data["scores"][0].int_value())     # 95
    print(data["scores"].array_count())      # 3

    # 序列化
    print(dumps(data))                       # 紧凑
    print(dumps(data, indent="  "))          # 缩进
```

## 核心用法

### 解析

`loads(s)` 把字符串解析为 `Value`;`load(path)` / `load(file_handle)` 从文件解析。

```mojo
var v = loads('{"a": 1, "b": [true, null, "x"]}')

var from_file = load("config.json")
```

带配置解析(`ParserConfig`):

```mojo
from json.config import ParserConfig

# 严格模式(默认):不允许注释、尾逗号,深度不限
var strict = ParserConfig.default()

# 宽松模式:允许 // 与 /* */ 注释、尾逗号
var lenient = ParserConfig.lenient()

# 自定义:限制最大嵌套深度
var custom = ParserConfig(max_depth=10, allow_comments=True, allow_trailing_comma=True)

var v = loads('{"a": 1,} // trailing comma and comment', custom)
```

### 序列化

`dumps(v)` 返回字符串;`dump(v, file)` 写入文件。可用 `SerializerConfig` 控制缩进、排序、转义:

```mojo
from json.config import SerializerConfig

print(dumps(v))                                     # 紧凑
print(dumps(v, indent="  "))                        # 两空格缩进
print(dumps(v, SerializerConfig(sort_keys=True, indent="  ")))       # 键排序
print(dumps(v, SerializerConfig(escape_unicode=True)))               # \uXXXX 转义
print(dumps(v, SerializerConfig(escape_forward_slash=True)))         # \/ 转义

dump(v, open("out.json", "w"))
```

### Value 类型

`Value` 是 JSON 值的核心类型,提供类型谓词、取值、访问与修改方法。

类型检查与取值:

```mojo
v.is_null(); v.is_bool(); v.is_int(); v.is_float()
v.is_string(); v.is_array(); v.is_object(); v.is_number()

v.bool_value()      # Bool
v.int_value()       # Int64
v.float_value()     # Float64
v.string_value()    # String
v.raw_json()        # 原始 JSON 片段
```

访问元素:

```mojo
var obj = loads('{"a": 1, "b": 2}')
obj["a"].int_value()                     # 按键访问
obj.at("/a").int_value()                 # JSON Pointer 访问

var arr = loads('[10, 20, 30]')
arr[1].int_value()                       # 按下标访问

for item in arr.array_items():           # 遍历数组
    print(item)

for pair in obj.object_items():          # 遍历对象 (key, value)
    print(pair[0], pair[1])

obj.object_keys()                        # List[String]
```

修改:

```mojo
var doc = loads('{"users": [{"name": "Alice"}]}')

doc["users"].append(loads('{"name": "Bob"}'))     # 数组追加
doc["users"][0]["name"].set(Value("Alicia"))      # 键更新(父链可见)
doc["users"][1].set("age", Value(30))             # 键新增
doc.set_at("/users/0/age", Value(25))             # JSON Pointer 写入
```

构造原生 `Value`:`Value(42)`、`Value(3.14)`、`Value("hi")`、`Value(True)`、`Value(Null())`。

## 下一步

- 深入 API 见 [API 参考](api.md)
- JSONPath、JSON Patch、Schema、反射序列化、NDJSON、惰性与流式解析见 [进阶指南](advanced.md)
