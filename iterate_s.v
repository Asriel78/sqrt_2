`timescale 1ns/1ps

module iterate (
    input  wire        clk,
    input  wire        enable,
    input  wire        n_valid,

    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,
    input  wire        is_num,

    input  wire        sign_in,
    input  wire [10:0] mant_in,
    input  wire signed [6:0] exp_in,

    output wire        it_valid,
    output wire        result,

    output wire        sign_out,
    output wire signed [6:0] exp_out,
    output wire [10:0] mant_out,
    
    output wire        is_nan_out,
    output wire        is_pinf_out,
    output wire        is_ninf_out
);

    localparam ITER_MAX = 4'd11;

    // ========================================================================
    // РЕГИСТРЫ СОСТОЯНИЯ
    // ========================================================================
    wire active;
    wire [3:0] iter_left;
    wire [33:0] radicand;
    wire [22:0] remainder;
    wire [11:0] root;
    wire is_special;
    wire stored_is_nan;
    wire stored_is_pinf;
    wire stored_is_ninf;

    // ========================================================================
    // ДЕТЕКТОРЫ ВХОДНЫХ УСЛОВИЙ
    // ========================================================================
    
    // is_zero = (exp_in == -15) && (mant_in == 0)
    wire [6:0] minus15_pattern = 7'b1110001; // -15 в дополнительном коде
    wire exp_is_minus15;
    wire mant_is_zero;
    wire is_zero;
    
    comparator_eq_n #(.WIDTH(7)) exp_m15_cmp(
        .a(exp_in), 
        .b(minus15_pattern), 
        .eq(exp_is_minus15)
    );
    
    is_zero_n #(.WIDTH(11)) mant_zero_check(
        .in(mant_in), 
        .is_zero(mant_is_zero)
    );
    
    and(is_zero, exp_is_minus15, mant_is_zero);
    
    // is_special_input = !is_num || is_nan_in || is_pinf_in || is_ninf_in
    wire not_is_num;
    wire is_special_input;
    not(not_is_num, is_num);
    or(is_special_input, not_is_num, is_nan_in, is_pinf_in, is_ninf_in);
    
    // Триггер начала: n_valid && !active
    wire active_n;
    wire start_trigger;
    not(active_n, active);
    and(start_trigger, n_valid, active_n);

    // ========================================================================
    // КОМБИНАЦИОННАЯ ЛОГИКА АЛГОРИТМА
    // ========================================================================
    
    // trial_comb = {root[10:0], 2'b01}
    wire [22:0] trial_comb;
    assign trial_comb = {root[10:0], 2'b01};
    
    // remainder_next = {remainder[20:0], radicand[33:32]}
    wire [22:0] remainder_next;
    assign remainder_next = {remainder[20:0], radicand[33:32]};
    
    // Сравнение: remainder_next >= trial_comb
    wire rem_gte_trial;
    comparator_gte_n #(.WIDTH(23)) rem_cmp(
        .a(remainder_next),
        .b(trial_comb),
        .gte(rem_gte_trial)
    );
    
    // root_next = (remainder_next >= trial_comb) ? {root[10:0], 1'b1} : {root[10:0], 1'b0}
    wire [11:0] root_next;
    wire [11:0] root_with_1, root_with_0;
    assign root_with_1 = {root[10:0], 1'b1};
    assign root_with_0 = {root[10:0], 1'b0};
    
    mux2_n #(.WIDTH(12)) root_next_mux(
        .a(root_with_0),
        .b(root_with_1),
        .sel(rem_gte_trial),
        .out(root_next)
    );
    
    // remainder вычитание: remainder_next - trial_comb
    wire [22:0] remainder_minus_trial;
    wire borrow_rem;
    
    subtractor_n #(.WIDTH(23)) rem_sub(
        .a(remainder_next),
        .b(trial_comb),
        .diff(remainder_minus_trial),
        .borrow(borrow_rem)
    );

    // ========================================================================
    // ЛОГИКА work_mant и work_exp
    // ========================================================================
    
    // Проверка чётности экспоненты: exp_in[0]
    wire exp_is_odd;
    assign exp_is_odd = exp_in[0];
    
    // work_mant = exp_in[0] ? {mant_in, 1'b0} : mant_in (расширяем до 12 бит)
    wire [11:0] work_mant;
    wire [11:0] mant_shifted;
    assign mant_shifted = {mant_in, 1'b0};
    
    mux2_n #(.WIDTH(12)) work_mant_mux(
        .a({1'b0, mant_in}),
        .b(mant_shifted),
        .sel(exp_is_odd),
        .out(work_mant)
    );
    
    // work_exp = exp_in[0] ? (exp_in - 1) : exp_in
    wire signed [6:0] exp_minus_1;
    wire cout_exp;
    
    adder_n #(.WIDTH(7)) exp_dec(
        .a(exp_in),
        .b(7'b1111111), // -1 в дополнительном коде
        .cin(1'b0),
        .sum(exp_minus_1),
        .cout(cout_exp)
    );
    
    wire signed [6:0] work_exp;
    mux2_n #(.WIDTH(7)) work_exp_mux(
        .a(exp_in),
        .b(exp_minus_1),
        .sel(exp_is_odd),
        .out(work_exp)
    );
    
    // exp_out_start = work_exp >>> 1 (арифметический сдвиг вправо)
    wire signed [6:0] exp_out_start;
    assign exp_out_start = {work_exp[6], work_exp[6:1]};

    // ========================================================================
    // ЛОГИКА mant_out во время итераций
    // ========================================================================
    
    // Проверка iter_left > 1
    wire iter_gt_1;
    comparator_gt_n #(.WIDTH(4)) iter_cmp(
        .a(iter_left),
        .b(4'd1),
        .gt(iter_gt_1)
    );
    
    // shift_amt = iter_left - 1
    wire [3:0] iter_minus_1;
    wire cout_iter;
    
    adder_n #(.WIDTH(4)) iter_dec(
        .a(iter_left),
        .b(4'b1111), // -1
        .cin(1'b0),
        .sum(iter_minus_1),
        .cout(cout_iter)
    );
    
    // mant_out_computing = iter_left > 1 ? (root_next[10:0] << iter_minus_1) : root_next[10:0]
    wire [10:0] mant_shifted_compute;
    barrel_shift_left_11bit mant_shifter(
        .in(root_next[10:0]),
        .shift_amt(iter_minus_1),
        .out(mant_shifted_compute)
    );
    
    wire [10:0] mant_out_computing;
    mux2_n #(.WIDTH(11)) mant_compute_mux(
        .a(root_next[10:0]),
        .b(mant_shifted_compute),
        .sel(iter_gt_1),
        .out(mant_out_computing)
    );

    // ========================================================================
    // ЛОГИКА NEXT ЗНАЧЕНИЙ ДЛЯ РЕГИСТРОВ (enable == 1)
    // ========================================================================
    
    // --- active_next ---
    wire active_next_enabled;
    wire active_stays_on;
    wire iter_eq_1;
    
    comparator_eq_n #(.WIDTH(4)) iter_eq1_cmp(
        .a(iter_left),
        .b(4'd1),
        .eq(iter_eq_1)
    );
    
    wire iter_not_eq_1;
    not(iter_not_eq_1, iter_eq_1);
    and(active_stays_on, active, iter_not_eq_1);
    
    wire start_computing;
    wire not_is_zero;
    wire not_is_special_input;
    not(not_is_zero, is_zero);
    not(not_is_special_input, is_special_input);
    and(start_computing, start_trigger, not_is_zero, not_is_special_input);
    
    or(active_next_enabled, start_computing, active_stays_on);
    
    // --- iter_left_next ---
    wire [3:0] iter_left_next_enabled;
    wire [3:0] iter_left_dec;
    
    decrement_n #(.WIDTH(4)) iter_decrement(
        .in(iter_left),
        .out(iter_left_dec)
    );
    
    wire [3:0] iter_for_start;
    wire [3:0] iter_when_active;
    
    mux2_n #(.WIDTH(4)) iter_start_mux(
        .a(iter_left),
        .b(ITER_MAX),
        .sel(start_computing),
        .out(iter_for_start)
    );
    
    mux2_n #(.WIDTH(4)) iter_active_mux(
        .a(iter_for_start),
        .b(iter_left_dec),
        .sel(active),
        .out(iter_left_next_enabled)
    );
    
    // --- radicand_next ---
    wire [33:0] radicand_next_enabled;
    wire [33:0] radicand_shifted;
    wire [33:0] radicand_for_start;
    
    assign radicand_shifted = {radicand[31:0], 2'b00};
    
    mux2_n #(.WIDTH(34)) radicand_start_mux(
        .a(radicand),
        .b({work_mant, 22'd0}),
        .sel(start_computing),
        .out(radicand_for_start)
    );
    
    mux2_n #(.WIDTH(34)) radicand_active_mux(
        .a(radicand_for_start),
        .b(radicand_shifted),
        .sel(active),
        .out(radicand_next_enabled)
    );
    
    // --- remainder_next ---
    wire [22:0] remainder_next_enabled;
    wire [22:0] remainder_updated;
    wire [22:0] remainder_for_start;
    
    mux2_n #(.WIDTH(23)) remainder_update_mux(
        .a(remainder_next),
        .b(remainder_minus_trial),
        .sel(rem_gte_trial),
        .out(remainder_updated)
    );
    
    mux2_n #(.WIDTH(23)) remainder_start_mux(
        .a(remainder),
        .b(23'd0),
        .sel(start_computing),
        .out(remainder_for_start)
    );
    
    mux2_n #(.WIDTH(23)) remainder_active_mux(
        .a(remainder_for_start),
        .b(remainder_updated),
        .sel(active),
        .out(remainder_next_enabled)
    );
    
    // --- root_next ---
    wire [11:0] root_next_enabled;
    wire [11:0] root_for_start;
    
    mux2_n #(.WIDTH(12)) root_start_mux(
        .a(root),
        .b(12'd0),
        .sel(start_computing),
        .out(root_for_start)
    );
    
    mux2_n #(.WIDTH(12)) root_active_mux(
        .a(root_for_start),
        .b(root_next),
        .sel(active),
        .out(root_next_enabled)
    );
    
    // --- is_special_next ---
    wire is_special_next_enabled;
    wire is_special_set;
    wire is_special_keep;
    
    or(is_special_set, is_zero, is_special_input);
    and(is_special_keep, start_trigger, is_special_set);
    
    wire is_special_held;
    and(is_special_held, is_special, active_n);
    
    or(is_special_next_enabled, is_special_keep, is_special_held);
    
    // --- stored flags ---
    wire stored_is_nan_next, stored_is_pinf_next, stored_is_ninf_next;
    wire store_nan, store_pinf, store_ninf;
    
    // Сохраняем флаги только при is_special_input (не zero!)
    wire store_special_flags;
    and(store_special_flags, start_trigger, is_special_input);
    
    // NaN: стандартный или из -Inf
    wire store_nan_from_ninf;
    and(store_nan_from_ninf, store_special_flags, is_ninf_in);
    
    wire store_nan_regular;
    and(store_nan_regular, store_special_flags, is_nan_in);
    
    or(store_nan, store_nan_regular, store_nan_from_ninf);
    
    // +Inf: только если входной +Inf
    and(store_pinf, store_special_flags, is_pinf_in);
    
    // -Inf не сохраняется (превращается в NaN)
    assign store_ninf = 1'b0;
    
    wire keep_stored_nan, keep_stored_pinf, keep_stored_ninf;
    and(keep_stored_nan, stored_is_nan, active_n);
    and(keep_stored_pinf, stored_is_pinf, active_n);
    and(keep_stored_ninf, stored_is_ninf, active_n);
    
    or(stored_is_nan_next, store_nan, keep_stored_nan);
    or(stored_is_pinf_next, store_pinf, keep_stored_pinf);
    or(stored_is_ninf_next, store_ninf, keep_stored_ninf);
    
    // --- it_valid_next ---
    wire it_valid_next_enabled;
    wire it_valid_on;
    
    or(it_valid_on, start_trigger, active);
    assign it_valid_next_enabled = it_valid_on;
    
    // --- result_next ---
    wire result_next_enabled;
    wire result_on;
    wire result_from_start, result_from_active;
    
    and(result_from_start, start_trigger, is_special_set);
    and(result_from_active, active, iter_eq_1);
    or(result_on, result_from_start, result_from_active);
    assign result_next_enabled = result_on;
    
    // --- sign_out_next ---
    wire sign_out_next_enabled;
    wire sign_for_zero, sign_for_special, sign_for_compute;
    wire [2:0] sign_sel; // 3-битный селектор для разных случаев
    
    // Случай 1: zero -> sign_in
    and(sign_sel[0], start_trigger, is_zero);
    assign sign_for_zero = sign_in;
    
    // Случай 2: special -> зависит от типа
    // NaN или -Inf: sign=1, +Inf: sign=0
    wire sign_for_nan_or_ninf;
    wire is_nan_or_ninf;
    or(is_nan_or_ninf, is_nan_in, is_ninf_in);
    assign sign_for_nan_or_ninf = is_nan_or_ninf;
    
    wire sign_for_pinf;
    assign sign_for_pinf = 1'b0;
    
    mux2 sign_special_mux(
        .a(sign_for_pinf),
        .b(1'b1),
        .sel(is_nan_or_ninf),
        .out(sign_for_special)
    );
    
    and(sign_sel[1], start_trigger, is_special_input);
    
    // Случай 3: compute -> 0
    and(sign_sel[2], start_trigger, not_is_zero, not_is_special_input);
    assign sign_for_compute = 1'b0;
    
    // Финальный мультиплексор для sign
    wire sign_choice1, sign_choice2;
    mux2 sign_mux1(.a(sign_out), .b(sign_for_zero), .sel(sign_sel[0]), .out(sign_choice1));
    mux2 sign_mux2(.a(sign_choice1), .b(sign_for_special), .sel(sign_sel[1]), .out(sign_choice2));
    mux2 sign_mux3(.a(sign_choice2), .b(sign_for_compute), .sel(sign_sel[2]), .out(sign_out_next_enabled));
    
    // --- exp_out_next ---
    wire signed [6:0] exp_out_next_enabled;
    wire signed [6:0] exp_for_zero, exp_for_special, exp_for_compute;
    wire signed [6:0] exp_choice1, exp_choice2;
    
    assign exp_for_zero = minus15_pattern; // -15
    assign exp_for_special = 7'sd16; // Для NaN/Inf
    assign exp_for_compute = exp_out_start;
    
    mux2_n #(.WIDTH(7)) exp_mux1(.a(exp_out), .b(exp_for_zero), .sel(sign_sel[0]), .out(exp_choice1));
    mux2_n #(.WIDTH(7)) exp_mux2(.a(exp_choice1), .b(exp_for_special), .sel(sign_sel[1]), .out(exp_choice2));
    mux2_n #(.WIDTH(7)) exp_mux3(.a(exp_choice2), .b(exp_for_compute), .sel(sign_sel[2]), .out(exp_out_next_enabled));
    
    // --- mant_out_next ---
    wire [10:0] mant_out_next_enabled;
    wire [10:0] mant_for_zero, mant_for_special, mant_for_compute;
    wire [10:0] mant_choice1, mant_choice2, mant_choice3;
    
    assign mant_for_zero = 11'd0;
    
    // mant для special зависит от типа: NaN/ninf -> 11'b10000000000, +Inf -> 0
    wire [10:0] mant_nan_pattern = 11'b10000000000;
    wire [10:0] mant_special_value;
    
    mux2_n #(.WIDTH(11)) mant_special_mux(
        .a(11'd0),
        .b(mant_nan_pattern),
        .sel(is_nan_or_ninf),
        .out(mant_special_value)
    );
    
    assign mant_for_special = mant_special_value;
    assign mant_for_compute = mant_out; // При старте держим текущее
    
    mux2_n #(.WIDTH(11)) mant_mux1(.a(mant_out), .b(mant_for_zero), .sel(sign_sel[0]), .out(mant_choice1));
    mux2_n #(.WIDTH(11)) mant_mux2(.a(mant_choice1), .b(mant_for_special), .sel(sign_sel[1]), .out(mant_choice2));
    mux2_n #(.WIDTH(11)) mant_mux3(.a(mant_choice2), .b(mant_for_compute), .sel(sign_sel[2]), .out(mant_choice3));
    
    // Во время active: обновляем mant_out
    mux2_n #(.WIDTH(11)) mant_active_final(.a(mant_choice3), .b(mant_out_computing), .sel(active), .out(mant_out_next_enabled));
    
    // --- is_nan_out, is_pinf_out, is_ninf_out ---
    wire is_nan_out_next, is_pinf_out_next, is_ninf_out_next;
    wire nan_from_special, pinf_from_special, ninf_from_special;
    wire nan_from_stored, pinf_from_stored, ninf_from_stored;
    
    // Во время special start: устанавливаем флаги
    and(nan_from_special, start_trigger, is_special_input, is_nan_or_ninf);
    and(pinf_from_special, start_trigger, is_special_input, is_pinf_in);
    // ninf превращается в nan, поэтому ninf_from_special = 0
    
    // Когда is_special && !active: восстанавливаем из stored
    wire restore_flags;
    and(restore_flags, is_special, active_n);
    
    and(nan_from_stored, restore_flags, stored_is_nan);
    and(pinf_from_stored, restore_flags, stored_is_pinf);
    and(ninf_from_stored, restore_flags, stored_is_ninf);
    
    // Комбинируем
    or(is_nan_out_next, nan_from_special, nan_from_stored);
    or(is_pinf_out_next, pinf_from_special, pinf_from_stored);
    or(is_ninf_out_next, ninf_from_stored); // всегда 0

    // ========================================================================
    // ФИНАЛЬНЫЕ NEXT ЗНАЧЕНИЯ С УЧЕТОМ enable
    // ========================================================================
    
    wire active_next, is_special_next;
    wire [3:0] iter_left_next;
    wire [33:0] radicand_next;
    wire [22:0] remainder_next_final;
    wire [11:0] root_next_final;
    wire stored_is_nan_next_final, stored_is_pinf_next_final, stored_is_ninf_next_final;
    wire it_valid_next, result_next, sign_out_next;
    wire signed [6:0] exp_out_next;
    wire [10:0] mant_out_next;
    wire is_nan_out_next_final, is_pinf_out_next_final, is_ninf_out_next_final;
    
    // Если enable=0, всё сбрасывается. Если enable=1, используем _next_enabled
    mux2 active_en(.a(1'b0), .b(active_next_enabled), .sel(enable), .out(active_next));
    mux2 is_special_en(.a(1'b0), .b(is_special_next_enabled), .sel(enable), .out(is_special_next));
    mux2_n #(.WIDTH(4)) iter_en(.a(4'd0), .b(iter_left_next_enabled), .sel(enable), .out(iter_left_next));
    mux2_n #(.WIDTH(34)) radicand_en(.a(34'd0), .b(radicand_next_enabled), .sel(enable), .out(radicand_next));
    mux2_n #(.WIDTH(23)) remainder_en(.a(23'd0), .b(remainder_next_enabled), .sel(enable), .out(remainder_next_final));
    mux2_n #(.WIDTH(12)) root_en(.a(12'd0), .b(root_next_enabled), .sel(enable), .out(root_next_final));
    
    mux2 stored_nan_en(.a(1'b0), .b(stored_is_nan_next), .sel(enable), .out(stored_is_nan_next_final));
    mux2 stored_pinf_en(.a(1'b0), .b(stored_is_pinf_next), .sel(enable), .out(stored_is_pinf_next_final));
    mux2 stored_ninf_en(.a(1'b0), .b(stored_is_ninf_next), .sel(enable), .out(stored_is_ninf_next_final));
    
    mux2 it_valid_en(.a(1'b0), .b(it_valid_next_enabled), .sel(enable), .out(it_valid_next));
    mux2 result_en(.a(1'b0), .b(result_next_enabled), .sel(enable), .out(result_next));
    mux2 sign_en(.a(1'b0), .b(sign_out_next_enabled), .sel(enable), .out(sign_out_next));
    mux2_n #(.WIDTH(7)) exp_en(.a(7'sd0), .b(exp_out_next_enabled), .sel(enable), .out(exp_out_next));
    mux2_n #(.WIDTH(11)) mant_en(.a(11'd0), .b(mant_out_next_enabled), .sel(enable), .out(mant_out_next));
    
    mux2 nan_out_en(.a(1'b0), .b(is_nan_out_next), .sel(enable), .out(is_nan_out_next_final));
    mux2 pinf_out_en(.a(1'b0), .b(is_pinf_out_next), .sel(enable), .out(is_pinf_out_next_final));
    mux2 ninf_out_en(.a(1'b0), .b(is_ninf_out_next), .sel(enable), .out(is_ninf_out_next_final));

    // ========================================================================
    // РЕГИСТРЫ
    // ========================================================================
    
    dff active_reg(.clk(clk), .d(active_next), .q(active));
    dff is_special_reg(.clk(clk), .d(is_special_next), .q(is_special));
    
    register_n #(.WIDTH(4)) iter_left_reg(.clk(clk), .rst(1'b0), .d(iter_left_next), .q(iter_left));
    register_n #(.WIDTH(34)) radicand_reg(.clk(clk), .rst(1'b0), .d(radicand_next), .q(radicand));
    register_n #(.WIDTH(23)) remainder_reg(.clk(clk), .rst(1'b0), .d(remainder_next_final), .q(remainder));
    register_n #(.WIDTH(12)) root_reg(.clk(clk), .rst(1'b0), .d(root_next_final), .q(root));
    
    dff stored_nan_reg(.clk(clk), .d(stored_is_nan_next_final), .q(stored_is_nan));
    dff stored_pinf_reg(.clk(clk), .d(stored_is_pinf_next_final), .q(stored_is_pinf));
    dff stored_ninf_reg(.clk(clk), .d(stored_is_ninf_next_final), .q(stored_is_ninf));
    
    dff it_valid_reg(.clk(clk), .d(it_valid_next), .q(it_valid));
    dff result_reg(.clk(clk), .d(result_next), .q(result));
    dff sign_out_reg(.clk(clk), .d(sign_out_next), .q(sign_out));
    register_n #(.WIDTH(7)) exp_out_reg(.clk(clk), .rst(1'b0), .d(exp_out_next), .q(exp_out));
    register_n #(.WIDTH(11)) mant_out_reg(.clk(clk), .rst(1'b0), .d(mant_out_next), .q(mant_out));
    
    dff nan_out_reg(.clk(clk), .d(is_nan_out_next_final), .q(is_nan_out));
    dff pinf_out_reg(.clk(clk), .d(is_pinf_out_next_final), .q(is_pinf_out));
    dff ninf_out_reg(.clk(clk), .d(is_ninf_out_next_final), .q(is_ninf_out));

endmodule