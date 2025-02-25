module timer_clock(
    input clk,               // 系统时钟
    input rst,               // 复位按键
    input pause_resume,      // 暂停/恢复计数
    input set_time_mode,     // 进入/退出时间设置模式
    input [3:0] set_buttons, // 设置时间的按钮
    input power_switch,      // 电源开关 (拨码开关)
    output reg [6:0] disp_seg_o, // 七段数码管段信号输出
    output reg [3:0] disp_an_o,  // 数码管位选信号 (4位)
    output reg led_state       // 状态指示灯输出
);
    // 声明按钮状态
    reg button_1_last = 0;   // 按钮1上次状态
    reg button_2_last = 0;   // 按钮2上次状态
    reg button_3_last = 0;   // 按钮3上次状态
    reg button_1_current = 0; // 按钮1当前状态
    reg button_2_current = 0; // 按钮2当前状态
    reg button_3_current = 0; // 按钮3当前状态
    reg [5:0] seconds = 0;   // 秒计数器，最大59
    reg [5:0] minutes = 0;   // 分钟计数器，最大59
    reg paused = 0;          // 暂停标志
    reg setting_mode = 0;    // 时间设置模式
    reg [31:0] clk_count = 0; // 时钟分频计数器
    reg enable_count = 0;    // 是否使能计数
    reg [1:0] digit_pos = 0; // 位选择，用于多路复用
    reg [15:0] digit_clk_count = 0; // 数码管分频时钟
    reg digit_clk_enable = 0; // 数码管位选切换时钟使能
    reg power_on = 0;        // 电源状态标志

    // 时钟分频，生成1Hz的计时信号
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            clk_count <= 0;
            enable_count <= 0;
        end else if (power_on && !paused && !setting_mode) begin
            if (clk_count == 50_000_000 - 1) begin // 假设系统时钟为50MHz
                clk_count <= 0;
                enable_count <= 1; // 1Hz计数信号
            end else begin
                clk_count <= clk_count + 1;
                enable_count <= 0;
            end
        end else begin
            clk_count <= clk_count;
            enable_count <= 0;
        end
    end

    // 秒和分的计数逻辑
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            seconds <= 0;
            minutes <= 0;
        end else if (!set_buttons[1]) begin
            // 当电路开关关闭时，保持当前时间
            seconds <= seconds;
            minutes <= minutes;
        end else if (setting_mode) begin
            // 设置模式：根据按钮的状态变化设置时间
            if (button_2_current && !button_2_last) begin
                // 如果按钮2按下并且上次状态是未按下，增加分钟
                minutes <= (minutes < 59) ? minutes + 1 : 0;
            end
            
            if (button_3_current && !button_3_last) begin
                // 如果按钮3按下并且上次状态是未按下，增加秒数
                seconds <= (seconds < 59) ? seconds + 1 : 0;
            end
        end else if (enable_count && !paused) begin
            // 正常计时模式
            if (seconds == 59) begin
                seconds <= 0;
                if (minutes == 59) begin
                    minutes <= 0;
                end else begin
                    minutes <= minutes + 1;
                end
            end else begin
                seconds <= seconds + 1;
            end
        end
    end

    // 按钮状态存储
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            button_1_last <= 0; // 按钮1上次状态
            button_2_last <= 0; // 按钮2上次状态
            button_3_last <= 0; // 按钮3上次状态
            button_1_current <= 0; // 按钮1当前状态
            button_2_current <= 0; // 按钮2当前状态
            button_3_current <= 0; // 按钮3当前状态
        end else begin
            button_1_last <= button_1_current; // 更新上次状态
            button_2_last <= button_2_current; // 更新上次状态
            button_3_last <= button_3_current; // 更新上次状态
            
            button_1_current <= set_buttons[1]; // 更新当前状态
            button_2_current <= set_buttons[2]; // 更新当前状态
            button_3_current <= set_buttons[3]; // 更新当前状态
        end
    end

    // 按钮1控制电源状态
    always @(posedge button_1_current or negedge rst) begin
        if (~rst) begin
            power_on <= 0; // 默认电源关闭
        end else begin
            power_on <= ~power_on; // 切换电源状态
        end
    end

    // 暂停/恢复功能
    always @(posedge set_buttons[0] or negedge rst) begin
        if (~rst) begin
            paused <= 0;
        end else begin
            paused <= ~paused;
        end
    end

    // 设置模式
    always @(posedge set_time_mode or negedge rst) begin
        if (~rst) begin
            setting_mode <= 0;
        end else begin
            setting_mode <= ~setting_mode;
        end
    end

    // 状态指示灯逻辑
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            led_state <= 0;
        end else if (!power_on) begin
            led_state <= 0; // 关闭电源时关闭状态指示灯
        end else if (!paused && !setting_mode) begin
            led_state <= 1; 
        end else begin
            led_state <= 0;
        end
    end

    // 数码管时钟分频
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            digit_clk_count <= 0;
            digit_clk_enable <= 0;
        end else if (digit_clk_count == 5000 - 1) begin
            digit_clk_count <= 0;
            digit_clk_enable <= 1;
        end else begin
            digit_clk_count <= digit_clk_count + 1;
            digit_clk_enable <= 0;
        end
    end

    // 位选信号和段信号控制
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            digit_pos <= 0;
            disp_an_o <= 4'b1110; // 初始状态为显示最左边的数码管
        end else if (digit_clk_enable) begin
            digit_pos <= digit_pos + 1;
            disp_an_o <= {disp_an_o[2:0], disp_an_o[3]}; 
        end
    end

    // 数码管段显示逻辑
    always @(*) begin
        if (!power_on) begin
            disp_seg_o = 7'b1111111; // 关闭电源时，数码管全灭
        end else if (setting_mode) begin
            // 显示设置的时间
            case(digit_pos)
                2'b00: disp_seg_o = get_segment(minutes / 10); // 左边第一个
                2'b01: disp_seg_o = get_segment(minutes % 10); // 左边第二个
                2'b10: disp_seg_o = get_segment(seconds / 10); // 右边第二个
                2'b11: disp_seg_o = get_segment(seconds % 10); // 右边第一个
            endcase
        end else begin
            // 显示当前时间
            case(digit_pos)
                2'b00: disp_seg_o = get_segment(minutes / 10); // 左边第一个
                2'b01: disp_seg_o = get_segment(minutes % 10); // 左边第二个
                2'b10: disp_seg_o = get_segment(seconds / 10); // 右边第二个
                2'b11: disp_seg_o = get_segment(seconds % 10); // 右边第一个
            endcase
        end
    end

    // 数字到七段数码管的转换
    function [6:0] get_segment;
        input [3:0] digit;
        case(digit)
            4'd0: get_segment = 7'b1000000; // 数码管显示0
            4'd1: get_segment = 7'b1111001; // 数码管显示1
            4'd2: get_segment = 7'b0100100; // 数码管显示2
            4'd3: get_segment = 7'b0110000; // 数码管显示3
            4'd4: get_segment = 7'b0011001; // 数码管显示4
            4'd5: get_segment = 7'b0010010; // 数码管显示5
            4'd6: get_segment = 7'b0000010; 
            4'd7: get_segment = 7'b1111000; // 数码管显示7
            4'd8: get_segment = 7'b0000000; // 数码管显示8
            4'd9: get_segment = 7'b0010000; // 数码管显示9
            default: get_segment = 7'b1111111; // 默认显示全灭
        endcase
    endfunction

endmodule
