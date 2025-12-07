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

    not(enable_n, enable);
    not(prev_enable_n, prev_enable);
    
    and(first_cycle, enable, prev_enable_n);
    
    assign prev_enable_next = enable;
    
    assign valid_next = first_cycle;
    
    wire prev_enable_d;
    mux2 prev_en_mux(
        .a(1'b0),              
        .b(prev_enable_next),  
        .sel(enable),
        .out(prev_enable_d)
    );
    
    dff prev_enable_ff(
        .clk(clk),
        .d(prev_enable_d),
        .q(prev_enable)
    );
    
    wire valid_d;
    mux2 valid_mux(
        .a(1'b0),        
        .b(valid_next),  
        .sel(enable),
        .out(valid_d)
    );
    
    dff valid_ff(
        .clk(clk),
        .d(valid_d),
        .q(valid)
    );
    
    wire [15:0] data_latched;
    wire [15:0] data_next;
    

    mux2_n #(.WIDTH(16)) data_mux(
        .a(data_latched),
        .b(data),
        .sel(first_cycle),
        .out(data_next)
    );
    

    wire [15:0] data_to_reg;
    mux2_n #(.WIDTH(16)) data_en_mux(
        .a(data_latched),  // Если enable=0, держим старое
        .b(data_next),     
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