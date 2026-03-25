# Testbench-Generator 示例代码

本文档包含 SKILL.md 中所有的使用示例。

---

## 示例1：组合逻辑（译码器）

**DUT**: 3-to-8 译码器

**生成的Testbench**（关键部分）：

```systemverilog
// DUT实例化
decoder3_8 u_dut (
    .in  (in),
    .en  (en),
    .out (out)
);

// Reference Model（组合逻辑）
always_comb begin
    if (!en)
        ref_out = 8'b0;
    else begin
        case (in)
            3'b000: ref_out = 8'b00000001;
            3'b001: ref_out = 8'b00000010;
            ...
        endcase
    end
end

// 检查窗口：组合逻辑在en有效时立即有效
assign check_valid = en;

// 自动比对：在negedge clk检查（输入稳定后）
always @(negedge clk) begin
    if (rst_n && check_valid) begin
        if (out !== ref_out)
            $display("[ERROR] Time=%0t: Mismatch! DUT=%h, REF=%h", 
                     $time, out, ref_out);
    end
end

// 激励
initial begin
    @(posedge rst_n);
    @(posedge clk);
    
    // 测试用例1
    en = 1; in = 3'b000; @(posedge clk);
    // 检查在negedge自动进行
    
    // 测试用例2
    en = 1; in = 3'b101; @(posedge clk);
    
    done = 1;
end
```

---

## 示例2：时序逻辑（带load的寄存器）

**DUT**: 8-bit 寄存器

```systemverilog
// DUT实例化
reg8 u_dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .load     (load),
    .data_in  (data_in),
    .data_out (data_out)
);

// Reference Model（与DUT完全相同的时序）
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ref_data_out <= 8'd0;
    else if (load)
        ref_data_out <= data_in;  // 与DUT同一周期更新
end

// 检查窗口：load后的下一个周期
always_ff @(posedge clk) begin
    check_valid <= load;  // 延迟1周期
end

// 自动比对：在posedge clk检查（DUT和Ref都已更新）
always_ff @(posedge clk) begin
    if (rst_n && check_valid) begin
        if (data_out !== ref_data_out)
            $display("[ERROR] Mismatch! DUT=%h, REF=%h", 
                     data_out, ref_data_out);
    end
end

// 激励
initial begin
    @(posedge rst_n);
    @(posedge clk);
    
    // load = 1, DUT会在下一个posedge更新
    load = 1; data_in = 8'hAB; @(posedge clk);
    // 检查在下一个posedge自动进行（此时check_valid=1）
    
    // load = 0, 保持
    load = 0; @(posedge clk);
    
    done = 1;
end
```

---

## 示例3：流水线（3级流水线乘法器）

**DUT**: 3级流水线乘法器

```systemverilog
// DUT实例化
mult_pipeline u_dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (valid_in),
    .a         (a),
    .b         (b),
    .product   (product),
    .valid_out (valid_out)
);

// Reference Model（3级流水线，与DUT相同）
logic [15:0] ref_pipe [3];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ref_pipe[0] <= 0;
        ref_pipe[1] <= 0;
        ref_pipe[2] <= 0;
    end else if (valid_in) begin
        ref_pipe[0] <= a * b;       // 第1级
        ref_pipe[1] <= ref_pipe[0];  // 第2级
        ref_pipe[2] <= ref_pipe[1];  // 第3级
    end
end

assign ref_product = ref_pipe[2];

// 检查窗口：使用移位寄存器追踪3个周期
logic [2:0] check_delay;
always_ff @(posedge clk) begin
    if (rst_n && valid_in)
        check_delay <= 3'b001;
    else
        check_delay <= {check_delay[1:0], 1'b0};
end
assign check_valid = check_delay[2];  // 3周期后有效

// 自动比对
always_ff @(posedge clk) begin
    if (rst_n && check_valid) begin
        if (product !== ref_product)
            $display("[ERROR] Pipeline mismatch!");
    end
end

// 激励
initial begin
    @(posedge rst_n);
    @(posedge clk);
    
    // 输入数据（3周期后检查结果）
    valid_in = 1; a = 8'd5; b = 8'd10; @(posedge clk);
    valid_in = 1; a = 8'd3; b = 8'd7;  @(posedge clk);
    valid_in = 0; @(posedge clk);
    
    // 等待结果完成
    repeat(3) @(posedge clk);
    
    done = 1;
end
```
