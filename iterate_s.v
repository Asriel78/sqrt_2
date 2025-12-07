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

    wire active;
    wire [3:0] iter_left;
    wire [33:0] radicand;
    wire [22:0] remainder;
    wire [11:0] root;
    wire is_special;
    wire stored_is_nan, stored_is_pinf, stored_is_ninf;


    wire [6:0] minus15 = 7'b1110001;
    wire exp_is_minus15, mant_is_zero, is_zero;
    
    comparator_eq_n #(.WIDTH(7)) exp_cmp(.a(exp_in), .b(minus15), .eq(exp_is_minus15));
    is_zero_n #(.WIDTH(11)) mant_check(.in(mant_in), .is_zero(mant_is_zero));
    and(is_zero, exp_is_minus15, mant_is_zero);
    

    wire not_is_num, is_special_input;
    not(not_is_num, is_num);
    or(is_special_input, not_is_num, is_nan_in, is_pinf_in, is_ninf_in);
    

    wire active_n, start_trigger;
    not(active_n, active);
    and(start_trigger, n_valid, active_n);

  
    wire [22:0] trial = {root[10:0], 2'b01};
    wire [22:0] remainder_next = {remainder[20:0], radicand[33:32]};
    
    wire rem_gte_trial;
    comparator_gte_n #(.WIDTH(23)) cmp(.a(remainder_next), .b(trial), .gte(rem_gte_trial));
    
    wire [11:0] root_next;
    mux2_n #(.WIDTH(12)) root_mux(
        .a({root[10:0], 1'b0}),
        .b({root[10:0], 1'b1}),
        .sel(rem_gte_trial),
        .out(root_next)
    );
    
    wire [22:0] remainder_sub;
    wire borrow;
    subtractor_n #(.WIDTH(23)) sub(.a(remainder_next), .b(trial), .diff(remainder_sub), .borrow(borrow));

    wire exp_is_odd = exp_in[0];
    
    wire [11:0] work_mant;
    mux2_n #(.WIDTH(12)) mant_mux(
        .a({1'b0, mant_in}),
        .b({mant_in, 1'b0}),
        .sel(exp_is_odd),
        .out(work_mant)
    );
    
    wire signed [6:0] exp_dec;
    wire cout;
    adder_n #(.WIDTH(7)) exp_add(.a(exp_in), .b(7'b1111111), .cin(1'b0), .sum(exp_dec), .cout(cout));
    
    wire signed [6:0] work_exp;
    mux2_n #(.WIDTH(7)) exp_mux(.a(exp_in), .b(exp_dec), .sel(exp_is_odd), .out(work_exp));
    
    wire signed [6:0] exp_out_calc = {work_exp[6], work_exp[6:1]};

    wire iter_gt_1;
    comparator_gt_n #(.WIDTH(4)) iter_cmp(.a(iter_left), .b(4'd1), .gt(iter_gt_1));
    
    wire [3:0] shift_amt;
    decrement_n #(.WIDTH(4)) dec(.in(iter_left), .out(shift_amt));
    
    wire [10:0] mant_shifted;
    barrel_shift_left_11bit shifter(.in(root_next[10:0]), .shift_amt(shift_amt), .out(mant_shifted));
    
    wire [10:0] mant_computing;
    mux2_n #(.WIDTH(11)) mant_comp_mux(.a(root_next[10:0]), .b(mant_shifted), .sel(iter_gt_1), .out(mant_computing));

    wire iter_eq_1, iter_not_1;
    comparator_eq_n #(.WIDTH(4)) iter_eq(.a(iter_left), .b(4'd1), .eq(iter_eq_1));
    not(iter_not_1, iter_eq_1);
    
    wire start_compute;
    wire not_zero, not_special;
    not(not_zero, is_zero);
    not(not_special, is_special_input);
    and(start_compute, start_trigger, not_zero, not_special);
    
    wire active_stay;
    and(active_stay, active, iter_not_1);

    wire active_next_en;
    or(active_next_en, start_compute, active_stay);
    
    wire [3:0] iter_next_en;
    wire [3:0] iter_dec;
    decrement_n #(.WIDTH(4)) iter_d(.in(iter_left), .out(iter_dec));
    wire [3:0] iter_temp;
    mux2_n #(.WIDTH(4)) iter_m1(.a(iter_left), .b(ITER_MAX), .sel(start_compute), .out(iter_temp));
    mux2_n #(.WIDTH(4)) iter_m2(.a(iter_temp), .b(iter_dec), .sel(active), .out(iter_next_en));
    
    wire [33:0] rad_next_en;
    wire [33:0] rad_shift = {radicand[31:0], 2'b00};
    wire [33:0] rad_temp;
    mux2_n #(.WIDTH(34)) rad_m1(.a(radicand), .b({work_mant, 22'd0}), .sel(start_compute), .out(rad_temp));
    mux2_n #(.WIDTH(34)) rad_m2(.a(rad_temp), .b(rad_shift), .sel(active), .out(rad_next_en));
    
    wire [22:0] rem_next_en;
    wire [22:0] rem_upd;
    mux2_n #(.WIDTH(23)) rem_m1(.a(remainder_next), .b(remainder_sub), .sel(rem_gte_trial), .out(rem_upd));
    wire [22:0] rem_temp;
    mux2_n #(.WIDTH(23)) rem_m2(.a(remainder), .b(23'd0), .sel(start_compute), .out(rem_temp));
    mux2_n #(.WIDTH(23)) rem_m3(.a(rem_temp), .b(rem_upd), .sel(active), .out(rem_next_en));
    
    wire [11:0] root_next_en;
    wire [11:0] root_temp;
    mux2_n #(.WIDTH(12)) root_m1(.a(root), .b(12'd0), .sel(start_compute), .out(root_temp));
    mux2_n #(.WIDTH(12)) root_m2(.a(root_temp), .b(root_next), .sel(active), .out(root_next_en));
    
    wire is_special_next_en;
    wire spec_set, spec_keep;
    or(spec_set, is_zero, is_special_input);
    and(spec_keep, start_trigger, spec_set);
    wire spec_held;
    and(spec_held, is_special, active_n);
    or(is_special_next_en, spec_keep, spec_held);
    
    wire store_flags;
    and(store_flags, start_trigger, is_special_input);
    
    wire store_nan_ninf, store_nan_reg;
    and(store_nan_ninf, store_flags, is_ninf_in);
    and(store_nan_reg, store_flags, is_nan_in);
    wire store_nan;
    or(store_nan, store_nan_reg, store_nan_ninf);
    
    wire store_pinf;
    and(store_pinf, store_flags, is_pinf_in);
    
    wire keep_nan, keep_pinf, keep_ninf;
    and(keep_nan, stored_is_nan, active_n);
    and(keep_pinf, stored_is_pinf, active_n);
    and(keep_ninf, stored_is_ninf, active_n);
    
    wire snan_next, spinf_next, sninf_next;
    or(snan_next, store_nan, keep_nan);
    or(spinf_next, store_pinf, keep_pinf);
    or(sninf_next, keep_ninf);
    
    wire it_valid_next_en;
    wire valid_on;
    or(valid_on, start_trigger, active);
    assign it_valid_next_en = valid_on;
    
    wire result_next_en;
    wire res_start, res_active, res_on;
    and(res_start, start_trigger, spec_set);
    and(res_active, active, iter_eq_1);
    or(res_on, res_start, res_active);
    assign result_next_en = res_on;
    
    wire sign_next_en;
    wire sign_zero, sign_spec, sign_compute;
    and(sign_zero, start_trigger, is_zero);
    and(sign_spec, start_trigger, is_special_input);
    and(sign_compute, start_trigger, not_zero, not_special);
    
    wire is_nan_or_ninf;
    or(is_nan_or_ninf, is_nan_in, is_ninf_in);
    
    wire sign_s;
    mux2 sign_sm(.a(1'b0), .b(1'b1), .sel(is_nan_or_ninf), .out(sign_s));
    
    wire sign_c1, sign_c2;
    mux2 s1(.a(sign_out), .b(sign_in), .sel(sign_zero), .out(sign_c1));
    mux2 s2(.a(sign_c1), .b(sign_s), .sel(sign_spec), .out(sign_c2));
    mux2 s3(.a(sign_c2), .b(1'b0), .sel(sign_compute), .out(sign_next_en));
    
    wire signed [6:0] exp_next_en;
    wire signed [6:0] exp_zero = minus15;
    wire signed [6:0] exp_spec = 7'sd16;
    wire signed [6:0] exp_c1, exp_c2;
    mux2_n #(.WIDTH(7)) e1(.a(exp_out), .b(exp_zero), .sel(sign_zero), .out(exp_c1));
    mux2_n #(.WIDTH(7)) e2(.a(exp_c1), .b(exp_spec), .sel(sign_spec), .out(exp_c2));
    mux2_n #(.WIDTH(7)) e3(.a(exp_c2), .b(exp_out_calc), .sel(sign_compute), .out(exp_next_en));
    
    wire [10:0] mant_next_en;
    wire [10:0] mant_zero = 11'd0;
    wire [10:0] mant_spec;
    mux2_n #(.WIDTH(11)) ms(.a(11'd0), .b(11'b10000000000), .sel(is_nan_or_ninf), .out(mant_spec));
    
    wire [10:0] mant_c1, mant_c2, mant_c3;
    mux2_n #(.WIDTH(11)) m1(.a(mant_out), .b(mant_zero), .sel(sign_zero), .out(mant_c1));
    mux2_n #(.WIDTH(11)) m2(.a(mant_c1), .b(mant_spec), .sel(sign_spec), .out(mant_c2));
    mux2_n #(.WIDTH(11)) m3(.a(mant_c2), .b(mant_out), .sel(sign_compute), .out(mant_c3));
    mux2_n #(.WIDTH(11)) m4(.a(mant_c3), .b(mant_computing), .sel(active), .out(mant_next_en));
    
    wire nan_spec, pinf_spec;
    and(nan_spec, start_trigger, is_special_input, is_nan_or_ninf);
    and(pinf_spec, start_trigger, is_special_input, is_pinf_in);
    
    wire restore;
    and(restore, is_special, active_n);
    
    wire nan_stored, pinf_stored, ninf_stored;
    and(nan_stored, restore, stored_is_nan);
    and(pinf_stored, restore, stored_is_pinf);
    and(ninf_stored, restore, stored_is_ninf);
    
    wire nan_next, pinf_next, ninf_next;
    or(nan_next, nan_spec, nan_stored);
    or(pinf_next, pinf_spec, pinf_stored);
    or(ninf_next, ninf_stored);

    wire active_final, is_special_final;
    wire [3:0] iter_final;
    wire [33:0] rad_final;
    wire [22:0] rem_final;
    wire [11:0] root_final;
    wire snan_final, spinf_final, sninf_final;
    wire it_valid_final, result_final, sign_final;
    wire signed [6:0] exp_final;
    wire [10:0] mant_final;
    wire nan_final, pinf_final, ninf_final;
    
    mux2 a_en(.a(1'b0), .b(active_next_en), .sel(enable), .out(active_final));
    mux2 sp_en(.a(1'b0), .b(is_special_next_en), .sel(enable), .out(is_special_final));
    mux2_n #(.WIDTH(4)) i_en(.a(4'd0), .b(iter_next_en), .sel(enable), .out(iter_final));
    mux2_n #(.WIDTH(34)) r_en(.a(34'd0), .b(rad_next_en), .sel(enable), .out(rad_final));
    mux2_n #(.WIDTH(23)) rm_en(.a(23'd0), .b(rem_next_en), .sel(enable), .out(rem_final));
    mux2_n #(.WIDTH(12)) rt_en(.a(12'd0), .b(root_next_en), .sel(enable), .out(root_final));
    
    mux2 sn_en(.a(1'b0), .b(snan_next), .sel(enable), .out(snan_final));
    mux2 sp2_en(.a(1'b0), .b(spinf_next), .sel(enable), .out(spinf_final));
    mux2 sn2_en(.a(1'b0), .b(sninf_next), .sel(enable), .out(sninf_final));
    
    mux2 v_en(.a(1'b0), .b(it_valid_next_en), .sel(enable), .out(it_valid_final));
    mux2 res_en(.a(1'b0), .b(result_next_en), .sel(enable), .out(result_final));
    mux2 sg_en(.a(1'b0), .b(sign_next_en), .sel(enable), .out(sign_final));
    mux2_n #(.WIDTH(7)) ex_en(.a(7'sd0), .b(exp_next_en), .sel(enable), .out(exp_final));
    mux2_n #(.WIDTH(11)) mn_en(.a(11'd0), .b(mant_next_en), .sel(enable), .out(mant_final));
    
    mux2 n_en(.a(1'b0), .b(nan_next), .sel(enable), .out(nan_final));
    mux2 p_en(.a(1'b0), .b(pinf_next), .sel(enable), .out(pinf_final));
    mux2 ni_en(.a(1'b0), .b(ninf_next), .sel(enable), .out(ninf_final));

    dff active_ff(.clk(clk), .d(active_final), .q(active));
    dff special_ff(.clk(clk), .d(is_special_final), .q(is_special));
    register_n #(.WIDTH(4)) iter_reg(.clk(clk), .rst(1'b0), .d(iter_final), .q(iter_left));
    register_n #(.WIDTH(34)) rad_reg(.clk(clk), .rst(1'b0), .d(rad_final), .q(radicand));
    register_n #(.WIDTH(23)) rem_reg(.clk(clk), .rst(1'b0), .d(rem_final), .q(remainder));
    register_n #(.WIDTH(12)) root_reg(.clk(clk), .rst(1'b0), .d(root_final), .q(root));
    
    dff snan_ff(.clk(clk), .d(snan_final), .q(stored_is_nan));
    dff spinf_ff(.clk(clk), .d(spinf_final), .q(stored_is_pinf));
    dff sninf_ff(.clk(clk), .d(sninf_final), .q(stored_is_ninf));
    
    dff valid_ff(.clk(clk), .d(it_valid_final), .q(it_valid));
    dff result_ff(.clk(clk), .d(result_final), .q(result));
    dff sign_ff(.clk(clk), .d(sign_final), .q(sign_out));
    register_n #(.WIDTH(7)) exp_reg(.clk(clk), .rst(1'b0), .d(exp_final), .q(exp_out));
    register_n #(.WIDTH(11)) mant_reg(.clk(clk), .rst(1'b0), .d(mant_final), .q(mant_out));
    
    dff nan_ff(.clk(clk), .d(nan_final), .q(is_nan_out));
    dff pinf_ff(.clk(clk), .d(pinf_final), .q(is_pinf_out));
    dff ninf_ff(.clk(clk), .d(ninf_final), .q(is_ninf_out));

endmodule