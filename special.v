`timescale 1ns/1ps
module special (
    input  wire        clk,
    input  wire        enable,   // <--- добавил
    input  wire        valid,

    input  wire        sign_in,
    input  wire [4:0]  exp_in,
    input  wire [9:0]  mant_in,

    output reg         s_valid,

    output reg         is_nan,
    output reg         is_pinf,
    output reg         is_ninf,
    output reg         is_normal,
    output reg         is_subnormal,

    output reg         sign_out,
    output reg  [4:0]  exp_out,
    output reg  [9:0]  mant_out
);

    localparam [4:0] EXP_MAX = 5'b11111;

    always @(posedge clk) begin
        if (!enable) begin
            s_valid     <= 1'b0;
            is_nan      <= 1'b0;
            is_pinf     <= 1'b0;
            is_ninf     <= 1'b0;
            is_normal   <= 1'b0;
            is_subnormal<= 1'b0;
            sign_out    <= 1'b0;
            exp_out     <= 5'b0;
            mant_out    <= 10'b0;
        end else begin
            s_valid <= 1'b0;

            if (valid) begin
                sign_out <= sign_in;
                exp_out  <= exp_in;
                mant_out <= mant_in;

                is_nan <= ((exp_in == EXP_MAX) && (mant_in != 0));

                is_pinf      <= (exp_in == EXP_MAX) && (mant_in == 0) && (sign_in == 0);
                is_ninf      <= (exp_in == EXP_MAX) && (mant_in == 0) && (sign_in == 1);

                is_normal    <= (exp_in != 0) && (exp_in != EXP_MAX);
                is_subnormal <= (exp_in == 0) && (mant_in != 0);

                s_valid <= 1'b1;
            end
        end
    end

endmodule