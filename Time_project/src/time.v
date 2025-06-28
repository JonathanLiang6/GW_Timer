/**
 * 文件名：time.v
 * 功能：基于高云FPGA的多功能秒表设计
 * 作者：[您的姓名]
 * 日期：2024年
 * 描述：实现具有计时、暂停/恢复、时间设置等功能的秒表
 * 
 * 主要功能：
 * 1. 连续计时（00:00 - 59:59）
 * 2. 暂停/恢复功能
 * 3. 时间预置设置
 * 4. 4位7段数码管显示
 * 5. 状态指示灯
 */

module timer_clock(
    // ==================== 输入端口 ====================
    input wire clk,                    // 系统时钟输入 (50MHz)
    input wire rst,                    // 复位信号，低电平有效
    input wire pause_resume,           // 暂停/恢复控制信号
    input wire set_time_mode,          // 时间设置模式切换信号
    input wire [3:0] set_buttons,      // 设置按钮组 [3:电源, 2:分钟+, 1:秒+, 0:暂停]
    input wire power_switch,           // 电源开关信号 (拨码开关)
    
    // ==================== 输出端口 ====================
    output reg [6:0] disp_seg_o,       // 7段数码管段信号输出 (a-g)
    output reg [3:0] disp_an_o,        // 数码管位选信号 (4位，低电平有效)
    output reg led_state               // 状态指示灯输出
);

    // ==================== 内部信号定义 ====================
    
    // 按钮状态寄存器 - 用于消抖和边沿检测
    reg button_1_last = 1'b0;          // 按钮1(电源)上次状态
    reg button_2_last = 1'b0;          // 按钮2(分钟+)上次状态  
    reg button_3_last = 1'b0;          // 按钮3(秒+)上次状态
    reg button_1_current = 1'b0;       // 按钮1当前状态
    reg button_2_current = 1'b0;       // 按钮2当前状态
    reg button_3_current = 1'b0;       // 按钮3当前状态
    
    // 时间计数器
    reg [5:0] seconds = 6'd0;          // 秒计数器 (0-59)
    reg [5:0] minutes = 6'd0;          // 分钟计数器 (0-59)
    
    // 控制状态寄存器
    reg paused = 1'b0;                 // 暂停标志位
    reg setting_mode = 1'b0;           // 时间设置模式标志位
    reg power_on = 1'b0;               // 电源状态标志位
    
    // 时钟分频相关
    reg [31:0] clk_count = 32'd0;      // 50MHz到1Hz的分频计数器
    reg enable_count = 1'b0;           // 1Hz计时使能信号
    
    // 数码管扫描相关
    reg [1:0] digit_pos = 2'd0;        // 当前扫描位位置 (0-3)
    reg [15:0] digit_clk_count = 16'd0; // 数码管扫描时钟分频计数器
    reg digit_clk_enable = 1'b0;       // 数码管扫描时钟使能信号

    // ==================== 时钟分频模块 ====================
    /**
     * 功能：将50MHz系统时钟分频为1Hz的计时信号
     * 原理：计数到50,000,000-1时产生一个时钟周期的使能信号
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            // 复位时清零计数器
            clk_count <= 32'd0;
            enable_count <= 1'b0;
        end 
        else if (power_on && !paused && !setting_mode) begin
            // 只有在电源开启、非暂停、非设置模式下才进行计时
            if (clk_count == 32'd50_000_000 - 1) begin
                clk_count <= 32'd0;
                enable_count <= 1'b1;   // 产生1Hz使能脉冲
            end 
            else begin
                clk_count <= clk_count + 32'd1;
                enable_count <= 1'b0;
            end
        end 
        else begin
            // 其他情况下保持计数器值，不产生使能信号
            clk_count <= clk_count;
            enable_count <= 1'b0;
        end
    end

    // ==================== 时间计数模块 ====================
    /**
     * 功能：实现秒和分钟的计数逻辑
     * 包含：正常计时、时间设置、电源控制等功能
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            // 复位时清零时间计数器
            seconds <= 6'd0;
            minutes <= 6'd0;
        end 
        else if (!set_buttons[1]) begin
            // 当电源按钮关闭时，保持当前时间值
            seconds <= seconds;
            minutes <= minutes;
        end 
        else if (setting_mode) begin
            // 时间设置模式：通过按钮调整时间
            if (button_2_current && !button_2_last) begin
                // 按钮2按下上升沿：增加分钟
                minutes <= (minutes < 6'd59) ? minutes + 6'd1 : 6'd0;
            end
            
            if (button_3_current && !button_3_last) begin
                // 按钮3按下上升沿：增加秒数
                seconds <= (seconds < 6'd59) ? seconds + 6'd1 : 6'd0;
            end
        end 
        else if (enable_count && !paused) begin
            // 正常计时模式：每秒递增
            if (seconds == 6'd59) begin
                seconds <= 6'd0;        // 秒数归零
                if (minutes == 6'd59) begin
                    minutes <= 6'd0;    // 分钟也归零（1小时循环）
                end 
                else begin
                    minutes <= minutes + 6'd1;  // 分钟加1
                end
            end 
            else begin
                seconds <= seconds + 6'd1;      // 秒数加1
            end
        end
    end

    // ==================== 按钮状态检测模块 ====================
    /**
     * 功能：检测按钮状态变化，实现边沿检测
     * 作用：消除按钮抖动，确保每次按下只触发一次
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            // 复位时清零所有按钮状态
            button_1_last <= 1'b0;
            button_2_last <= 1'b0;
            button_3_last <= 1'b0;
            button_1_current <= 1'b0;
            button_2_current <= 1'b0;
            button_3_current <= 1'b0;
        end 
        else begin
            // 更新按钮状态：上次状态 <- 当前状态 <- 输入信号
            button_1_last <= button_1_current;
            button_2_last <= button_2_current;
            button_3_last <= button_3_current;
            
            button_1_current <= set_buttons[1];  // 电源按钮
            button_2_current <= set_buttons[2];  // 分钟+按钮
            button_3_current <= set_buttons[3];  // 秒+按钮
        end
    end

    // ==================== 电源控制模块 ====================
    /**
     * 功能：控制秒表的电源开关状态
     * 触发：按钮1的上升沿
     */
    always @(posedge button_1_current or negedge rst) begin
        if (!rst) begin
            power_on <= 1'b0;           // 复位时电源关闭
        end 
        else begin
            power_on <= ~power_on;      // 切换电源状态
        end
    end

    // ==================== 暂停/恢复控制模块 ====================
    /**
     * 功能：控制秒表的暂停和恢复
     * 触发：按钮0的上升沿
     */
    always @(posedge set_buttons[0] or negedge rst) begin
        if (!rst) begin
            paused <= 1'b0;             // 复位时非暂停状态
        end 
        else begin
            paused <= ~paused;          // 切换暂停状态
        end
    end

    // ==================== 时间设置模式控制模块 ====================
    /**
     * 功能：控制时间设置模式的进入和退出
     * 触发：set_time_mode信号的上升沿
     */
    always @(posedge set_time_mode or negedge rst) begin
        if (!rst) begin
            setting_mode <= 1'b0;       // 复位时退出设置模式
        end 
        else begin
            setting_mode <= ~setting_mode;  // 切换设置模式状态
        end
    end

    // ==================== 状态指示灯控制模块 ====================
    /**
     * 功能：控制LED状态指示灯的亮灭
     * 逻辑：电源开启且非暂停且非设置模式时点亮
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            led_state <= 1'b0;          // 复位时LED熄灭
        end 
        else if (!power_on) begin
            led_state <= 1'b0;          // 电源关闭时LED熄灭
        end 
        else if (!paused && !setting_mode) begin
            led_state <= 1'b1;          // 正常运行状态时LED点亮
        end 
        else begin
            led_state <= 1'b0;          // 暂停或设置模式时LED熄灭
        end
    end

    // ==================== 数码管扫描时钟分频模块 ====================
    /**
     * 功能：生成数码管动态扫描所需的时钟信号
     * 频率：50MHz / 5000 = 10kHz，确保人眼无闪烁感
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            digit_clk_count <= 16'd0;
            digit_clk_enable <= 1'b0;
        end 
        else if (digit_clk_count == 16'd5000 - 1) begin
            digit_clk_count <= 16'd0;
            digit_clk_enable <= 1'b1;   // 产生扫描时钟脉冲
        end 
        else begin
            digit_clk_count <= digit_clk_count + 16'd1;
            digit_clk_enable <= 1'b0;
        end
    end

    // ==================== 数码管位选控制模块 ====================
    /**
     * 功能：控制4位数码管的位选信号
     * 实现：循环扫描，每次只点亮一位数码管
     */
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            digit_pos <= 2'd0;
            disp_an_o <= 4'b1110;       // 初始状态：最左边数码管有效
        end 
        else if (digit_clk_enable) begin
            digit_pos <= digit_pos + 2'd1;  // 扫描位置递增
            // 位选信号循环移位：1110 -> 1101 -> 1011 -> 0111 -> 1110
            disp_an_o <= {disp_an_o[2:0], disp_an_o[3]};
        end
    end

    // ==================== 数码管段显示控制模块 ====================
    /**
     * 功能：根据当前扫描位置和显示数据生成段信号
     * 显示格式：MM:SS (分钟:秒)
     */
    always @(*) begin
        if (!power_on) begin
            // 电源关闭时，数码管全灭
            disp_seg_o = 7'b1111111;
        end 
        else if (setting_mode) begin
            // 设置模式：显示当前设置的时间值
            case(digit_pos)
                2'b00: disp_seg_o = get_segment(minutes / 6'd10);  // 分钟十位
                2'b01: disp_seg_o = get_segment(minutes % 6'd10);  // 分钟个位
                2'b10: disp_seg_o = get_segment(seconds / 6'd10);  // 秒十位
                2'b11: disp_seg_o = get_segment(seconds % 6'd10);  // 秒个位
                default: disp_seg_o = 7'b1111111;
            endcase
        end 
        else begin
            // 正常模式：显示当前计时时间
            case(digit_pos)
                2'b00: disp_seg_o = get_segment(minutes / 6'd10);  // 分钟十位
                2'b01: disp_seg_o = get_segment(minutes % 6'd10);  // 分钟个位
                2'b10: disp_seg_o = get_segment(seconds / 6'd10);  // 秒十位
                2'b11: disp_seg_o = get_segment(seconds % 6'd10);  // 秒个位
                default: disp_seg_o = 7'b1111111;
            endcase
        end
    end

    // ==================== 7段数码管编码函数 ====================
    /**
     * 功能：将4位二进制数字转换为7段数码管段信号
     * 参数：digit - 4位二进制数字 (0-9)
     * 返回：7位段信号 (a-g，低电平有效)
     * 
     * 7段数码管段定义：
     *     a
     *   f   b
     *     g
     *   e   c
     *     d
     */
    function [6:0] get_segment;
        input [3:0] digit;
        case(digit)
            4'd0: get_segment = 7'b1000000;  // 0: abcdef (点亮a,b,c,d,e,f段)
            4'd1: get_segment = 7'b1111001;  // 1: bc (点亮b,c段)
            4'd2: get_segment = 7'b0100100;  // 2: abdeg (点亮a,b,d,e,g段)
            4'd3: get_segment = 7'b0110000;  // 3: abcdg (点亮a,b,c,d,g段)
            4'd4: get_segment = 7'b0011001;  // 4: bcfg (点亮b,c,f,g段)
            4'd5: get_segment = 7'b0010010;  // 5: acdfg (点亮a,c,d,f,g段)
            4'd6: get_segment = 7'b0000010;  // 6: acdefg (点亮a,c,d,e,f,g段)
            4'd7: get_segment = 7'b1111000;  // 7: abc (点亮a,b,c段)
            4'd8: get_segment = 7'b0000000;  // 8: abcdefg (点亮所有段)
            4'd9: get_segment = 7'b0010000;  // 9: abcdfg (点亮a,b,c,d,f,g段)
            default: get_segment = 7'b1111111;  // 其他值：全灭
        endcase
    endfunction

endmodule
