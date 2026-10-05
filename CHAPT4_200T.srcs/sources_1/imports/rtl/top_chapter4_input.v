`timescale 1ns/1ps

module top_chapter4_input #(
    parameter integer CLK_HZ             = 50_000_000,
    parameter integer POR_BITS           = 21,

    // 0: 4x4 matrix keypad mode; O_SWR drives four scan rows.
    // 1: Touch-key mode; O_SWR is high impedance and O_SWR[3] is read.
    parameter integer A_GROUP_MODE       = 1,

    // Touch-key polarity may differ between hardware revisions.
    // 0: active high; 1: active low.
    parameter integer TOUCH_ACTIVE_LOW   = 0,

    // 0: board-compatible EC11 mode. Either A or B event advances +1.
    // 1: true quadrature mode. CW +1 and CCW -1.
    parameter integer EC_DIRECTION_MODE  = 0,
    parameter integer EC_DIR_INVERT      = 0
)(
    input  wire       sys_clk,
    input  wire [3:0] I_SWC,
    inout  wire [3:0] O_SWR,

    input  wire S1_KEYA,
    input  wire S1_KEYB,
    input  wire S1_KEYC_TOUCH,
    input  wire S1_KEYD,
    input  wire S1_KEYP,

    input  wire EC_A,
    input  wire EC_B,
    input  wire EC_KEY,

    output wire [4:0] led
);

    //============================================================
    // 1. Power-on reset
    //============================================================
    wire rst_n;

    por_reset #(
        .COUNTER_BITS(POR_BITS)
    ) u_por_reset (
        .clk  (sys_clk),
        .rst_n(rst_n)
    );

    //============================================================
    // 2. 4x4 matrix keypad / Touch-key shared A-group
    //============================================================
    wire [3:0] keypad_row;
    wire       keypad_valid_raw;
    wire [3:0] keypad_code_raw;

    keypad4x4_scan #(
        .CLK_HZ          (CLK_HZ),
        .ROW_SCAN_HZ     (1000),
        .DEBOUNCE_FRAMES (3)
    ) u_keypad (
        .clk      (sys_clk),
        .rst_n    (rst_n),
        .col_i    (I_SWC),
        .row_o    (keypad_row),
        .key_valid(keypad_valid_raw),
        .key_code (keypad_code_raw)
    );

    assign O_SWR = (A_GROUP_MODE == 0) ? keypad_row : 4'bzzzz;

    wire keypad_valid;
    wire [3:0] keypad_code;
    wire touch_raw;

    assign keypad_valid = (A_GROUP_MODE == 0) ? keypad_valid_raw : 1'b0;
    assign keypad_code  = keypad_code_raw;
    assign touch_raw    = O_SWR[3];

    //============================================================
    // 3. Five-way key and Touch-key
    //============================================================
    wire up_level;
    wire down_level;
    wire left_level;
    wire right_level;
    wire center_level;
    wire touch_level_raw;

    wire up_press;
    wire down_press;
    wire left_press;
    wire right_press;
    wire center_press;
    wire touch_press_raw;

    wire up_release;
    wire down_release;
    wire left_release;
    wire right_release;
    wire center_release;
    wire touch_release_raw;

    fiveway_touch_input #(
        .CLK_HZ           (CLK_HZ),
        .KEY_DEBOUNCE_MS  (20),
        .TOUCH_FILTER_MS  (8),
        .TOUCH_ACTIVE_LOW (TOUCH_ACTIVE_LOW)
    ) u_fiveway_touch (
        .clk           (sys_clk),
        .rst_n         (rst_n),

        .s1_keya       (S1_KEYA),
        .s1_keyb       (S1_KEYB),
        .s1_keyc       (S1_KEYC_TOUCH),
        .s1_keyd       (S1_KEYD),
        .s1_keyp       (S1_KEYP),

        .touch_in      (touch_raw),

        .up_level      (up_level),
        .down_level    (down_level),
        .left_level    (left_level),
        .right_level   (right_level),
        .center_level  (center_level),
        .touch_level   (touch_level_raw),

        .up_press      (up_press),
        .down_press    (down_press),
        .left_press    (left_press),
        .right_press   (right_press),
        .center_press  (center_press),
        .touch_press   (touch_press_raw),

        .up_release    (up_release),
        .down_release  (down_release),
        .left_release  (left_release),
        .right_release (right_release),
        .center_release(center_release),
        .touch_release (touch_release_raw)
    );

    wire touch_press;
    wire touch_release;

    assign touch_press =
        (A_GROUP_MODE != 0) ? touch_press_raw : 1'b0;
    assign touch_release =
        (A_GROUP_MODE != 0) ? touch_release_raw : 1'b0;

    //============================================================
    // 4. EC11 rotary encoder
    //============================================================
    wire ec_key_level;
    wire ec_key_press;
    wire ec_key_release;

    debounce_event #(
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (20),
        .ACTIVE_LOW  (1)
    ) u_ec_key (
        .clk          (sys_clk),
        .rst_n        (rst_n),
        .key_in       (EC_KEY),
        .key_level    (ec_key_level),
        .press_pulse  (ec_key_press),
        .release_pulse(ec_key_release)
    );

    wire ec_cw_raw;
    wire ec_ccw_raw;
    wire ec_step_raw;

    ec11_decoder #(
        .DIR_INVERT(EC_DIR_INVERT)
    ) u_ec11_direction (
        .clk      (sys_clk),
        .rst_n    (rst_n),
        .ec_a     (EC_A),
        .ec_b     (EC_B),
        .cw_pulse (ec_cw_raw),
        .ccw_pulse(ec_ccw_raw)
    );

    ec11_compat #(
        .CLK_HZ     (CLK_HZ),
        .LOCKOUT_MS (20)
    ) u_ec11_compat (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .ec_a      (EC_A),
        .ec_b      (EC_B),
        .step_pulse(ec_step_raw)
    );

    wire ec_cw;
    wire ec_ccw;
    wire ec_step;
    wire ec_event;

    assign ec_cw   = (EC_DIRECTION_MODE != 0) ? ec_cw_raw  : 1'b0;
    assign ec_ccw  = (EC_DIRECTION_MODE != 0) ? ec_ccw_raw : 1'b0;
    assign ec_step = (EC_DIRECTION_MODE == 0) ? ec_step_raw : 1'b0;
    assign ec_event= ec_cw | ec_ccw | ec_step;

    reg [4:0] ec_count;

    wire [4:0] ec_count_after_event;
    assign ec_count_after_event =
        ec_cw   ? (ec_count + 5'd1) :
        ec_ccw  ? (ec_count - 5'd1) :
        ec_step ? (ec_count + 5'd1) :
                  ec_count;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            ec_count <= 5'd0;
        end else if (ec_key_press) begin
            ec_count <= 5'd0;
        end else if (ec_event) begin
            ec_count <= ec_count_after_event;
        end
    end

    //============================================================
    // 5. Five yellow LEDs show the most recent input event
    //============================================================
    reg [4:0] led_register;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            led_register <= 5'b00000;

        end else if (touch_press) begin
            led_register <= 5'b11111;

        end else if (touch_release) begin
            led_register <= 5'b00000;

        end else if (keypad_valid) begin
            // LED[4]=1 marks a matrix-key event.
            // LED[3:0] is the 0-F key code.
            led_register <= {1'b1, keypad_code};

        end else if (up_press) begin
            led_register <= 5'b00001;

        end else if (down_press) begin
            led_register <= 5'b00010;

        end else if (left_press) begin
            led_register <= 5'b00100;

        end else if (right_press) begin
            led_register <= 5'b01000;

        end else if (center_press) begin
            led_register <= 5'b10000;

        end else if (ec_key_press) begin
            led_register <= 5'b00000;

        end else if (ec_event) begin
            led_register <= ec_count_after_event;
        end
    end

    assign led = led_register;

endmodule
