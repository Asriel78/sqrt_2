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

    wire is_zero_input;
    wire exp_zero;
    wire mant_zero;
    
    is_zero_n #(.WIDTH(5)) exp_z(.in(exp_in), .is_zero(exp_zero));
    is_zero_n #(.WIDTH(10)) mant_z(.in(mant_in), .is_zero(mant_zero));
    and(is_zero_input, exp_zero, mant_zero);

    // CLZ для субнормальных
    wire [3:0] clz_count;
    clz_10bit clz_inst(.in(mant_in), .count(clz_count));

    // Нормализация мантиссы субнормальных: сдвиг влево на (clz+1)
    wire [3:0] shift_amt_subnorm;
    increment_n #(.WIDTH(4)) clz_inc(
        .in(clz_count),
        .out(shift_amt_subnorm),
        .overflow()
    );
    
    wire [10:0] mant_subnorm_shifted;
    wire [10:0] mant_subnorm_input;
    assign mant_subnorm_input = {1'b0, mant_in};
    
    // Barrel shifter для субнормальных
    wire [10:0] subnorm_stage0, subnorm_stage1, subnorm_stage2, subnorm_stage3;
    
    genvar i;
    generate
        for (i = 0; i < 11; i = i + 1) begin : subnorm_s0
            if (i == 0)
                mux2 m(.a(mant_subnorm_input[i]), .b(1'b0), .sel(shift_amt_subnorm[0]), .out(subnorm_stage0[i]));
            else
                mux2 m(.a(mant_subnorm_input[i]), .b(mant_subnorm_input[i-1]), .sel(shift_amt_subnorm[0]), .out(subnorm_stage0[i]));
        end
        
        for (i = 0; i < 11; i = i + 1) begin : subnorm_s1
            if (i < 2)
                mux2 m(.a(subnorm_stage0[i]), .b(1'b0), .sel(shift_amt_subnorm[1]), .out(subnorm_stage1[i]));
            else
                mux2 m(.a(subnorm_stage0[i]), .b(subnorm_stage0[i-2]), .sel(shift_amt_subnorm[1]), .out(subnorm_stage1[i]));
        end
        
        for (i = 0; i < 11; i = i + 1) begin : subnorm_s2
            if (i < 4)
                mux2 m(.a(subnorm_stage1[i]), .b(1'b0), .sel(shift_amt_subnorm[2]), .out(subnorm_stage2[i]));
            else
                mux2 m(.a(subnorm_stage1[i]), .b(subnorm_stage1[i-4]), .sel(shift_amt_subnorm[2]), .out(subnorm_stage2[i]));
        end
        
        for (i = 0; i < 11; i = i + 1) begin : subnorm_s3
            if (i < 8)
                mux2 m(.a(subnorm_stage2[i]), .b(1'b0), .sel(shift_amt_subnorm[3]), .out(subnorm_stage3[i]));
            else
                mux2 m(.a(subnorm_stage2[i]), .b(subnorm_stage2[i-8]), .sel(shift_amt_subnorm[3]), .out(subnorm_stage3[i]));
        end
    endgenerate
    
    assign mant_subnorm_shifted = subnorm_stage3;

    // Экспонента для субнормальных: -BIAS - clz
    wire [6:0] clz_extended;
    assign clz_extended = {3'b000, clz_count};
    
    wire [6:0] neg_bias;
    wire [6:0] bias_const;
    wire [6:0] bias_inv;
    
    assign bias_const = BIAS;
    
    generate
        for (i = 0; i < 7; i = i + 1) begin : bias_inv_gen
            not(bias_inv[i], bias_const[i]);
        end
    endgenerate
    adder_n #(.WIDTH(7)) bias_neg(
        .a(bias_inv),
        .b(7'd1),
        .cin(1'b0),
        .sum(neg_bias),
        .cout()
    );
    
    wire [6:0] exp_subnorm;
    subtractor_n #(.WIDTH(7)) exp_sub(
        .a(neg_bias),
        .b(clz_extended),
        .diff(exp_subnorm),
        .borrow()
    );

    // Экспонента для нормальных: exp_in - BIAS
    wire [6:0] exp_extended;
    assign exp_extended = {2'b00, exp_in};
    wire [6:0] exp_normal;
    subtractor_n #(.WIDTH(7)) exp_norm_sub(
        .a(exp_extended),
        .b(BIAS),
        .diff(exp_normal),
        .borrow()
    );

    // Мантисса для нормальных
    wire [10:0] mant_normal;
    assign mant_normal = {1'b1, mant_in};

    // Мантисса для специальных значений
    wire [10:0] mant_special;
    assign mant_special = {1'b0, mant_in};

    // Экспонента для нуля: -15
    wire [6:0] exp_zero_val;
    wire [6:0] fifteen_const;
    wire [6:0] fifteen_inv;
    
    assign fifteen_const = 7'd15;
    
    generate
        for (i = 0; i < 7; i = i + 1) begin : fifteen_inv_gen
            not(fifteen_inv[i], fifteen_const[i]);
        end
    endgenerate
    adder_n #(.WIDTH(7)) exp_zero_calc(
        .a(fifteen_inv),
        .b(7'd1),
        .cin(1'b0),
        .sum(exp_zero_val),
        .cout()
    );

    // Комбинационная логика выбора выходов
    wire [10:0] mant_out_comb;
    wire [6:0] exp_out_comb;
    wire sign_out_comb;
    wire is_num_comb, is_nan_comb, is_pinf_comb, is_ninf_comb;

    assign sign_out_comb = sign_in;

    // Выбор мантиссы
    wire [10:0] mant_choice1;
    mux2_n #(.WIDTH(11)) mant_m1(
        .a(mant_special),
        .b(mant_normal),
        .sel(is_normal_in),
        .out(mant_choice1)
    );
    
    wire [10:0] mant_choice2;
    mux2_n #(.WIDTH(11)) mant_m2(
        .a(mant_choice1),
        .b(mant_subnorm_shifted),
        .sel(is_subnormal_in),
        .out(mant_choice2)
    );
    
    mux2_n #(.WIDTH(11)) mant_m3(
        .a(mant_choice2),
        .b(11'd0),
        .sel(is_zero_input),
        .out(mant_out_comb)
    );

    // Выбор экспоненты
    wire [6:0] exp_choice1;
    mux2_n #(.WIDTH(7)) exp_m1(
        .a(exp_normal),
        .b(exp_normal),
        .sel(is_normal_in),
        .out(exp_choice1)
    );
    
    wire [6:0] exp_choice2;
    mux2_n #(.WIDTH(7)) exp_m2(
        .a(exp_choice1),
        .b(exp_subnorm),
        .sel(is_subnormal_in),
        .out(exp_choice2)
    );
    
    mux2_n #(.WIDTH(7)) exp_m3(
        .a(exp_choice2),
        .b(exp_zero_val),
        .sel(is_zero_input),
        .out(exp_out_comb)
    );

    // Флаги
    wire is_regular;
    or(is_regular, is_normal_in, is_subnormal_in, is_zero_input);
    assign is_num_comb = is_regular;
    assign is_nan_comb = is_nan_in;
    assign is_pinf_comb = is_pinf_in;
    assign is_ninf_comb = is_ninf_in;

    // Регистры
    wire n_valid_next;
    and(n_valid_next, s_valid, enable);
    
    wire n_valid_d;
    mux2 n_valid_mux(.a(1'b0), .b(n_valid_next), .sel(enable), .out(n_valid_d));
    dff n_valid_ff(.clk(clk), .d(n_valid_d), .q(n_valid));

    wire is_num_d, is_nan_d, is_pinf_d, is_ninf_d;
    
    mux2 is_num_mux(.a(1'b0), .b(is_num_comb), .sel(n_valid_next), .out(is_num_d));
    dff is_num_ff(.clk(clk), .d(is_num_d), .q(is_num));
    
    mux2 is_nan_mux(.a(1'b0), .b(is_nan_comb), .sel(n_valid_next), .out(is_nan_d));
    dff is_nan_ff(.clk(clk), .d(is_nan_d), .q(is_nan));
    
    mux2 is_pinf_mux(.a(1'b0), .b(is_pinf_comb), .sel(n_valid_next), .out(is_pinf_d));
    dff is_pinf_ff(.clk(clk), .d(is_pinf_d), .q(is_pinf));
    
    mux2 is_ninf_mux(.a(1'b0), .b(is_ninf_comb), .sel(n_valid_next), .out(is_ninf_d));
    dff is_ninf_ff(.clk(clk), .d(is_ninf_d), .q(is_ninf));

    wire sign_out_d;
    wire [6:0] exp_out_d;
    wire [10:0] mant_out_d;
    
    mux2 sign_mux(.a(sign_out), .b(sign_out_comb), .sel(n_valid_next), .out(sign_out_d));
    dff sign_ff(.clk(clk), .d(sign_out_d), .q(sign_out));
    
    mux2_n #(.WIDTH(7)) exp_mux(.a(exp_out), .b(exp_out_comb), .sel(n_valid_next), .out(exp_out_d));
    register_n #(.WIDTH(7)) exp_reg(.clk(clk), .rst(1'b0), .d(exp_out_d), .q(exp_out));
    
    mux2_n #(.WIDTH(11)) mant_mux(.a(mant_out), .b(mant_out_comb), .sel(n_valid_next), .out(mant_out_d));
    register_n #(.WIDTH(11)) mant_reg(.clk(clk), .rst(1'b0), .d(mant_out_d), .q(mant_out));

endmodule