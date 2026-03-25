---
name: verilog-partition
description: 利用LLM Agent自动对Verilog RTL设计进行拆分，按always块生成多个子模块
---

## 角色定义

你是一个 Verilog RTL 拆分任务的操作者，负责：
1. 激活环境并调用 Partition Agent
2. 监控执行结果
3. 如有问题，手动修复拆分后的代码

## 输入

```json
{
  "inputs": {
    "verilog_file": {
      "type": "string",
      "description": "需要拆分的 Verilog 文件路径，如 'data/traffic.v'"
    }
  }
}
```

## 执行步骤

### Step 1: 调用 Partition Agent

直接运行 `agent_partition <verilog_file>`：

```bash
agent_partition <verilog_file>
```

例如：

```bash
agent_partition data/traffic.v
```

### Step 2: 检查执行结果

Agent 会自动完成以下步骤：

1. **启发式拆分** - 按 always 块将模块拆分为子模块
2. **一致性审查** - 对照原始文件检查类型、位宽、端口等
3. **语法检查** - 使用 Verible 检查语法
4. **Lint 检查** - 使用 Verible 检查风格

**成功输出示例**：

```
Partition Agent
==============
Workspace: /home/node/.openclaw/workspace/partition_xxx
Source: traffic.v

--- Turn 1 ---
  [step] run "ls"
  [step] read file traffic.v line 1-100
  [step] run_heuristic_partition source=traffic.v output_dir=output
  [step] request_partition_consistency_review original_file=traffic.v output_dir=output
  ...
  [step] check_verilog_syntax output/u_block_1.v
  [step] check_verilog_syntax output/u_block_2.v
  [step] check_verilog_syntax output/u_block_3.v
  [step] check_verilog_lint output/u_block_1.v
  ...
```

### Step 3: 查看结果汇报

Agent 会输出最终汇报，包含：
- 拆分出的子模块数量
- 审查修正内容（如有）
- 语法/Lint 检查结果

### Step 4: 确认文件位置

拆分结果位于：

```
workspace/partition_<uuid>/
├── traffic.v              # 源文件副本
└── output/
    ├── u_block_1.v       # 子模块1
    ├── u_block_2.v       # 子模块2
    └── u_block_N.v      # 子模块N
```

**汇报格式**：

```
## 拆分完成总结

**源文件**: traffic.v → **N个子模块** (位于 output/)

| 子模块 | 功能 |
|--------|------|
| u_block_1 | ... |
| u_block_2 | ... |

**检查结果**:
- ✅ 语法检查：N/N 通过
- ✅ Lint 检查：N/N 通过
结果位于 `根据agent的输出，把这里替换为实际目录` 目录。
```

### Step 5: 手动修复（如有问题）

如果 Agent 汇报有问题，需要手动修复：

1. **读取原始文件和子模块**：
```bash
read_file traffic.v
read_file output/u_block_1.v
```

2. **使用 edit_file 修正问题**

3. **重新检查**：
```bash
check_verilog_syntax output/u_block_1.v
check_verilog_lint output/u_block_1.v
```

## 输出格式

### 主要输出：拆分后的子模块

- **位置**: `workspace/partition_<uuid>/output/`
- **文件**: `u_block_1.v`, `u_block_2.v`, ...

### 汇报内容

```
## 拆分完成总结

**源文件**: <source> → <N>个子模块 (位于 output/)

**审查修正内容**（如有）:
- u_block_X: <问题描述> → <修正内容>

**检查结果**:
- ✅ 语法检查：N/N 通过
- ✅ Lint 检查：N/N 通过
结果位于 `根据agent的输出，把这里替换为实际目录` 目录。
```

## 使用示例

### 示例1：traffic.v 拆分

```bash
# 运行拆分
agent_partition data/traffic.v
```

**输出**：

```
## 拆分完成总结

**源文件**: traffic.v → 3个子模块 (位于 output/)

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
结果位于 workspace/partition_12345678/output/ 目录。
```

### 示例2：其他文件

```bash
agent_partition data/uart.v
agent_partition data/fsm.v
```

## 注意事项

### 1. 大多数情况无需手动干预

`agent_partition.py` 内部已经封装了完整流程，包括：
- 一致性审查
- 语法检查
- Lint 检查

只需运行命令即可。

### 2. 何时需要手动修复

- 一致性审查发现的问题 Agent 无法自动修正
- 语法检查仍然失败
- 拆分逻辑明显错误

### 3. 查看 workspace

如需查看详情：

```bash
# 查看 workspace 目录
ls workspace/

# 查看具体的拆分结果
ls workspace/partition_<uuid>/output/
```

## 协作关系

```json
{
  "workflow": {
    "current_skill": {
      "name": "verilog-partition",
      "role": "调用 Partition Agent 自动拆分 Verilog 模块",
      "input": "verilog_file_path",
      "tasks": [
        "激活虚拟环境",
        "调用 agent_partition.py",
        "监控执行结果",
        "手动修复（如有问题）"
      ],
      "output": {
        "directory": "workspace/partition_<uuid>/output/",
        "files": ["u_block_1.v", "u_block_2.v", "..."],
        "description": "拆分后的子模块"
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
| 拆分数量不对 | 手动检查 always 块归属 |
