`timescale 1ns/1ps

module fiveway_touch_input #(
    parameter integer CLK_HZ            = 50_000_000,
    parameter integer KEY_DEBOUNCE_MS   = 20,
    parameter integer TOUCH_FILTER_MS   = 8,
    parameter integer TOUCH_ACTIVE_LOW  = 0
)(
    input  wire clk,
    input  wire rst_n,

    input  wire s1_keya,
    input  wire s1_keyb,
    input  wire s1_keyc,
    input  wire s1_keyd,
    input  wire s1_keyp,

    input  wire touch_in,

    output wire up_level,
    output wire down_level,
    output wire left_level,
    output wire right_level,
    output wire center_level,
    output wire touch_level,

    output wire up_press,
    output wire down_press,
    output wire left_press,
    output wire right_press,
    output wire center_press,
    output wire touch_press,

    output wire up_release,
    output wire down_release,
    output wire left_release,
    output wire right_release,
    output wire center_release,
    output wire touch_release
);

    // Verified physical direction mapping on this GX-BIDT board:
    // S1_KEYA = RIGHT
    // S1_KEYB = DOWN
    // S1_KEYC = UP
    // S1_KEYD = LEFT
    // S1_KEYP = CENTER

    debounce_event #(
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (KEY_DEBOUNCE_MS),
        .ACTIVE_LOW  (1)
    ) u_up (
        .clk          (clk),
        .rst_n        (rst_n),
        .key_in       (s1_keyc),
        .key_level    (up_level),
        .press_pulse  (up_press),
        .release_pulse(up_release)
    );

    debounce_event #(
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (KEY_DEBOUNCE_MS),
        .ACTIVE_LOW  (1)
    ) u_down (
        .clk          (clk),
        .rst_n        (rst_n),
        .key_in       (s1_keyb),
        .key_level    (down_level),
        .press_pulse  (down_press),
        .release_pulse(down_release)
    );

    debounce_event #(
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (KEY_DEBOUNCE_MS),
        .ACTIVE_LOW  (1)
    ) u_left (
        .clk          (clk),
        .rst_n        (rst_n),
        .key_in       (s1_keyd),
        .key_level    (left_level),
        .press_pulse  (left_press),
        .release_pulse(left_release)
    );

    debounce_event #(
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (KEY_DEBOUNCE_MS),
        .ACTIVE_LOW  (1)
    ) u_right (
        .clk          (clk),
        .rst_n        (rst_n),
        .key_in       (s1_keya),
        .key_level    (right_level),
        .press_pulse  (right_press),
        .release_pulse(right_release)
    );

    debounce_event #(
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (KEY_DEBOUNCE_MS),
        .ACTIVE_LOW  (1)
    ) u_center (
        .clk          (clk),
        .rst_n        (rst_n),
        .key_in       (s1_keyp),
        .key_level    (center_level),
        .press_pulse  (center_press),
        .release_pulse(center_release)
    );

    debounce_event #(
        .CLK_HZ      (CLK_HZ),
        .DEBOUNCE_MS (TOUCH_FILTER_MS),
        .ACTIVE_LOW  (TOUCH_ACTIVE_LOW)
    ) u_touch (
        .clk          (clk),
        .rst_n        (rst_n),
        .key_in       (touch_in),
        .key_level    (touch_level),
        .press_pulse  (touch_press),
        .release_pulse(touch_release)
    );

endmodule
