---
name: verilog-merge
description: 将拆分后的Verilog子模块合并回完整RTL，并用testbench-generator+iverilog完成最终验证
---

## 角色定义

你是 `verilog-merge` agent 的调用者，也是进一步检查的工程师。你负责的不只是“让 agent 合并”，而是把结果做成可验证的结论：
1. 激活环境并调用 `agent_merge.py` 完成合并
2. 确认合并产物 `merged.v` 的语法/风格检查不阻断仿真
3. 在等价性工具返回 `warning` 或仿真发现不一致时，调用 `testbench-generator` 生成 tb，并用 `iverilog + vvp` 进行最终验证
4. 若验证失败，推动 `merged.v` 修复并重新验证，直到通过
# 等价性验证指南

当 Yosys ABC CEC 返回 `warning`（无法判断等价性）时，需要使用 Icarus Verilog (iverilog) 进行仿真验证。

## 问题说明

Yosys BLIF + ABC CEC 在以下情况可能返回 warning（假阴性）：
- BLIF 包含 `$add`, `$sub`, `$mul` 等算术运算符
- BLIF 包含 `$reduce_or`, `$reduce_and` 等归约运算符
- BLIF 包含 `$mux`, `$pmux` 等多路复用器
- 时序逻辑（如带使能的寄存器 `$adffe`）

这些是 Yosys/ABC 工具的内部限制，不代表设计真的不等价。

## 验证方法

假设：
- 原始文件：`original.v`
- 合并后文件：`merged.v`
- 工作目录：`workspace/`

由于两个文件模块名相同，需要重命名其中一个模块避免冲突。
你的skill：testbench-generator可以用于验证等价性。
把原始的文件作为ref,merged后作为待测项目。
随后利用iverilog vvp给出结论。
如果不正确，请修复merge文件直至等价。

## 输入

```json
{
  "inputs": {
    "partition_workspace_dir": {
      "type": "string",
      "description": "Partition 产物目录，例如：workspace/partition_<uuid>"
    },
    "reference_file": {
      "type": "string",
      "description": "原始 RTL 文件名（通常在 partition workspace 根目录），例如：traffic.v（可选）"
    }
  }
}
```

## 执行步骤

### Step 1: 激活虚拟环境

```bash
source /home/openclawer/anaconda3/etc/profile.d/conda.sh
conda activate /home/openclawer/Projects/Partition/.venv
```

### Step 2: 调用 Merge Agent

直接运行 `agent_merge.py`：

```bash
python agent_merge.py <partition_workspace_dir>
```

例如：

```bash
python agent_merge.py workspace/partition_xxx
```

### Step 3: 检查执行结果

Agent 会自动完成以下步骤：

1. **合并识别** - 在工作区内识别原始单文件与 parts_dir（通常为 output/）
2. **合并产物生成** - 将子模块合并回完整模块并得到 `merged.v`
3. **语法检查** - 使用 Verible 检查语法
4. **Lint 检查** - 使用 Verible 检查风格
5. **等价性入口检查** - 调用 `check_equivalence(merged_file, original_file)`（可能返回 `warning`）

**成功输出示例**：

```
Merge Agent
==============
Workspace: /home/openclawer/Projects/Partition/workspace/partition_xxx
Source: traffic.v

--- Turn 1 ---
  [step] run "ls"
  [step] read file traffic.v line 1-100
  [step] run_heuristic_merge parts_dir=output original_file=traffic.v output_file=merged.v
  [step] check_equivalence merged=merged.v original=traffic.v
  ...
  [step] check_verilog_syntax merged.v
  [step] check_verilog_lint merged.v
  ...
```

### Step 4: 生成 testbench 并用 iverilog 验证

作为调用者/工程师，你需要把等价性从“工具判断”变成“可观测的仿真结论”。
如果子 agent 的 Yosys/ABC 等价性检查返回 `warning`（无法判断，可能是假阴性），你**必须**使用 `testbench-generator` 生成 tb，并通过 `iverilog + vvp` 完成最终验证，直到仿真验证通过（行为一致）为止。

> 注意：你在执行 tb 检查前应先读取 `merged.v` 对应的关键检查汇总（如果 workspace 里存在例如 `result.md`/等价性报告），避免被前面冗长的 agent 输出干扰导致跳过 tb。

流程建议：
1. 用 `-rtl-spec-analyzer`(skill) 对 `reference_file`（原始 RTL）生成 `analysis_result`
2. 调用 `-testbench-generator`(skill) 基于 `analysis_result` 生成 `tb_<module>.sv`
3. 避免 module 同名冲突：
   - 若 `reference_file` 和 `merged.v` 的 module 名相同，编译前必须重命名其中一个，或修改 tb 的实例化目标
4. 编译与运行：
```bash
iverilog -g2012 -o simv tb_<module>.sv <reference_file> merged.v
vvp simv
```
5. 读取 tb 输出的 PASS/FAIL 或 mismatch 细节；若发现 mismatch，直接进入 Step 5

#### tb 检查的输出隔离要求（必须遵守）
如果你进入 `testbench-generator -> iverilog + vvp` 的 tb 检查流程：
1. 在 `workspace/merge_<uuid>/` 下新建子文件夹 `iverilog_check_for_merge/`
2. 将 `tb_<module>.sv`、`simv`/编译产物、`vvp` 运行日志/输出等全部写入该子文件夹
3. 禁止覆盖或复用其它阶段可能生成的同类文件，避免与后续/并行流程冲突

### Step 5: 仿真失败修复方向

通常 mismatch 来自以下方面（优先级从高到低）：
1. 端口位宽/方向在合并时出现偏差
2. always 语义不一致（reset 条件、enable 条件、阻塞/非阻塞赋值、case/default 完整性）
3. 组合逻辑漏赋值或优先级变化导致 X 泄漏/行为差异

修复后回到 Step 4 重新验证。

### Step 6: 重新检查（快速兜底）

在重新跑 Step 4 之前，至少确认：
- `merged.v` 语法检查通过
- tb 编译不会因位宽/端口错误而失败

## Verible 用法（语法/风格，用于手动合并修复）
当你需要手动修复 `merged.v`（例如 agent 合并后仍可能存在语法或行为相关问题），可以直接用 Verible 做“快速收敛”：

### 1) 语法检查（必须先过）
Verible 语法检查使用 `verible-verilog-syntax`，等价于项目 `tools.py` 的 `check_verilog_syntax()` 行为：

```bash
/home/openclawer/Projects/Partition/verible-tools/bin/verible-verilog-syntax --export_json merged.v
```

判定规则：
- 退出码 `0`：语法通过
- 非 `0`：在终端输出（通常是 `stderr`）里找具体错误行/错误类型，先修语法错误，再处理 lint

### 2) Lint/风格检查（用于定位潜在行为缺口）
Verible 风格检查使用 `verible-verilog-lint`，等价于项目 `tools.py` 的 `check_verilog_lint()` 行为（注意：`tools.py` 会禁用部分规则以避免噪音淹没重点）：

```bash
/home/openclawer/Projects/Partition/verible-tools/bin/verible-verilog-lint \
  --rules=-no-trailing-spaces,-posix-eof,-line-length,-explicit-parameter-storage-type,-module-filename,-parameter-name-style \
  merged.v
```

判定规则：
- 退出码 `0`：lint 通过（无 style 问题）
- 退出码非 `0`：把输出里列出的 warnings 逐条处理

修复建议（跟仿真 mismatch 相关的优先级更高）：
- `case-missing-default`：如果是组合 `always @*`，很可能导致未覆盖分支产生 `X`/错误行为；先补 `default` 或补齐赋值
- `no-tabs`：纯风格问题，通常不影响功能；但如果你是在“逐行手动改代码”，把 tab 清理掉可以减少后续误判
- 与端口位宽/时序语义无关的纯风格 warning：可以暂时忽略，等 `iverilog`/tb 通过后再决定是否清理

### 3) 推荐调试顺序
1. 先跑 Verible syntax（必须过）
2. 再跑 lint（把跟 `case`/赋值覆盖相关的 warning 优先修）
3. 最后才进入 `testbench-generator -> iverilog/vvp` 的最终验证循环

## 输出格式

### 主要输出：合并后的 `merged.v` + tb

- **位置**: `workspace/merge_<uuid>/`
- **文件**: `merged.v`
- **tb 文件**: `tb_<module>.sv`（由 `testbench-generator` 生成）

### 汇报内容

```
## 合并验证总结

**reference_file**: <reference_file>

**不一致修复记录**（如有）:
- <迭代>: <mismatch_desc> -> <修复要点>

**验证结果**:
- ✅ 语法检查：merged.v 通过
- ✅ Lint 检查：merged.v 通过或仅风格警告
```

## 使用示例

### 示例1：由 partition workspace 合并 traffic.v

```bash
# 激活环境
source /home/openclawer/anaconda3/etc/profile.d/conda.sh
conda activate /home/openclawer/Projects/Partition/.venv

# 运行合并
python agent_merge.py workspace/partition_xxx
```

**输出**：

```
## 合并验证总结

**reference_file**: traffic.v

| 子模块 | 功能 | 主要信号 |
|--------|------|----------|
| u_block_1 | 状态机逻辑 | state, p_red, p_green, p_yellow |
| u_block_2 | 计数器逻辑 | cnt (8位) |
| u_block_3 | 输出寄存器 | red, yellow, green |

**一致性审查修正内容**:
- u_block_1: p_red/p_green/p_yellow 从 output wire 改为 output reg
- u_block_2: cnt 位宽从 7'd 修正为 8'd
- u_block_3: 添加缺失的 else 分支

**检查结果**:
- ✅ 语法检查：3/3 通过
- ✅ Lint 检查：3/3 通过
结果位于 `根据agent的输出，把这里替换为实际目录` 目录。
```

### 示例2：其他文件

```bash
python agent_merge.py workspace/partition_xxx
python agent_merge.py workspace/partition_xxx
```

## 注意事项

### 1. 大多数情况无需手动干预

`agent_merge.py` 内部已经封装了完整流程，包括：
- 一致性审查
- 语法检查
- Lint 检查

只需运行命令即可。

### 2. 何时需要手动修复

- 一致性审查发现的问题 Agent 无法自动修正
- 语法检查仍然失败
- 合并逻辑明显错误

### 3. 查看 workspace

如需查看详情：

```bash
# 查看 workspace 目录
ls workspace/

# 查看具体的拆分结果
ls workspace/merge_<uuid>/
```

## 协作关系

```json
{
  "workflow": {
    "upstream_skill": {
      "name": "rtl-spec-analyzer",
      "output": {
        "name": "analysis_result",
        "format": "JSON",
        "data_structure": {
          "module_info": "RTL端口信息",
          "circuit_type": "电路类型（v1.0新增）",
          "features": "功能点列表",
          "feature_mappings": "功能点到Pin的映射",
          "latency_cycles": "功能延迟周期（v1.0新增）"
        }
      }
    },
    "upstream_skill": {
      "name": "testbench-generator",
      "role": "生成testbench",
      "input": "analysis_result",
      "tasks": [
        "生成Testbench框架",
        "生成各功能点的激励代码",
        "生成与DUT时序同步的Reference Model",
        "生成基于有效信号的自动比对逻辑"
      ],
      "output": {
        "file_name": "tb_<module>.sv",
        "description": "完整Testbench文件"
      }
    }
  }
}
```

```json
{
  "workflow": {
    "current_skill": {
      "name": "verilog-merge",
      "role": "……",
      "input": "verilog_file_path",
      "tasks": [
        "激活虚拟环境",
        "调用 agent_merge.py",
        "生成 testbench",
        "调用iverilog",
        "手动修复（如有问题）"
      ],
      "output": {
        "directory": "workspace/merge_<uuid>/",
        "files": ["merged.v", "tb_<module>.sv"],
        "description": "合并后的产物与仿真tb"
      }
    },
    "downstream_skill": {
      "name": "verilog-merge",
      "input": "partition workspace",
      "description": "将拆分后的子模块重新合并"
    }
  }
}
```

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| Agent 运行失败 | 检查 .env 配置（API_BASE, API_KEY） |
| 语法检查失败 | 手动读取文件，对照原始修改 |
| 仿真失败/等价不一致 | 查看 tb 的 mismatch 细节；优先检查端口位宽/方向，以及 always 里的 reset/enable 与非阻塞赋值 |
