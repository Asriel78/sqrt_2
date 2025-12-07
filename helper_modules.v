`timescale 1ns/1ps

module register_with_capture_enable #(parameter WIDTH = 8) (
    input  wire clk,
    input  wire enable,
    input  wire capture,
    input  wire [WIDTH-1:0] d_in,
    output wire [WIDTH-1:0] q_out
);
    wire [WIDTH-1:0] captured, final_data;
    
    mux2_n #(.WIDTH(WIDTH)) capture_mux(
        .a(q_out),
        .b(d_in),
        .sel(capture),
        .out(captured)
    );
    
    mux2_n #(.WIDTH(WIDTH)) enable_mux(
        .a({WIDTH{1'b0}}),
        .b(captured),
        .sel(enable),
        .out(final_data)
    );
    
    register_n #(.WIDTH(WIDTH)) reg_inst(
        .clk(clk),
        .rst(1'b0),
        .d(final_data),
        .q(q_out)
    );
endmodule

module dff_with_capture_enable (
    input  wire clk,
    input  wire enable,
    input  wire capture,
    input  wire d_in,
    output wire q_out
);
    wire captured, final_data;
    
    mux2 capture_mux(
        .a(q_out),
        .b(d_in),
        .sel(capture),
        .out(captured)
    );
    
    mux2 enable_mux(
        .a(1'b0),
        .b(captured),
        .sel(enable),
        .out(final_data)
    );
    
    dff dff_inst(
        .clk(clk),
        .d(final_data),
        .q(q_out)
    );
endmodule


module first_cycle_detector (
    input  wire clk,
    input  wire enable,
    output wire first_cycle
);
    wire prev_enable, prev_enable_n, prev_enable_d;
    
    not(prev_enable_n, prev_enable);
    and(first_cycle, enable, prev_enable_n);
    
    mux2 prev_mux(
        .a(1'b0),
        .b(enable),
        .sel(enable),
        .out(prev_enable_d)
    );
    
    dff prev_ff(
        .clk(clk),
        .d(prev_enable_d),
        .q(prev_enable)
    );
endmodule


module subtract_with_bias_n #(parameter WIDTH = 7) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] bias,
    output wire [WIDTH-1:0] result,
    output wire cout
);
    wire [WIDTH-1:0] bias_neg;
    
    negate_n #(.WIDTH(WIDTH)) neg(.in(bias), .out(bias_neg));
    adder_n #(.WIDTH(WIDTH)) sub(
        .a(a), 
        .b(bias_neg), 
        .cin(1'b1), 
        .sum(result), 
        .cout(cout)
    );
endmodule



module fp16_special_detector (
    input  wire [4:0] exp_in,
    input  wire [9:0] mant_in,
    input  wire sign_in,
    
    output wire is_zero,
    output wire is_nan,
    output wire is_inf,
    output wire is_normal,
    output wire is_subnormal
);
    wire exp_all_ones, exp_all_zeros;
    wire mant_is_zero, mant_nonzero;
    
    comparator_eq_n #(.WIDTH(5)) exp_max_check(
        .a(exp_in), 
        .b(5'b11111), 
        .eq(exp_all_ones)
    );
    
    is_zero_n #(.WIDTH(5)) exp_zero_check(
        .in(exp_in), 
        .is_zero(exp_all_zeros)
    );
    
    is_zero_n #(.WIDTH(10)) mant_zero_check(
        .in(mant_in), 
        .is_zero(mant_is_zero)
    );
    
    not(mant_nonzero, mant_is_zero);
    
    and(is_zero, exp_all_zeros, mant_is_zero);
    and(is_nan, exp_all_ones, mant_nonzero);
    and(is_inf, exp_all_ones, mant_is_zero);
    
    wire exp_nonzero, exp_not_max;
    not(exp_nonzero, exp_all_zeros);
    not(exp_not_max, exp_all_ones);
    and(is_normal, exp_nonzero, exp_not_max);
    
    and(is_subnormal, exp_all_zeros, mant_nonzero);
endmodule



module fp16_special_handler (
    input wire        sign_in,
    input wire [4:0]  exp_in,
    input wire [9:0]  mant_in,
   
    input wire        is_zero_detected,
    input wire        is_nan_detected,
    input wire        is_inf_detected,
   
    output wire       is_nan_out,
    output wire       is_pinf_out,
    output wire       is_ninf_out,
   
    output wire       sign_out,
    output wire [4:0] exp_out,
    output wire [9:0] mant_out
);
    wire not_zero, not_inf, is_nonzero_finite, is_invalid_op;
    wire sign_in_n;
   
    not(not_zero, is_zero_detected);
    not(not_inf , is_inf_detected);
    and(is_nonzero_finite, not_zero, not_inf);
    and(is_invalid_op, sign_in, is_nonzero_finite);
   
    or(is_nan_out, is_nan_detected, is_invalid_op);
   
    not(sign_in_n, sign_in);
    and(is_pinf_out, is_inf_detected, sign_in_n);
    and(is_ninf_out, is_inf_detected, sign_in);
   
    wire force_canonical_qnan;
    assign force_canonical_qnan = is_invalid_op;
   
    wire [9:0] mant_with_quiet;
    assign mant_with_quiet = mant_in | 10'b1000000000;
   
    wire [9:0] selected_mant;
    mux2_n #(.WIDTH(10)) mant_sel(
        .a(mant_with_quiet),
        .b(10'b1000000000),
        .sel(force_canonical_qnan),
        .out(selected_mant)
    );
   
    wire selected_sign;
    mux2 sign_sel(
        .a(sign_in),
        .b(1'b1),
        .sel(force_canonical_qnan),
        .out(selected_sign)
    );
   
    mux2_n #(.WIDTH(5)) exp_mux(
        .a(exp_in),
        .b(5'b11111),
        .sel(is_nan_out),
        .out(exp_out)
    );
   
    mux2_n #(.WIDTH(10)) mant_mux(
        .a(mant_in),
        .b(selected_mant),
        .sel(is_nan_out),
        .out(mant_out)
    );
   
    mux2 sign_mux(
        .a(sign_in),
        .b(selected_sign),
        .sel(is_nan_out),
        .out(sign_out)
    );
endmodule


module count_leading_zeros_10bit (
    input  wire [9:0] data_in,
    output wire [3:0] count_out
);
    assign count_out = 
        data_in[9] ? 4'd0 : data_in[8] ? 4'd1 : data_in[7] ? 4'd2 :
        data_in[6] ? 4'd3 : data_in[5] ? 4'd4 : data_in[4] ? 4'd5 :
        data_in[3] ? 4'd6 : data_in[2] ? 4'd7 : data_in[1] ? 4'd8 :
        data_in[0] ? 4'd9 : 4'd10;
endmodule


module fp16_normalize_normal (
    input  wire [4:0]  exp_in,
    input  wire [9:0]  mant_in,
    output wire [10:0] mant_out,
    output wire signed [6:0] exp_out
);
    localparam signed [6:0] BIAS = 7'd15;
    
    assign mant_out = {1'b1, mant_in};
    
    wire signed [6:0] exp_extended;
    assign exp_extended = {2'b00, exp_in};
    
    subtract_with_bias_n #(.WIDTH(7)) exp_calc(
        .a(exp_extended),
        .bias(BIAS),
        .result(exp_out),
        .cout()
    );
endmodule

module fp16_normalize_subnormal (
    input  wire [9:0]  mant_in,
    input  wire [3:0]  clz,
    output wire [10:0] mant_out,
    output wire signed [6:0] exp_out
);
    wire [3:0] clz_plus_1;
    wire [10:0] mant_to_shift;
    
    increment_n #(.WIDTH(4)) clz_inc(
        .in(clz), 
        .out(clz_plus_1)
    );
    
    assign mant_to_shift = {1'b0, mant_in};
    
    barrel_shift_left_11bit shifter(
        .in(mant_to_shift), 
        .shift_amt(clz_plus_1), 
        .out(mant_out)
    );
    
    wire signed [6:0] clz_extended;
    assign clz_extended = {3'b000, clz};
    
    subtract_with_bias_n #(.WIDTH(7)) exp_calc(
        .a(-7'd15),
        .bias(clz_extended),
        .result(exp_out),
        .cout()
    );
endmodule

module fp16_normalizer (
    input  wire        sign_in,
    input  wire [4:0]  exp_in,
    input  wire [9:0]  mant_in,
    input  wire        is_normal_in,
    input  wire        is_subnormal_in,
    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,
    
    output wire        sign_out,
    output wire signed [6:0] exp_out,
    output wire [10:0] mant_out,
    output wire        is_num
);
    wire exp_is_zero, mant_is_zero, is_zero;
    
    is_zero_n #(.WIDTH(5)) exp_zero_check(.in(exp_in), .is_zero(exp_is_zero));
    is_zero_n #(.WIDTH(10)) mant_zero_check(.in(mant_in), .is_zero(mant_is_zero));
    and(is_zero, exp_is_zero, mant_is_zero);
    
    wire [3:0] clz;
    count_leading_zeros_10bit clz_counter(.data_in(mant_in), .count_out(clz));
    
    wire [10:0] normal_mant;
    wire signed [6:0] normal_exp;
    fp16_normalize_normal norm_normal(
        .exp_in(exp_in),
        .mant_in(mant_in),
        .mant_out(normal_mant),
        .exp_out(normal_exp)
    );
    
    wire [10:0] subnorm_mant;
    wire signed [6:0] subnorm_exp;
    fp16_normalize_subnormal norm_subnorm(
        .mant_in(mant_in),
        .clz(clz),
        .mant_out(subnorm_mant),
        .exp_out(subnorm_exp)
    );
    
    wire [10:0] mant_choice1;
    wire signed [6:0] exp_choice1;
    
    mux2_n #(.WIDTH(11)) mant_mux1(
        .a(11'd0), 
        .b(normal_mant), 
        .sel(is_normal_in), 
        .out(mant_choice1)
    );
    
    mux2_n #(.WIDTH(7)) exp_mux1(
        .a(-7'd15), 
        .b(normal_exp), 
        .sel(is_normal_in), 
        .out(exp_choice1)
    );
    
    wire zero_or_normal;
    or(zero_or_normal, is_zero, is_normal_in);
    
    wire [10:0] mant_choice2;
    wire signed [6:0] exp_choice2;
    
    mux2_n #(.WIDTH(11)) mant_mux2(
        .a(subnorm_mant), 
        .b(mant_choice1), 
        .sel(zero_or_normal), 
        .out(mant_choice2)
    );
    
    mux2_n #(.WIDTH(7)) exp_mux2(
        .a(subnorm_exp), 
        .b(exp_choice1), 
        .sel(zero_or_normal), 
        .out(exp_choice2)
    );
    
    wire is_any_special, not_is_any_special;
    wire signed [6:0] exp_extended;
    
    or(is_any_special, is_nan_in, is_pinf_in, is_ninf_in);
    not(not_is_any_special, is_any_special);
    
    assign exp_extended = {2'b00, exp_in};
    
    mux2_n #(.WIDTH(11)) mant_mux3(
        .a({1'b0, mant_in}), 
        .b(mant_choice2), 
        .sel(not_is_any_special), 
        .out(mant_out)
    );
    
    mux2_n #(.WIDTH(7)) exp_mux3(
        .a(exp_extended), 
        .b(exp_choice2), 
        .sel(not_is_any_special), 
        .out(exp_out)
    );
    
    assign sign_out = sign_in;
    not(is_num, is_any_special);
endmodule



module fp16_pack_subnormal (
    input  wire signed [6:0] exp_biased,
    input  wire [10:0] mant_in,
    output wire [9:0] frac_out
);
    wire signed [6:0] one_minus_exp;
    wire [4:0] shift_amt;
    wire [10:0] mant_shifted;
    wire shift_overflow;
    
    subtract_with_bias_n #(.WIDTH(7)) calc_shift(
        .a(7'd1),
        .bias(exp_biased),
        .result(one_minus_exp),
        .cout()
    );
    
    assign shift_amt = one_minus_exp[4:0];
    
    comparator_gte_n #(.WIDTH(5)) shift_overflow_check(
        .a(shift_amt),
        .b(5'd12),
        .gte(shift_overflow)
    );
    
    barrel_shift_right_11bit mant_shifter(
        .in(mant_in),
        .shift_amt(shift_amt[3:0]),
        .out(mant_shifted)
    );
    
    mux2_n #(.WIDTH(10)) subnorm_frac_mux(
        .a(mant_shifted[9:0]),
        .b(10'b0),
        .sel(shift_overflow),
        .out(frac_out)
    );
endmodule

module fp16_packer (
    input  wire        sign_in,
    input  wire signed [6:0] exp_in,
    input  wire [10:0] mant_in,
    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,
    output wire [15:0] out_data
);
    wire signed [6:0] exp_biased;
    wire exp_is_minus15, mant_is_zero, is_zero;
    
    adder_n #(.WIDTH(7)) exp_add_bias(
        .a(exp_in),
        .b(7'd15),
        .cin(1'b0),
        .sum(exp_biased),
        .cout()
    );

    comparator_eq_n #(.WIDTH(7)) exp_m15_cmp(
        .a(exp_in),
        .b(7'b1110001),
        .eq(exp_is_minus15)
    );
    
    is_zero_n #(.WIDTH(11)) mant_zero_check(
        .in(mant_in),
        .is_zero(mant_is_zero)
    );
    
    and(is_zero, exp_is_minus15, mant_is_zero);
    
    wire exp_biased_le_zero, exp_biased_is_zero, exp_biased_is_negative;
    
    is_zero_n #(.WIDTH(7)) exp_biased_zero_check(
        .in(exp_biased),
        .is_zero(exp_biased_is_zero)
    );
    
    assign exp_biased_is_negative = exp_biased[6];
    or(exp_biased_le_zero, exp_biased_is_zero, exp_biased_is_negative);

    wire [9:0] frac10_subnormal, frac10_normal;
    
    fp16_pack_subnormal pack_subnorm(
        .exp_biased(exp_biased),
        .mant_in(mant_in),
        .frac_out(frac10_subnormal)
    );

    assign frac10_normal = mant_in[9:0];

    wire [15:0] nan_pattern, pinf_pattern, special_value;
    wire [15:0] zero_value, subnorm_value, normal_value;
    wire [15:0] non_zero_value, number_value;
    wire is_any_special;
    
    // NaN сохраняет sign и mantissa (с quiet bit уже установленным в iterate)
    assign nan_pattern = {sign_in, 5'b11111, mant_in[9:0]};
    assign pinf_pattern = 16'h7C00;
    
    mux2_n #(.WIDTH(16)) special_mux(
        .a(pinf_pattern),
        .b(nan_pattern),
        .sel(is_nan_in),
        .out(special_value)
    );
    
    assign zero_value = {sign_in, 15'b0};
    assign subnorm_value = {sign_in, 5'b00000, frac10_subnormal};
    assign normal_value = {sign_in, exp_biased[4:0], frac10_normal};
    
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
    
    or(is_any_special, is_nan_in, is_pinf_in, is_ninf_in);
    
    mux2_n #(.WIDTH(16)) final_mux(
        .a(number_value),
        .b(special_value),
        .sel(is_any_special),
        .out(out_data)
    );
endmodule

module sqrt_iteration_core (
    input  wire [11:0] root,
    input  wire [22:0] remainder,
    input  wire [33:0] radicand,
    
    output wire [11:0] root_next,
    output wire [22:0] remainder_next,
    output wire [33:0] radicand_next
);

    wire [22:0] trial = {root[10:0], 2'b01};
    wire [22:0] remainder_shifted = {remainder[20:0], radicand[33:32]};

    wire can_subtract;
    comparator_gte_n #(.WIDTH(23)) compare(
        .a(remainder_shifted),
        .b(trial),
        .gte(can_subtract)
    );
    

    mux2_n #(.WIDTH(12)) root_mux(
        .a({root[10:0], 1'b0}),
        .b({root[10:0], 1'b1}),
        .sel(can_subtract),
        .out(root_next)
    );
    
    wire [22:0] remainder_sub;
    wire borrow;
    subtractor_n #(.WIDTH(23)) subtract(
        .a(remainder_shifted),
        .b(trial),
        .diff(remainder_sub),
        .borrow(borrow)
    );
    
    mux2_n #(.WIDTH(23)) remainder_mux(
        .a(remainder_shifted),
        .b(remainder_sub),
        .sel(can_subtract),
        .out(remainder_next)
    );

    assign radicand_next = {radicand[31:0], 2'b00};
endmodule


module sqrt_input_prepare (
    input  wire signed [6:0] exp_in,
    input  wire [10:0] mant_in,
    
    output wire signed [6:0] exp_halved,
    output wire [11:0] mant_prepared
);
    wire exp_is_odd = exp_in[0];
    
    mux2_n #(.WIDTH(12)) mant_mux(
        .a({1'b0, mant_in}),
        .b({mant_in, 1'b0}),
        .sel(exp_is_odd),
        .out(mant_prepared)
    );
    
    wire signed [6:0] exp_decremented;
    decrement_n #(.WIDTH(7)) exp_dec(.in(exp_in), .out(exp_decremented));
    
    wire signed [6:0] exp_adjusted;
    mux2_n #(.WIDTH(7)) exp_mux(
        .a(exp_in),
        .b(exp_decremented),
        .sel(exp_is_odd),
        .out(exp_adjusted)
    );
    
    assign exp_halved = {exp_adjusted[6], exp_adjusted[6:1]};
endmodule


module sqrt_output_formatter (
    input  wire [11:0] root,
    input  wire [3:0] iter_left,
    
    output wire [10:0] mant_out
);
    wire iter_gt_1;
    comparator_gt_n #(.WIDTH(4)) cmp(.a(iter_left), .b(4'd1), .gt(iter_gt_1));
    
    wire [3:0] shift_amount;
    decrement_n #(.WIDTH(4)) dec(.in(iter_left), .out(shift_amount));
    
    wire [10:0] mant_shifted;
    barrel_shift_left_11bit shifter(
        .in(root[10:0]),
        .shift_amt(shift_amount),
        .out(mant_shifted)
    );
    
    mux2_n #(.WIDTH(11)) output_mux(
        .a(root[10:0]),
        .b(mant_shifted),
        .sel(iter_gt_1),
        .out(mant_out)
    );
endmodule