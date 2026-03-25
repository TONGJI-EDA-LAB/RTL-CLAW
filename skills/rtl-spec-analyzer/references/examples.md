# RTL-Spec-Analyzer 示例代码

本文档包含 SKILL.md 中所有的使用示例。

---

## 示例1：简单ALU

### 输入RTL

```verilog
module alu (
    input        clk,
    input        rst_n,
    input  [1:0] op,
    input  [7:0] a,
    input  [7:0] b,
    output reg [7:0] result
);
```

### 输入Spec片段

```
3.1 加法运算
当操作码op为2'b00时，ALU执行加法运算：result = a + b
输入a和b为8位无符号数，运算结果在下一个时钟上升沿输出到result
```

### 分析输出

```json
{
  "feature_mappings": [
    {
      "feature_id": "F001",
      "name": "加法运算",
      "pin_assignments": [
        {"pin_name": "op", "role": "control", "assignment": "2'b00", "note": "Spec明确op=00为加法"},
        {"pin_name": "a", "role": "data_input", "assignment": "测试数据", "note": "加法操作数1"},
        {"pin_name": "b", "role": "data_input", "assignment": "测试数据", "note": "加法操作数2"}
      ],
      "stimulus_strategy": "设置op=00，给a和b赋不同测试值（如0x05, 0x03, 0xFF等边界值）",
      "expected_outputs": [
        {"pin_name": "result", "expected_value": "a + b", "check_timing": "下一个时钟上升沿后"}
      ]
    }
  ]
}
```

---

## 示例2：带控制信号的模块

### 输入RTL

```verilog
module data_processor (
    input         clk,
    input         rst_n,
    input         start,
    input  [15:0] data_in,
    output reg    done,
    output reg [31:0] data_out
);
```

### 输入Spec片段

```
4.2 数据处理流程
用户将输入数据置于data_in端口，拉高start信号启动处理。
处理完成后，done信号拉高，处理结果从data_out输出。
处理需要3个时钟周期。
```

### 分析输出

```json
{
  "feature_mappings": [
    {
      "feature_id": "F005",
      "name": "数据处理流程",
      "pin_assignments": [
        {"pin_name": "data_in", "role": "data_input", "assignment": "待处理数据", "note": "Spec明确data_in为输入数据"},
        {"pin_name": "start", "role": "control", "assignment": "先拉高(1)一个周期，再拉低(0)", "note": "start是触发信号，需脉冲触发"}
      ],
      "stimulus_strategy": "设置data_in值 → 拉高start一个周期 → 拉低start → 等待3个周期",
      "expected_outputs": [
        {"pin_name": "done", "expected_value": "1'b1", "check_timing": "start拉高后3个时钟周期"},
        {"pin_name": "data_out", "expected_value": "处理后的结果", "check_timing": "done拉高后"}
      ]
    }
  ]
}
```

---

## 示例3：Signal到Pin的映射分析

### 场景描述

Spec描述："当reset信号拉低时，所有寄存器清零，输出端口data_out归零"

### 分析结果

```json
{
  "feature_id": "F003",
  "name": "复位清零功能",
  "pin_assignments": [
    {
      "pin_name": "rst_n",
      "role": "control",
      "assignment": "先拉低(0)保持若干周期，再拉高(1)",
      "note": "Spec明确提到reset信号控制复位"
    }
  ],
  "expected_outputs": [
    {
      "pin_name": "data_out",
      "expected_value": "8'h00",
      "check_timing": "rst_n拉高后1个时钟周期"
    }
  ]
}
```
