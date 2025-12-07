`timescale 1ns/1ps
module load(
    input  wire        clk,
    input  wire        enable,
    input  wire [15:0] data,
    output reg         sign,
    output reg  [4:0]  exp,
    output reg  [9:0]  mant,
    output reg         valid  
);

    reg prev_enable;

    initial begin
        prev_enable = 1'b0;
        valid = 1'b0;
        sign = 1'b0;
        exp = 5'd0;
        mant = 10'd0;
    end

    always @(posedge clk) begin
        if (!enable) begin
            prev_enable <= 1'b0;
            valid <= 1'b0;
        end else begin
            if (!prev_enable) begin
                sign <= data[15];
                exp  <= data[14:10];
                mant <= data[9:0];
                valid <= 1'b1;
            end else begin
                valid <= 1'b0;
            end
            prev_enable <= 1'b1;
        end
    end

endmodule