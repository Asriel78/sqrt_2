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

    // Сигналы между модулями
    wire        l_sign;
    wire [4:0]  l_exp;
    wire [9:0]  l_mant;
    wire        l_valid;

    wire        s_is_nan;
    wire        s_is_pinf;
    wire        s_is_ninf;
    wire        s_is_normal;
    wire        s_is_subnormal;
    wire        s_sign;
    wire [4:0]  s_exp;
    wire [9:0]  s_mant;
    wire        s_valid;

    wire        n_is_num;
    wire        n_is_nan;
    wire        n_is_pinf;
    wire        n_is_ninf;
    wire        n_sign;
    wire signed [6:0] n_exp;
    wire [10:0]       n_mant;
    wire        n_valid;

    wire        it_sign;
    wire signed [6:0] it_exp;
    wire [10:0]       it_mant;
    wire        it_valid;
    wire        it_result;

    wire [15:0] p_out_data;
    wire        p_is_nan;
    wire        p_is_pinf;
    wire        p_is_ninf;
    wire        p_valid;
    wire        p_result_out;

    // Управление IO_DATA
    reg        drive_en = 0;
    reg [15:0] drive_data = 0;
    reg        result_reg = 0;
    reg        is_nan_reg = 0;
    reg        is_pinf_reg = 0;
    reg        is_ninf_reg = 0;

    load load_u (
        .clk(CLK),
        .enable(ENABLE),
        .data(IO_DATA),
        .sign(l_sign),
        .exp(l_exp),
        .mant(l_mant),
        .valid(l_valid)
    );

    special special_u (
        .clk(CLK),
        .enable(ENABLE),
        .valid(l_valid),
        .sign_in(l_sign),
        .exp_in(l_exp),
        .mant_in(l_mant),
        .s_valid(s_valid),
        .is_nan(s_is_nan),
        .is_pinf(s_is_pinf),
        .is_ninf(s_is_ninf),
        .is_normal(s_is_normal),
        .is_subnormal(s_is_subnormal),
        .sign_out(s_sign),
        .exp_out(s_exp),
        .mant_out(s_mant)
    );

    normalize normalize_u (
        .clk(CLK),
        .enable(ENABLE),
        .s_valid(s_valid),
        .sign_in(s_sign),
        .exp_in(s_exp),
        .mant_in(s_mant),
        .is_normal_in(s_is_normal),
        .is_subnormal_in(s_is_subnormal),
        .is_nan_in(s_is_nan),
        .is_pinf_in(s_is_pinf),
        .is_ninf_in(s_is_ninf),
        .n_valid(n_valid),
        .is_num(n_is_num),
        .is_nan(n_is_nan),
        .is_pinf(n_is_pinf),
        .is_ninf(n_is_ninf),
        .sign_out(n_sign),
        .exp_out(n_exp),
        .mant_out(n_mant)
    );

    iterate iter_u (
        .clk(CLK),
        .enable(ENABLE),
        .n_valid(n_valid),
        .sign_in(n_sign),        // ДОБАВЛЕНО
        .is_nan_in(n_is_nan),
        .is_pinf_in(n_is_pinf),
        .is_ninf_in(n_is_ninf),
        .is_num(n_is_num),
        .mant_in(n_mant),
        .exp_in(n_exp),
        .it_valid(it_valid),
        .result(it_result),
        .sign_out(it_sign),
        .exp_out(it_exp),
        .mant_out(it_mant)
    );

    pack pack_u (
        .clk(CLK),
        .enable(ENABLE),
        .it_valid(it_valid),
        .result_in(it_result),
        .sign_in(it_sign),
        .exp_in(it_exp),
        .mant_in(it_mant),
        .is_nan_in(n_is_nan),
        .is_pinf_in(n_is_pinf),
        .is_ninf_in(n_is_ninf),
        .p_valid(p_valid),
        .result_out(p_result_out),
        .out_data(p_out_data),
        .is_nan_out(p_is_nan),
        .is_pinf_out(p_is_pinf),
        .is_ninf_out(p_is_ninf)
    );

    // Логика вывода на IO_DATA и флагов
    always @(posedge CLK) begin
        if (!ENABLE) begin
            drive_en    <= 1'b0;
            drive_data  <= 16'hzzzz;
            result_reg  <= 1'b0;
            is_nan_reg  <= 1'b0;
            is_pinf_reg <= 1'b0;
            is_ninf_reg <= 1'b0;
        end else begin
            // ИСПРАВЛЕНО: выводим промежуточные результаты
            if (p_valid) begin
                drive_data <= p_out_data;
                drive_en   <= 1'b1;
                
                // Обновляем флаги только при финальном результате
                if (p_result_out) begin
                    result_reg  <= 1'b1;
                    is_nan_reg  <= p_is_nan;
                    is_pinf_reg <= p_is_pinf;
                    is_ninf_reg <= p_is_ninf;
                end
            end
        end
    end

    // Выходы
    assign IO_DATA = drive_en ? drive_data : 16'hzzzz;
    assign RESULT  = result_reg;
    assign IS_NAN  = is_nan_reg;
    assign IS_PINF = is_pinf_reg;
    assign IS_NINF = is_ninf_reg;

endmodule