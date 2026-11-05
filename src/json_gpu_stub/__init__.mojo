# json_gpu_stub — macOS 构建期的 json.gpu 替身（不参与任何平台的正常构建）。
#
# 背景：json/gpu 是 CUDA-only（全部文件 import max.gpu，与 _cublas/_cudnn
# 同族），mac 的 max 包不含 gpu 模块，真 gpu 源码在 darwin 上不可能编译
# （2026-11-05 macos-14 探针 C4 六轮实录）。而核心 parser 顶层急切导入
# .gpu——Mojo 对文本 import 的解析与 comptime 可达性无关（第八轮实录：
# comptime if 死分支里的 import 照样解析），所以"守卫+延迟导入"不可行。
#
# 唯一干净的结构：darwin 构建时由 recipe 用本目录整个替换 json/gpu，
# 签名与真包完全一致，调用即得到明确的运行时错误。本目录在 src/ 下位于
# json/ 包之外，linux 预编译不会碰它；改真包签名时必须同步改这里。
#
# 签名镜像自：src/json/gpu/parser.mojo::parse_json_gpu 与
#             src/json/gpu/tape_adapter.mojo::parse_gpu_to_value

from json.types import JSONInput, JSONResult
from json.value import Value

# 模块级常量:1.2 的 file-scope 写法是 `comptime NAME: Type = value`
# (alias 在 1.2 不再接受这个形态——第九轮+本地最小复现实录)。
comptime _STUB_MSG: String = "json: target='gpu' is CUDA-only (max.gpu) and is not built on macOS"


def parse_json_gpu(
    var input: JSONInput, verbose: Bool = False
) raises -> JSONResult:
    """macOS stub — the real implementation lives in json/gpu (CUDA-only)."""
    raise Error(_STUB_MSG)


def parse_json_gpu_from_pinned(
    var input: JSONInput, verbose: Bool = False
) raises -> JSONResult:
    """macOS stub — see parse_json_gpu."""
    raise Error(_STUB_MSG)


def parse_gpu_to_value(var input: String, gpu_result: JSONResult) raises -> Value:
    """macOS stub — the real implementation lives in json/gpu (CUDA-only)."""
    raise Error(_STUB_MSG)
