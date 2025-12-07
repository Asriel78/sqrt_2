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

    wire first_cycle;
    first_cycle_detector fcd(
        .clk(clk),
        .enable(enable),
        .first_cycle(first_cycle)
    );
    
    wire valid_d;
    mux2 valid_mux(.a(1'b0), .b(first_cycle), .sel(enable), .out(valid_d));
    dff valid_ff(.clk(clk), .d(valid_d), .q(valid));
    
    wire [15:0] data_latched;
    register_with_enable #(.WIDTH(16)) data_reg(
        .clk(clk),
        .enable(first_cycle),
        .d_in(data),
        .q_out(data_latched)
    );
    
    assign sign = data_latched[15];
    assign exp  = data_latched[14:10];
    assign mant = data_latched[9:0];

endmodule