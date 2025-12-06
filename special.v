`timescale 1ns/1ps
module special (
    input  wire        clk,
    input  wire        enable,
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
    localparam [9:0] QUIET_BIT = 10'b1000000000;  

    wire is_input_nan;
    wire is_negative_number;
    
    assign is_input_nan = (exp_in == EXP_MAX) && (mant_in != 0);
    assign is_negative_number = sign_in && (exp_in != EXP_MAX) && ((exp_in != 0) || (mant_in != 0));

    always @(posedge clk) begin
        if (!enable) begin
            s_valid      <= 1'b0;
            is_nan       <= 1'b0;
            is_pinf      <= 1'b0;
            is_ninf      <= 1'b0;
            is_normal    <= 1'b0;
            is_subnormal <= 1'b0;
            sign_out     <= 1'b0;
            exp_out      <= 5'b0;
            mant_out     <= 10'b0;
        end else begin
            s_valid <= 1'b0;

            if (valid) begin
                sign_out <= sign_in;
                exp_out  <= exp_in;
                mant_out <= mant_in;

                if (is_input_nan) begin
                    is_nan       <= 1'b1;
                    is_pinf      <= 1'b0;
                    is_ninf      <= 1'b0;
                    is_normal    <= 1'b0;
                    is_subnormal <= 1'b0;
                    sign_out <= sign_in;  
                    exp_out  <= EXP_MAX;
                    mant_out <= mant_in | QUIET_BIT; 
                end
                else if (is_negative_number) begin
                    is_nan       <= 1'b1;
                    is_pinf      <= 1'b0;
                    is_ninf      <= 1'b0;
                    is_normal    <= 1'b0;
                    is_subnormal <= 1'b0;
                    
                    sign_out <= 1'b1;
                    exp_out  <= EXP_MAX;
                    mant_out <= QUIET_BIT;
                end
                
                else if ((exp_in == EXP_MAX) && (mant_in == 0) && (sign_in == 0)) begin
                    is_nan       <= 1'b0;
                    is_pinf      <= 1'b1;
                    is_ninf      <= 1'b0;
                    is_normal    <= 1'b0;
                    is_subnormal <= 1'b0;
                end
                
                else if ((exp_in == EXP_MAX) && (mant_in == 0) && (sign_in == 1)) begin
                    is_nan       <= 1'b0;
                    is_pinf      <= 1'b0;
                    is_ninf      <= 1'b1;
                    is_normal    <= 1'b0;
                    is_subnormal <= 1'b0;
                end
                
                else if ((exp_in != 0) && (exp_in != EXP_MAX)) begin
                    is_nan       <= 1'b0;
                    is_pinf      <= 1'b0;
                    is_ninf      <= 1'b0;
                    is_normal    <= 1'b1;
                    is_subnormal <= 1'b0;
                end
                else begin
                    is_nan       <= 1'b0;
                    is_pinf      <= 1'b0;
                    is_ninf      <= 1'b0;
                    is_normal    <= 1'b0;
                    is_subnormal <= (mant_in != 0);  
                end

                s_valid <= 1'b1;
            end
        end
    end

endmodule
