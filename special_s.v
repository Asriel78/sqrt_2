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

    localparam [4:0] EXP_MAX = 5'b11111;
    localparam [9:0] QUIET_BIT = 10'b1000000000;

    // ========================================================================
    // Комбинационная логика для определения типа входа
    // ========================================================================
    
    // Проверка exp == 31
    wire exp_is_max;
    comparator_eq_n #(.WIDTH(5)) exp_max_cmp(
        .a(exp_in),
        .b(EXP_MAX),
        .eq(exp_is_max)
    );
    
    // Проверка exp == 0
    wire exp_is_zero;
    is_zero_n #(.WIDTH(5)) exp_zero_check(
        .in(exp_in),
        .is_zero(exp_is_zero)
    );
    
    // Проверка mant == 0
    wire mant_is_zero;
    is_zero_n #(.WIDTH(10)) mant_zero_check(
        .in(mant_in),
        .is_zero(mant_is_zero)
    );
    
    // Проверка mant != 0
    wire mant_is_nonzero;
    not(mant_is_nonzero, mant_is_zero);
    
    // is_input_nan = (exp == 31) && (mant != 0)
    wire is_input_nan_comb;
    and(is_input_nan_comb, exp_is_max, mant_is_nonzero);
    
    // Проверка на отрицательное обычное число
    // is_negative_number = sign && (exp != 31) && ((exp != 0) || (mant != 0))
    wire exp_not_max;
    not(exp_not_max, exp_is_max);
    
    wire exp_or_mant_nonzero;  // (exp != 0) || (mant != 0)
    wire exp_nonzero;
    not(exp_nonzero, exp_is_zero);
    or(exp_or_mant_nonzero, exp_nonzero, mant_is_nonzero);
    
    wire temp_negative;
    and(temp_negative, sign_in, exp_not_max);
    
    wire is_negative_number_comb;
    and(is_negative_number_comb, temp_negative, exp_or_mant_nonzero);
    
    // Проверка на +Inf: exp==31, mant==0, sign==0
    wire sign_in_n;
    not(sign_in_n, sign_in);
    wire temp_pinf;
    and(temp_pinf, exp_is_max, mant_is_zero);
    wire is_pinf_comb;
    and(is_pinf_comb, temp_pinf, sign_in_n);
    
    // Проверка на -Inf: exp==31, mant==0, sign==1
    wire temp_ninf;
    and(temp_ninf, exp_is_max, mant_is_zero);
    wire is_ninf_comb;
    and(is_ninf_comb, temp_ninf, sign_in);
    
    // Проверка на нормальное число: (exp != 0) && (exp != 31)
    wire is_normal_comb;
    and(is_normal_comb, exp_nonzero, exp_not_max);
    
    // Проверка на субнормальное: (exp == 0) && (mant != 0)
    wire is_subnormal_comb;
    and(is_subnormal_comb, exp_is_zero, mant_is_nonzero);
    
    // ========================================================================
    // Определение выходных значений (комбинационно)
    // ========================================================================
    
    // Если вход NaN или отрицательное число -> выход NaN
    wire output_is_nan_comb;
    or(output_is_nan_comb, is_input_nan_comb, is_negative_number_comb);
    
    // Выходная мантисса для NaN (с quiet bit)
    wire [9:0] mant_with_quiet;
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : mant_quiet_gen
            or(mant_with_quiet[i], mant_in[i], QUIET_BIT[i]);
        end
    endgenerate
    
    // Выходной sign
    // Если NaN из-за отрицательного числа -> sign=1
    // Если NaN из входного NaN -> sign от входа
    // Иначе -> sign от входа
    wire sign_out_comb;
    mux2 sign_mux(
        .a(sign_in),      // Обычный случай
        .b(1'b1),         // Если отрицательное -> 1
        .sel(is_negative_number_comb),
        .out(sign_out_comb)
    );
    
    // Выходная экспонента
    // Если NaN -> 31, если +Inf/-Inf -> 31, иначе -> exp_in
    wire [4:0] exp_out_comb;
    wire exp_select;  // 1 если нужна EXP_MAX
    or(exp_select, output_is_nan_comb, is_pinf_comb, is_ninf_comb);
    
    mux2_n #(.WIDTH(5)) exp_mux(
        .a(exp_in),
        .b(EXP_MAX),
        .sel(exp_select),
        .out(exp_out_comb)
    );
    
    // Выходная мантисса
    // Если NaN -> mant с quiet bit
    // Если отрицательное число -> только QUIET_BIT
    // Если +Inf/-Inf -> 0
    // Иначе -> mant_in
    wire [9:0] mant_out_step1;
    mux2_n #(.WIDTH(10)) mant_mux1(
        .a(mant_in),
        .b(mant_with_quiet),
        .sel(is_input_nan_comb),
        .out(mant_out_step1)
    );
    
    wire [9:0] mant_out_step2;
    mux2_n #(.WIDTH(10)) mant_mux2(
        .a(mant_out_step1),
        .b(QUIET_BIT),
        .sel(is_negative_number_comb),
        .out(mant_out_step2)
    );
    
    wire [9:0] mant_out_comb;
    wire inf_select;
    or(inf_select, is_pinf_comb, is_ninf_comb);
    mux2_n #(.WIDTH(10)) mant_mux3(
        .a(mant_out_step2),
        .b(10'b0),
        .sel(inf_select),
        .out(mant_out_comb)
    );
    
    // ========================================================================
    // Регистры для выходов
    // ========================================================================
    
    wire enable_n;
    not(enable_n, enable);
    
    // s_valid регистр
    wire s_valid_next;
    wire s_valid_d;
    and(s_valid_next, valid, enable);
    mux2 s_valid_mux(
        .a(1'b0),
        .b(s_valid_next),
        .sel(enable),
        .out(s_valid_d)
    );
    dff s_valid_ff(.clk(clk), .d(s_valid_d), .q(s_valid));
    
    // Регистры флагов типа
    wire is_nan_d, is_pinf_d, is_ninf_d, is_normal_d, is_subnormal_d;
    
    mux2 is_nan_mux(
        .a(1'b0),
        .b(output_is_nan_comb),
        .sel(s_valid_next),
        .out(is_nan_d)
    );
    dff is_nan_ff(.clk(clk), .d(is_nan_d), .q(is_nan));
    
    mux2 is_pinf_mux(
        .a(1'b0),
        .b(is_pinf_comb),
        .sel(s_valid_next),
        .out(is_pinf_d)
    );
    dff is_pinf_ff(.clk(clk), .d(is_pinf_d), .q(is_pinf));
    
    mux2 is_ninf_mux(
        .a(1'b0),
        .b(is_ninf_comb),
        .sel(s_valid_next),
        .out(is_ninf_d)
    );
    dff is_ninf_ff(.clk(clk), .d(is_ninf_d), .q(is_ninf));
    
    // is_normal и is_subnormal должны быть 0 для специальных значений
    wire normal_out;
    wire subnormal_out;
    wire is_special_value;
    or(is_special_value, output_is_nan_comb, is_pinf_comb, is_ninf_comb);
    
    wire is_special_n;
    not(is_special_n, is_special_value);
    
    and(normal_out, is_normal_comb, is_special_n);
    and(subnormal_out, is_subnormal_comb, is_special_n);
    
    mux2 is_normal_mux(
        .a(1'b0),
        .b(normal_out),
        .sel(s_valid_next),
        .out(is_normal_d)
    );
    dff is_normal_ff(.clk(clk), .d(is_normal_d), .q(is_normal));
    
    mux2 is_subnormal_mux(
        .a(1'b0),
        .b(subnormal_out),
        .sel(s_valid_next),
        .out(is_subnormal_d)
    );
    dff is_subnormal_ff(.clk(clk), .d(is_subnormal_d), .q(is_subnormal));
    
    // Регистры данных (sign, exp, mant)
    wire sign_out_d;
    wire [4:0] exp_out_d;
    wire [9:0] mant_out_d;
    
    mux2 sign_out_mux(
        .a(sign_out),
        .b(sign_out_comb),
        .sel(s_valid_next),
        .out(sign_out_d)
    );
    dff sign_out_ff(.clk(clk), .d(sign_out_d), .q(sign_out));
    
    mux2_n #(.WIDTH(5)) exp_out_mux(
        .a(exp_out),
        .b(exp_out_comb),
        .sel(s_valid_next),
        .out(exp_out_d)
    );
    register_n #(.WIDTH(5)) exp_out_reg(
        .clk(clk),
        .rst(1'b0),
        .d(exp_out_d),
        .q(exp_out)
    );
    
    mux2_n #(.WIDTH(10)) mant_out_mux(
        .a(mant_out),
        .b(mant_out_comb),
        .sel(s_valid_next),
        .out(mant_out_d)
    );
    register_n #(.WIDTH(10)) mant_out_reg(
        .clk(clk),
        .rst(1'b0),
        .d(mant_out_d),
        .q(mant_out)
    );

endmodule