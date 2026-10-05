`timescale 1ns/1ps

// 第5章：矩阵键盘、EC11、五向键与触摸键。
// 工程：CHAPT4_200T；Design Top：top_chapter4_input。
// 文件：tb_chapter5_all.v；Simulation Top：tb_chapter5_all。
// 添加到 Simulation Sources，右键本模块 Set as Top，运行行为仿真。
// 保留工程原有7个RTL模块；本文件不包含替代的设计模块。
// 建议先 run 1000 us。checks_done=1、checks_pass=1表示自动检查通过。
// 无$finish/$stop；完成检查后保持仿真窗口和时钟运行。
//
// 本文件覆盖触摸、五向键、矩阵键盘、EC11兼容模式及正交模式。
// 一次稳定动作只产生一次单周期事件；覆盖短抖动、稳定按下、保持、释放。
// 矩阵覆盖键码6/9、释放后重新按下和多键拒绝。
// EC11兼容模式旋转加1，轴心按下清零；正交模式顺时针+1、逆时针-1。
//
// 仿真加速说明：真实激励时钟仍为50 MHz、周期20 ns。
// 仅DUT实例参数CLK_HZ=100000、POR_BITS=4，缩短计数等待500倍。
// 因此五向键/轴心去抖和EC11锁定约40 us，触摸过滤约16 us。
// 这些us级等待是加速仿真时间；板级原参数分别为20 ms和8 ms。
// A组矩阵与触摸共用物理通路；在独立DUT中分别检查两种参数分支。
// dut_input：A_GROUP_MODE=1、TOUCH_ACTIVE_LOW=0、EC_DIRECTION_MODE=0。
// dut_matrix：A_GROUP_MODE=0、EC_DIRECTION_MODE=0。
// dut_quad：A_GROUP_MODE=1、EC_DIRECTION_MODE=1、EC_DIR_INVERT=0。
//
// 图5-1 触摸按下释放与去抖事件：时间约470..530 us。
// 在tb_chapter5_all顶层选择：
//   touch_raw, touch_filter_count, touch_level, touch_press,
//   touch_release, led_register, touch_press_events, touch_release_events。
// 2-us短触摸不应触发；稳定按下LED=11111，稳定释放LED=00000。
// touch_*_events从0变1，便于在全程图中识别20-ns事件脉冲。
//
// 图5-2 EC11或矩阵输入事件（按文档占位选择）：
// EC11兼容模式：时间约515..725 us；A_GROUP_MODE=1、EC_DIRECTION_MODE=0。
//   ec_ab, ec_step, ec_count, ec_key_n, ec_key_press, led_register,
//   ec_step_events, ec_key_press_events。
// 两次分离旋转产生两个事件，计数0->1->2；轴心按下后清零。
// 矩阵模式：时间约0..115 us；A_GROUP_MODE=0、EC_DIRECTION_MODE=0。
//   matrix_keys, matrix_row, matrix_col, matrix_row_index,
//   matrix_stable_frames, matrix_valid, matrix_code, matrix_led_register。
// 先键码6、LED=10110；释放再按键码9、LED=11001。
// 两种通路可作为图5-2的两个小图，不增加重复图号。
//
// 补充检查不另设文档图号：五向键5..485 us；正交模式0..160 us。
// 五向键位序{中心,右,左,下,上}；原始键为低有效。
// 实际接口映射KEYA=右、KEYB=下、KEYC=上、KEYD=左、KEYP=中心。
//
// 显示格式：touch_level/事件/原始单比特=Binary。
// led_register、matrix_led_register、ec_ab、matrix_row/col/keys=Binary。
// 各计数器、事件累计数、ec_count、matrix_row_index=Unsigned Decimal。
// matrix_code=Hexadecimal。所有截图信号均在仿真顶层。
// 事件脉冲仅20 ns宽；需要检查脉宽时再围绕事件单独放大。

module tb_chapter5_all;


    localparam integer SIM_COUNT_CLK_HZ = 100_000;
    localparam integer SIM_POR_BITS     = 4;

    reg sys_clk = 1'b0;
    always #10 sys_clk = ~sys_clk;

    // Bit order: {CENTER, RIGHT, LEFT, DOWN, UP}; active low.
    // Actual board mapping: KEYA=RIGHT, KEYB=DOWN, KEYC=UP,
    // KEYD=LEFT, KEYP=CENTER.
    reg [4:0] fiveway_raw_n = 5'b11111;
    reg ec_a = 1'b1;
    reg ec_b = 1'b1;
    reg ec_key_n = 1'b1;
    reg touch_raw = 1'b0;             // default touch polarity: active high
    tri [3:0] touch_bus;
    wire [4:0] led_input;
    assign touch_bus = {touch_raw, 3'bzzz};

    top_chapter4_input #(
        .CLK_HZ            (SIM_COUNT_CLK_HZ),
        .POR_BITS          (SIM_POR_BITS),
        .A_GROUP_MODE      (1),
        .TOUCH_ACTIVE_LOW  (0),
        .EC_DIRECTION_MODE (0),
        .EC_DIR_INVERT     (0)
    ) dut_input (
        .sys_clk      (sys_clk),
        .I_SWC        (4'b1111),
        .O_SWR        (touch_bus),
        .S1_KEYA      (fiveway_raw_n[3]),
        .S1_KEYB      (fiveway_raw_n[1]),
        .S1_KEYC_TOUCH(fiveway_raw_n[0]),
        .S1_KEYD      (fiveway_raw_n[2]),
        .S1_KEYP      (fiveway_raw_n[4]),
        .EC_A         (ec_a),
        .EC_B         (ec_b),
        .EC_KEY       (ec_key_n),
        .led          (led_input)
    );

    // Matrix model: a pressed contact connects its active-low scan row
    // to its column. Code = row_index * 4 + column_index, both zero-based.
    reg [15:0] matrix_keys = 16'h0000;
    reg [3:0] matrix_col;
    wire [3:0] matrix_row;
    wire [4:0] led_matrix;
    integer model_row;
    integer model_col;
    always @(*) begin
        matrix_col = 4'b1111;
        for (model_row = 0; model_row < 4; model_row = model_row + 1)
            for (model_col = 0; model_col < 4; model_col = model_col + 1)
                if (matrix_keys[model_row*4 + model_col] &&
                    (matrix_row[model_row] === 1'b0))
                    matrix_col[model_col] = 1'b0;
    end

    top_chapter4_input #(
        .CLK_HZ            (SIM_COUNT_CLK_HZ),
        .POR_BITS          (SIM_POR_BITS),
        .A_GROUP_MODE      (0),
        .TOUCH_ACTIVE_LOW  (0),
        .EC_DIRECTION_MODE (0),
        .EC_DIR_INVERT     (0)
    ) dut_matrix (
        .sys_clk      (sys_clk),
        .I_SWC        (matrix_col),
        .O_SWR        (matrix_row),
        .S1_KEYA      (1'b1), .S1_KEYB (1'b1),
        .S1_KEYC_TOUCH(1'b1), .S1_KEYD (1'b1), .S1_KEYP(1'b1),
        .EC_A         (1'b1), .EC_B (1'b1), .EC_KEY (1'b1),
        .led          (led_matrix)
    );

    // An independent optional direction-mode instance. In the default
    // compatibility mode BOTH directions add one; do not call that a
    // direction-decode failure.
    reg quad_a = 1'b1;
    reg quad_b = 1'b1;
    reg quad_key_n = 1'b1;
    tri [3:0] quad_touch_bus;
    wire [4:0] led_quad;
    assign quad_touch_bus = 4'b0zzz;

    top_chapter4_input #(
        .CLK_HZ            (SIM_COUNT_CLK_HZ),
        .POR_BITS          (SIM_POR_BITS),
        .A_GROUP_MODE      (1),
        .TOUCH_ACTIVE_LOW  (0),
        .EC_DIRECTION_MODE (1),
        .EC_DIR_INVERT     (0)
    ) dut_quad (
        .sys_clk      (sys_clk),
        .I_SWC        (4'b1111),
        .O_SWR        (quad_touch_bus),
        .S1_KEYA      (1'b1), .S1_KEYB (1'b1),
        .S1_KEYC_TOUCH(1'b1), .S1_KEYD (1'b1), .S1_KEYP(1'b1),
        .EC_A         (quad_a), .EC_B (quad_b), .EC_KEY (quad_key_n),
        .led          (led_quad)
    );

    // Read-only root aliases for Objects -> Add to Wave Window.
    wire rst_n = dut_input.rst_n;
    wire up_raw_n = fiveway_raw_n[0];
    wire up_level = dut_input.up_level;
    wire up_press = dut_input.up_press;
    wire up_release = dut_input.up_release;
    wire [31:0] up_debounce_count =
        dut_input.u_fiveway_touch.u_up.stable_count;
    wire [4:0] fiveway_level = {dut_input.center_level,
        dut_input.right_level, dut_input.left_level,
        dut_input.down_level, dut_input.up_level};
    wire [4:0] fiveway_press = {dut_input.center_press,
        dut_input.right_press, dut_input.left_press,
        dut_input.down_press, dut_input.up_press};
    wire [4:0] fiveway_release = {dut_input.center_release,
        dut_input.right_release, dut_input.left_release,
        dut_input.down_release, dut_input.up_release};
    wire touch_level = dut_input.touch_level_raw;
    wire touch_press = dut_input.touch_press;
    wire touch_release = dut_input.touch_release;
    wire [31:0] touch_filter_count =
        dut_input.u_fiveway_touch.u_touch.stable_count;
    wire [1:0] matrix_row_index = dut_matrix.u_keypad.row_index;
    wire matrix_valid = dut_matrix.keypad_valid;
    wire [3:0] matrix_code = dut_matrix.keypad_code;
    wire [7:0] matrix_stable_frames = dut_matrix.u_keypad.stable_frames;
    wire [1:0] ec_ab = {ec_a, ec_b};
    wire ec_step = dut_input.ec_step;
    wire [4:0] ec_count = dut_input.ec_count;
    wire ec_key_level = dut_input.ec_key_level;
    wire ec_key_press = dut_input.ec_key_press;
    wire ec_key_release = dut_input.ec_key_release;
    wire [31:0] ec_lockout_count = dut_input.u_ec11_compat.lockout_count;
    wire [1:0] quad_ab = {quad_a, quad_b};
    wire quad_cw = dut_quad.ec_cw;
    wire quad_ccw = dut_quad.ec_ccw;
    wire [4:0] quad_count = dut_quad.ec_count;

    reg [3:0] input_stage = 4'd0;
    reg [2:0] matrix_stage = 3'd0;
    reg [2:0] quad_stage = 3'd0;
    reg input_done = 1'b0;
    reg matrix_done = 1'b0;
    reg quad_done = 1'b0;
    reg checks_done = 1'b0;
    reg checks_pass = 1'b0;
    integer errors = 0;
    integer up_press_events = 0;
    integer up_release_events = 0;
    integer fiveway_press_events = 0;
    integer fiveway_release_events = 0;
    integer touch_press_events = 0;
    integer touch_release_events = 0;
    integer matrix_events = 0;
    integer ec_step_events = 0;
    integer ec_key_press_events = 0;
    integer ec_key_release_events = 0;
    integer quad_cw_events = 0;
    integer quad_ccw_events = 0;
    reg [4:0] previous_fiveway_press = 5'b00000;
    reg [4:0] previous_fiveway_release = 5'b00000;
    reg [7:0] previous_other_events = 8'b00000000;
    wire [7:0] other_events = {quad_ccw, quad_cw, ec_key_release,
        ec_key_press, ec_step, matrix_valid, touch_release, touch_press};
    integer event_bit;

    task expect_value;
        input [31:0] actual;
        input [31:0] expected;
        input [8*96-1:0] description;
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $display("CH5 ERROR at %0t: %0s; actual=%0d expected=%0d",
                         $time, description, actual, expected);
            end
        end
    endtask

    // Sample event outputs after the DUT's nonblocking updates. All
    // stimulus/check tasks below change inputs at falling-clock times.
    always @(posedge sys_clk) begin
        #0.001;
        if (rst_n === 1'b1) begin
            if ((|(fiveway_press & previous_fiveway_press)) ||
                (|(fiveway_release & previous_fiveway_release)) ||
                (|(other_events & previous_other_events))) begin
                errors = errors + 1;
                $display("CH5 ERROR at %0t: event wider than one clock", $time);
            end
            if (up_press) up_press_events = up_press_events + 1;
            if (up_release) up_release_events = up_release_events + 1;
            for (event_bit = 0; event_bit < 5; event_bit = event_bit + 1) begin
                if (fiveway_press[event_bit])
                    fiveway_press_events = fiveway_press_events + 1;
                if (fiveway_release[event_bit])
                    fiveway_release_events = fiveway_release_events + 1;
            end
            if (touch_press) touch_press_events = touch_press_events + 1;
            if (touch_release) touch_release_events = touch_release_events + 1;
            if (matrix_valid) begin
                matrix_events = matrix_events + 1;
                if (matrix_events == 1)
                    expect_value(matrix_code, 6, "first matrix code");
                else if (matrix_events == 2)
                    expect_value(matrix_code, 9, "second matrix code");
                else begin
                    errors = errors + 1;
                    $display("CH5 ERROR: extra / multi-key matrix event");
                end
            end
            if (ec_step) ec_step_events = ec_step_events + 1;
            if (ec_key_press) ec_key_press_events = ec_key_press_events + 1;
            if (ec_key_release) ec_key_release_events = ec_key_release_events + 1;
            if (quad_cw) quad_cw_events = quad_cw_events + 1;
            if (quad_ccw) quad_ccw_events = quad_ccw_events + 1;
            previous_fiveway_press = fiveway_press;
            previous_fiveway_release = fiveway_release;
            previous_other_events = other_events;
        end else begin
            previous_fiveway_press = 5'b00000;
            previous_fiveway_release = 5'b00000;
            previous_other_events = 8'b00000000;
        end
    end

    task press_direction;
        input integer bit_index;
        input [4:0] expected_led;
        begin
            fiveway_raw_n[bit_index] = 1'b0;
            #45000;
            expect_value(fiveway_level, expected_led, "five-way stable level");
            expect_value(led_input, expected_led, "five-way LED mapping");
            fiveway_raw_n[bit_index] = 1'b1;
            #45000;
            expect_value(fiveway_level, 0, "five-way release");
            expect_value(led_input, expected_led, "LED retains last key event");
        end
    endtask

    task compat_rotation;
        input integer clockwise;
        begin
            if (clockwise != 0) begin
                {ec_a, ec_b} = 2'b10; #2000;
                {ec_a, ec_b} = 2'b00; #2000;
                {ec_a, ec_b} = 2'b01; #2000;
                {ec_a, ec_b} = 2'b11; #2000;
            end else begin
                {ec_a, ec_b} = 2'b01; #2000;
                {ec_a, ec_b} = 2'b00; #2000;
                {ec_a, ec_b} = 2'b10; #2000;
                {ec_a, ec_b} = 2'b11; #2000;
            end
            #45000; // Allow the 40-us accelerated lockout to expire.
        end
    endtask

    task quadrature_rotation;
        input integer clockwise;
        begin
            if (clockwise != 0) begin
                {quad_a, quad_b} = 2'b10; #2000;
                {quad_a, quad_b} = 2'b00; #2000;
                {quad_a, quad_b} = 2'b01; #2000;
                {quad_a, quad_b} = 2'b11; #2000;
            end else begin
                {quad_a, quad_b} = 2'b01; #2000;
                {quad_a, quad_b} = 2'b00; #2000;
                {quad_a, quad_b} = 2'b10; #2000;
                {quad_a, quad_b} = 2'b11; #2000;
            end
        end
    endtask

    initial begin : input_stimulus
        #10000;
        input_stage = 4'd1;
        expect_value(rst_n, 1, "power-on reset released");
        // Two 2-us low glitches, shorter than the 40-us debounce.
        fiveway_raw_n[0] = 1'b0; #2000;
        fiveway_raw_n[0] = 1'b1; #2000;
        fiveway_raw_n[0] = 1'b0; #2000;
        fiveway_raw_n[0] = 1'b1; #2000;
        expect_value(up_press_events, 0, "UP bounce must not trigger");
        fiveway_raw_n[0] = 1'b0;
        #50000;
        expect_value(up_level, 1, "UP held level");
        expect_value(up_press_events, 1, "one UP press while held");
        expect_value(led_input, 5'b00001, "physical KEYC maps to UP LED");
        fiveway_raw_n[0] = 1'b1;
        #50000;
        expect_value(up_level, 0, "UP released level");
        expect_value(up_release_events, 1, "one UP release");

        input_stage = 4'd2; press_direction(1, 5'b00010); // DOWN
        input_stage = 4'd3; press_direction(2, 5'b00100); // LEFT
        input_stage = 4'd4; press_direction(3, 5'b01000); // RIGHT
        input_stage = 4'd5; press_direction(4, 5'b10000); // CENTER
        expect_value(fiveway_press_events, 5, "five-way press total");
        expect_value(fiveway_release_events, 5, "five-way release total");

        input_stage = 4'd6;
        touch_raw = 1'b1; #2000; // Shorter than the 16-us touch filter.
        touch_raw = 1'b0; #4000;
        expect_value(touch_press_events, 0, "short touch pulse rejected");
        touch_raw = 1'b1; #20000;
        expect_value(touch_level, 1, "touch stable level");
        expect_value(touch_press_events, 1, "one touch press");
        expect_value(led_input, 5'b11111, "touch lights all LEDs");
        touch_raw = 1'b0; #20000;
        expect_value(touch_level, 0, "touch off level");
        expect_value(touch_release_events, 1, "one touch release");
        expect_value(led_input, 0, "touch release clears LEDs");

        input_stage = 4'd7;
        compat_rotation(1);
        expect_value(ec_count, 1, "compatibility first rotation increments");
        expect_value(ec_step_events, 1, "compatibility suppresses second edge");
        expect_value(led_input, 1, "first encoder count LED");
        compat_rotation(0);
        expect_value(ec_count, 2, "compatibility reverse also increments");
        expect_value(ec_step_events, 2, "two separated compatibility events");
        expect_value(led_input, 2, "second encoder count LED");

        input_stage = 4'd8;
        ec_key_n = 1'b0; #45000;
        expect_value(ec_count, 0, "shaft press clears encoder count");
        expect_value(led_input, 0, "shaft press clears LEDs");
        expect_value(ec_key_press_events, 1, "one shaft press");
        ec_key_n = 1'b1; #45000;
        expect_value(ec_key_release_events, 1, "one shaft release");
        input_stage = 4'd9;
        input_done = 1'b1;
    end

    initial begin : matrix_stimulus
        #1000;
        matrix_stage = 3'd1;
        matrix_keys = 16'h0040; // Row 1, column 2 => code 6.
        #40000;
        expect_value(matrix_events, 1, "one matrix event while held");
        expect_value(matrix_code, 6, "matrix code 6 retained");
        expect_value(led_matrix, 5'b10110, "matrix code 6 LED");
        matrix_keys = 16'h0000; #20000;
        expect_value(matrix_events, 1, "matrix release creates no press");

        matrix_stage = 3'd2;
        matrix_keys = 16'h0200; // Row 2, column 1 => code 9.
        #40000;
        expect_value(matrix_events, 2, "matrix re-arms after release");
        expect_value(matrix_code, 9, "second matrix code 9");
        expect_value(led_matrix, 5'b11001, "matrix code 9 LED");
        matrix_keys = 16'h0000; #20000;

        matrix_stage = 3'd3;
        matrix_keys = 16'h0003; // Two keys in row 0; reject ambiguity.
        #32000;
        expect_value(matrix_events, 2, "multiple columns must be rejected");
        expect_value(led_matrix, 5'b11001, "invalid matrix leaves last LED");
        matrix_keys = 16'h0000; #20000;
        matrix_stage = 3'd4;
        matrix_done = 1'b1;
    end

    initial begin : quadrature_stimulus
        #10000;
        quad_stage = 3'd1;
        quadrature_rotation(1);
        expect_value(quad_count, 1, "optional CW adds one");
        expect_value(quad_cw_events, 1, "one pulse for a full CW cycle");
        expect_value(led_quad, 1, "optional CW LED");
        #10000;
        quad_stage = 3'd2;
        quadrature_rotation(0);
        expect_value(quad_count, 0, "optional CCW subtracts one");
        expect_value(quad_ccw_events, 1, "one pulse for a full CCW cycle");
        expect_value(led_quad, 0, "optional CCW LED");
        #10000;
        quad_stage = 3'd3;
        quadrature_rotation(1);
        expect_value(quad_count, 1, "optional count before clear");
        expect_value(quad_cw_events, 2, "second optional CW cycle");
        quad_stage = 3'd4;
        quad_key_n = 1'b0; #45000;
        expect_value(quad_count, 0, "optional shaft press clears count");
        expect_value(led_quad, 0, "optional shaft press clears LEDs");
        quad_key_n = 1'b1; #45000;
        quad_stage = 3'd5;
        quad_done = 1'b1;
    end

    initial begin : completion
        wait (input_done && matrix_done && quad_done);
        #1000;
        checks_done = 1'b1;
        checks_pass = (errors == 0);
        $display("CH5 RESULT: pass=%0d errors=%0d; matrix=%0d; fiveway=%0d/%0d; touch=%0d/%0d; compat=%0d; quad=%0d/%0d",
                 checks_pass, errors, matrix_events,
                 fiveway_press_events, fiveway_release_events,
                 touch_press_events, touch_release_events,
                 ec_step_events, quad_cw_events, quad_ccw_events);
        $display("CH5: acceleration is 500x for input counters; clock=50MHz; simulation remains open.");
    end


    // Read-only aliases named to match the teaching-manual captions.
    wire [4:0] led_register = dut_input.led_register;
    wire [4:0] matrix_led_register = dut_matrix.led_register;
    wire [31:0] a_group_mode = dut_input.A_GROUP_MODE;
    wire [31:0] ec_direction_mode = dut_input.EC_DIRECTION_MODE;
    wire [31:0] matrix_a_group_mode = dut_matrix.A_GROUP_MODE;

endmodule
