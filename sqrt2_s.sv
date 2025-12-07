`timescale 1ns/1ps

module sqrt2 (
    inout  wire [15:0] IO_DATA,
    output wire        IS_NAN,
    output wire        IS_PINF,
    output wire        IS_NINF,
    output wire        RESULT,
    input  wire        CLK,
    input  wire        ENABLE
);

    // ========================================================================
    // LOAD: читает данные с шины
    // ========================================================================
    wire        load_sign;
    wire [4:0]  load_exp;
    wire [9:0]  load_mant;
    wire        load_valid;

    load load_inst (
        .clk(CLK),
        .enable(ENABLE),
        .data(IO_DATA),
        .sign(load_sign),
        .exp(load_exp),
        .mant(load_mant),
        .valid(load_valid)
    );

    // ========================================================================
    // SPECIAL: определяет тип числа (NaN, Inf, normal, subnormal)
    // ========================================================================
    wire        spec_valid;
    wire        spec_is_nan;
    wire        spec_is_pinf;
    wire        spec_is_ninf;
    wire        spec_is_normal;
    wire        spec_is_subnormal;
    wire        spec_sign;
    wire [4:0]  spec_exp;
    wire [9:0]  spec_mant;

    special special_inst (
        .clk(CLK),
        .enable(ENABLE),
        .valid(load_valid),
        .sign_in(load_sign),
        .exp_in(load_exp),
        .mant_in(load_mant),
        .s_valid(spec_valid),
        .is_nan(spec_is_nan),
        .is_pinf(spec_is_pinf),
        .is_ninf(spec_is_ninf),
        .is_normal(spec_is_normal),
        .is_subnormal(spec_is_subnormal),
        .sign_out(spec_sign),
        .exp_out(spec_exp),
        .mant_out(spec_mant)
    );

    // ========================================================================
    // NORMALIZE: нормализует мантиссу и экспоненту
    // ========================================================================
    wire        norm_valid;
    wire        norm_is_num;
    wire        norm_is_nan;
    wire        norm_is_pinf;
    wire        norm_is_ninf;
    wire        norm_sign;
    wire signed [6:0] norm_exp;
    wire [10:0] norm_mant;
    
    normalize normalize_inst (
        .clk(CLK),
        .enable(ENABLE),
        .s_valid(spec_valid),
        .sign_in(spec_sign),
        .exp_in(spec_exp),
        .mant_in(spec_mant),
        .is_normal_in(spec_is_normal),
        .is_subnormal_in(spec_is_subnormal),
        .is_nan_in(spec_is_nan),
        .is_pinf_in(spec_is_pinf),
        .is_ninf_in(spec_is_ninf),
        .n_valid(norm_valid),
        .is_num(norm_is_num),
        .is_nan(norm_is_nan),
        .is_pinf(norm_is_pinf),
        .is_ninf(norm_is_ninf),
        .sign_out(norm_sign),
        .exp_out(norm_exp),
        .mant_out(norm_mant)
    );

    // ========================================================================
    // ITERATE: вычисляет квадратный корень
    // ========================================================================
    wire        iter_valid;
    wire        iter_result;
    wire        iter_sign;
    wire signed [6:0] iter_exp;
    wire [10:0] iter_mant;
    wire        iter_is_nan;
    wire        iter_is_pinf;
    wire        iter_is_ninf;
    
    iterate iterate_inst (
        .clk(CLK),
        .enable(ENABLE),
        .n_valid(norm_valid),
        .is_nan_in(norm_is_nan),
        .is_pinf_in(norm_is_pinf),
        .is_ninf_in(norm_is_ninf),
        .is_num(norm_is_num),
        .sign_in(norm_sign),
        .mant_in(norm_mant),
        .exp_in(norm_exp),
        .it_valid(iter_valid),
        .result(iter_result),
        .sign_out(iter_sign),
        .exp_out(iter_exp),
        .mant_out(iter_mant),
        .is_nan_out(iter_is_nan),
        .is_pinf_out(iter_is_pinf),
        .is_ninf_out(iter_is_ninf)
    );

    // ========================================================================
    // PACK: упаковывает обратно в float16
    // ========================================================================
    wire        pack_valid;
    wire        pack_result;
    wire [15:0] pack_data;
    wire        pack_is_nan;
    wire        pack_is_pinf;
    wire        pack_is_ninf;
    
    pack pack_inst (
        .clk(CLK),
        .enable(ENABLE),
        .it_valid(iter_valid),
        .sign_in(iter_sign),
        .exp_in(iter_exp),
        .mant_in(iter_mant),
        .is_nan_in(iter_is_nan),
        .is_pinf_in(iter_is_pinf),
        .is_ninf_in(iter_is_ninf),
        .result_in(iter_result),
        .p_valid(pack_valid),
        .result_out(pack_result),
        .out_data(pack_data),
        .is_nan_out(pack_is_nan),
        .is_pinf_out(pack_is_pinf),
        .is_ninf_out(pack_is_ninf)
    );

    // ========================================================================
    // Управление шиной IO_DATA
    // ========================================================================
    wire drive_output;
    assign drive_output = pack_valid & pack_result;
    assign IO_DATA = drive_output ? pack_data : 16'hzzzz;
    
    // Выходы
    assign RESULT  = pack_result;
    assign IS_NAN  = pack_is_nan;
    assign IS_PINF = pack_is_pinf;
    assign IS_NINF = pack_is_ninf;

endmodule