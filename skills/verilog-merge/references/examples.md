# verilog-partition 示例

本文档展示 verilog-partition skill 的使用示例。

---

## 示例1：拆分 traffic.v

### 执行命令

```bash
source /home/openclawer/anaconda3/etc/profile.d/conda.sh
conda activate /home/openclawer/Projects/Partition/.venv
python agent_partition.py data/traffic.v
```

### 执行结果

```
============================================================
Partition Agent
============================================================
Workspace: /home/openclawer/Projects/Partition/workspace/partition_f0a9199f
Source: traffic.v

--- Turn 1 ---
  [step] run "ls"
  [step] read file traffic.v (full)
  [step] run_heuristic_partition source=traffic.v output_dir=output
  [step] request_partition_consistency_review original_file=traffic.v output_dir=output
  -> review instructions for 3 parts (see review_instructions in result)
  [step] edit_file output/u_block_1.v
  -> Replaced lines 4-6 in u_block_1.v
  [step] edit_file output/u_block_2.v
  -> Replaced lines 6-6 in u_block_2.v
  [step] edit_file output/u_block_3.v
  -> Replaced lines 4-10 in u_block_3.v
  [step] check_verilog_syntax output/u_block_1.v
  -> syntax ok
  [step] check_verilog_syntax output/u_block_2.v
  -> syntax ok
  [step] check_verilog_syntax output/u_block_3.v
  -> syntax ok
  [step] check_verilog_lint output/u_block_1.v
  -> lint ok
  [step] check_verilog_lint output/u_block_2.v
  -> lint ok (1 warnings)
  [step] check_verilog_lint output/u_block_3.v
  -> lint ok

[Agent finished (no more tool calls)]
```

### 汇报

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
- ✅ 拆分一致性：所有类型、位宽、端口、always 块语义均与原始文件一致
```

---

## 示例2：拆分其他文件

```bash
# 拆分 uart.v
python agent_partition.py data/uart.v

# 拆分 fsm.v
python agent_partition.py data/fsm.v
```

---

## 示例3：手动修复（如有问题）

如果 Agent 汇报语法检查失败，需要手动修复：

```bash
# 读取原始文件和出错的子模块
read_file data/traffic.v
read_file output/u_block_1.v

# 修正后重新检查
check_verilog_syntax output/u_block_1.v
check_verilog_lint output/u_block_1.v
```
