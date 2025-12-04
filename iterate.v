`timescale 1ns/1ps
module iterate (
    input  wire        clk,
    input  wire        enable,
    input  wire        n_valid,

    input  wire        sign_in,
    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,
    input  wire        is_num,

    input  wire [10:0] mant_in,
    input  wire signed [6:0] exp_in,

    output reg         it_valid,
    output reg         result,

    output reg         sign_out,
    output reg signed [6:0] exp_out,
    output reg [10:0]  mant_out
);

    localparam ROOT_BITS = 11;
    localparam ITER_MAX  = ROOT_BITS;

    // Registers for digit-by-digit algorithm
    reg [21:0] radicand;      // 22 bits for mantissa processing
    reg [14:0] remainder;     // 15 bits for remainder
    reg [10:0] root;          // 11 bits result accumulator
    reg [4:0]  iter_count;    // iteration counter
    reg        computing;     // active computation flag

    // Combinational logic for current iteration
    reg [1:0]  top2;
    reg [14:0] rem_shifted;
    reg [12:0] trial_root;
    reg [14:0] trial_val;
    reg [10:0] next_root;
    reg [14:0] next_rem;

    always @(posedge clk) begin
        if (!enable) begin
            // Reset all state
            computing      <= 1'b0;
            iter_count     <= 0;
            radicand       <= 0;
            remainder      <= 0;
            root           <= 0;
            sign_out       <= 1'b0;
            exp_out        <= 7'sd0;
            mant_out       <= 11'b0;
            it_valid       <= 1'b0;
            result         <= 1'b0;
        end
        else begin
            it_valid <= 1'b0;

            // Start new computation when n_valid arrives
            if (!computing && n_valid) begin
                
                // Case 1: Special values (handled by special.v, just pass through)
                if (is_nan_in || is_pinf_in || is_ninf_in) begin
                    // These are already processed by special.v
                    // Just pass through the flags
                    sign_out   <= sign_in;
                    exp_out    <= exp_in;
                    mant_out   <= mant_in;
                    it_valid   <= 1'b1;
                    result     <= 1'b1;
                    computing  <= 1'b0;
                end
                // Case 2: Zero (is_num=0 and not special)
                else if (!is_num) begin
                    sign_out   <= sign_in;
                    exp_out    <= -7'sd15;
                    mant_out   <= 11'b0;
                    it_valid   <= 1'b1;
                    result     <= 1'b1;
                    computing  <= 1'b0;
                end
                // Case 3: Normal positive number - start iteration
                else begin
                    sign_out   <= 1'b0;  // sqrt is always positive
                    
                    // Adjust exponent (must be even) and prepare radicand
                    // Mantissa is in format: 1.xxxxxxxxxx (11 bits with implicit 1)
                    if (exp_in[0]) begin
                        // Odd exponent: multiply mantissa by 2 (shift left by 1)
                        // mant_in[10:0] << 11 gives us the mantissa in upper bits
                        radicand <= {mant_in[10:0], 11'b0};
                        exp_out  <= (exp_in - 7'sd1) >>> 1;
                    end else begin
                        // Even exponent: shift mantissa right by 1 to put in [1,2) range
                        // This places it as 01.xxxxxxxxx in upper bits
                        radicand <= {1'b0, mant_in[10:0], 10'b0};
                        exp_out  <= exp_in >>> 1;
                    end
                    
                    remainder  <= 15'b0;
                    root       <= 11'b0;
                    iter_count <= ITER_MAX;
                    computing  <= 1'b1;
                end
            end

            // Execute digit-by-digit iterations
            else if (computing && iter_count > 0) begin
                // Extract top 2 bits from radicand
                top2 = radicand[21:20];
                
                // Shift remainder left by 2 and add top2
                rem_shifted = {remainder[12:0], top2};
                
                // Trial value: (2*root + 1)
                // trial_root has 13 bits: (root << 1) | 1
                trial_root = ({2'b00, root} << 1) | 13'd1;
                trial_val = {2'b00, trial_root};
                
                // Compare and update
                if (rem_shifted >= trial_val) begin
                    next_rem  = rem_shifted - trial_val;
                    next_root = {root[9:0], 1'b1};  // root*2 + 1
                end else begin
                    next_rem  = rem_shifted;
                    next_root = {root[9:0], 1'b0};  // root*2 + 0
                end
                
                // Update registers
                remainder  <= next_rem;
                root       <= next_root;
                radicand   <= {radicand[19:0], 2'b00};  // shift left by 2
                
                // Output current result
                mant_out   <= next_root;
                it_valid   <= 1'b1;
                iter_count <= iter_count - 5'd1;
                
                // Check if this is the last iteration
                if (iter_count == 5'd1) begin
                    result    <= 1'b1;
                    computing <= 1'b0;
                end
            end
            // Hold result state until enable=0
        end
    end

endmodule
