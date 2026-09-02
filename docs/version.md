# 版本记录

## 0.1.2(2026-09-02)

数值访问类型安全修复版本,已发布到 `mojo-force` 渠道。

### 修复

- **`Document.get_float` 对 INT 条目的越界 UB**:tape 编码中 INT 条目直接把整数值存 payload,旧实现无 tag 检查直接 `float_pool[payload]`。整数值恰好落在 float 池范围内时读到错误 float,越界时崩溃(实测 `"price":10` 因 float 池仅 2 项而越界)。现改为按 tag 分流:FLOAT 走 float 池、INT 转 `Float64`、其余 tag `raise Error("Value is not a float")`。
- **`Value.float_value()` 同步加 `raises` 透传**,`serialize` / `jsonpath` / `schema` / `patch` / `reflection` 内部不 raises 的调用点改用 `_num` helper 或 try/except 适配,消除取值路径的潜在越界。

### 测试

- 新增 4 个回归用例:`INT → 10.0`、`负 INT → -7.0`、`FLOAT → 10.5`、`string 误调 → raise`。

## 0.1.1(2026-08-24)

UTF-8 字节精确修复版本,已发布到 `mojo-force` 渠道。

### 修复

- **序列化双重编码**:`_escape_string` / `_format_json` / `_escape_unicode_chars` / `_escape_forward_slashes` / `config` 预处理 / `errors` 上下文片段,统一改为按 UTF-8 字节区间整段复制(多字节字符绝不逐字节 `chr()` 重编码)。
- **pretty 缩进回归**:`_format_json` 重写为递归下降(匹配闭括号递归缩进),嵌套对象/数组的深度缩进正确,且多字节 UTF-8 字节精确。
- **`escape_unicode` 代理对**:`\uXXXX` 转义支持补充字符(BMP 外 emoji 等)按 UTF-16 代理对输出(`\ud83d\ude00`)。

### 测试

- 新增 `tests/test_main.mojo`(12 组):中文/em dash/emoji/混合 UTF-8 往返、`Value` 直接构造转义、ASCII 转义、pretty 嵌套、`escape_unicode`(CJK + 代理对)、`escape_forward_slash`、嵌套稳定性、NDJSON。

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
