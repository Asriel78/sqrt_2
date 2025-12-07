`timescale 1ns/1ps

module d_latch(
    input wire d,
    input wire enable,
    output wire q,
    output wire q_n
);
    wire d_n, s, r;
    not(d_n, d);
    nand(s, d, enable);
    nand(r, d_n, enable);
    nand(q, s, q_n);
    nand(q_n, r, q);
endmodule

module dff(
    input wire clk,
    input wire d,
    output wire q
);
    wire clk_n, master_q, master_q_n, slave_q_n;
    not(clk_n, clk);
    d_latch master(.d(d), .enable(clk_n), .q(master_q), .q_n(master_q_n));
    d_latch slave(.d(master_q), .enable(clk), .q(q), .q_n(slave_q_n));
endmodule


module mux2(
    input wire a,
    input wire b,
    input wire sel,
    output wire out
);
    wire sel_n, a_sel, b_sel;
    not(sel_n, sel);
    and(a_sel, a, sel_n);
    and(b_sel, b, sel);
    or(out, a_sel, b_sel);
endmodule

module mux2_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire sel,
    output wire [WIDTH-1:0] out
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : mux_gen
            mux2 m(.a(a[i]), .b(b[i]), .sel(sel), .out(out[i]));
        end
    endgenerate
endmodule

module negate_n #(parameter WIDTH = 8) (
    input  wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : neg
            not(out[i], in[i]);
        end
    endgenerate
endmodule


module register_n #(parameter WIDTH = 8) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] d,
    output wire [WIDTH-1:0] q
);
    wire [WIDTH-1:0] d_gated;
    wire rst_n;
    not(rst_n, rst);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gate_gen
            wire d_and_rst;
            and(d_and_rst, d[i], rst_n);
            assign d_gated[i] = d_and_rst;
        end
    endgenerate
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : dff_gen
            dff dff_inst(.clk(clk), .d(d_gated[i]), .q(q[i]));
        end
    endgenerate
endmodule

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


module half_adder(
    input wire a,
    input wire b,
    output wire sum,
    output wire carry
);
    xor(sum, a, b);
    and(carry, a, b);
endmodule

module full_adder(
    input wire a,
    input wire b,
    input wire cin,
    output wire sum,
    output wire cout
);
    wire sum1, c1, c2;
    half_adder ha1(.a(a), .b(b), .sum(sum1), .carry(c1));
    half_adder ha2(.a(sum1), .b(cin), .sum(sum), .carry(c2));
    or(cout, c1, c2);
endmodule

module adder_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire cin,
    output wire [WIDTH-1:0] sum,
    output wire cout
);
    wire [WIDTH:0] carry;
    assign carry[0] = cin;
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : adder_gen
            full_adder fa(.a(a[i]), .b(b[i]), .cin(carry[i]), .sum(sum[i]), .cout(carry[i+1]));
        end
    endgenerate
    assign cout = carry[WIDTH];
endmodule

module subtractor_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] diff,
    output wire borrow
);
    wire [WIDTH-1:0] b_inv;
    wire cout;
    
    negate_n #(.WIDTH(WIDTH)) invert(.in(b), .out(b_inv));
    adder_n #(.WIDTH(WIDTH)) sub(.a(a), .b(b_inv), .cin(1'b1), .sum(diff), .cout(cout));
    
    not(borrow, cout);
endmodule

module increment_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out,
    output wire cout
);
    adder_n #(.WIDTH(WIDTH)) inc(
        .a(in), 
        .b({WIDTH{1'b0}}), 
        .cin(1'b1), 
        .sum(out), 
        .cout(cout)
    );
endmodule

module decrement_n #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    wire cout;
    adder_n #(.WIDTH(WIDTH)) dec(
        .a(in), 
        .b({WIDTH{1'b1}}), 
        .cin(1'b0), 
        .sum(out), 
        .cout(cout)
    );
endmodule


module is_zero_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] in,
    output wire is_zero
);
    wire [WIDTH-1:0] or_chain;
    assign or_chain[0] = in[0];
    genvar i;
    generate
        for (i = 1; i < WIDTH; i = i + 1) begin : or_gen
            or(or_chain[i], or_chain[i-1], in[i]);
        end
    endgenerate
    not(is_zero, or_chain[WIDTH-1]);
endmodule

module comparator_eq_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire eq
);
    wire [WIDTH-1:0] xor_result;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : xor_gen
            xor(xor_result[i], a[i], b[i]);
        end
    endgenerate
    
    is_zero_n #(.WIDTH(WIDTH)) check_all_zero(
        .in(xor_result),
        .is_zero(eq)
    );
endmodule

module comparator_gte_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire gte
);
    wire [WIDTH-1:0] diff;
    wire borrow;
    
    subtractor_n #(.WIDTH(WIDTH)) sub(
        .a(a), 
        .b(b), 
        .diff(diff), 
        .borrow(borrow)
    );
    
    not(gte, borrow);
endmodule

module comparator_gt_n #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire gt
);
    wire eq, gte, eq_n;
    
    comparator_eq_n #(.WIDTH(WIDTH)) cmp_eq(.a(a), .b(b), .eq(eq));
    comparator_gte_n #(.WIDTH(WIDTH)) cmp_gte(.a(a), .b(b), .gte(gte));
    
    not(eq_n, eq);
    and(gt, gte, eq_n);
endmodule


module barrel_shift_left_11bit(
    input wire [10:0] in,
    input wire [3:0] shift_amt,
    output wire [10:0] out
);
    wire [10:0] stage0, stage1, stage2, stage3;
    genvar i;
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage0_gen
            if (i == 0)
                mux2 m(.a(in[i]), .b(1'b0), .sel(shift_amt[0]), .out(stage0[i]));
            else
                mux2 m(.a(in[i]), .b(in[i-1]), .sel(shift_amt[0]), .out(stage0[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage1_gen
            if (i < 2)
                mux2 m(.a(stage0[i]), .b(1'b0), .sel(shift_amt[1]), .out(stage1[i]));
            else
                mux2 m(.a(stage0[i]), .b(stage0[i-2]), .sel(shift_amt[1]), .out(stage1[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage2_gen
            if (i < 4)
                mux2 m(.a(stage1[i]), .b(1'b0), .sel(shift_amt[2]), .out(stage2[i]));
            else
                mux2 m(.a(stage1[i]), .b(stage1[i-4]), .sel(shift_amt[2]), .out(stage2[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage3_gen
            if (i < 8)
                mux2 m(.a(stage2[i]), .b(1'b0), .sel(shift_amt[3]), .out(stage3[i]));
            else
                mux2 m(.a(stage2[i]), .b(stage2[i-8]), .sel(shift_amt[3]), .out(stage3[i]));
        end
    endgenerate
    
    assign out = stage3;
endmodule

module barrel_shift_right_11bit(
    input wire [10:0] in,
    input wire [3:0] shift_amt,
    output wire [10:0] out
);
    wire [10:0] stage0, stage1, stage2, stage3;
    genvar i;
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage0_gen
            if (i == 10)
                mux2 m(.a(in[i]), .b(1'b0), .sel(shift_amt[0]), .out(stage0[i]));
            else
                mux2 m(.a(in[i]), .b(in[i+1]), .sel(shift_amt[0]), .out(stage0[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage1_gen
            if (i > 8)
                mux2 m(.a(stage0[i]), .b(1'b0), .sel(shift_amt[1]), .out(stage1[i]));
            else
                mux2 m(.a(stage0[i]), .b(stage0[i+2]), .sel(shift_amt[1]), .out(stage1[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage2_gen
            if (i > 6)
                mux2 m(.a(stage1[i]), .b(1'b0), .sel(shift_amt[2]), .out(stage2[i]));
            else
                mux2 m(.a(stage1[i]), .b(stage1[i+4]), .sel(shift_amt[2]), .out(stage2[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage3_gen
            if (i > 2)
                mux2 m(.a(stage2[i]), .b(1'b0), .sel(shift_amt[3]), .out(stage3[i]));
            else
                mux2 m(.a(stage2[i]), .b(stage2[i+8]), .sel(shift_amt[3]), .out(stage3[i]));
        end
    endgenerate
    
    assign out = stage3;
endmodule

module enable_gate #(parameter WIDTH = 1) (
    input wire enable,
    input wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);
    mux2_n #(.WIDTH(WIDTH)) gate(
        .a({WIDTH{1'b0}}),
        .b(data_in),
        .sel(enable),
        .out(data_out)
    );
endmodule