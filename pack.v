`timescale 1ns/1ps
module pack (
    input  wire        clk,
    input  wire        enable,
    input  wire        it_valid,

    input  wire        sign_in,
    input  wire signed [6:0] exp_in,
    input  wire [10:0] mant_in,

    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,

    input  wire        result_in,

    output reg         p_valid,
    output reg         result_out,
    output reg [15:0]  out_data,

    output reg         is_nan_out,
    output reg         is_pinf_out,
    output reg         is_ninf_out
);

    localparam signed [6:0] BIAS = 15;

    reg signed [6:0] e_biased;
    reg [9:0] frac10;
    reg [10:0] shifted;
    reg [4:0] shift_amt;

    always @(posedge clk) begin
        if (!enable) begin
            p_valid     <= 1'b0;
            result_out  <= 1'b0;
            out_data    <= 16'h0000;

            is_nan_out  <= 1'b0;
            is_pinf_out <= 1'b0;
            is_ninf_out <= 1'b0;
        end else begin
            p_valid <= 1'b0;

            if (it_valid) begin
                result_out <= result_in;

                is_nan_out  <= is_nan_in;
                is_pinf_out <= is_pinf_in;
                is_ninf_out <= is_ninf_in;

                if (is_nan_in) begin
                    out_data <= {1'b1, 5'b11111, 10'b1000000000};
                end
                

                else if (is_pinf_in) begin
                    out_data <= 16'h7C00; 
                end
                
                else if (is_ninf_in) begin
                    out_data <= 16'hFE00;  
                end
                
                else begin
                    e_biased = exp_in + BIAS;

                    if (exp_in == -7'sd15 && mant_in == 11'd0) begin
                        out_data <= {sign_in, 5'b00000, 10'b0000000000};
                    end
                    else if (e_biased <= 0) begin
                        shift_amt = 1 - e_biased;
                        if (shift_amt >= 12)
                            frac10 = 10'b0;
                        else begin
                            shifted = mant_in >> shift_amt;
                            frac10 = shifted[9:0];
                        end
                        out_data <= {sign_in, 5'b00000, frac10};
                    end
                    else begin
                        frac10 = mant_in[9:0];
                        out_data <= {sign_in, e_biased[4:0], frac10};
                    end
                end

                p_valid <= 1'b1;
            end
        end
    end
endmodule