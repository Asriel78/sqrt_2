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

    localparam signed [6:0] BIAS = 15;

    // e_biased = exp_in + BIAS
    wire [6:0] bias_const;
    assign bias_const = BIAS;
    
    wire [6:0] e_biased;
    adder_n #(.WIDTH(7)) exp_bias_add(
        .a(exp_in),
        .b(bias_const),
        .cin(1'b0),
        .sum(e_biased),
        .cout()
    );

    // Проверка на zero: exp_in == -15 && mant_in == 0
    wire [6:0] minus_fifteen;
    wire [6:0] fifteen_const;
    wire [6:0] fifteen_inv;
    assign fifteen_const = 7'd15;
    
    genvar i;
    generate
        for (i = 0; i < 7; i = i + 1) begin : fifteen_neg_gen
            not(fifteen_inv[i], fifteen_const[i]);
        end
    endgenerate
    adder_n #(.WIDTH(7)) fifteen_neg_calc(
        .a(fifteen_inv),
        .b(7'd1),
        .cin(1'b0),
        .sum(minus_fifteen),
        .cout()
    );
    
    wire exp_is_minus15;
    comparator_eq_n #(.WIDTH(7)) exp_cmp(
        .a(exp_in),
        .b(minus_fifteen),
        .eq(exp_is_minus15)
    );
    
    wire mant_is_zero;
    is_zero_n #(.WIDTH(11)) mant_zero_check(
        .in(mant_in),
        .is_zero(mant_is_zero)
    );
    
    wire is_zero;
    and(is_zero, exp_is_minus15, mant_is_zero);

    // Проверка e_biased <= 0 (subnormal результат)
    wire e_biased_sign;
    assign e_biased_sign = e_biased[6];
    
    wire e_biased_zero;
    is_zero_n #(.WIDTH(7)) e_biased_zero_check(
        .in(e_biased),
        .is_zero(e_biased_zero)
    );
    
    wire e_biased_lte_zero;
    or(e_biased_lte_zero, e_biased_sign, e_biased_zero);

    // shift_amt для subnormal = 1 - e_biased
    wire [6:0] one_const;
    assign one_const = 7'd1;
    
    wire [6:0] shift_amt_7bit;
    subtractor_n #(.WIDTH(7)) shift_calc(
        .a(one_const),
        .b(e_biased),
        .diff(shift_amt_7bit),
        .borrow()
    );
    
    wire [4:0] shift_amt;
    assign shift_amt = shift_amt_7bit[4:0];

    // Проверка shift_amt >= 12
    wire shift_gte_12;
    wire [4:0] twelve_const;
    assign twelve_const = 5'd12;
    comparator_gte_n #(.WIDTH(5)) shift_cmp(
        .a(shift_amt),
        .b(twelve_const),
        .gte(shift_gte_12)
    );

    // Barrel shifter вправо для denormalization
    wire [10:0] shifted;
    wire [10:0] s0, s1, s2, s3, s4;
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : shift_s0
            if (i == 10)
                mux2 m(.a(mant_in[i]), .b(1'b0), .sel(shift_amt[0]), .out(s0[i]));
            else
                mux2 m(.a(mant_in[i]), .b(mant_in[i+1]), .sel(shift_amt[0]), .out(s0[i]));
        end
        
        for (i = 0; i < 11; i = i + 1) begin : shift_s1
            if (i > 8)
                mux2 m(.a(s0[i]), .b(1'b0), .sel(shift_amt[1]), .out(s1[i]));
            else
                mux2 m(.a(s0[i]), .b(s0[i+2]), .sel(shift_amt[1]), .out(s1[i]));
        end
        
        for (i = 0; i < 11; i = i + 1) begin : shift_s2
            if (i > 6)
                mux2 m(.a(s1[i]), .b(1'b0), .sel(shift_amt[2]), .out(s2[i]));
            else
                mux2 m(.a(s1[i]), .b(s1[i+4]), .sel(shift_amt[2]), .out(s2[i]));
        end
        
        for (i = 0; i < 11; i = i + 1) begin : shift_s3
            if (i > 2)
                mux2 m(.a(s2[i]), .b(1'b0), .sel(shift_amt[3]), .out(s3[i]));
            else
                mux2 m(.a(s2[i]), .b(s2[i+8]), .sel(shift_amt[3]), .out(s3[i]));
        end
        
        // 5-й бит для сдвига на 16 (не используется для 11 бит)
        assign s4 = s3;
    endgenerate
    
    assign shifted = s4;

    // frac10 из shifted или 0
    wire [9:0] frac10_subnorm;
    mux2_n #(.WIDTH(10)) frac_subnorm_mux(
        .a(shifted[9:0]),
        .b(10'd0),
        .sel(shift_gte_12),
        .out(frac10_subnorm)
    );

    // frac10 для normal
    wire [9:0] frac10_normal;
    assign frac10_normal = mant_in[9:0];

    // Выбор frac10
    wire [9:0] frac10_num;
    mux2_n #(.WIDTH(10)) frac_choice(
        .a(frac10_normal),
        .b(frac10_subnorm),
        .sel(e_biased_lte_zero),
        .out(frac10_num)
    );

    // Выбор exp для output
    wire [4:0] exp_subnorm;
    assign exp_subnorm = 5'd0;
    
    wire [4:0] exp_normal;
    assign exp_normal = e_biased[4:0];
    
    wire [4:0] exp_num;
    mux2_n #(.WIDTH(5)) exp_choice(
        .a(exp_normal),
        .b(exp_subnorm),
        .sel(e_biased_lte_zero),
        .out(exp_num)
    );

    // Формирование выходов для разных случаев
    wire [15:0] data_nan, data_pinf, data_ninf, data_zero, data_num;
    
    assign data_nan = 16'hFE00;
    assign data_pinf = 16'h7C00;
    assign data_ninf = 16'hFE00;
    
    assign data_zero = {sign_in, 15'd0};
    assign data_num = {sign_in, exp_num, frac10_num};

    // Выбор выхода
    wire [15:0] data_step1, data_step2, data_step3, data_step4;
    
    mux2_n #(.WIDTH(16)) data_m1(
        .a(data_num),
        .b(data_nan),
        .sel(is_nan_in),
        .out(data_step1)
    );
    
    mux2_n #(.WIDTH(16)) data_m2(
        .a(data_step1),
        .b(data_pinf),
        .sel(is_pinf_in),
        .out(data_step2)
    );
    
    mux2_n #(.WIDTH(16)) data_m3(
        .a(data_step2),
        .b(data_ninf),
        .sel(is_ninf_in),
        .out(data_step3)
    );
    
    mux2_n #(.WIDTH(16)) data_m4(
        .a(data_step3),
        .b(data_zero),
        .sel(is_zero),
        .out(data_step4)
    );
    
    wire [15:0] out_data_comb;
    assign out_data_comb = data_step4;

    // Регистры
    wire p_valid_next;
    and(p_valid_next, it_valid, enable);
    
    wire p_valid_d;
    mux2 p_valid_mux(.a(1'b0), .b(p_valid_next), .sel(enable), .out(p_valid_d));
    dff p_valid_ff(.clk(clk), .d(p_valid_d), .q(p_valid));

    wire result_out_d;
    mux2 result_mux(.a(result_out), .b(result_in), .sel(p_valid_next), .out(result_out_d));
    dff result_ff(.clk(clk), .d(result_out_d), .q(result_out));

    wire [15:0] out_data_d;
    mux2_n #(.WIDTH(16)) data_mux(.a(out_data), .b(out_data_comb), .sel(p_valid_next), .out(out_data_d));
    register_n #(.WIDTH(16)) data_reg(.clk(clk), .rst(1'b0), .d(out_data_d), .q(out_data));

    wire is_nan_out_d, is_pinf_out_d, is_ninf_out_d;
    
    mux2 is_nan_mux(.a(is_nan_out), .b(is_nan_in), .sel(p_valid_next), .out(is_nan_out_d));
    dff is_nan_ff(.clk(clk), .d(is_nan_out_d), .q(is_nan_out));
    
    mux2 is_pinf_mux(.a(is_pinf_out), .b(is_pinf_in), .sel(p_valid_next), .out(is_pinf_out_d));
    dff is_pinf_ff(.clk(clk), .d(is_pinf_out_d), .q(is_pinf_out));
    
    mux2 is_ninf_mux(.a(is_ninf_out), .b(is_ninf_in), .sel(p_valid_next), .out(is_ninf_out_d));
    dff is_ninf_ff(.clk(clk), .d(is_ninf_out_d), .q(is_ninf_out));

endmodule