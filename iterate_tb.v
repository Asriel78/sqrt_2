`timescale 1ns/1ps

module iterate_tb;
    reg clk;
    reg enable;
    reg n_valid;
    
    reg        sign_in;
    reg        is_nan_in;
    reg        is_pinf_in;
    reg        is_ninf_in;
    reg        is_num;
    reg [10:0] mant_in;
    reg signed [6:0] exp_in;
    
    wire        it_valid;
    wire        result;
    wire        sign_out;
    wire signed [6:0] exp_out;
    wire [10:0] mant_out;

    iterate dut (
        .clk(clk),
        .enable(enable),
        .n_valid(n_valid),
        .sign_in(sign_in),
        .is_nan_in(is_nan_in),
        .is_pinf_in(is_pinf_in),
        .is_ninf_in(is_ninf_in),
        .is_num(is_num),
        .mant_in(mant_in),
        .exp_in(exp_in),
        .it_valid(it_valid),
        .result(result),
        .sign_out(sign_out),
        .exp_out(exp_out),
        .mant_out(mant_out)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Helper function to convert mantissa to real
    function real mant_to_real;
        input [10:0] m;
        integer i;
        real val;
        begin
            val = 0.0;
            for (i = 0; i < 10; i = i + 1) begin
                if (m[9-i])
                    val = val + (1.0 / (2.0 ** (i+1)));
            end
            // Add implicit 1 if MSB is set
            if (m[10])
                mant_to_real = 1.0 + val;
            else
                mant_to_real = val;
        end
    endfunction

    function real compute_result;
        input [10:0] m;
        input signed [6:0] e;
        real mantissa_val;
        begin
            mantissa_val = mant_to_real(m);
            compute_result = mantissa_val * (2.0 ** e);
        end
    endfunction

    integer cycle;
    integer errors;
    
    initial begin
        $dumpfile("iterate_tb.vcd");
        $dumpvars(0, iterate_tb);
        
        errors = 0;
        enable = 0;
        n_valid = 0;
        sign_in = 0;
        is_nan_in = 0;
        is_pinf_in = 0;
        is_ninf_in = 0;
        is_num = 0;
        mant_in = 0;
        exp_in = 0;
        
        $display("\n========================================");
        $display("  TESTBENCH: iterate module");
        $display("========================================\n");
        
        // Wait for reset
        repeat(3) @(posedge clk);
        enable = 1;
        repeat(2) @(posedge clk);

        // Test 1: sqrt(4.0) = 2.0
        // 4.0 = 1.0 * 2^2, so mant=11'h400, exp=2
        test_normal("sqrt(4.0)", 11'h400, 7'sd2, 11'h400, 7'sd1, 2.0);

        // Test 2: sqrt(1.0) = 1.0
        // 1.0 = 1.0 * 2^0
        test_normal("sqrt(1.0)", 11'h400, 7'sd0, 11'h400, 7'sd0, 1.0);

        // Test 3: sqrt(16.0) = 4.0
        // 16.0 = 1.0 * 2^4
        test_normal("sqrt(16.0)", 11'h400, 7'sd4, 11'h400, 7'sd2, 4.0);

        // Test 4: sqrt(2.0) ≈ 1.414
        // 2.0 = 1.0 * 2^1
        test_normal_approx("sqrt(2.0)", 11'h400, 7'sd1, 1.414, 0.01);

        // Test 5: sqrt(0.25) = 0.5
        // 0.25 = 1.0 * 2^-2
        test_normal("sqrt(0.25)", 11'h400, -7'sd2, 11'h400, -7'sd1, 0.5);

        // Test 6: sqrt(3.0) ≈ 1.732
        // 3.0 = 1.5 * 2^1 = (1 + 0.5) * 2^1
        // mant = 1.1000000000 = 11'h600
        test_normal_approx("sqrt(3.0)", 11'h600, 7'sd1, 1.732, 0.01);

        // Test 7: Special cases (passed through from special.v)
        $display("\n=== Special Value Tests ===\n");
        
        // NaN - special.v already made it quiet, we pass through
        test_passthrough("NaN (quiet)", 1'b1, 1'b1, 1'b0, 1'b0, 
                        11'h600, 7'sd16);  // quiet NaN from special
        
        // +Inf
        test_passthrough("+Inf", 1'b0, 1'b0, 1'b1, 1'b0, 
                        11'h000, 7'sd16);
        
        // -Inf (special.v converts to NaN)
        test_passthrough("-Inf->NaN", 1'b1, 1'b1, 1'b0, 1'b0, 
                        11'h400, 7'sd16);

        // Final report
        $display("\n========================================");
        if (errors == 0) begin
            $display("  ALL TESTS PASSED");
            $display("========================================\n");
            $finish;
        end else begin
            $display("  FAILED: %0d errors", errors);
            $display("========================================\n");
            $fatal(2, "Tests failed");
        end
    end

    // Task: Test normal number with exact result
    task test_normal;
        input [255:0] name;
        input [10:0] mant;
        input signed [6:0] exp;
        input [10:0] exp_mant_out;
        input signed [6:0] exp_exp_out;
        input real exp_real;
        
        real result_real;
        
        begin
            $display("\n=== Test: %s ===", name);
            $display("Input:  mant=%h exp=%0d (%.6f)", mant, exp, compute_result(mant, exp));
            $display("Expect: mant=%h exp=%0d (%.6f)", exp_mant_out, exp_exp_out, exp_real);
            
            // Send input
            @(posedge clk);
            n_valid = 1;
            sign_in = 0;
            is_nan_in = 0;
            is_pinf_in = 0;
            is_ninf_in = 0;
            is_num = 1;
            mant_in = mant;
            exp_in = exp;
            
            @(posedge clk);
            n_valid = 0;
            
            // Monitor iterations
            cycle = 0;
            $display("\nIteration progress:");
            $display("Cycle | Valid | Result | Root (bin)  | Mantissa    | Remainder   | Computing | Iter");
            $display("------|-------|--------|-------------|-------------|-------------|-----------|-----");
            
            while (!result && cycle < 20) begin
                @(posedge clk);
                cycle = cycle + 1;
                
                $display("%5d | %5b | %6b | %11b | %11b | %15b | %9b | %4d",
                         cycle, it_valid, result, 
                         dut.root, mant_out, dut.remainder,
                         dut.computing, dut.iter_count);
                
                if (it_valid && !result) begin
                    result_real = compute_result(mant_out, exp_out);
                    $display("      | Intermediate: %.6f", result_real);
                end
            end
            
            if (!result) begin
                $display("\nFAIL: Timeout (no RESULT after %0d cycles)", cycle);
                errors = errors + 1;
            end else begin
                result_real = compute_result(mant_out, exp_out);
                $display("\nFinal:  mant=%h exp=%0d (%.6f) [%0d cycles]", 
                         mant_out, exp_out, result_real, cycle);
                
                if (mant_out === exp_mant_out && exp_out === exp_exp_out) begin
                    $display("PASS: Exact match");
                end else begin
                    $display("FAIL: Mismatch");
                    $display("  Expected: mant=%h exp=%0d", exp_mant_out, exp_exp_out);
                    $display("  Got:      mant=%h exp=%0d", mant_out, exp_out);
                    errors = errors + 1;
                end
            end
            
            // Reset
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
            enable = 1;
            repeat(2) @(posedge clk);
        end
    endtask

    // Task: Test normal number with approximate result
    task test_normal_approx;
        input [255:0] name;
        input [10:0] mant;
        input signed [6:0] exp;
        input real exp_real;
        input real tolerance;
        
        real result_real;
        real error;
        
        begin
            $display("\n=== Test: %s ===", name);
            $display("Input:  mant=%h exp=%0d (%.6f)", mant, exp, compute_result(mant, exp));
            $display("Expect: %.6f ± %.6f", exp_real, tolerance);
            
            @(posedge clk);
            n_valid = 1;
            sign_in = 0;
            is_nan_in = 0;
            is_pinf_in = 0;
            is_ninf_in = 0;
            is_num = 1;
            mant_in = mant;
            exp_in = exp;
            
            @(posedge clk);
            n_valid = 0;
            
            cycle = 0;
            $display("\nIteration progress:");
            while (!result && cycle < 20) begin
                @(posedge clk);
                cycle = cycle + 1;
                if (it_valid && cycle <= 5) begin
                    $display("  Cycle %2d: root=%11b mant_out=%11b", 
                             cycle, dut.root, mant_out);
                end
            end
            
            if (!result) begin
                $display("\nFAIL: Timeout");
                errors = errors + 1;
            end else begin
                result_real = compute_result(mant_out, exp_out);
                error = result_real - exp_real;
                if (error < 0) error = -error;
                
                $display("\nFinal:  mant=%h exp=%0d (%.6f) [%0d cycles]", 
                         mant_out, exp_out, result_real, cycle);
                
                if (error <= tolerance) begin
                    $display("PASS: error=%.6f within tolerance", error);
                end else begin
                    $display("FAIL: error=%.6f exceeds tolerance %.6f", error, tolerance);
                    errors = errors + 1;
                end
            end
            
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
            enable = 1;
            repeat(2) @(posedge clk);
        end
    endtask

    // Task: Test special values (passthrough from special.v)
    task test_passthrough;
        input [255:0] name;
        input sign;
        input nan;
        input pinf;
        input ninf;
        input [10:0] mant;
        input signed [6:0] exp;
        
        begin
            $display("\nTest: %s", name);
            $display("Flags: sign=%b nan=%b pinf=%b ninf=%b is_num=0",
                     sign, nan, pinf, ninf);
            
            @(posedge clk);
            n_valid = 1;
            sign_in = sign;
            is_nan_in = nan;
            is_pinf_in = pinf;
            is_ninf_in = ninf;
            is_num = 0;  // Special values have is_num=0
            mant_in = mant;
            exp_in = exp;
            
            @(posedge clk);
            n_valid = 0;
            
            cycle = 0;
            while (!result && cycle < 5) begin
                @(posedge clk);
                cycle = cycle + 1;
            end
            
            if (result && it_valid) begin
                $display("Result in %0d cycle: mant=%h exp=%d sign=%b",
                         cycle, mant_out, exp_out, sign_out);
                $display("PASS: Special value passed through in 1 cycle");
            end else begin
                $display("FAIL: Special value not handled correctly");
                errors = errors + 1;
            end
            
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
            enable = 1;
            repeat(2) @(posedge clk);
        end
    endtask

    // Timeout watchdog
    initial begin
        #100000;
        $display("\n!!! GLOBAL TIMEOUT !!!");
        $fatal(2, "Simulation timeout");
    end

endmodule
