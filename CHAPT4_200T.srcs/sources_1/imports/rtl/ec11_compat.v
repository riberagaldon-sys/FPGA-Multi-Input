`timescale 1ns/1ps

module ec11_compat #(
    parameter integer CLK_HZ      = 50_000_000,
    parameter integer LOCKOUT_MS  = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire ec_a,
    input  wire ec_b,
    output reg  step_pulse
);

    localparam integer LOCKOUT_CYCLES_CALC =
        (CLK_HZ / 1000) * LOCKOUT_MS;
    localparam integer LOCKOUT_CYCLES =
        (LOCKOUT_CYCLES_CALC < 1) ? 1 : LOCKOUT_CYCLES_CALC;

    (* ASYNC_REG = "TRUE" *) reg [1:0] a_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] b_sync;

    reg [2:0] a_history;
    reg [2:0] b_history;
    reg       a_level;
    reg       b_level;
    reg       a_previous;
    reg       b_previous;
    reg [31:0] lockout_count;

    wire [2:0] a_history_next;
    wire [2:0] b_history_next;
    wire       a_falling;
    wire       b_falling;

    assign a_history_next = {a_history[1:0], a_sync[1]};
    assign b_history_next = {b_history[1:0], b_sync[1]};
    assign a_falling      = a_previous && !a_level;
    assign b_falling      = b_previous && !b_level;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_sync <= 2'b11;
            b_sync <= 2'b11;
        end else begin
            a_sync <= {a_sync[0], ec_a};
            b_sync <= {b_sync[0], ec_b};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_history    <= 3'b111;
            b_history    <= 3'b111;
            a_level      <= 1'b1;
            b_level      <= 1'b1;
            a_previous   <= 1'b1;
            b_previous   <= 1'b1;
            lockout_count<= 32'd0;
            step_pulse   <= 1'b0;
        end else begin
            a_history  <= a_history_next;
            b_history  <= b_history_next;
            step_pulse <= 1'b0;

            if (a_history_next == 3'b111)
                a_level <= 1'b1;
            else if (a_history_next == 3'b000)
                a_level <= 1'b0;

            if (b_history_next == 3'b111)
                b_level <= 1'b1;
            else if (b_history_next == 3'b000)
                b_level <= 1'b0;

            a_previous <= a_level;
            b_previous <= b_level;

            if (lockout_count != 32'd0) begin
                lockout_count <= lockout_count - 32'd1;
            end else if (a_falling || b_falling) begin
                step_pulse    <= 1'b1;
                lockout_count <= LOCKOUT_CYCLES - 1;
            end
        end
    end

endmodule
