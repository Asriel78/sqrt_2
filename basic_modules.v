`timescale 1ns/1ps

// ============================================================================
// БАЗОВЫЕ БЛОКИ (Must-Have)
// ============================================================================

// ----------------------------------------------------------------------------
// D-триггер с синхронным сбросом
// ----------------------------------------------------------------------------
module dff_r(
    input wire clk,
    input wire rst,
    input wire d,
    output wire q
);
    wire clk_n, rst_n;
    wire d_gated, rst_gated;
    wire master, master_n;
    wire slave, slave_n;
    
    not(clk_n, clk);
    not(rst_n, rst);
    
    // Сброс имеет приоритет
    and(d_gated, d, rst_n);
    
    // Master latch (активен при clk=0)
    wire m1, m2, m3, m4;
    nand(m1, d_gated, clk_n);
    nand(m2, master_n, clk_n);
    nand(master, m1, master_n);
    nand(master_n, m2, master, rst);
    
    // Slave latch (активен при clk=1)
    wire s1, s2;
    nand(s1, master, clk);
    nand(s2, slave_n, clk);
    nand(slave, s1, slave_n);
    nand(slave_n, s2, slave, rst);
    
    assign q = slave;
endmodule

// ----------------------------------------------------------------------------
// D-триггер без сброса (более простой)
// ----------------------------------------------------------------------------
module dff(
    input wire clk,
    input wire d,
    output wire q
);
    wire clk_n;
    wire master, master_n;
    wire slave, slave_n;
    
    not(clk_n, clk);
    
    // Master latch
    wire m1, m2;
    nand(m1, d, clk_n);
    nand(m2, master_n, clk_n);
    nand(master, m1, master_n);
    nand(master_n, m2, master);
    
    // Slave latch
    wire s1, s2;
    nand(s1, master, clk);
    nand(s2, slave_n, clk);
    nand(slave, s1, slave_n);
    nand(slave_n, s2, slave);
    
    assign q = slave;
endmodule

// ----------------------------------------------------------------------------
// Регистр N-битный
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

// ----------------------------------------------------------------------------
// Полусумматор (Half Adder)
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
// Полный сумматор (Full Adder)
// ----------------------------------------------------------------------------
module full_adder(
    input wire a,
    input wire b,
    input wire cin,
    output wire sum,
    output wire cout
);
    wire sum1, c1, c2;
    
    // Первый полусумматор
    half_adder ha1(.a(a), .b(b), .sum(sum1), .carry(c1));
    
    // Второй полусумматор
    half_adder ha2(.a(sum1), .b(cin), .sum(sum), .carry(c2));
    
    // Выходной перенос
    or(cout, c1, c2);
endmodule

// ----------------------------------------------------------------------------
// N-битный сумматор (Ripple Carry Adder)
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
// Использует дополнение до двух: a - b = a + (~b) + 1
// ----------------------------------------------------------------------------
module subtractor_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] diff,
    output wire borrow  // 0 если a >= b, 1 если a < b
);
    wire [WIDTH-1:0] b_inv;
    wire cout;
    
    // Инвертируем b
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : invert_gen
            not(b_inv[i], b[i]);
        end
    endgenerate
    
    // a + (~b) + 1
    adder_n #(.WIDTH(WIDTH)) sub(
        .a(a),
        .b(b_inv),
        .cin(1'b1),
        .sum(diff),
        .cout(cout)
    );
    
    // Если есть перенос, то a >= b (нет заема)
    not(borrow, cout);
endmodule

// ----------------------------------------------------------------------------
// N-битный компаратор (a >= b)
// ----------------------------------------------------------------------------
module comparator_gte_n #(parameter WIDTH = 8) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire gte  // 1 если a >= b
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
    wire [WIDTH-1:0] nor_chain;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : xor_gen
            xor(xor_result[i], a[i], b[i]);
        end
    endgenerate
    
    // Проверяем, что все биты равны (все XOR = 0)
    assign nor_chain[0] = xor_result[0];
    generate
        for (i = 1; i < WIDTH; i = i + 1) begin : or_chain
            or(nor_chain[i], nor_chain[i-1], xor_result[i]);
        end
    endgenerate
    
    not(eq, nor_chain[WIDTH-1]);
endmodule

// ----------------------------------------------------------------------------
// Счетчик ведущих нулей для 10-битного числа (CLZ)
// ----------------------------------------------------------------------------
module clz_10bit(
    input wire [9:0] in,
    output wire [3:0] count
);
    // Priority encoder
    wire [3:0] pos;
    
    // Находим позицию первой единицы
    assign pos[3] = in[9];
    
    wire n9;
    not(n9, in[9]);
    and(pos[2], n9, in[8]);
    
    wire n9n8;
    nor(n9n8, in[9], in[8]);
    and(pos[1], n9n8, in[7]);
    
    wire n9n8n7;
    wire temp1;
    nor(temp1, in[9], in[8]);
    nor(n9n8n7, temp1, in[7]);
    and(pos[0], n9n8n7, in[6]);
    
    // Кодируем в количество нулей
    // Если in[9]=1, то 0 нулей
    // Если in[8]=1, то 1 ноль
    // Если in[7]=1, то 2 нуля
    // и т.д.
    
    wire [9:0] bit_active;
    assign bit_active[9] = in[9];
    
    wire n9_w;
    not(n9_w, in[9]);
    and(bit_active[8], n9_w, in[8]);
    
    wire n98;
    nor(n98, in[9], in[8]);
    and(bit_active[7], n98, in[7]);
    
    wire n987, t1;
    nor(t1, in[9], in[8]);
    nor(n987, t1, in[7]);
    and(bit_active[6], n987, in[6]);
    
    wire n9876, t2, t3;
    nor(t2, in[9], in[8]);
    nor(t3, t2, in[7]);
    nor(n9876, t3, in[6]);
    and(bit_active[5], n9876, in[5]);
    
    wire n98765, t4, t5, t6;
    nor(t4, in[9], in[8]);
    nor(t5, t4, in[7]);
    nor(t6, t5, in[6]);
    nor(n98765, t6, in[5]);
    and(bit_active[4], n98765, in[4]);
    
    wire n987654, t7, t8, t9, t10;
    nor(t7, in[9], in[8]);
    nor(t8, t7, in[7]);
    nor(t9, t8, in[6]);
    nor(t10, t9, in[5]);
    nor(n987654, t10, in[4]);
    and(bit_active[3], n987654, in[3]);
    
    wire n9876543, t11, t12, t13, t14, t15;
    nor(t11, in[9], in[8]);
    nor(t12, t11, in[7]);
    nor(t13, t12, in[6]);
    nor(t14, t13, in[5]);
    nor(t15, t14, in[4]);
    nor(n9876543, t15, in[3]);
    and(bit_active[2], n9876543, in[2]);
    
    wire n98765432, t16, t17, t18, t19, t20, t21;
    nor(t16, in[9], in[8]);
    nor(t17, t16, in[7]);
    nor(t18, t17, in[6]);
    nor(t19, t18, in[5]);
    nor(t20, t19, in[4]);
    nor(t21, t20, in[3]);
    nor(n98765432, t21, in[2]);
    and(bit_active[1], n98765432, in[1]);
    
    wire n987654321, t22, t23, t24, t25, t26, t27, t28;
    nor(t22, in[9], in[8]);
    nor(t23, t22, in[7]);
    nor(t24, t23, in[6]);
    nor(t25, t24, in[5]);
    nor(t26, t25, in[4]);
    nor(t27, t26, in[3]);
    nor(t28, t27, in[2]);
    nor(n987654321, t28, in[1]);
    and(bit_active[0], n987654321, in[0]);
    
    // Преобразуем в count
    // 0: bit[9], 1: bit[8], ..., 9: bit[0], 10: all_zero
    wire c0_bit, c1_bit, c2_bit, c3_bit;
    
    // count[0] = 1 if bit 1,3,5,7,9 active
    or(c0_bit, bit_active[9], bit_active[7], bit_active[5], bit_active[3], bit_active[1]);
    assign count[0] = c0_bit;
    
    // count[1] = 1 if bit 2,3,6,7 active  
    wire c1_temp;
    or(c1_temp, bit_active[7], bit_active[6], bit_active[3], bit_active[2]);
    assign count[1] = c1_temp;
    
    // count[2] = 1 if bit 4,5,6,7 active
    wire c2_temp;
    or(c2_temp, bit_active[7], bit_active[6], bit_active[5], bit_active[4]);
    assign count[2] = c2_temp;
    
    // count[3] = 1 if bit 8,9 active
    or(c3_bit, bit_active[9], bit_active[8]);
    assign count[3] = c3_bit;
endmodule

// ----------------------------------------------------------------------------
// Barrel shifter - сдвиг влево на 0-11 позиций (для 11-битного числа)
// ----------------------------------------------------------------------------
module barrel_shift_left_11bit(
    input wire [10:0] in,
    input wire [3:0] shift_amt,  // 0-11
    output wire [10:0] out
);
    wire [10:0] stage0, stage1, stage2, stage3;
    
    // Stage 0: сдвиг на 0 или 1
    genvar i;
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage0_gen
            if (i == 0)
                mux2 m(.a(in[i]), .b(1'b0), .sel(shift_amt[0]), .out(stage0[i]));
            else
                mux2 m(.a(in[i]), .b(in[i-1]), .sel(shift_amt[0]), .out(stage0[i]));
        end
    endgenerate
    
    // Stage 1: сдвиг на 0 или 2
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage1_gen
            if (i < 2)
                mux2 m(.a(stage0[i]), .b(1'b0), .sel(shift_amt[1]), .out(stage1[i]));
            else
                mux2 m(.a(stage0[i]), .b(stage0[i-2]), .sel(shift_amt[1]), .out(stage1[i]));
        end
    endgenerate
    
    // Stage 2: сдвиг на 0 или 4
    generate
        for (i = 0; i < 11; i = i + 1) begin : stage2_gen
            if (i < 4)
                mux2 m(.a(stage1[i]), .b(1'b0), .sel(shift_amt[2]), .out(stage2[i]));
            else
                mux2 m(.a(stage1[i]), .b(stage1[i-4]), .sel(shift_amt[2]), .out(stage2[i]));
        end
    endgenerate
    
    // Stage 3: сдвиг на 0 или 8
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
// Barrel shifter - сдвиг вправо на 0-11 позиций (для 11-битного числа)
// ----------------------------------------------------------------------------
module barrel_shift_right_11bit(
    input wire [10:0] in,
    input wire [3:0] shift_amt,  // 0-11
    output wire [10:0] out
);
    wire [10:0] stage0, stage1, stage2, stage3;
    
    // Stage 0: сдвиг на 0 или 1
    genvar i;
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
// Счетчик на N бит с инкрементом и сбросом
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
    
    // count + 1
    adder_n #(.WIDTH(WIDTH)) inc(
        .a(count),
        .b({{(WIDTH-1){1'b0}}, 1'b1}),
        .cin(1'b0),
        .sum(count_plus_one),
        .cout(cout)
    );
    
    // Если en=1, то count+1, иначе count
    mux2_n #(.WIDTH(WIDTH)) mux(
        .a(count),
        .b(count_plus_one),
        .sel(en),
        .out(count_next)
    );
    
    // Регистр
    register_n #(.WIDTH(WIDTH)) reg_inst(
        .clk(clk),
        .rst(rst),
        .d(count_next),
        .q(count)
    );
endmodule

// ----------------------------------------------------------------------------
// Декремент на N бит (count - 1)
// ----------------------------------------------------------------------------
module decrement_n #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    wire [WIDTH-1:0] ones_comp;
    wire cout;
    
    // Вычитаем 1: in + (~0) + 1 + (~1) = in + all_ones + 0 = in - 1
    // Проще: in + 11111111 (в дополнении это -1)
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : ones_gen
            assign ones_comp[i] = 1'b1;
        end
    endgenerate
    
    adder_n #(.WIDTH(WIDTH)) dec(
        .a(in),
        .b(ones_comp),
        .cin(1'b0),
        .sum(out),
        .cout(cout)
    );
endmodule

// ----------------------------------------------------------------------------
// Арифметический сдвиг вправо на 1 (для знаковых чисел)
// Дублирует знаковый бит
// ----------------------------------------------------------------------------
module arith_shift_right_1 #(parameter WIDTH = 7) (
    input wire [WIDTH-1:0] in,
    output wire [WIDTH-1:0] out
);
    // Старший бит остается на месте (знак)
    assign out[WIDTH-1] = in[WIDTH-1];
    
    // Остальные биты сдвигаются вправо
    genvar i;
    generate
        for (i = 0; i < WIDTH-1; i = i + 1) begin : shift_gen
            assign out[i] = in[i+1];
        end
    endgenerate
endmodule

// ----------------------------------------------------------------------------
// Инкремент на N бит (in + 1)
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

// ----------------------------------------------------------------------------
// Мультиплексор 16:1 для barrel shifter
// ----------------------------------------------------------------------------
module mux16(
    input wire [15:0] in,
    input wire [3:0] sel,
    output wire out
);
    wire out0, out1;
    
    mux8 m0(.in(in[7:0]), .sel(sel[2:0]), .out(out0));
    mux8 m1(.in(in[15:8]), .sel(sel[2:0]), .out(out1));
    mux2 m2(.a(out0), .b(out1), .sel(sel[3]), .out(out));
endmodule

// ----------------------------------------------------------------------------
// Расширенный barrel shifter влево для больших чисел (34 бита, сдвиг 0-33)
// ----------------------------------------------------------------------------
module barrel_shift_left_34bit(
    input wire [33:0] in,
    input wire [5:0] shift_amt,  // 0-33
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

// ----------------------------------------------------------------------------
// Компаратор > (строго больше)
// ----------------------------------------------------------------------------
module comparator_gt_n #(parameter WIDTH = 4) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    output wire gt  // 1 если a > b
);
    wire eq, gte;
    
    comparator_eq_n #(.WIDTH(WIDTH)) cmp_eq(
        .a(a), .b(b), .eq(eq)
    );
    
    comparator_gte_n #(.WIDTH(WIDTH)) cmp_gte(
        .a(a), .b(b), .gte(gte)
    );
    
    wire eq_n;
    not(eq_n, eq);
    and(gt, gte, eq_n);
endmodule