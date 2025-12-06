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

    output reg         n_valid,

    output reg         is_num,
    output reg         is_nan,
    output reg         is_pinf,
    output reg         is_ninf,

    output reg         sign_out,
    output reg signed [6:0] exp_out,
    output reg  [10:0] mant_out
);

    localparam signed [6:0] BIAS = 7'd15;

    wire [3:0] clz_comb;
    assign clz_comb =
        mant_in[9] ? 4'd0 :
        mant_in[8] ? 4'd1 :
        mant_in[7] ? 4'd2 :
        mant_in[6] ? 4'd3 :
        mant_in[5] ? 4'd4 :
        mant_in[4] ? 4'd5 :
        mant_in[3] ? 4'd6 :
        mant_in[2] ? 4'd7 :
        mant_in[1] ? 4'd8 :
        mant_in[0] ? 4'd9 : 4'd10;

    reg [10:0] tmp_m;
    reg signed [6:0] tmp_exp;
    wire is_zero;
    
    assign is_zero = (exp_in == 5'd0) && (mant_in == 10'd0);

    always @(posedge clk) begin
        if (!enable) begin
            n_valid   <= 1'b0;
            is_num    <= 1'b0;
            is_nan    <= 1'b0;
            is_pinf   <= 1'b0;
            is_ninf   <= 1'b0;
            sign_out  <= 1'b0;
            exp_out   <= 7'sd0;
            mant_out  <= 11'd0;
        end else begin
            n_valid <= 1'b0;

            if (s_valid) begin
                // Проверка на ±0 в начале
                if (is_zero) begin
                    // ±0 - это число со специальным представлением
                    is_num   <= 1'b1;
                    is_nan   <= 1'b0;
                    is_pinf  <= 1'b0;
                    is_ninf  <= 1'b0;
                    sign_out <= sign_in;  // сохраняем знак ±0
                    exp_out  <= -7'sd15;  // минимальная экспонента
                    mant_out <= 11'd0;
                end
                // Normal числа
                else if (is_normal_in) begin
                    is_num   <= 1'b1;
                    is_nan   <= 1'b0;
                    is_pinf  <= 1'b0;
                    is_ninf  <= 1'b0;
                    sign_out <= sign_in;
                    mant_out <= {1'b1, mant_in};  // добавляем implicit bit
                    exp_out  <= $signed({2'b00, exp_in}) - BIAS;
                end 
                // Subnormal числа
                else if (is_subnormal_in) begin
                    is_num   <= 1'b1;
                    is_nan   <= 1'b0;
                    is_pinf  <= 1'b0;
                    is_ninf  <= 1'b0;
                    sign_out <= sign_in;
                    // Нормализуем через CLZ
                    tmp_m   = ({1'b0, mant_in} << (clz_comb + 1));
                    tmp_exp = $signed(7'sd0) - BIAS - $signed({3'b000, clz_comb});
                    mant_out <= tmp_m;
                    exp_out  <= tmp_exp;
                end 
                // Special значения (NaN, ±Inf)
                else begin
                    is_num   <= 1'b0;
                    is_nan   <= is_nan_in;
                    is_pinf  <= is_pinf_in;
                    is_ninf  <= is_ninf_in;
                    sign_out <= sign_in;
                    mant_out <= {1'b0, mant_in};
                    exp_out  <= $signed({2'b00, exp_in}) - BIAS;
                end

                n_valid <= 1'b1;
            end
        end
    end

endmodule