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

    output wire        p_valid,
    output wire        result_out,
    output wire [15:0] out_data,

    output wire        is_nan_out,
    output wire        is_pinf_out,
    output wire        is_ninf_out
);

    wire [15:0] out_data_comb;
    
    fp16_packer packer(
        .sign_in(sign_in),
        .exp_in(exp_in),
        .mant_in(mant_in),
        .is_nan_in(is_nan_in),
        .is_pinf_in(is_pinf_in),
        .is_ninf_in(is_ninf_in),
        .out_data(out_data_comb)
    );

    wire capture;
    and(capture, it_valid, enable);
    
    wire p_valid_d;
    mux2 p_valid_mux(.a(1'b0), .b(capture), .sel(enable), .out(p_valid_d));
    dff p_valid_ff(.clk(clk), .d(p_valid_d), .q(p_valid));
    
    dff_with_capture_enable result_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(result_in),
        .q_out(result_out)
    );
    
    register_with_capture_enable #(.WIDTH(16)) data_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(out_data_comb),
        .q_out(out_data)
    );
    
    dff_with_capture_enable nan_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_nan_in),
        .q_out(is_nan_out)
    );
    
    dff_with_capture_enable pinf_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_pinf_in),
        .q_out(is_pinf_out)
    );
    
    dff_with_capture_enable ninf_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_ninf_in),
        .q_out(is_ninf_out)
    );

endmodule