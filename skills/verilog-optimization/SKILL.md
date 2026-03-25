---
name: verilog-optimization
description: 在 Verilog partition 之后、merge 之前对 part 文件做 Yosys 优化，并用 Verible 进行语法/lint 兜底
---

## 角色定义
你是一个 optimization 的调用者/工程师，目标是在 `verilog-partition` 之后、`verilog-merge` 之前，把 part 文件做一次可控优化，同时确保优化后的 RTL 仍可编译、风格合规（至少不引入语法错误）。

你需要做到：
1. 激活环境并调用 `agent_optimization.py`
2. 定位优化产物（`partition_opt`、`yosys_opt_record`）
3. 用 Verible 对优化产物做 `syntax + lint` 检查
4. 输出一个“可以直接喂给 merge 的 workspace 目录”

> 注意：本 skill 的 agent 流程中包含等价性验证；如果等价性验证返回 `warning`（无法确定，可能是假阴性），你仍需要确保优化前/后的文件行为一致，必要时走 `testbench-generator -> iverilog/vvp` 进行最终确认。

## 输入
```json
{
  "inputs": {
    "partition_workspace_dir": {
      "type": "string",
      "description": "Partition 产物目录，例如：workspace/partition_<uuid>"
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

### Step 2: 调用 Optimization Agent（Yosys + LLM 驱动）
```bash
cd /home/openclawer/Projects/Partition
python agent_optimization.py <partition_workspace_dir>
```

### Step 3: 定位优化产物
`agent_optimization.py` 会在 `Projects/Partition/workspace/` 下创建一个新的优化会话目录（形如：`workspace/optimization_<uuid>/`），并在其中生成：
1. `workspace/optimization_<uuid>/partition_opt/`：优化后的 part 文件（通常是 `u_block_*.v`）
2. `workspace/optimization_<uuid>/yosys_opt_record/<timestamp>/`：Yosys 优化记录
3. `workspace/optimization_<uuid>/partition_opt/result.md`：汇总报告

> 重要：你必须**优先读取** `partition_opt/result.md` 来判断是否需要进入后续的等价性/仿真验证步骤。不要只看 agent 输出中前面的 MARO 大量提示文本，否则容易跳过 tb 检查。

### Step 4: Verible 语法检查（必须通过）
Verible 语法检查在项目 `tools.py` 中对应 `check_verilog_syntax()`：
```bash
/home/openclawer/Projects/Partition/verible-tools/bin/verible-verilog-syntax --export_json <FILE>
```

判定规则：
- 退出码 `0`：语法通过
- 非 `0`：停止进入 merge 前的任何后续步骤，先修语法错误

建议至少检查：
- `partition_opt/u_block_*.v`

### Step 5: Verible lint/风格检查（定位风险点）
Verible lint 在项目 `tools.py` 中对应 `check_verilog_lint()`，并禁用部分无关规则（避免噪音）。
```bash
/home/openclawer/Projects/Partition/verible-tools/bin/verible-verilog-lint \
  --rules=-no-trailing-spaces,-posix-eof,-line-length,-explicit-parameter-storage-type,-module-filename,-parameter-name-style \
  <FILE>
```

判定规则：
- 退出码 `0`：lint 通过（无 style 问题）
- 非 `0`：把输出里的 warnings 逐条记录

### Step 6: 生成 testbench 并用 iverilog 验证

作为调用者/工程师，你需要把等价性从“工具判断”变成“可观测的仿真结论”。
如果子 agent 的 Yosys/ABC 等价性检查返回 `warning`（无法判断，可能是假阴性），你**必须**使用 `testbench-generator` 生成 tb，并通过 `iverilog + vvp` 完成最终验证，直到仿真验证通过（行为一致）为止。
> 注意：你在执行 tb 检查前应先读取 `partition_opt/result.md` 的关键检查汇总（例如是否已确认语法/风格、以及是否标注等价性状态），避免被前面冗长的 agent 提示干扰导致跳过 tb。

流程建议：
1. 用 `-rtl-spec-analyzer`(skill) 对“优化前文件（reference / original）”生成 `analysis_result`
2. 调用 `-testbench-generator`(skill) 基于 `analysis_result` 生成 `tb_<module>.sv`
3. 避免 module 同名冲突：
   - 若“优化前文件”和“优化后产物”module 名相同，编译前必须重命名其中一个，或修改 tb 的实例化目标
4. 编译与运行（把下面两个路径替换为 workspace 内的真实文件名）：
```bash
iverilog -g2012 -o simv tb_<module>.sv <original_file> <optimized_file>
vvp simv
```
5. 读取 tb 输出的 PASS/FAIL 或 mismatch 细节；若发现 mismatch，直接进入 Step 7

#### tb 检查的输出隔离要求（必须遵守）
如果你进入 `testbench-generator -> iverilog + vvp` 的 tb 检查流程：
1. 在 `workspace/optimization_<uuid>/` 下新建子文件夹 `iverilog_check_for_opt/`
2. 将 `tb_<module>.sv`、`simv`/编译产物、`vvp` 运行日志/输出等全部写入该子文件夹
3. 禁止覆盖或复用其它阶段可能生成的同类文件，避免与后续/并行流程冲突

### Step 7: 仿真失败修复方向

通常 mismatch 来自以下方面（优先级从高到低）：
1. 端口位宽/方向在优化时出现偏差
2. always 语义不一致（reset 条件、enable 条件、阻塞/非阻塞赋值、case/default 完整性）
3. 组合逻辑漏赋值或优先级变化导致 X 泄漏/行为差异

修复后回到 Step 6 重新验证。

### Step 8: 重新检查（快速兜底）

在重新跑 Step 6 之前，至少确认：
- `<optimized_file>` 语法检查通过
- tb 编译不会因位宽/端口错误而失败

### Step 9: 输出给 merge 的“可用 workspace”
为了让 `agent_merge.py` 能正确识别：
- 原始 RTL（通常仍位于 `optimization_<uuid>/` 根目录）
- parts 目录（通常为 `optimization_<uuid>/partition_opt/`）

请将下面目录作为 downstream 输入：
1. `workspace/optimization_<uuid>/`（整个优化会话目录）

这样 `verilog-merge` 的 LLM 才能在 workspace 内自行发现 `original_file` 与 parts_dir。

## 输出格式
你最终需要给出：
1. `optimized_workspace_dir`：`workspace/optimization_<uuid>/`
2. `partition_opt_dir`：`workspace/optimization_<uuid>/partition_opt/`
3. `yosys_opt_record_dir`：`workspace/optimization_<uuid>/yosys_opt_record/<timestamp>/`
4. Verible 检查结论：
   - syntax：pass/fail
   - lint：pass/fail + warnings 摘要（如有）

## 故障排查
- Agent 运行失败（例如 API 限流/429）：等待一段时间后重试；本项目 `api.py` 已对 429 做最多 5 次重试
- Verible syntax 失败：先修语法错误，修好后再对同一批 `partition_opt/u_block_*.v` 复检
- Verible lint 告警很多：先筛掉与行为强相关的（default 缺失/赋值覆盖），其余延后到仿真验证阶段处理

## 协作关系
```json
{
  "workflow": {
    "upstream_skill": {
      "name": "verilog-partition",
      "role": "生成 partition workspace",
      "output": {
        "directory": "workspace/partition_<uuid>/",
        "description": "原始 RTL + 拆分后的子模块 parts（通常位于 output/）"
      }
    },
    "current_skill": {
      "name": "verilog-optimization",
      "role": "partition 后优化 parts 并兜底 syntax/lint 与等价性确认",
      "input": "partition_workspace_dir",
      "tasks": [
        "调用 agent_optimization.py",
        "优先读取 partition_opt/result.md",
        "对 partition_opt/u_block_*.v 做 Verible syntax + lint",
        "若等价性检查为 warning：必须对每个子模块走 testbench-generator + iverilog/vvp 最终确认"
      ],
      "output": {
        "optimized_workspace_dir": "workspace/optimization_<uuid>/",
        "partition_opt_dir": "workspace/optimization_<uuid>/partition_opt/",
        "yosys_opt_record_dir": "workspace/optimization_<uuid>/yosys_opt_record/<timestamp>/"
      }
    },
    "downstream_skill": {
      "name": "verilog-merge",
      "role": "把优化后的 parts 合并回完整 RTL",
      "input": "workspace/optimization_<uuid>/",
      "description": "verilog-merge 只需要在同一 workspace 内自行识别 original_file 与 parts_dir"
    }
  }
}
```

## 使用示例
最简单的使用方式是在聊天框输入：
`使用verilog-optimization优化path/to/workspace/partition_c575b2a6`

对应的终端等价操作（可选）：
```bash
source /home/openclawer/anaconda3/etc/profile.d/conda.sh
conda activate /home/openclawer/Projects/Partition/.venv
cd /home/openclawer/Projects/Partition
python agent_optimization.py workspace/partition_c575b2a6
```

## 注意事项
1. 你必须优先读 `partition_opt/result.md`，不要被 agent 前面的大量 MARO 提示文本干扰导致跳过 tb/等价性最终确认。
2. syntax 必须先过，再谈 lint；仿真验证必须在 tb 编译通过后进行。
3. tb 与仿真产物要隔离到 `iverilog_check_for_opt/`，避免与 merge/其它阶段文件冲突。

