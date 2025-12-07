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

    wire [4:0] EXP_MAX = 5'b11111;
    wire [9:0] QUIET_BIT = 10'b1000000000;
    
    wire exp_all_ones;
    wire mant_nonzero;
    wire is_input_nan_comb;
    wire is_zero_exp;
    wire is_zero_all;
    wire is_negative_number_comb;
    
    comparator_eq_n #(.WIDTH(5)) exp_max_cmp(
        .a(exp_in), 
        .b(5'b11111), 
        .eq(exp_all_ones)
    );
    
    is_zero_n #(.WIDTH(10)) mant_zero_check(
        .in(mant_in), 
        .is_zero(is_zero_all)
    );
    not(mant_nonzero, is_zero_all);
    
    and(is_input_nan_comb, exp_all_ones, mant_nonzero);
    
    is_zero_n #(.WIDTH(5)) exp_zero_check(
        .in(exp_in), 
        .is_zero(is_zero_exp)
    );
    
    wire not_special;
    wire has_value;
    wire exp_or_mant;
    
    not(not_special, exp_all_ones);
    or(exp_or_mant, |exp_in, |mant_in);
    and(has_value, not_special, exp_or_mant);
    and(is_negative_number_comb, sign_in, has_value);
    
    wire is_pinf_comb, is_ninf_comb, is_normal_comb, is_subnormal_comb;
    wire is_nan_final;
    
    wire mant_is_zero;
    is_zero_n #(.WIDTH(10)) mant_z(
        .in(mant_in), 
        .is_zero(mant_is_zero)
    );
    wire sign_in_n;
    not(sign_in_n, sign_in);
    wire pinf_cond1, pinf_cond2;
    and(pinf_cond1, exp_all_ones, mant_is_zero);
    and(is_pinf_comb, pinf_cond1, sign_in_n);
    
    and(pinf_cond2, exp_all_ones, mant_is_zero);
    and(is_ninf_comb, pinf_cond2, sign_in);
    
    or(is_nan_final, is_input_nan_comb, is_negative_number_comb);
    
    wire exp_nonzero, exp_not_max;
    not(exp_nonzero, is_zero_exp);
    not(exp_not_max, exp_all_ones);
    and(is_normal_comb, exp_nonzero, exp_not_max);
    
    and(is_subnormal_comb, is_zero_exp, mant_nonzero);
    
    wire [4:0] exp_out_comb;
    wire [9:0] mant_out_comb;
    wire sign_out_comb;
    
    wire [4:0] nan_exp;
    wire [9:0] nan_mant;
    wire [9:0] mant_with_quiet;
    
    assign nan_exp = 5'b11111;
    
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : mant_quiet_gen
            if (i == 9)
                assign mant_with_quiet[i] = 1'b1;
            else
                or(mant_with_quiet[i], mant_in[i], (i == 9 ? 1'b1 : 1'b0));
        end
    endgenerate
    
    mux2_n #(.WIDTH(10)) nan_mant_mux(
        .a(QUIET_BIT),
        .b(mant_in | QUIET_BIT),
        .sel(is_input_nan_comb),
        .out(nan_mant)
    );
    
    wire sign_for_nan;
    mux2 sign_nan_mux(
        .a(1'b1),
        .b(sign_in),
        .sel(is_input_nan_comb),
        .out(sign_for_nan)
    );
    
    mux2_n #(.WIDTH(5)) exp_final_mux(
        .a(exp_in),
        .b(nan_exp),
        .sel(is_nan_final),
        .out(exp_out_comb)
    );
    
    mux2_n #(.WIDTH(10)) mant_final_mux(
        .a(mant_in),
        .b(nan_mant),
        .sel(is_nan_final),
        .out(mant_out_comb)
    );
    
    mux2 sign_final_mux(
        .a(sign_in),
        .b(sign_for_nan),
        .sel(is_nan_final),
        .out(sign_out_comb)
    );
    
    wire capture;
    and(capture, valid, enable);
    
    wire s_valid_next;
    wire s_valid_d;
    
    mux2 valid_mux(
        .a(1'b0),
        .b(capture),
        .sel(enable),
        .out(s_valid_d)
    );
    
    dff valid_ff(
        .clk(clk),
        .d(s_valid_d),
        .q(s_valid)
    );
    
    wire is_nan_d, is_pinf_d, is_ninf_d, is_normal_d, is_subnormal_d;
    wire sign_out_d;
    wire [4:0] exp_out_d;
    wire [9:0] mant_out_d;
    
    mux2 nan_reg_mux(.a(is_nan), .b(is_nan_final), .sel(capture), .out(is_nan_d));
    mux2 pinf_reg_mux(.a(is_pinf), .b(is_pinf_comb), .sel(capture), .out(is_pinf_d));
    mux2 ninf_reg_mux(.a(is_ninf), .b(is_ninf_comb), .sel(capture), .out(is_ninf_d));
    mux2 normal_reg_mux(.a(is_normal), .b(is_normal_comb), .sel(capture), .out(is_normal_d));
    mux2 subnorm_reg_mux(.a(is_subnormal), .b(is_subnormal_comb), .sel(capture), .out(is_subnormal_d));
    mux2 sign_reg_mux(.a(sign_out), .b(sign_out_comb), .sel(capture), .out(sign_out_d));
    mux2_n #(.WIDTH(5)) exp_reg_mux(.a(exp_out), .b(exp_out_comb), .sel(capture), .out(exp_out_d));
    mux2_n #(.WIDTH(10)) mant_reg_mux(.a(mant_out), .b(mant_out_comb), .sel(capture), .out(mant_out_d));
    
    wire is_nan_final_d, is_pinf_final_d, is_ninf_final_d, is_normal_final_d, is_subnormal_final_d;
    wire sign_out_final_d;
    wire [4:0] exp_out_final_d;
    wire [9:0] mant_out_final_d;
    
    mux2 nan_en_mux(.a(1'b0), .b(is_nan_d), .sel(enable), .out(is_nan_final_d));
    mux2 pinf_en_mux(.a(1'b0), .b(is_pinf_d), .sel(enable), .out(is_pinf_final_d));
    mux2 ninf_en_mux(.a(1'b0), .b(is_ninf_d), .sel(enable), .out(is_ninf_final_d));
    mux2 normal_en_mux(.a(1'b0), .b(is_normal_d), .sel(enable), .out(is_normal_final_d));
    mux2 subnorm_en_mux(.a(1'b0), .b(is_subnormal_d), .sel(enable), .out(