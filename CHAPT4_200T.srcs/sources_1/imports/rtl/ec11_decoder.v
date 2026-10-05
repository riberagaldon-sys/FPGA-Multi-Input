`timescale 1ns/1ps

module ec11_decoder #(
    parameter integer DIR_INVERT = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire ec_a,
    input  wire ec_b,
    output reg  cw_pulse,
    output reg  ccw_pulse
);

    (* ASYNC_REG = "TRUE" *) reg [1:0] a_sync;
    (* ASYNC_REG = "TRUE" *) reg [1:0] b_sync;

    reg [2:0] a_history;
    reg [2:0] b_history;
    reg       a_level;
    reg       b_level;

    reg [1:0] ab_previous;
    reg signed [3:0] transition_accumulator;
    reg signed [1:0] transition_delta;

    wire [2:0] a_history_next;
    wire [2:0] b_history_next;
    wire [1:0] ab_now;
    wire       invalid_jump;

    assign a_history_next = {a_history[1:0], a_sync[1]};
    assign b_history_next = {b_history[1:0], b_sync[1]};
    assign ab_now         = {a_level, b_level};
    assign invalid_jump   =
        (ab_now != ab_previous) && (transition_delta == 0);

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
            a_history <= 3'b111;
            b_history <= 3'b111;
            a_level   <= 1'b1;
            b_level   <= 1'b1;
        end else begin
            a_history <= a_history_next;
            b_history <= b_history_next;

            if (a_history_next == 3'b111)
                a_level <= 1'b1;
            else if (a_history_next == 3'b000)
                a_level <= 1'b0;

            if (b_history_next == 3'b111)
                b_level <= 1'b1;
            else if (b_history_next == 3'b000)
                b_level <= 1'b0;
        end
    end

    always @(*) begin
        transition_delta = 2'sd0;

        case ({ab_previous, ab_now})
            4'b1110,
            4'b1000,
            4'b0001,
            4'b0111:
                transition_delta = 2'sd1;

            4'b1101,
            4'b0100,
            4'b0010,
            4'b1011:
                transition_delta = -2'sd1;

            default:
                transition_delta = 2'sd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ab_previous           <= 2'b11;
            transition_accumulator<= 4'sd0;
            cw_pulse              <= 1'b0;
            ccw_pulse             <= 1'b0;
        end else begin
            cw_pulse  <= 1'b0;
            ccw_pulse <= 1'b0;

            if (invalid_jump) begin
                transition_accumulator <= 4'sd0;
            end else if (transition_delta == 2'sd1) begin
                if (transition_accumulator >= 4'sd3) begin
                    transition_accumulator <= 4'sd0;

                    if (DIR_INVERT != 0)
                        ccw_pulse <= 1'b1;
                    else
                        cw_pulse <= 1'b1;
                end else begin
                    transition_accumulator <=
                        transition_accumulator + 4'sd1;
                end
            end else if (transition_delta == -2'sd1) begin
                if (transition_accumulator <= -4'sd3) begin
                    transition_accumulator <= 4'sd0;

                    if (DIR_INVERT != 0)
                        cw_pulse <= 1'b1;
                    else
                        ccw_pulse <= 1'b1;
                end else begin
                    transition_accumulator <=
                        transition_accumulator - 4'sd1;
                end
            end

            ab_previous <= ab_now;
        end
    end

endmodule
