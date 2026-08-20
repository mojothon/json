# 版本记录

## 0.1.0(2026-08-20)

首个公开发布版本,已发布到 `mojo-force` 渠道。

### 核心能力

- **解析**:Python 风格 `loads` / `load`,支持字符串、文件句柄、文件路径;编译期 `target` 选择后端(`cpu` / `cpu-simdjson` / `gpu`)。
- **序列化**:`dumps` / `dump`,支持缩进、键排序、Unicode 转义、斜杠转义等 `SerializerConfig` 选项;NDJSON 序列化。
- **Value 类型**:tape-backed 视图,类型谓词、取值访问器、数组/对象遍历、JSON Pointer 导航与写入;嵌套修改沿父链传播。
- **反射 serde**:`serialize_json` / `deserialize_json` / `try_deserialize_json`,零样板;`JsonSerializable` / `JsonDeserializable` 覆写单类型。
- **RFC 查询**:JSONPath (RFC 9535)、JSON Patch (RFC 6902)、JSON Merge Patch (RFC 7396)、JSON Schema 校验(draft-07 子集)。
- **大数据**:NDJSON 解析/序列化、`LazyValue` 按需惰性解析、`StreamingParser` 分块流式解析。
- **GPU 加速**:融合结构位图内核,NVIDIA / AMD / Apple Metal 共享同一流水线。

### 发布流程

- 构建:`rattler-build build -r src`(含 `mojo precompile json` 打包为 `json.mojoc`)。
- 测试:轻量 smoke 测试(`mojo build -I ${PREFIX}/lib/mojo` 编译 `smoke_test.mojo` 并运行)验证打包产物可用。
- 上传:`rattler-build upload prefix -c mojo-force`。

### 安装

```bash
pixi add json --platform linux-64 -c https://prefix.dev/mojo-force -c https://conda.modular.com/max/
```
