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

    localparam signed [6:0] BIAS = 7'd15;

    wire signed [6:0] exp_biased;
    wire [6:0] bias_unsigned = 7'd15;
    wire cout_bias;
    
    adder_n #(.WIDTH(7)) exp_add_bias(
        .a(exp_in),
        .b(bias_unsigned),
        .cin(1'b0),
        .sum(exp_biased),
        .cout(cout_bias)
    );

    wire exp_is_minus15;
    wire [6:0] minus15_pattern = 7'b1110001;
    comparator_eq_n #(.WIDTH(7)) exp_m15_cmp(
        .a(exp_in),
        .b(minus15_pattern),
        .eq(exp_is_minus15)
    );
    
    wire mant_is_zero;
    is_zero_n #(.WIDTH(11)) mant_zero_check(
        .in(mant_in),
        .is_zero(mant_is_zero)
    );
    
    wire is_zero;
    and(is_zero, exp_is_minus15, mant_is_zero);
    
    wire exp_biased_le_zero;
    wire exp_biased_is_zero;
    wire exp_biased_is_negative;
    
    is_zero_n #(.WIDTH(7)) exp_biased_zero_check(
        .in(exp_biased),
        .is_zero(exp_biased_is_zero)
    );
    
    assign exp_biased_is_negative = exp_biased[6];
    
    or(exp_biased_le_zero, exp_biased_is_zero, exp_biased_is_negative);

    wire signed [6:0] one_minus_exp;
    wire [6:0] exp_biased_negated;
    wire cout_one_minus;
    
    genvar i;
    generate
        for (i = 0; i < 7; i = i + 1) begin : exp_neg
            not(exp_biased_negated[i], exp_biased[i]);
        end
    endgenerate
    
    adder_n #(.WIDTH(7)) one_minus_exp_calc(
        .a(7'd1),
        .b(exp_biased_negated),
        .cin(1'b1),
        .sum(one_minus_exp),
        .cout(cout_one_minus)
    );
    
    wire [4:0] shift_amt;
    assign shift_amt = one_minus_exp[4:0];
    
    wire shift_overflow;
    comparator_gte_n #(.WIDTH(5)) shift_overflow_check(
        .a(shift_amt),
        .b(5'd12),
        .gte(shift_overflow)
    );
    
    wire [10:0] mant_shifted;
    barrel_shift_right_11bit mant_shifter(
        .in(mant_in),
        .shift_amt(shift_amt[3:0]),
        .out(mant_shifted)
    );
    
    wire [9:0] frac10_subnormal;
    mux2_n #(.WIDTH(10)) subnorm_frac_mux(
        .a(10'b0),
        .b(mant_shifted[9:0]),
        .sel(shift_overflow),
        .out(frac10_subnormal)
    );

    wire [9:0] frac10_normal;
    assign frac10_normal = mant_in[9:0];

    wire [15:0] out_data_comb;
    
    wire [15:0] nan_pattern = 16'hFE00;
    wire [15:0] pinf_pattern = 16'h7C00;
    
    wire [15:0] special_value;
    wire [15:0] number_value;
    
    mux2_n #(.WIDTH(16)) special_mux(
        .a(pinf_pattern),
        .b(nan_pattern),
        .sel(is_nan_in),
        .out(special_value)
    );
    
    wire [15:0] zero_value;
    wire [15:0] subnorm_value;
    wire [15:0] normal_value;
    
    assign zero_value = {sign_in, 15'b0};
    assign subnorm_value = {sign_in, 5'b00000, frac10_subnormal};
    assign normal_value = {sign_in, exp_biased[4:0], frac10_normal};
    
    wire [15:0] non_zero_value;
    mux2_n #(.WIDTH(16)) subnorm_normal_mux(
        .a(normal_value),
        .b(subnorm_value),
        .sel(exp_biased_le_zero),
        .out(non_zero_value)
    );
    
    mux2_n #(.WIDTH(16)) zero_nonzero_mux(
        .a(non_zero_value),
        .b(zero_value),
        .sel(is_zero),
        .out(number_value)
    );
    
    wire is_any_special;
    or(is_any_special, is_nan_in, is_pinf_in, is_ninf_in);
    
    mux2_n #(.WIDTH(16)) final_mux(
        .a(number_value),
        .b(special_value),
        .sel(is_any_special),
        .out(out_data_comb)
    );

    wire capture;
    and(capture, it_valid, enable);
    
    wire p_valid_d;
    mux2 p_valid_mux(.a(1'b0), .b(capture), .sel(enable), .out(p_valid_d));
    dff p_valid_ff(.clk(clk), .d(p_valid_d), .q(p_valid));
    
    wire result_out_d;
    mux2 result_mux(.a(result_out), .b(result_in), .sel(capture), .out(result_out_d));
    wire result_out_final;
    mux2 result_en_mux(.a(1'b0), .b(result_out_d), .sel(enable), .out(result_out_final));
    dff result_ff(.clk(clk), .d(result_out_final), .q(result_out));
    
    wire [15:0] out_data_d;
    mux2_n #(.WIDTH(16)) out_data_mux(.a(out_data), .b(out_data_comb), .sel(capture), .out(out_data_d));
    wire [15:0] out_data_final;
    mux2_n #(.WIDTH(16)) out_data_en_mux(.a(16'h0000), .b(out_data_d), .sel(enable), .out(out_data_final));
    register_n #(.WIDTH(16)) out_data_reg(.clk(clk), .rst(1'b0), .d(out_data_final), .q(out_data));
    
    wire is_nan_out_d, is_pinf_out_d, is_ninf_out_d;
    mux2 nan_out_mux(.a(is_nan_out), .b(is_nan_in), .sel(capture), .out(is_nan_out_d));
    mux2 pinf_out_mux(.a(is_pinf_out), .b(is_pinf_in), .sel(capture), .out(is_pinf_out_d));
    mux2 ninf_out_mux(.a(is_ninf_out), .b(is_ninf_in), .sel(capture), .out(is_ninf_out_d));
    
    wire is_nan_out_final, is_pinf_out_final, is_ninf_out_final;
    mux2 nan_en_mux(.a(1'b0), .b(is_nan_out_d), .sel(enable), .out(is_nan_out_final));
    mux2 pinf_en_mux(.a(1'b0), .b(is_pinf_out_d), .sel(enable), .out(is_pinf_out_final));
    mux2 ninf_en_mux(.a(1'b0), .b(is_ninf_out_d), .sel(enable), .out(is_ninf_out_final));
    
    dff nan_out_ff(.clk(clk), .d(is_nan_out_final), .q(is_nan_out));
    dff pinf_out_ff(.clk(clk), .d(is_pinf_out_final), .q(is_pinf_out));
    dff ninf_out_ff(.clk(clk), .d(is_ninf_out_final), .q(is_ninf_out));

endmodule