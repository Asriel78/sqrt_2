`timescale 1ns/1ps

module normalize (
    input  wire        clk,
    input  wire        enable,
    input  wire        s_valid,
    input  wire        sign_in,
    input  wire [4:0]  exp_in,
    input  wire [9:0]  mant_in,
    input  wire        is_normal_in,
    input  wire        is_subnormal_in,
    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,
    output wire        n_valid,
    output wire        is_num,
    output wire        is_nan,
    output wire        is_pinf,
    output wire        is_ninf,
    output wire        sign_out,
    output wire signed [6:0] exp_out,
    output wire [10:0] mant_out
);

    wire sign_out_comb;
    wire signed [6:0] exp_out_comb;
    wire [10:0] mant_out_comb;
    wire is_num_comb;
    
    fp16_normalizer normalizer(
        .sign_in(sign_in),
        .exp_in(exp_in),
        .mant_in(mant_in),
        .is_normal_in(is_normal_in),
        .is_subnormal_in(is_subnormal_in),
        .is_nan_in(is_nan_in),
        .is_pinf_in(is_pinf_in),
        .is_ninf_in(is_ninf_in),
        .sign_out(sign_out_comb),
        .exp_out(exp_out_comb),
        .mant_out(mant_out_comb),
        .is_num(is_num_comb)
    );
    
    wire capture;
    and(capture, s_valid, enable);
    
    wire n_valid_d;
    mux2 valid_mux(.a(1'b0), .b(capture), .sel(enable), .out(n_valid_d));
    dff valid_ff(.clk(clk), .d(n_valid_d), .q(n_valid));
    
    dff_with_capture_enable is_num_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_num_comb),
        .q_out(is_num)
    );
    
    dff_with_capture_enable is_nan_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_nan_in),
        .q_out(is_nan)
    );
    
    dff_with_capture_enable is_pinf_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_pinf_in),
        .q_out(is_pinf)
    );
    
    dff_with_capture_enable is_ninf_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_ninf_in),
        .q_out(is_ninf)
    );
    
    dff_with_capture_enable sign_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(sign_out_comb),
        .q_out(sign_out)
    );
    
    register_with_capture_enable #(.WIDTH(7)) exp_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(exp_out_comb),
        .q_out(exp_out)
    );
    
    register_with_capture_enable #(.WIDTH(11)) mant_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(mant_out_comb),
        .q_out(mant_out)
    );

endmodule