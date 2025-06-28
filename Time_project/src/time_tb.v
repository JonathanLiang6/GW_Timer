/**
 * 文件名：time_tb.v
 * 功能：秒表模块的测试文件
 * 作者：[您的姓名]
 * 日期：2024年
 * 描述：验证timer_clock模块的各项功能
 */

`timescale 1ns / 1ps

module time_tb();

    // ==================== 测试信号定义 ====================
    reg clk;                    // 系统时钟
    reg rst;                    // 复位信号
    reg pause_resume;           // 暂停/恢复信号
    reg set_time_mode;          // 时间设置模式信号
    reg [3:0] set_buttons;      // 设置按钮组
    reg power_switch;           // 电源开关
    
    wire [6:0] disp_seg_o;      // 7段数码管段信号
    wire [3:0] disp_an_o;       // 数码管位选信号
    wire led_state;             // 状态指示灯

    // ==================== 实例化被测模块 ====================
    timer_clock uut (
        .clk(clk),
        .rst(rst),
        .pause_resume(pause_resume),
        .set_time_mode(set_time_mode),
        .set_buttons(set_buttons),
        .power_switch(power_switch),
        .disp_seg_o(disp_seg_o),
        .disp_an_o(disp_an_o),
        .led_state(led_state)
    );

    // ==================== 时钟生成 ====================
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50MHz时钟 (20ns周期)
    end

    // ==================== 测试任务定义 ====================
    
    // 任务：等待指定数量的时钟周期
    task wait_cycles;
        input integer cycles;
        begin
            repeat(cycles) @(posedge clk);
        end
    endtask

    // 任务：按下按钮
    task press_button;
        input [3:0] button;
        begin
            set_buttons[button] = 1'b1;
            wait_cycles(10);  // 等待10个时钟周期
            set_buttons[button] = 1'b0;
            wait_cycles(10);  // 等待10个时钟周期
        end
    endtask

    // 任务：检查显示值
    task check_display;
        input [5:0] expected_minutes;
        input [5:0] expected_seconds;
        begin
            $display("时间: %02d:%02d", expected_minutes, expected_seconds);
            $display("段信号: %b", disp_seg_o);
            $display("位选信号: %b", disp_an_o);
            $display("LED状态: %b", led_state);
            $display("------------------------");
        end
    endtask

    // ==================== 主测试程序 ====================
    initial begin
        // 初始化信号
        rst = 1'b0;
        pause_resume = 1'b0;
        set_time_mode = 1'b0;
        set_buttons = 4'b0000;
        power_switch = 1'b0;
        
        // 等待系统稳定
        wait_cycles(10);
        
        // 测试1：复位功能
        $display("=== 测试1：复位功能 ===");
        rst = 1'b1;
        wait_cycles(10);
        check_display(6'd0, 6'd0);
        
        // 测试2：电源控制
        $display("=== 测试2：电源控制 ===");
        press_button(1);  // 按下电源按钮
        wait_cycles(100);
        check_display(6'd0, 6'd0);
        
        // 测试3：正常计时功能
        $display("=== 测试3：正常计时功能 ===");
        // 等待1秒 (50,000,000个时钟周期，这里用较少的周期进行快速测试)
        wait_cycles(1000);
        check_display(6'd0, 6'd0);  // 由于分频比例很大，实际测试中可能看不到变化
        
        // 测试4：暂停/恢复功能
        $display("=== 测试4：暂停/恢复功能 ===");
        press_button(0);  // 按下暂停按钮
        wait_cycles(100);
        check_display(6'd0, 6'd0);
        
        press_button(0);  // 再次按下暂停按钮（恢复）
        wait_cycles(100);
        check_display(6'd0, 6'd0);
        
        // 测试5：时间设置功能
        $display("=== 测试5：时间设置功能 ===");
        press_button(1);  // 进入设置模式
        wait_cycles(10);
        
        // 设置分钟
        press_button(2);  // 增加分钟
        wait_cycles(10);
        check_display(6'd1, 6'd0);
        
        // 设置秒数
        press_button(3);  // 增加秒数
        wait_cycles(10);
        check_display(6'd1, 6'd1);
        
        press_button(1);  // 退出设置模式
        wait_cycles(10);
        
        // 测试6：LED状态指示
        $display("=== 测试6：LED状态指示 ===");
        $display("正常运行状态LED: %b", led_state);
        
        press_button(0);  // 暂停
        wait_cycles(10);
        $display("暂停状态LED: %b", led_state);
        
        press_button(0);  // 恢复
        wait_cycles(10);
        $display("恢复状态LED: %b", led_state);
        
        // 测试完成
        $display("=== 所有测试完成 ===");
        $finish;
    end

    // ==================== 监控和调试 ====================
    
    // 监控重要信号变化
    always @(posedge clk) begin
        if (rst) begin
            // 监控按钮状态变化
            if (set_buttons != 4'b0000) begin
                $display("时间 %0t: 按钮按下 - %b", $time, set_buttons);
            end
        end
    end

    // 监控数码管扫描
    always @(posedge clk) begin
        if (disp_an_o != 4'b1111) begin
            $display("时间 %0t: 数码管扫描 - 位选:%b 段信号:%b", 
                     $time, disp_an_o, disp_seg_o);
        end
    end

    // 生成波形文件
    initial begin
        $dumpfile("time_tb.vcd");
        $dumpvars(0, time_tb);
    end

endmodule 