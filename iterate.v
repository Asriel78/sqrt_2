`timescale 1ns/1ps

module iterate_tb;
    reg clk;
    reg enable;
    reg n_valid;
    
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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function real mant_to_real;
        input [10:0] m;
        integer i;
        real val;
        begin
            val = 0.0;
            for (i = 0; i < 11; i = i + 1) begin
                if (m[10-i])
                    val = val + (1.0 / (2.0 ** i));
            end
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
        is_nan_in = 0;
        is_pinf_in = 0;
        is_ninf_in = 0;
        is_num = 0;
        mant_in = 0;
        exp_in = 0;
        
        $display("\n========================================");
        $display("  TESTBENCH: iterate module");
        $display("========================================\n");
        
        repeat(3) @(posedge clk);
        enable = 1;
        repeat(2) @(posedge clk);

        // Тесты special случаев
        $display("\n--- Special Cases ---");
        test_special("NaN input", 1, 0, 0, 1, 7'sd16, 11'b10000000000);
        test_special("+Inf input", 0, 1, 0, 0, 7'sd16, 11'd0);
        test_special("-Inf input", 0, 0, 1, 1, 7'sd16, 11'b10000000000);
        
        // Тесты нормальных чисел
        $display("\n--- Normal Numbers ---");
        test_detailed("sqrt(4.0)", 11'h400, 7'sd2, 11'h400, 7'sd1, 2.0);
        test_detailed("sqrt(1.0)", 11'h400, 7'sd0, 11'h400, 7'sd0, 1.0);
        test_detailed("sqrt(16.0)", 11'h400, 7'sd4, 11'h400, 7'sd2, 4.0);
        test_detailed("sqrt(2.0)", 11'h400, 7'sd1, 11'h5A8, 7'sd0, 1.414);
        test_detailed("sqrt(0.25)", 11'h400, -7'sd2, 11'h400, -7'sd1, 0.5);
        test_detailed("sqrt(3.0)", 11'h600, 7'sd1, 11'h5DB, 7'sd0, 1.732);
        test_detailed("sqrt(9.0)", 11'h480, 7'sd3, 11'h600, 7'sd1, 3.0);
        test_detailed("sqrt(0.0625)", 11'h400, -7'sd4, 11'h400, -7'sd2, 0.25);

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

    task test_special;
        input [255:0] name;
        input nan_flag;
        input pinf_flag;
        input ninf_flag;
        input exp_sign_out;
        input signed [6:0] exp_exp_out;
        input [10:0] exp_mant_out;
        
        begin
            $display("\n=== Test: %s ===", name);
            
            @(posedge clk);
            n_valid = 1;
            is_nan_in = nan_flag;
            is_pinf_in = pinf_flag;
            is_ninf_in = ninf_flag;
            is_num = 0;
            mant_in = 11'h0;
            exp_in = 7'sd0;
            
            @(posedge clk);
            n_valid = 0;
            
            // Special случаи должны отработать за 1 такт
            if (!it_valid || !result) begin
                $display("FAIL: Special case should set it_valid=1 and result=1 immediately");
                errors = errors + 1;
            end else begin
                if (sign_out !== exp_sign_out) begin
                    $display("FAIL: sign_out=%b, expected %b", sign_out, exp_sign_out);
                    errors = errors + 1;
                end else if (exp_out !== exp_exp_out) begin
                    $display("FAIL: exp_out=%0d, expected %0d", exp_out, exp_exp_out);
                    errors = errors + 1;
                end else if (mant_out !== exp_mant_out) begin
                    $display("FAIL: mant_out=0x%03h, expected 0x%03h", mant_out, exp_mant_out);
                    errors = errors + 1;
                end else begin
                    $display("PASS: sign=%b exp=%0d mant=0x%03h", sign_out, exp_out, mant_out);
                end
            end
            
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
            enable = 1;
            repeat(2) @(posedge clk);
        end
    endtask

    task test_detailed;
        input [255:0] name;
        input [10:0] mant;
        input signed [6:0] exp;
        input [10:0] exp_mant_out;
        input signed [6:0] exp_exp_out;
        input real exp_real;
        
        real result_real;
        real error;
        integer iter_count;
        
        begin
            $display("\n=== Test: %s ===", name);
            $display("Input:    mant=0x%h exp=%0d -> %.6f", 
                     mant, exp, compute_result(mant, exp));
            $display("Expected: mant=0x%h exp=%0d -> %.6f", 
                     exp_mant_out, exp_exp_out, exp_real);
            
            @(posedge clk);
            n_valid = 1;
            is_nan_in = 0;
            is_pinf_in = 0;
            is_ninf_in = 0;
            is_num = 1;
            mant_in = mant;
            exp_in = exp;
            
            @(posedge clk);
            n_valid = 0;
            
            cycle = 0;
            iter_count = 0;
            
            while (!result && cycle < 25) begin
                @(posedge clk);
                cycle = cycle + 1;
                
                if (it_valid) begin
                    iter_count = iter_count + 1;
                    if (cycle <= 3 || result) begin
                        result_real = compute_result(mant_out, exp_out);
                        $display("Cycle %2d: mant=0x%03h exp=%2d -> %.6f [iter_left=%0d]",
                                 cycle, mant_out, exp_out, result_real, dut.iter_left);
                    end
                end
            end
            
            if (!result) begin
                $display("\nFAIL: Timeout (no RESULT after %0d cycles)", cycle);
                errors = errors + 1;
            end else begin
                result_real = compute_result(mant_out, exp_out);
                $display("\nFinal:  mant=0x%03h exp=%0d -> %.6f [%0d iterations]", 
                         mant_out, exp_out, result_real, iter_count);
                
                error = result_real - exp_real;
                if (error < 0) error = -error;
                
                // Проверка экспоненты
                if (exp_out !== exp_exp_out) begin
                    $display("FAIL: Wrong exponent: got %0d, expected %0d", exp_out, exp_exp_out);
                    errors = errors + 1;
                end
                // Проверка точности результата
                else if (error <= 0.01) begin
                    $display("PASS: error=%.6f (within tolerance)", error);
                end else begin
                    $display("FAIL: error=%.6f (exceeds tolerance 0.01)", error);
                    $display("  Expected: mant=0x%03h exp=%0d", exp_mant_out, exp_exp_out);
                    $display("  Got:      mant=0x%03h exp=%0d", mant_out, exp_out);
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

    initial begin
        #100000;
        $display("\n!!! GLOBAL TIMEOUT !!!");
        $fatal(2, "Simulation timeout");
    end

endmodule
