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
    localparam signed [6:0] BIAS = 7'd15;
    wire exp_is_zero, mant_is_zero, is_zero;
    is_zero_n #(.WIDTH(5)) exp_zero_check(.in(exp_in), .is_zero(exp_is_zero));
    is_zero_n #(.WIDTH(10)) mant_zero_check(.in(mant_in), .is_zero(mant_is_zero));
    and(is_zero, exp_is_zero, mant_is_zero);
    wire [3:0] clz;
    assign clz = 
        mant_in[9] ? 4'd0 : mant_in[8] ? 4'd1 : mant_in[7] ? 4'd2 :
        mant_in[6] ? 4'd3 : mant_in[5] ? 4'd4 : mant_in[4] ? 4'd5 :
        mant_in[3] ? 4'd6 : mant_in[2] ? 4'd7 : mant_in[1] ? 4'd8 :
        mant_in[0] ? 4'd9 : 4'd10;
    wire [10:0] normal_mant;
    wire signed [6:0] normal_exp;
    wire signed [6:0] exp_extended;
    assign normal_mant = {1'b1, mant_in};
    assign exp_extended = {2'b00, exp_in};
    wire [6:0] bias_7bit = 7'd15;
    wire [6:0] bias_negated;
    wire cout_bias;
    genvar i;
    generate
        for (i = 0; i < 7; i = i + 1) begin : bias_inv
            not(bias_negated[i], bias_7bit[i]);
        end
    endgenerate
    adder_n #(.WIDTH(7)) exp_sub(.a(exp_extended), .b(bias_negated), .cin(1'b1), .sum(normal_exp), .cout(cout_bias));
    wire [10:0] subnorm_mant;
    wire signed [6:0] subnorm_exp;
    wire [3:0] clz_plus_1;
    wire cout_clz;
    adder_n #(.WIDTH(4)) clz_inc(.a(clz), .b(4'd1), .cin(1'b0), .sum(clz_plus_1), .cout(cout_clz));
    wire [10:0] mant_to_shift;
    assign mant_to_shift = {1'b0, mant_in};
    wire [10:0] mant_shifted;
    barrel_shift_left_11bit shifter(.in(mant_to_shift), .shift_amt(clz_plus_1), .out(mant_shifted));
    assign subnorm_mant = mant_shifted;
    wire signed [6:0] minus_15 = -7'd15;
    wire signed [6:0] clz_extended = {3'b000, clz};
    wire signed [6:0] clz_negated;
    wire cout_clz_exp;
    generate
        for (i = 0; i < 7; i = i + 1) begin : clz_inv
            not(clz_negated[i], clz_extended[i]);
        end
    endgenerate
    adder_n #(.WIDTH(7)) subnorm_exp_calc(.a(minus_15), .b(clz_negated), .cin(1'b1), .sum(subnorm_exp), .cout(cout_clz_exp));
    wire [10:0] mant_out_comb;
    wire signed [6:0] exp_out_comb;
    wire sign_out_comb;
    wire is_num_comb;
    wire is_nan_comb, is_pinf_comb, is_ninf_comb;
    wire [10:0] mant_choice1, mant_choice2;
    wire signed [6:0] exp_choice1, exp_choice2;
    mux2_n #(.WIDTH(11)) mant_mux1(.a(11'd0), .b(normal_mant), .sel(is_normal_in), .out(mant_choice1));
    mux2_n #(.WIDTH(7)) exp_mux1(.a(-7'd15), .b(normal_exp), .sel(is_normal_in), .out(exp_choice1));
    wire zero_or_normal;
    or(zero_or_normal, is_zero, is_normal_in);
    mux2_n #(.WIDTH(11)) mant_mux2(.a(subnorm_mant), .b(mant_choice1), .sel(zero_or_normal), .out(mant_choice2));
    mux2_n #(.WIDTH(7)) exp_mux2(.a(subnorm_exp), .b(exp_choice1), .sel(zero_or_normal), .out(exp_choice2));
    wire is_any_special;
    or(is_any_special, is_nan_in, is_pinf_in, is_ninf_in);
    wire not_is_any_special;
    not(not_is_any_special, is_any_special);
    mux2_n #(.WIDTH(11)) mant_mux3(.a({1'b0, mant_in}), .b(mant_choice2), .sel(not_is_any_special), .out(mant_out_comb));
    mux2_n #(.WIDTH(7)) exp_mux3(.a(exp_extended), .b(exp_choice2), .sel(not_is_any_special), .out(exp_out_comb));
    assign sign_out_comb = sign_in;
    not(is_num_comb, is_any_special);
    assign is_nan_comb = is_nan_in;
    assign is_pinf_comb = is_pinf_in;
    assign is_ninf_comb = is_ninf_in;
    wire capture;
    and(capture, s_valid, enable);
    wire n_valid_d;
    mux2 valid_mux(.a(1'b0), .b(capture), .sel(enable), .out(n_valid_d));
    dff valid_ff(.clk(clk), .d(n_valid_d), .q(n_valid));
    wire is_num_d, is_nan_d, is_pinf_d, is_ninf_d;
    mux2 is_num_mux(.a(is_num), .b(is_num_comb), .sel(capture), .out(is_num_d));
    mux2 is_nan_mux(.a(is_nan), .b(is_nan_comb), .sel(capture), .out(is_nan_d));
    mux2 is_pinf_mux(.a(is_pinf), .b(is_pinf_comb), .sel(capture), .out(is_pinf_d));
    mux2 is_ninf_mux(.a(is_ninf), .b(is_ninf_comb), .sel(capture), .out(is_ninf_d));
    wire is_num_final, is_nan_final, is_pinf_final, is_ninf_final;
    mux2 is_num_en(.a(1'b0), .b(is_num_d), .sel(enable), .out(is_num_final));
    mux2 is_nan_en(.a(1'b0), .b(is_nan_d), .sel(enable), .out(is_nan_final));
    mux2 is_pinf_en(.a(1'b0), .b(is_pinf_d), .sel(enable), .out(is_pinf_final));
    mux2 is_ninf_en(.a(1'b0), .b(is_ninf_d), .sel(enable), .out(is_ninf_final));
    dff is_num_ff(.clk(clk), .d(is_num_final), .q(is_num));
    dff is_nan_ff(.clk(clk), .d(is_nan_final), .q(is_nan));
    dff is_pinf_ff(.clk(clk), .d(is_pinf_final), .q(is_pinf));
    dff is_ninf_ff(.clk(clk), .d(is_ninf_final), .q(is_ninf));
    wire sign_out_d;
    wire [6:0] exp_out_d;
    wire [10:0] mant_out_d;
    mux2 sign_mux(.a(sign_out), .b(sign_out_comb), .sel(capture), .out(sign_out_d));
    mux2_n #(.WIDTH(7)) exp_mux(.a(exp_out), .b(exp_out_comb), .sel(capture), .out(exp_out_d));
    mux2_n #(.WIDTH(11)) mant_mux(.a(mant_out), .b(mant_out_comb), .sel(capture), .out(mant_out_d));
    wire sign_out_final;
    wire [6:0] exp_out_final;
    wire [10:0] mant_out_final;
    mux2 sign_en(.a(1'b0), .b(sign_out_d), .sel(enable), .out(sign_out_final));
    mux2_n #(.WIDTH(7)) exp_en(.a(7'b0), .b(exp_out_d), .sel(enable), .out(exp_out_final));
    mux2_n #(.WIDTH(11)) mant_en(.a(11'b0), .b(mant_out_d), .sel(enable), .out(mant_out_final));
    dff sign_ff(.clk(clk), .d(sign_out_final), .q(sign_out));
    register_n #(.WIDTH(7)) exp_reg(.clk(clk), .rst(1'b0), .d(exp_out_final), .q(exp_out));
    register_n #(.WIDTH(11)) mant_reg(.clk(clk), .rst(1'b0), .d(mant_out_final), .q(mant_out));
endmodule