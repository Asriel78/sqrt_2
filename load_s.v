`timescale 1ns/1ps


module load(
    input  wire        clk,
    input  wire        enable,
    input  wire [15:0] data,
    output wire        sign,
    output wire [4:0]  exp,
    output wire [9:0]  mant,
    output wire        valid  
);

    // Внутренние сигналы
    wire prev_enable;
    wire enable_n;
    wire prev_enable_n;
    wire first_cycle;  // enable=1 && prev_enable=0
    wire valid_next;
    wire prev_enable_next;
    
    // Инверсии
    not(enable_n, enable);
    not(prev_enable_n, prev_enable);
    
    // Определяем первый цикл после enable 0->1
    and(first_cycle, enable, prev_enable_n);
    
    // Логика для prev_enable_next
    // Если enable=1, то prev_enable_next = 1
    // Если enable=0, то prev_enable_next = 0
    // Проще: prev_enable_next = enable
    assign prev_enable_next = enable;
    
    // Логика для valid_next
    // valid = 1 только на первом цикле (first_cycle)
    // Во всех остальных случаях valid = 0
    // Если enable=0, то valid=0
    assign valid_next = first_cycle;
    
    // Регистр prev_enable
    wire prev_enable_d;
    mux2 prev_en_mux(
        .a(1'b0),              // Если enable=0
        .b(prev_enable_next),  // Если enable=1
        .sel(enable),
        .out(prev_enable_d)
    );
    
    dff prev_enable_ff(
        .clk(clk),
        .d(prev_enable_d),
        .q(prev_enable)
    );
    
    // Регистр valid
    wire valid_d;
    mux2 valid_mux(
        .a(1'b0),         // Если enable=0
        .b(valid_next),   // Если enable=1
        .sel(enable),
        .out(valid_d)
    );
    
    dff valid_ff(
        .clk(clk),
        .d(valid_d),
        .q(valid)
    );
    
    // Регистры данных (защелкиваются только на first_cycle)
    wire [15:0] data_latched;
    wire [15:0] data_next;
    
    // Если first_cycle=1, берем новые данные, иначе держим старые
    mux2_n #(.WIDTH(16)) data_mux(
        .a(data_latched),
        .b(data),
        .sel(first_cycle),
        .out(data_next)
    );
    
    // Регистр для данных (с enable через first_cycle или текущие данные)
    wire [15:0] data_to_reg;
    mux2_n #(.WIDTH(16)) data_en_mux(
        .a(data_latched),  // Если enable=0, держим старое
        .b(data_next),     // Если enable=1, обновляем
        .sel(enable),
        .out(data_to_reg)
    );
    
    register_n #(.WIDTH(16)) data_reg(
        .clk(clk),
        .rst(1'b0),
        .d(data_to_reg),
        .q(data_latched)
    );
    
    // Выходы - просто разбиваем data_latched
    assign sign = data_latched[15];
    assign exp  = data_latched[14:10];
    assign mant = data_latched[9:0];

endmodule