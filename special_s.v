`timescale 1ns/1ps

module special (
    input  wire        clk,
    input  wire        enable,
    input  wire        valid,

    input  wire        sign_in,
    input  wire [4:0]  exp_in,
    input  wire [9:0]  mant_in,

    output wire        s_valid,

    output wire        is_nan,
    output wire        is_pinf,
    output wire        is_ninf,
    output wire        is_normal,
    output wire        is_subnormal,

    output wire        sign_out,
    output wire [4:0]  exp_out,
    output wire [9:0]  mant_out
);

    wire is_zero_detected, is_nan_detected, is_inf_detected;
    wire is_normal_detected, is_subnormal_detected;
    
    fp16_special_detector detector(
        .exp_in(exp_in),
        .mant_in(mant_in),
        .sign_in(sign_in),
        .is_zero(is_zero_detected),
        .is_nan(is_nan_detected),
        .is_inf(is_inf_detected),
        .is_normal(is_normal_detected),
        .is_subnormal(is_subnormal_detected)
    );
    
    wire is_nan_output, is_pinf_output, is_ninf_output;
    wire sign_output;
    wire [4:0] exp_output;
    wire [9:0] mant_output;
    
    fp16_special_handler handler(
        .sign_in(sign_in),
        .exp_in(exp_in),
        .mant_in(mant_in),
        .is_zero_detected(is_zero_detected),
        .is_nan_detected(is_nan_detected),
        .is_inf_detected(is_inf_detected),
        .is_nan_out(is_nan_output),
        .is_pinf_out(is_pinf_output),
        .is_ninf_out(is_ninf_output),
        .sign_out(sign_output),
        .exp_out(exp_output),
        .mant_out(mant_output)
    );
    
    wire capture;
    and(capture, valid, enable);
    
    wire s_valid_d;
    mux2 valid_gate(.a(1'b0), .b(capture), .sel(enable), .out(s_valid_d));
    dff valid_reg(.clk(clk), .d(s_valid_d), .q(s_valid));
    
    dff_with_capture_enable nan_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_nan_output),
        .q_out(is_nan)
    );
    
    dff_with_capture_enable pinf_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_pinf_output),
        .q_out(is_pinf)
    );
    
    dff_with_capture_enable ninf_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_ninf_output),
        .q_out(is_ninf)
    );
    
    dff_with_capture_enable normal_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_normal_detected),
        .q_out(is_normal)
    );
    
    dff_with_capture_enable subnormal_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(is_subnormal_detected),
        .q_out(is_subnormal)
    );
    
    dff_with_capture_enable sign_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(sign_output),
        .q_out(sign_out)
    );
    
    register_with_capture_enable #(.WIDTH(5)) exp_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(exp_output),
        .q_out(exp_out)
    );
    
    register_with_capture_enable #(.WIDTH(10)) mant_reg(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .d_in(mant_output),
        .q_out(mant_out)
    );

endmodule