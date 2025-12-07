`timescale 1ns/1ps

// ============================================================================
// БАЗОВЫЕ ЭЛЕМЕНТЫ ПАМЯТИ (D-триггеры и защёлки)
// ============================================================================

// ----------------------------------------------------------------------------
// D-защёлка (D-latch) - прозрачна при enable=1
// ----------------------------------------------------------------------------
module d_latch(
    input wire d,
    input wire enable,
    output wire q,
    output wire q_n
);
    wire d_n;
    wire s, r;
    
    not(d_n, d);
    nand(s, d, enable);
    nand(r, d_n, enable);
    nand(q, s, q_n);
    nand(q_n, r, q);
endmodule

// ----------------------------------------------------------------------------
// D-триггер БЕЗ сброса (positive edge triggered)
// ----------------------------------------------------------------------------
module dff(
    input wire clk,
    input wire d,
    output wire q
);
    wire clk_n;
    wire master_q, master_q_n;
    wire slave_q_n;
    
    not(clk_n, clk);
    
    d_latch master(
        .d(d),
        .enable(clk_n),
        .q(master_q),
        .q_n(master_q_n)
    );
    
    d_latch slave(
        .d(master_q),
        .enable(clk),
        .q(q),
        .q_n(slave_q_n)
    );
endmodule

// ----------------------------------------------------------------------------
// D-триггер С СИНХРОННЫМ СБРОСОМ
// ----------------------------------------------------------------------------
module dff_r(
    input wire clk,
    input wire rst,
    input wire d,
    output wire q
);
    wire d_gated;
    wire rst_n;
    
    not(rst_n, rst);
    and(d_gated, d, rst_n);
    
    dff dff_inst(
        .clk(clk),
        .d(d_gated),
        .q(q)
    );
endmodule

// ----------------------------------------------------------------------------
// N-битный регистр
// ----------------------------------------------------------------------------
module register_n #(parameter WIDTH = 8) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] d,
    output wire [WIDTH-1:0] q
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : dff_gen
            dff_r dff_inst(.clk(clk), .rst(rst), .d(d[i]), .q(q[i]));
        end
    endgenerate
endmodule

// ----------------------------------------------------------------------------
// Регистр с enable (захватывает данные только при enable=1)
// ----------------------------------------------------------------------------
module register_with_enable #(parameter WIDTH = 8) (
    input wire clk,
    input wire enable,
    input wire rst,
    input wire [WIDTH-1:0] d_in,
    output wire [WIDTH-1:0] q_out
);
    wire [WIDTH-1:0] d_selected;
    wire [WIDTH-1:0] d_final;
    
    mux2_n #(.WIDTH(WIDTH)) en_mux(
        .a(q_out), 
        .b(d_in), 
        .sel(enable), 
        .out(d_selected)
    );
    
    mux2_n #(.WIDTH(WIDTH)) rst_mux(
        .a(d_selected), 
        .b({WIDTH{1'b0}}), 
        .sel(rst), 
        .out(d_final)
    );
    
    register_n #(.WIDTH(WIDTH)) reg_inst(
        .clk(clk), 
        .rst(1'b0), 
        .d(d_final), 
        .q(q_out)
    );
endmodule

// ============================================================================
// МУЛЬТИПЛЕКСОРЫ
// ============================================================================

// ----------------------------------------------------------------------------
// Мультиплексор 2:1
// ----------------------------------------------------------------------------
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

// ----------------------------------------------------------------------------
// Мультиплексор 4:1
// ----------------------------------------------------------------------------
module mux4(
    input wire a,
    input wire b,
    input wire c,
    input wire d,
    input wire [1:0] sel,
    output wire out
);
    wire out0, out1;
    
    mux2 m0(.a(a), .b(b), .sel(sel[0]), .out(out0));
    mux2 m1(.a(c), .b(d), .sel(sel[0]), .out(out1));
    mux2 m2(.a(out0), .b(out1), .sel(sel[1]), .out(out));
endmodule

// ----------------------------------------------------------------------------
// Мультиплексор 8:1
// ----------------------------------------------------------------------------
module mux8(
    input wire [7:0] in,
    input wire [2:0] sel,
    output wire out
);
    wire out0, out1;
    
    mux4 m0(.a(in[0]), .b(in[1]), .c(in[2]), .d(in[3]), 
            .sel(sel[1:0]), .out(out0));
    mux4 m1(.a(in[4]), .b(in[5]), .c(in[6]), .d(in[7]), 
            .sel(sel[1:0]), .out(out1));
    mux2 m2(.a(out0), .b(out1), .sel(sel[2]), .out(out));
endmodule

// ----------------------------------------------------------------------------
// N-битный мультиплексор 2:1
// ----------------------------------------------------------------------------
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

// ============================================================================
// АРИФМЕТИКА
// ============================================================================

// ----------------------------------------------------------------------------
// Полусумматор
// ----------------------------------------------------------------------------
module half_adder(
    input wire a,
    input wire b,
    output wire sum,
    output wire carry
);
    xor(sum, a, b);
    and(carry, a, b);
endmodule

// ----------------------------------------------------------------------------
// Полный сумматор
// ----------------------------------------------------------------------------
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

// ----------------------------------------------------------------------------
// N-битный сумматор
// ----------------------------------------------------------------------------
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
            full_adder fa(
                .a(a[i]), 
                .b(b[i]), 
                .cin(carry[i]),
                .sum(sum[i]), 
                .cout(carry[i+1])
            );
        end
    endgenerate
    
    assign cout = carry[WIDTH];
endmodule

// ----------------------------------------------------------------------------
// N-битный вычитатель (a - b)
// ----------------------------------------------------------------------------
module subtractor_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] diff,
    output wire borrow
);
    wire [WIDTH-1:0] b_inv;
    wire cout;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : invert_gen
            not(b_inv[i], b[i]);
        end
    endgenerate
    
    adder_n #(.WIDTH(WIDTH)) sub(
        .a(a),
        .b(b_inv),
        .cin(1'b1),
        .sum(diff),
        .cout(cout)
    );
    
    not(borrow, cout);
endmodule

// ----------------------------------------------------------------------------
// Инкремент (in + 1)
// ----------------------------------------------------------------------------
module increment_n #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out,
    output wire overflow
);
    adder_n #(.WIDTH(WIDTH)) inc(
        .a(in),
        .b({{(WIDTH-1){1'b0}}, 1'b1}),
        .cin(1'b0),
        .sum(out),
        .cout(overflow)
    );
endmodule

// ----------------------------------------------------------------------------
// Декремент (in - 1)
// ----------------------------------------------------------------------------
module decrement_n #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    wire [WIDTH-1:0] ones_comp;
    wire cout;
    
    assign ones_comp = {WIDTH{1'b1}};
    
    adder_n #(.WIDTH(WIDTH)) dec(
        .a(in),
        .b(ones_comp),
        .cin(1'b0),
        .sum(out),
        .cout(cout)
    );
endmodule

// ============================================================================
// КОМПАРАТОРЫ
// ============================================================================

// ----------------------------------------------------------------------------
// N-битный компаратор (a >= b)
// ----------------------------------------------------------------------------
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

// ----------------------------------------------------------------------------
// N-битный компаратор равенства (a == b)
// ----------------------------------------------------------------------------
module comparator_eq_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire eq
);
    wire [WIDTH-1:0] xor_result;
    wire [WIDTH-1:0] or_chain;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : xor_gen
            xor(xor_result[i], a[i], b[i]);
        end
    endgenerate
    
    assign or_chain[0] = xor_result[0];
    generate
        for (i = 1; i < WIDTH; i = i + 1) begin : or_chain_gen
            or(or_chain[i], or_chain[i-1], xor_result[i]);
        end
    endgenerate
    
    not(eq, or_chain[WIDTH-1]);
endmodule

// ----------------------------------------------------------------------------
// N-битный компаратор (a > b)
// ----------------------------------------------------------------------------
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

// ----------------------------------------------------------------------------
// Проверка на ноль (all bits zero)
// ----------------------------------------------------------------------------
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

// ============================================================================
// BARREL SHIFTERS
// ============================================================================

// ----------------------------------------------------------------------------
// Barrel shifter влево для 11-бит (сдвиг 0-11)
// ----------------------------------------------------------------------------
module barrel_shift_left_11bit(
    input wire [10:0] in,
    input wire [3:0] shift_amt,
    output wire [10:0] out
);
    wire [10:0] stage0, stage1, stage2, stage3;
    
    genvar i;
    
    // Stage 0: +0 или +1
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage0_gen
            if (i == 0)
                mux2 m(.a(in[i]), .b(1'b0), .sel(shift_amt[0]), .out(stage0[i]));
            else
                mux2 m(.a(in[i]), .b(in[i-1]), .sel(shift_amt[0]), .out(stage0[i]));
        end
    endgenerate
    
    // Stage 1: +0 или +2
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage1_gen
            if (i < 2)
                mux2 m(.a(stage0[i]), .b(1'b0), .sel(shift_amt[1]), .out(stage1[i]));
            else
                mux2 m(.a(stage0[i]), .b(stage0[i-2]), .sel(shift_amt[1]), .out(stage1[i]));
        end
    endgenerate
    
    // Stage 2: +0 или +4
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage2_gen
            if (i < 4)
                mux2 m(.a(stage1[i]), .b(1'b0), .sel(shift_amt[2]), .out(stage2[i]));
            else
                mux2 m(.a(stage1[i]), .b(stage1[i-4]), .sel(shift_amt[2]), .out(stage2[i]));
        end
    endgenerate
    
    // Stage 3: +0 или +8
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

// ----------------------------------------------------------------------------
// Barrel shifter вправо для 11-бит (сдвиг 0-11)
// ----------------------------------------------------------------------------
module barrel_shift_right_11bit(
    input wire [10:0] in,
    input wire [3:0] shift_amt,
    output wire [10:0] out
);
    wire [10:0] stage0, stage1, stage2, stage3;
    
    genvar i;
    
    // Stage 0: сдвиг на 0 или 1
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage0_gen
            if (i == 10)
                mux2 m(.a(in[i]), .b(1'b0), .sel(shift_amt[0]), .out(stage0[i]));
            else
                mux2 m(.a(in[i]), .b(in[i+1]), .sel(shift_amt[0]), .out(stage0[i]));
        end
    endgenerate
    
    // Stage 1: сдвиг на 0 или 2
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage1_gen
            if (i > 8)
                mux2 m(.a(stage0[i]), .b(1'b0), .sel(shift_amt[1]), .out(stage1[i]));
            else
                mux2 m(.a(stage0[i]), .b(stage0[i+2]), .sel(shift_amt[1]), .out(stage1[i]));
        end
    endgenerate
    
    // Stage 2: сдвиг на 0 или 4
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage2_gen
            if (i > 6)
                mux2 m(.a(stage1[i]), .b(1'b0), .sel(shift_amt[2]), .out(stage2[i]));
            else
                mux2 m(.a(stage1[i]), .b(stage1[i+4]), .sel(shift_amt[2]), .out(stage2[i]));
        end
    endgenerate
    
    // Stage 3: сдвиг на 0 или 8
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

// ----------------------------------------------------------------------------
// Barrel shifter влево для 34-бит (для radicand в iterate)
// ----------------------------------------------------------------------------
module barrel_shift_left_34bit(
    input wire [33:0] in,
    input wire [5:0] shift_amt,
    output wire [33:0] out
);
    wire [33:0] stage0, stage1, stage2, stage3, stage4, stage5;
    
    genvar i;
    
    // Stage 0: +0 или +1
    generate
        for (i = 0; i < 34; i = i + 1) begin : s0
            if (i == 0)
                mux2 m(.a(in[i]), .b(1'b0), .sel(shift_amt[0]), .out(stage0[i]));
            else
                mux2 m(.a(in[i]), .b(in[i-1]), .sel(shift_amt[0]), .out(stage0[i]));
        end
    endgenerate
    
    // Stage 1: +0 или +2
    generate
        for (i = 0; i < 34; i = i + 1) begin : s1
            if (i < 2)
                mux2 m(.a(stage0[i]), .b(1'b0), .sel(shift_amt[1]), .out(stage1[i]));
            else
                mux2 m(.a(stage0[i]), .b(stage0[i-2]), .sel(shift_amt[1]), .out(stage1[i]));
        end
    endgenerate
    
    // Stage 2: +0 или +4
    generate
        for (i = 0; i < 34; i = i + 1) begin : s2
            if (i < 4)
                mux2 m(.a(stage1[i]), .b(1'b0), .sel(shift_amt[2]), .out(stage2[i]));
            else
                mux2 m(.a(stage1[i]), .b(stage1[i-4]), .sel(shift_amt[2]), .out(stage2[i]));
        end
    endgenerate
    
    // Stage 3: +0 или +8
    generate
        for (i = 0; i < 34; i = i + 1) begin : s3
            if (i < 8)
                mux2 m(.a(stage2[i]), .b(1'b0), .sel(shift_amt[3]), .out(stage3[i]));
            else
                mux2 m(.a(stage2[i]), .b(stage2[i-8]), .sel(shift_amt[3]), .out(stage3[i]));
        end
    endgenerate
    
    // Stage 4: +0 или +16
    generate
        for (i = 0; i < 34; i = i + 1) begin : s4
            if (i < 16)
                mux2 m(.a(stage3[i]), .b(1'b0), .sel(shift_amt[4]), .out(stage4[i]));
            else
                mux2 m(.a(stage3[i]), .b(stage3[i-16]), .sel(shift_amt[4]), .out(stage4[i]));
        end
    endgenerate
    
    // Stage 5: +0 или +32
    generate
        for (i = 0; i < 34; i = i + 1) begin : s5
            if (i < 32)
                mux2 m(.a(stage4[i]), .b(1'b0), .sel(shift_amt[5]), .out(stage5[i]));
            else
                mux2 m(.a(stage4[i]), .b(stage4[i-32]), .sel(shift_amt[5]), .out(stage5[i]));
        end
    endgenerate
    
    assign out = stage5;
endmodule

// ============================================================================
// СЧЁТЧИКИ И СПЕЦИАЛЬНЫЕ МОДУЛИ
// ============================================================================

// ----------------------------------------------------------------------------
// Счётчик на N бит с enable
// ----------------------------------------------------------------------------
module counter_n #(parameter WIDTH = 4) (
    input wire clk,
    input wire rst,
    input wire en,
    output wire [WIDTH-1:0] count
);
    wire [WIDTH-1:0] count_next;
    wire [WIDTH-1:0] count_plus_one;
    wire cout;
    
    adder_n #(.WIDTH(WIDTH)) inc(
        .a(count),
        .b({{(WIDTH-1){1'b0}}, 1'b1}),
        .cin(1'b0),
        .sum(count_plus_one),
        .cout(cout)
    );
    
    mux2_n #(.WIDTH(WIDTH)) mux(
        .a(count),
        .b(count_plus_one),
        .sel(en),
        .out(count_next)
    );
    
    register_n #(.WIDTH(WIDTH)) reg_inst(
        .clk(clk),
        .rst(rst),
        .d(count_next),
        .q(count)
    );
endmodule