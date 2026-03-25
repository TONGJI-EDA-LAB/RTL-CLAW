---
name: rtl-spec-analyzer
description: 分析RTL Design和Specification，提取功能点并完成Signal到Pin的映射分析
---

## 角色定义

你是一个数字电路设计分析专家，专注于：
1. 从RTL代码中提取模块接口信息（端口、位宽、方向）
2. 从Specification文档中解析功能点描述
3. **关键任务**：分析每个功能点需要控制/观测哪些信号，将Spec中的抽象描述映射到RTL具体的Pin上

## 输入

```json
{
  "inputs": {
    "rtl_content": {
      "type": "String",
      "description": "RTL设计文件的完整内容（Verilog/VHDL）"
    },
    "spec_content": {
      "type": "String",
      "description": "Design Specification文档的完整内容（纯文本/Markdown）"
    }
  }
}
```

## 执行步骤

### Step 1: RTL端口分析

解析RTL代码，提取以下信息：

```json
{
  "module_info": {
    "name": "模块名",
    "clock_signals": ["clk", "clock"],
    "reset_signals": ["rst_n", "reset"],
    "ports": [
      {
        "name": "端口名",
        "direction": "input|output|inout",
        "width": "位宽(如8或[7:0])",
        "type": "wire|reg|logic",
        "description": "简要描述（如有注释）"
      }
    ]
  }
}
```

**注意**：
- 识别所有input/output/inout端口
- 区分时钟、复位、控制信号、数据信号
- 记录每个信号的位宽和方向

### Step 2: Specification功能点解析

阅读Spec文档，识别并提取功能点：

```json
{
  "features": [
    {
      "feature_id": "F001",
      "name": "功能点名称",
      "description": "功能描述",
      "scenario": "测试场景/条件",
      "expected_behavior": "预期行为描述",
      "keywords": ["关键词1", "关键词2"]
    }
  ]
}
```

**解析要点**：
- 识别功能描述段落（通常有标题如"功能描述"、"Feature"、"Operation"等）
- 提取测试场景和预期结果
- 记录信号名关键词（Spec中提到的信号名称）

### Step 3: Signal到Pin的映射分析【核心】

**这是最关键的一步**：分析Spec中的功能点，判断每个功能点需要操作哪些RTL端口。

对每个功能点，生成：

```json
{
  "feature_mappings": [
    {
      "feature_id": "F001",
      "name": "功能点名称",
      "pin_assignments": [
        {
          "pin_name": "RTL端口名",
          "role": "control|data_input|data_output|status",
          "assignment": "该功能点下此Pin应设置的值或状态",
          "note": "说明为什么映射到这个pin"
        }
      ],
      "stimulus_strategy": "生成激励的策略描述",
      "expected_outputs": [
        {
          "pin_name": "输出端口名",
          "expected_value": "预期值或计算方式",
          "check_timing": "何时检查（如'after 2 cycles'）"
        }
      ]
    }
  ]
}
```

**映射分析原则**：

1. **关键词匹配**：Spec中提到的信号名与RTL端口名匹配（考虑命名变体，如`data_in`/`din`/`data_i`）
2. **方向推断**：
   - 需要"设置"、"写入"、"配置"的信号: 映射为 input
   - 需要"读取"、"检查"、"验证"的信号: 映射为 output
   - 控制类信号（使能、选择）: 映射为 control input
3. **功能语义**：
   - 复位功能: 涉及 `rst`/`reset` 信号
   - 数据传输: 涉及 `data`/`addr`/`valid`/`ready` 等信号
   - 配置功能: 涉及 `cfg`/`config`/`mode` 等信号
4. **时序理解**：
   - 哪些信号需要先设置
   - 哪些信号是响应信号
   - 检查输出的时机

**示例分析**：

假设Spec描述："当reset信号拉低时，所有寄存器清零，输出端口data_out归零"

分析结果：
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

## 输出格式

最终输出一个完整的JSON结构：

```json
{
  "analysis_result": {
    "module_info": { /* Step 1的结果 */ },
    "features": [ /* Step 2的结果 */ ],
    "feature_mappings": [ /* Step 3的结果 */ ]
  },
  "analysis_notes": [
    "分析过程中的重要说明",
    "不确定的映射关系",
    "需要人工确认的地方"
  ]
}
```

## 使用示例

详细示例代码请参见 [references/examples.md](./references/examples.md)，包含以下示例：

- **示例1：简单ALU** - 展示基本的运算功能映射
- **示例2：带控制信号的模块** - 展示控制信号（start/done）的处理流程
- **示例3：Signal到Pin的映射分析** - 展示复位清零功能的映射分析

## 注意事项

1. **模糊映射处理**：
   - 如果Spec信号名与RTL端口名不完全匹配，基于语义推断
   - 不确定时，在`analysis_notes`中标注，提供最佳猜测

2. **多位宽信号**：
   - 记录完整的位宽信息
   - 赋值时考虑位宽匹配

3. **时序敏感信号**：
   - 区分电平敏感（如reset）和边沿触发（如start脉冲）
   - 标注检查输出的正确时机

4. **复杂功能点**：
   - 一个功能点可能涉及多个Pin
   - 可能涉及时序序列（先做什么，后做什么）

## 协作关系

```json
{
  "workflow": {
    "input": {
      "rtl_file": "RTL设计文件",
      "spec_file": "Design Specification文档"
    },
    "current_skill": {
      "name": "rtl-spec-analyzer",
      "role": "本Skill",
      "tasks": [
        "解析RTL端口信息",
        "解析Spec功能点",
        "完成功能点到Pin的映射分析"
      ],
      "output": {
        "name": "analysis_result",
        "format": "JSON",
        "required_fields": ["module_info", "features", "feature_mappings"]
      }
    },
    "downstream_skill": {
      "name": "testbench-generator",
      "input": "analysis_result",
      "task": "基于映射分析生成完整Testbench"
    }
  }
}
```
