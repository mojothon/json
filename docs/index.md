# json

基于 Mojo 编程语言的高性能 JSON 库。

`json` 是一个纯 Mojo 实现的 JSON 解析与序列化库:热路径零 FFI(可选 simdjson FFI),CPU 与 GPU 共享同一套 tape-backed 表示,支持反射零样板序列化、JSONPath / JSON Patch / JSON Schema 等 RFC 查询,以及 NDJSON、惰性解析与流式解析。

## 特性

- **Python 风格 API**:`loads` / `dumps` / `load` / `dump`。
- **纯 Mojo、热路径零 FFI**:默认 CPU 解析器是 64 字节无分支 SIMD 两趟 walker;simdjson FFI 通过 `target='cpu-simdjson'` 选择加入。
- **CPU / GPU 同一表示**:所有后端写入同一个 tape-backed `Document`;`Value` 是 tape 上的稳定索引,嵌套修改沿父链传播。
- **GPU 加速**:`target='gpu'` 原生支持 NVIDIA / AMD / Apple Metal,融合结构位图内核 + 仅位置流压缩;对 >100 MB 文件有价值。
- **零样板反射序列化**:`serialize_json(struct)` / `deserialize_json[T](json)` 编译期遍历字段,可用 `JsonSerializable` / `JsonDeserializable` 覆写单个类型。
- **RFC 合规查询**:JSONPath (RFC 9535)、JSON Patch (RFC 6902)、JSON Merge Patch (RFC 7396)、JSON Schema 校验(draft-07 子集)。
- **NDJSON / 惰性 / 流式解析**:按行解析、按需惰性取值、超大文件分块流式处理。

## 快速上手

```mojo
from json import loads, dumps

def main() raises:
    var data = loads('{"name": "Alice", "scores": [95, 87, 92]}')
    print(data["name"].string_value())      # Alice
    print(data["scores"][0].int_value())    # 95

    print(dumps(data, indent="  "))         # pretty print
```

安装与更完整的使用说明见 [快速开始](quickstart.md)。

## 文档导航

- [快速开始](quickstart.md) — 安装、首个程序、核心用法
- [API 参考](api.md) — 完整的公开 API 面
- [进阶指南](advanced.md) — JSONPath、JSON Patch、JSON Schema、反射序列化、NDJSON、惰性与流式解析
- [版本记录](version.md) — 版本历史

## 项目信息

- 项目主页:https://github.com/mojothon/json
- 许可证:MIT(见 [LICENSE](https://github.com/mojothon/json/blob/master/LICENSE))
