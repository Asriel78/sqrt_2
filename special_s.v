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

    // ========================================================================
    // СЕКЦИЯ 1: Детекция типа входного числа
    // ========================================================================
    
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
    
    // ========================================================================
    // СЕКЦИЯ 2: Детекция отрицательных чисел (преобразуем в NaN)
    // ========================================================================
    
    // Отрицательное число = sign==1 && не-ноль && не-бесконечность
    wire is_negative_number;
    wire not_zero, not_inf;
    not(not_zero, is_zero_detected);
    not(not_inf, is_inf_detected);
    wire is_nonzero_finite;
    and(is_nonzero_finite, not_zero, not_inf);
    and(is_negative_number, sign_in, is_nonzero_finite);
    
    // ========================================================================
    // СЕКЦИЯ 3: Определение выходных флагов
    // ========================================================================
    
    // NaN: входной NaN или отрицательное число
    wire is_nan_output;
    or(is_nan_output, is_nan_detected, is_negative_number);
    
    // +Inf: только если вход = +Inf
    wire is_pinf_output;
    wire sign_in_n;
    not(sign_in_n, sign_in);
    and(is_pinf_output, is_inf_detected, sign_in_n);
    
    // -Inf: только если вход = -Inf
    wire is_ninf_output;
    and(is_ninf_output, is_inf_detected, sign_in);
    
    // Normal и Subnormal передаём как есть
    assign is_normal_output = is_normal_detected;
    assign is_subnormal_output = is_subnormal_detected;
    
    // ========================================================================
    // СЕКЦИЯ 4: Формирование выходных данных
    // ========================================================================
    
    wire [4:0] NAN_EXP = 5'b11111;
    wire [9:0] QUIET_BIT = 10'b1000000000;
    
    // Для NaN: устанавливаем quiet bit
    wire [9:0] mant_with_quiet;
    assign mant_with_quiet = mant_in | QUIET_BIT;
    
    // Выбираем мантиссу: входной NaN -> сохраняем с quiet, иначе -> просто quiet bit
    wire [9:0] nan_mantissa;
    mux2_n #(.WIDTH(10)) nan_mant_select(
        .a(QUIET_BIT),
        .b(mant_with_quiet),
        .sel(is_nan_detected),
        .out(nan_mantissa)
    );
    
    // Выбираем знак для NaN: входной NaN -> сохраняем знак, отрицательное число -> 1
    wire nan_sign;
    mux2 nan_sign_select(
        .a(1'b1),
        .b(sign_in),
        .sel(is_nan_detected),
        .out(nan_sign)
    );
    
    // Итоговые значения
    wire [4:0] exp_output;
    wire [9:0] mant_output;
    wire sign_output;
    
    mux2_n #(.WIDTH(5)) exp_final_mux(
        .a(exp_in),
        .b(NAN_EXP),
        .sel(is_nan_output),
        .out(exp_output)
    );
    
    mux2_n #(.WIDTH(10)) mant_final_mux(
        .a(mant_in),
        .b(nan_mantissa),
        .sel(is_nan_output),
        .out(mant_output)
    );
    
    mux2 sign_final_mux(
        .a(sign_in),
        .b(nan_sign),
        .sel(is_nan_output),
        .out(sign_output)
    );
    
    // ========================================================================
    // СЕКЦИЯ 5: Регистры с управлением
    // ========================================================================
    
    wire capture;
    and(capture, valid, enable);
    
    // Valid флаг
    wire s_valid_d;
    mux2 valid_gate(.a(1'b0), .b(capture), .sel(enable), .out(s_valid_d));
    dff valid_reg(.clk(clk), .d(s_valid_d), .q(s_valid));
    
    // Флаги типов чисел
    flag_registers flags(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .is_nan_in(is_nan_output),
        .is_pinf_in(is_pinf_output),
        .is_ninf_in(is_ninf_output),
        .is_normal_in(is_normal_output),
        .is_subnormal_in(is_subnormal_output),
        .is_nan_out(is_nan),
        .is_pinf_out(is_pinf),
        .is_ninf_out(is_ninf),
        .is_normal_out(is_normal),
        .is_subnormal_out(is_subnormal)
    );
    
    // Данные числа
    number_storage #(.EXP_WIDTH(5), .MANT_WIDTH(10)) data_storage(
        .clk(clk),
        .enable(enable),
        .capture(capture),
        .sign_in(sign_output),
        .exp_in(exp_output),
        .mant_in(mant_output),
        .sign_out(sign_out),
        .exp_out(exp_out),
        .mant_out(mant_out)
    );

endmodule