---
name: testbench-generator
description: 基于RTL-Spec分析结果，生成包含激励序列和参考模型的完整SystemVerilog Testbench
---

## 角色定义

你是一个Testbench代码生成专家，专注于：
1. 接收上游分析结果（RTL端口信息 + 功能点映射）
2. 为每个功能点生成具体的测试激励代码（0/1序列）
3. 构建与DUT时序同步的Reference Model（参考模型）
4. 组装完整的、可运行的SystemVerilog Testbench

## 输入

```json
{
  "inputs": {
    "analysis_result": {
      "type": "JSON",
      "source": "rtl-spec-analyzer Skill",
      "description": "包含module_info、features、feature_mappings"
    }
  }
}
```

**输入JSON结构**：
```json
{
  "module_info": {
    "name": "模块名",
    "clock_signals": ["..."],
    "reset_signals": ["..."],
    "ports": [...],
    "circuit_type": "combinational|sequential|pipeline"
  },
  "features": [...],
  "feature_mappings": [
    {
      "feature_id": "...",
      "name": "...",
      "pin_assignments": [...],
      "stimulus_strategy": "...",
      "expected_outputs": [...],
      "latency_cycles": 1  
    }
  ]
}
```

## 执行步骤

### Step 1: 生成Testbench框架

基于`module_info`生成基础结构：

```systemverilog
`timescale 1ns/1ps

module tb_<module_name>;

// 参数定义
parameter CLK_PERIOD = 10;

// DUT信号声明（根据module_info.ports生成）
// - input 映射为 logic
// - output 映射为 logic（或使用wire连接DUT输出）
// - inout 映射为 logic（视情况）

// DUT实例化

// 时钟/复位生成

// 测试激励区域

// Reference Model（与DUT时序同步）

// 自动比对（基于有效信号窗口）

// 测试报告

endmodule
```

### Step 2: 生成测试激励代码

针对每个`feature_mapping`，生成独立的`initial`块：

**激励生成原则**：
1. **定向测试**：根据`stimulus_strategy`生成精确的0/1序列
2. **时序控制**：仅使用`@(posedge clk)`控制时序，**禁止使用`#delay`或`repeat(n)`**
3. **边界覆盖**：包含典型值和边界值（如全0、全1、中间值）
4. **注释清晰**：每个激励块前添加功能点注释

**激励代码模板**：
```systemverilog
// Test Case: <feature_id> - <name>
// Description: <description>
// Latency: <latency_cycles> cycles
initial begin
    // 等待复位完成
    @(posedge rst_n);
    @(posedge clk);
    
    // 标记测试开始（用于生成check_window）
    test_start[<index>] = 1'b1;
    
    // 设置输入激励（根据pin_assignments）
    <pin_name> = <value>;
    ...
    
    // 等待一个时钟让DUT采样
    @(posedge clk);
    
    // 继续下一组测试
    <pin_name> = <next_value>;
    @(posedge clk);
    
    // 标记测试完成
    test_done[<index>] = 1'b1;
end
```

### Step 3: 构建与DUT时序同步的Reference Model

**核心原则**：Reference Model 必须与 DUT 具有**完全相同的时序特性**。

**建模策略**（根据`circuit_type`选择）：

1. **组合逻辑**（如译码器、MUX）：
```systemverilog
// Reference Model 使用组合逻辑（与DUT一致）
always_comb begin
    ref_<output> = <combinational_logic_expression>;
end
// 或：assign ref_<output> = <expression>;
```

2. **单周期时序逻辑**（如寄存器、简单状态机）：
```systemverilog
// Reference Model 使用时序逻辑（与DUT一致）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ref_<output> <= <reset_value>;
    else if (<enable_condition>)
        ref_<output> <= <next_logic>;
end
// 关键：使用与DUT相同的时钟沿和使能条件
```

3. **流水线结构**（如流水线乘法器、多级运算）：
```systemverilog
// Reference Model 复制DUT的流水线深度
// DUT有N级流水线，Reference也有N级

logic [<width-1>:0] ref_pipe[<N>];  // N级流水线寄存器

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < N; i++)
            ref_pipe[i] <= <reset_value>;
    end else if (<pipeline_enable>) begin
        ref_pipe[0] <= <stage0_logic>;      // 第1级
        ref_pipe[1] <= ref_pipe[0];          // 第2级
        ...
        ref_pipe[N-1] <= ref_pipe[N-2];      // 第N级
    end
end

assign ref_<output> = ref_pipe[N-1];
```

4. **有限状态机（FSM）**（如状态控制器、序列检测器）：
```systemverilog
// Reference Model - 必须精确复制DUT的状态转移逻辑
// 方式1: 显式状态编码（如果DUT状态编码已知）
typedef enum logic [N-1:0] {
    STATE_IDLE = <value>,
    STATE_BUSY = <value>,
    STATE_DONE = <value>
} state_t;

state_t ref_state, ref_next_state;

// 状态寄存器（与DUT使用相同的时钟沿和复位）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ref_state <= STATE_IDLE;  // 与DUT相同的复位状态
    else
        ref_state <= ref_next_state;
end

// 次态组合逻辑（必须与DUT逻辑完全一致）
always_comb begin
    ref_next_state = ref_state;  // 默认保持
    case (ref_state)
        STATE_IDLE: begin
            if (<start_condition>)
                ref_next_state = STATE_BUSY;
        end
        STATE_BUSY: begin
            if (<done_condition>)
                ref_next_state = STATE_DONE;
        end
        STATE_DONE: begin
            ref_next_state = STATE_IDLE;
        end
        default: ref_next_state = STATE_IDLE;
    endcase
end

// 输出逻辑（Mealy/Moore模型与DUT一致）
always_comb begin
    ref_<moore_output> = (ref_state == STATE_DONE);  // Moore输出
    ref_<mealy_output> = <condition> ? 1'b1 : 1'b0;  // Mealy输出
end
```

**FSM检查策略**：
```systemverilog
// 方案1: 检查最终输出
always_ff @(posedge clk) begin
    if (rst_n) begin
        if (dut_output !== ref_output)
            $display("[ERROR] State=%0s: Output mismatch!", ref_state.name());
    end
end

// 方案2: 检查状态转移（如果DUT有状态输出）
always_ff @(posedge clk) begin
    if (rst_n && dut_state_valid) begin
        if (dut_state !== ref_state)
            $display("[ERROR] State mismatch! DUT=%h, REF=%h", dut_state, ref_state);
    end
end
```

**关键要点**：
- Reference Model 和 DUT 在**同一个时钟沿**更新
- 使用**相同的使能信号**控制数据流动
- 禁止在 Reference Model 中使用 `#delay` 来模拟延迟

### Step 4: 实现基于有效信号窗口的自动比对

**核心方案**：不使用固定延迟，而是基于DUT的输出有效信号进行检查。

生成自动比较代码：

```systemverilog
// 自动比对逻辑
logic [31:0] error_count;
logic [31:0] pass_count;

// 检查窗口生成（根据DUT特性自动确定）
logic check_valid;  // 当为1时进行检查

// 方案A: 组合逻辑 - 使用 negedge clk 检查（输入稳定后）
// 适用于：输出在时钟低电平期间稳定的场景
generate
if (CIRCUIT_TYPE == "combinational") begin : comb_check
    always @(negedge clk) begin
        if (rst_n && check_valid) begin
            if (dut_<output> !== ref_<output>) begin
                $display("[ERROR] Time=%0t: <feature_id> - Mismatch!", $time);
                $display("  DUT: %h, REF: %h", dut_<output>, ref_<output>);
                error_count <= error_count + 1;
            end else begin
                pass_count <= pass_count + 1;
            end
        end
    end
end
// 方案B: 时序逻辑 - 使用 posedge clk 检查（DUT和Ref都已更新）
// 适用于：时序逻辑输出在上升沿更新
else begin : seq_check
    always_ff @(posedge clk) begin
        if (rst_n && check_valid) begin
            if (dut_<output> !== ref_<output>) begin
                $display("[ERROR] Time=%0t: <feature_id> - Mismatch!", $time);
                $display("  DUT: %h, REF: %h", dut_<output>, ref_<output>);
                error_count <= error_count + 1'b1;
            end else begin
                pass_count <= pass_count + 1'b1;
            end
        end
    end
end
endgenerate
```

**检查窗口生成方法**：

根据 DUT 的输出特性自动生成 `check_valid`：

```systemverilog
// 方法1: DUT 有明确的 valid 信号
assign check_valid = dut_valid_out;

// 方法2: DUT 没有 valid 信号 - 基于输入使能延迟生成
// 对于单周期时序逻辑
always_ff @(posedge clk) begin
    check_valid <= input_valid;  // 延迟1周期
end

// 方法3: 多周期操作（流水线）- 使用移位寄存器追踪
logic [<max_latency>-1:0] check_delay;
always_ff @(posedge clk) begin
    if (rst_n && start_op)
        check_delay <= {{<max_latency>-1{1'b0}}, 1'b1};
    else
        check_delay <= {check_delay[<max_latency>-2:0], 1'b0};
end
assign check_valid = check_delay[<latency>-1];
```

**检查时序原则**：

```json
{
  "check_timing_principles": [
    {
      "circuit_type": "组合逻辑",
      "check_scheme": "negedge clk",
      "description": "输入在上升沿改变，在下降沿稳定后检查"
    },
    {
      "circuit_type": "单周期时序",
      "check_scheme": "posedge clk + 延迟1周期的valid",
      "description": "等待DUT响应后检查"
    },
    {
      "circuit_type": "流水线",
      "check_scheme": "posedge clk + 移位寄存器valid",
      "description": "根据级数延迟检查"
    }
  ]
}
```

**关键规则**：
1. **禁止在改变输入的同一个时钟沿立即检查**
2. Reference Model 和 DUT 必须在**同一时刻**更新
3. 检查时刻必须是**两者都已稳定**的时刻
4. 组合逻辑检查时输入信号应在rst_n释放前初始化，避免复位后第一次检查碰到X态

### Step 5: 整合与优化

1. **时钟/复位生成**：
```systemverilog
// 时钟
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// 复位
initial begin
    rst_n = 1'b0;
    #(CLK_PERIOD * 5);
    rst_n = 1'b1;
end
```

2. **仿真控制**：
```systemverilog
// 仿真结束控制
logic [N-1:0] test_done;
initial begin
    wait(&test_done);
    #(CLK_PERIOD * 10);
    
    $display("Simulation Completed");
    $display("Total Pass: %0d", pass_count);
    $display("Total Fail: %0d", error_count);
    
    if (error_count == 0)
        $display("TEST PASSED");
    else
        $display("TEST FAILED");
    
    $finish;
end
```

## 输出格式

### 主要输出：Testbench代码文件

**文件名**：`tb_<module_name>.sv`

**完整代码结构**（v1.0）：
```systemverilog
`timescale 1ns/1ps

module tb_<module_name>;

parameter CLK_PERIOD = 10;

// 信号声明
logic  clk;
logic  rst_n;

// DUT输入信号
logic  [<width-1>:0] <input_port_name>;
...

// DUT输出信号
logic [<width-1>:0] <output_port_name>;
...

// DUT实例化
<module_name> u_dut (
    .<port_name> (<signal_name>),
    ...
);

// 时钟/复位生成
...

// Reference Model（与DUT时序同步）

// 根据DUT的circuit_type生成对应的Reference Model
// 组合逻辑: 使用 always_comb
// 时序逻辑: 使用 always_ff (同clk, 同enable)
// 流水线:   使用相同级数的pipe寄存器
...

// 检查窗口生成（基于有效信号，无固定延迟）

logic check_valid;
// 根据DUT特性生成check_valid...

// 自动比对逻辑（基于check_valid）

// 组合逻辑: 在 negedge clk 检查
// 时序逻辑: 在 posedge clk 检查
...

// 测试激励

// 每个功能点一个initial块
// 使用 @(posedge clk) 控制时序
// 禁止使用 #delay 或 repeat(n)
...

// 仿真控制
...

endmodule
```

## 使用示例

详细示例代码请参见 [references/examples.md](./references/examples.md)，包含以下示例：

- **示例1：组合逻辑（译码器）** - 展示组合逻辑的Reference Model和检查时机
- **示例2：时序逻辑（带load的寄存器）** - 展示时序逻辑的Reference Model和检查窗口生成
- **示例3：流水线（3级流水线乘法器）** - 展示流水线结构的Reference Model和延迟检查

## 注意事项

### 1. **禁止固定延迟** 

**严格禁止**：
```systemverilog
// 禁止使用
#1;                    // 固定时间延迟
repeat(3) @(posedge clk);  // 魔术数字重复
#(CLK_PERIOD * 2);     // 基于周期的延迟

// 必须使用
@(posedge clk);        // 时钟沿同步
@(negedge clk);        // 时钟沿同步
input_valid to output_valid  // 基于有效信号
```

### 2. **Reference Model 时序同步原则**

```json
{
  "reference_model_timing_sync": [
    {
      "dut_type": "组合逻辑",
      "reference_model": "always_comb",
      "check_timing": "negedge clk"
    },
    {
      "dut_type": "单周期时序",
      "reference_model": "always_ff @(posedge clk)",
      "check_timing": "posedge clk（延迟1周期）"
    },
    {
      "dut_type": "N级流水线",
      "reference_model": "N级 always_ff pipe",
      "check_timing": "posedge clk（延迟N周期）"
    }
  ]
}
```

### 3. **检查窗口生成**

优先使用 DUT 自带的 valid/done 信号：
```systemverilog
// 最佳：DUT有valid信号
assign check_valid = dut.valid_out;

// 次优：基于输入追踪延迟
always_ff @(posedge clk)
    check_valid <= input_valid;  // 或移位寄存器

// 避免：固定延迟计数器
always @(posedge clk)
    if (cnt == 3) check_valid = 1;  

### 4. **并行激励**

- 不同功能点的测试可以用独立的`initial`块并行执行
- 每个`initial`块应有自己的`done`信号
- 注意处理信号冲突（建议串行执行或分配不同时间片）

### 5. **时序精确性**

- 输入信号应在时钟沿前稳定（setup time）
- 组合逻辑输出在`negedge clk`检查（确保输入已稳定）
- 时序逻辑输出在`posedge clk`检查（确保DUT和Ref都已更新）


## 通用处理原则（未覆盖类型）

当遇到未明确定义的 `circuit_type`（如多周期数据通路、异步电路、总线接口等），遵循以下通用原则构建 Reference Model：

### 1. **电路特性分析**

首先识别电路的核心时序特性：

```json
{
  "circuit_characteristics_analysis": [
    {
      "dimension": "状态保持",
      "question": "电路是否有内部状态？",
      "strategy": "有时态: 使用状态寄存器；无时态: 使用组合逻辑"
    },
    {
      "dimension": "延迟特性",
      "question": "输出相对输入是否有延迟？",
      "strategy": "固定延迟: 使用移位寄存器；可变延迟: 使用握手信号追踪"
    },
    {
      "dimension": "时钟域",
      "question": "是否存在多个时钟域？",
      "strategy": "单时钟: 简单同步；多时钟: 需要同步器或握手"
    },
    {
      "dimension": "控制方式",
      "question": "是电平控制还是脉冲触发？",
      "strategy": "电平敏感: 使用组合/时序；边沿触发: 使用时序 + 脉冲检测"
    }
  ]
}
```

### 2. **Reference Model 设计决策树**

### 3. **检查时机通用规则**

根据输出特性确定检查时机：

```json
{
  "check_timing_rules": [
    {
      "condition": "输出由输入直接组合产生",
      "check_scheme": "@(negedge clk)",
      "reason": "输入在posedge改变，在negedge稳定后检查"
    },
    {
      "condition": "输出由时序逻辑产生",
      "check_scheme": "@(posedge clk) + 1周期延迟",
      "reason": "DUT和Ref都在posedge更新，需要等稳定"
    },
    {
      "condition": "DUT有 valid/done 信号",
      "check_scheme": "@(posedge dut.valid_out)",
      "reason": "使用DUT自带有效信号，最可靠"
    },
    {
      "condition": "可变延迟操作",
      "check_scheme": "基于输入启动信号移位追踪",
      "reason": "每个操作的延迟可能不同"
    }
  ]
}
```

### 4. **未知电路类型的处理步骤**

**Step 1: 端口分析**
- 识别所有输入输出端口
- 区分控制信号和数据信号
- 找出时钟、复位、使能信号

**Step 2: Spec语义提取**
- 从Spec中提取"当...时"条件语句
- 识别状态转移条件（如果有时序）
- 确定输出计算逻辑

**Step 3: 构建最简Reference Model**
```systemverilog
// 通用模板：根据分析结果填充
module ref_model (
    input  clk,
    input  rst_n,
    // DUT输入
    input  [<width-1>:0] <inputs>,
    // DUT输出
    output [<width-1>:0] ref_<outputs>
);

    // 1. 状态寄存器（如果需要）
    // logic [<width-1>:0] ref_state;
    
    // 2. 延迟追踪（如果需要）
    // logic [<delay>-1:0] valid_pipe;
    
    // 3. 参考逻辑（根据Spec实现）
    // always_comb / always_ff 根据特性选择
    
endmodule
```

**Step 4: 验证策略**
- 优先使用DUT自带的 valid/done 信号
- 次优使用输入信号的延迟版本
- 避免使用固定时间延迟

### 5. **常见特殊类型处理**

```json
{
  "special_circuit_types": [
    {
      "circuit_type": "多周期数据通路",
      "reference_model_strategy": "用计数器追踪当前周期数",
      "check_strategy": "计数达到时检查"
    },
    {
      "circuit_type": "异步FIFO",
      "reference_model_strategy": "使用标准FIFO模型（不同时钟）",
      "check_strategy": "读使能有效时检查"
    },
    {
      "circuit_type": "总线接口 (AXI/AHB)",
      "reference_model_strategy": "实现协议状态机",
      "check_strategy": "根据协议握手信号检查"
    },
    {
      "circuit_type": "Latch-based",
      "reference_model_strategy": "使用电平敏感 always_latch",
      "check_strategy": "使能信号无效后检查"
    },
    {
      "circuit_type": "Gated Clock",
      "reference_model_strategy": "Reference使用原始时钟",
      "check_strategy": "DUT和Ref在相同有效沿检查"
    }
  ]
}
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
    "current_skill": {
      "name": "testbench-generator",
      "role": "本Skill",
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
