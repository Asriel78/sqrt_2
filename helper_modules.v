`timescale 1ns/1ps

module register_with_enable #(parameter WIDTH = 8) (
    input  wire clk,
    input  wire enable,
    input  wire [WIDTH-1:0] d_in,
    output wire [WIDTH-1:0] q_out
);
    wire [WIDTH-1:0] d_gated;
    
    mux2_n #(.WIDTH(WIDTH)) enable_mux(
        .a(q_out),
        .b(d_in),
        .sel(enable),
        .out(d_gated)
    );
    
    register_n #(.WIDTH(WIDTH)) reg_inst(
        .clk(clk),
        .rst(1'b0),
        .d(d_gated),
        .q(q_out)
    );
endmodule

module dff_with_enable (
    input  wire clk,
    input  wire enable,
    input  wire d_in,
    output wire q_out
);
    wire d_gated;
    
    mux2 enable_mux(
        .a(q_out),
        .b(d_in),
        .sel(enable),
        .out(d_gated)
    );
    
    dff dff_inst(
        .clk(clk),
        .d(d_gated),
        .q(q_out)
    );
endmodule

module flag_registers (
    input  wire clk,
    input  wire enable,
    input  wire capture,
    
    input  wire is_nan_in,
    input  wire is_pinf_in,
    input  wire is_ninf_in,
    input  wire is_normal_in,
    input  wire is_subnormal_in,
    
    output wire is_nan_out,
    output wire is_pinf_out,
    output wire is_ninf_out,
    output wire is_normal_out,
    output wire is_subnormal_out
);
    wire is_nan_d, is_pinf_d, is_ninf_d, is_normal_d, is_subnormal_d;
    
    mux2 nan_cap(.a(is_nan_out), .b(is_nan_in), .sel(capture), .out(is_nan_d));
    mux2 pinf_cap(.a(is_pinf_out), .b(is_pinf_in), .sel(capture), .out(is_pinf_d));
    mux2 ninf_cap(.a(is_ninf_out), .b(is_ninf_in), .sel(capture), .out(is_ninf_d));
    mux2 norm_cap(.a(is_normal_out), .b(is_normal_in), .sel(capture), .out(is_normal_d));
    mux2 subn_cap(.a(is_subnormal_out), .b(is_subnormal_in), .sel(capture), .out(is_subnormal_d));
    
    wire is_nan_final, is_pinf_final, is_ninf_final, is_normal_final, is_subnormal_final;
    
    mux2 nan_en(.a(1'b0), .b(is_nan_d), .sel(enable), .out(is_nan_final));
    mux2 pinf_en(.a(1'b0), .b(is_pinf_d), .sel(enable), .out(is_pinf_final));
    mux2 ninf_en(.a(1'b0), .b(is_ninf_d), .sel(enable), .out(is_ninf_final));
    mux2 norm_en(.a(1'b0), .b(is_normal_d), .sel(enable), .out(is_normal_final));
    mux2 subn_en(.a(1'b0), .b(is_subnormal_d), .sel(enable), .out(is_subnormal_final));
    
    dff nan_ff(.clk(clk), .d(is_nan_final), .q(is_nan_out));
    dff pinf_ff(.clk(clk), .d(is_pinf_final), .q(is_pinf_out));
    dff ninf_ff(.clk(clk), .d(is_ninf_final), .q(is_ninf_out));
    dff norm_ff(.clk(clk), .d(is_normal_final), .q(is_normal_out));
    dff subn_ff(.clk(clk), .d(is_subnormal_final), .q(is_subnormal_out));
endmodule

module number_storage #(
    parameter EXP_WIDTH = 7,
    parameter MANT_WIDTH = 11
) (
    input  wire clk,
    input  wire enable,
    input  wire capture,
    
    input  wire sign_in,
    input  wire signed [EXP_WIDTH-1:0] exp_in,
    input  wire [MANT_WIDTH-1:0] mant_in,
    
    output wire sign_out,
    output wire signed [EXP_WIDTH-1:0] exp_out,
    output wire [MANT_WIDTH-1:0] mant_out
);
    wire sign_d, sign_final;
    wire signed [EXP_WIDTH-1:0] exp_d, exp_final;
    wire [MANT_WIDTH-1:0] mant_d, mant_final;
    
    mux2 sign_cap(.a(sign_out), .b(sign_in), .sel(capture), .out(sign_d));
    mux2_n #(.WIDTH(EXP_WIDTH)) exp_cap(.a(exp_out), .b(exp_in), .sel(capture), .out(exp_d));
    mux2_n #(.WIDTH(MANT_WIDTH)) mant_cap(.a(mant_out), .b(mant_in), .sel(capture), .out(mant_d));
    
    mux2 sign_en(.a(1'b0), .b(sign_d), .sel(enable), .out(sign_final));
    mux2_n #(.WIDTH(EXP_WIDTH)) exp_en(
        .a({EXP_WIDTH{1'b0}}), 
        .b(exp_d), 
        .sel(enable), 
        .out(exp_final)
    );
    mux2_n #(.WIDTH(MANT_WIDTH)) mant_en(
        .a({MANT_WIDTH{1'b0}}), 
        .b(mant_d), 
        .sel(enable), 
        .out(mant_final)
    );
    
    dff sign_ff(.clk(clk), .d(sign_final), .q(sign_out));
    register_n #(.WIDTH(EXP_WIDTH)) exp_reg(
        .clk(clk), 
        .rst(1'b0), 
        .d(exp_final), 
        .q(exp_out)
    );
    register_n #(.WIDTH(MANT_WIDTH)) mant_reg(
        .clk(clk), 
        .rst(1'b0), 
        .d(mant_final), 
        .q(mant_out)
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

module count_leading_zeros_10bit (
    input  wire [9:0] data_in,
    output wire [3:0] count_out
);
    assign count_out = 
        data_in[9] ? 4'd0 :
        data_in[8] ? 4'd1 :
        data_in[7] ? 4'd2 :
        data_in[6] ? 4'd3 :
        data_in[5] ? 4'd4 :
        data_in[4] ? 4'd5 :
        data_in[3] ? 4'd6 :
        data_in[2] ? 4'd7 :
        data_in[1] ? 4'd8 :
        data_in[0] ? 4'd9 : 4'd10;
endmodule

module sqrt_exponent_adjust (
    input  wire signed [6:0] exp_in,
    input  wire [10:0] mant_in,
    
    output wire signed [6:0] exp_out,
    output wire [11:0] mant_out
);
    wire exp_is_odd = exp_in[0];
    
    wire [11:0] mant_shifted = {mant_in, 1'b0};
    wire [11:0] mant_normal = {1'b0, mant_in};
    
    mux2_n #(.WIDTH(12)) mant_mux(
        .a(mant_normal),
        .b(mant_shifted),
        .sel(exp_is_odd),
        .out(mant_out)
    );
    
    wire signed [6:0] exp_dec;
    wire cout;
    adder_n #(.WIDTH(7)) exp_decrement(
        .a(exp_in),
        .b(7'b1111111),
        .cin(1'b0),
        .sum(exp_dec),
        .cout(cout)
    );
    
    wire signed [6:0] exp_adjusted;
    mux2_n #(.WIDTH(7)) exp_mux(
        .a(exp_in),
        .b(exp_dec),
        .sel(exp_is_odd),
        .out(exp_adjusted)
    );
    
    assign exp_out = {exp_adjusted[6], exp_adjusted[6:1]};
endmodule

module sqrt_iteration_step (
    input  wire [11:0] root_in,
    input  wire [22:0] remainder_in,
    input  wire [33:0] radicand_in,
    
    output wire [11:0] root_out,
    output wire [22:0] remainder_out,
    output wire [33:0] radicand_out
);
    wire [22:0] trial = {root_in[10:0], 2'b01};
    wire [22:0] remainder_next = {remainder_in[20:0], radicand_in[33:32]};
    
    wire can_subtract;
    comparator_gte_n #(.WIDTH(23)) compare(
        .a(remainder_next),
        .b(trial),
        .gte(can_subtract)
    );
    
    mux2_n #(.WIDTH(12)) root_mux(
        .a({root_in[10:0], 1'b0}),
        .b({root_in[10:0], 1'b1}),
        .sel(can_subtract),
        .out(root_out)
    );
    
    wire [22:0] remainder_sub;
    wire borrow;
    subtractor_n #(.WIDTH(23)) subtract(
        .a(remainder_next),
        .b(trial),
        .diff(remainder_sub),
        .borrow(borrow)
    );
    
    mux2_n #(.WIDTH(23)) remainder_mux(
        .a(remainder_next),
        .b(remainder_sub),
        .sel(can_subtract),
        .out(remainder_out)
    );
    
    assign radicand_out = {radicand_in[31:0], 2'b00};
endmodule

module sqrt_state_machine #(parameter ITER_MAX = 4'd11) (
    input  wire clk,
    input  wire enable,
    input  wire start_trigger,
    input  wire is_special_input,
    
    output wire active,
    output wire [3:0] iter_left,
    output wire iter_is_last
);
    wire iter_eq_1;
    comparator_eq_n #(.WIDTH(4)) iter_check(
        .a(iter_left),
        .b(4'd1),
        .eq(iter_eq_1)
    );
    
    assign iter_is_last = iter_eq_1;
    
    wire iter_not_1;
    not(iter_not_1, iter_eq_1);
    
    wire active_stay;
    and(active_stay, active, iter_not_1);
    
    wire start_compute;
    wire not_special;
    not(not_special, is_special_input);
    and(start_compute, start_trigger, not_special);
    
    wire active_next_en;
    or(active_next_en, start_compute, active_stay);
    
    wire [3:0] iter_dec;
    decrement_n #(.WIDTH(4)) dec(.in(iter_left), .out(iter_dec));
    
    wire [3:0] iter_temp;
    mux2_n #(.WIDTH(4)) iter_start_mux(
        .a(iter_left),
        .b(ITER_MAX),
        .sel(start_compute),
        .out(iter_temp)
    );
    
    wire [3:0] iter_next_en;
    mux2_n #(.WIDTH(4)) iter_active_mux(
        .a(iter_temp),
        .b(iter_dec),
        .sel(active),
        .out(iter_next_en)
    );
    
    wire active_final, [3:0] iter_final;
    
    mux2 active_en(.a(1'b0), .b(active_next_en), .sel(enable), .out(active_final));
    mux2_n #(.WIDTH(4)) iter_en(.a(4'd0), .b(iter_next_en), .sel(enable), .out(iter_final));
    
    dff active_ff(.clk(clk), .d(active_final), .q(active));
    register_n #(.WIDTH(4)) iter_reg(.clk(clk), .rst(1'b0), .d(iter_final), .q(iter_left));
endmodule

module iteration_output_formatter (
    input  wire [11:0] root,
    input  wire [3:0] iter_left,
    output wire [10:0] mant_out
);
    wire iter_gt_1;
    comparator_gt_n #(.WIDTH(4)) cmp(.a(iter_left), .b(4'd1), .gt(iter_gt_1));
    
    wire [3:0] shift_amt;
    decrement_n #(.WIDTH(4)) dec(.in(iter_left), .out(shift_amt));
    
    wire [10:0] mant_shifted;
    barrel_shift_left_11bit shifter(
        .in(root[10:0]),
        .shift_amt(shift_amt),
        .out(mant_shifted)
    );
    
    mux2_n #(.WIDTH(11)) mant_mux(
        .a(root[10:0]),
        .b(mant_shifted),
        .sel(iter_gt_1),
        .out(mant_out)
    );
endmodule

module first_cycle_detector (
    input  wire clk,
    input  wire enable,
    output wire first_cycle
);
    wire prev_enable;
    wire prev_enable_n;
    
    not(prev_enable_n, prev_enable);
    and(first_cycle, enable, prev_enable_n);
    
    wire prev_enable_d;
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