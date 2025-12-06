`timescale 1ns/1ps

module sqrt2_tb;
    reg         clk;
    reg         enable;
    reg  [15:0] data_in;
    wire [15:0] io_data;
    wire        is_nan;
    wire        is_pinf;
    wire        is_ninf;
    wire        result;

    // Bidirectional шина
    reg         drive_input;
    assign io_data = drive_input ? data_in : 16'hzzzz;

    sqrt2 dut (
        .IO_DATA(io_data),
        .IS_NAN(is_nan),
        .IS_PINF(is_pinf),
        .IS_NINF(is_ninf),
        .RESULT(result),
        .CLK(clk),
        .ENABLE(enable)
    );

    // Генератор тактов
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Переменные для тестирования
    integer errors;
    integer test_num;

    initial begin
        $dumpfile("sqrt2_tb.vcd");
        $dumpvars(0, sqrt2_tb);
        
        errors = 0;
        test_num = 0;
        enable = 0;
        drive_input = 0;
        data_in = 16'h0000;
        
        $display("\n========================================");
        $display("  SQRT2 SIMPLE TESTBENCH");
        $display("========================================\n");
        
        repeat(3) @(posedge clk);
        
        // ============ SPECIAL CASES ============
        $display("--- Special Cases ---");
        test_sqrt("+Inf",    16'h7C00, 16'h7C00, 1, 0, 1, 0);  // sqrt(+Inf) = +Inf
        test_sqrt("-Inf",    16'hFC00, 16'hFE00, 1, 1, 0, 0);  // sqrt(-Inf) = NaN
        test_sqrt("QNaN",    16'h7E00, 16'hFE00, 1, 1, 0, 0);  // sqrt(NaN) = NaN
        test_sqrt("SNaN",    16'h7D00, 16'hFE00, 1, 1, 0, 0);  // sqrt(sNaN) = qNaN
        test_sqrt("+0",      16'h0000, 16'h0000, 1, 0, 0, 0);  // sqrt(+0) = +0
        test_sqrt("-0",      16'h8000, 16'h8000, 1, 0, 0, 0);  // sqrt(-0) = -0
        
        // ============ NEGATIVE NUMBERS ============
        $display("\n--- Negative Numbers -> NaN ---");
        test_sqrt("-1.0",    16'hBC00, 16'hFE00, 1, 1, 0, 0);
        test_sqrt("-4.0",    16'hC400, 16'hFE00, 1, 1, 0, 0);
        test_sqrt("-0.5",    16'hB800, 16'hFE00, 1, 1, 0, 0);
        test_sqrt("-100",    16'hD640, 16'hFE00, 1, 1, 0, 0);
        
        // ============ PERFECT SQUARES ============
        $display("\n--- Perfect Squares ---");
        test_sqrt("0.25",    16'h3400, 16'h3800, 1, 0, 0, 0);  // sqrt(0.25) = 0.5
        test_sqrt("1.0",     16'h3C00, 16'h3C00, 1, 0, 0, 0);  // sqrt(1) = 1
        test_sqrt("4.0",     16'h4400, 16'h4000, 1, 0, 0, 0);  // sqrt(4) = 2
        test_sqrt("9.0",     16'h4880, 16'h4200, 1, 0, 0, 0);  // sqrt(9) = 3
        test_sqrt("16.0",    16'h4C00, 16'h4400, 1, 0, 0, 0);  // sqrt(16) = 4
        test_sqrt("25.0",    16'h4E40, 16'h4500, 1, 0, 0, 0);  // sqrt(25) = 5
        test_sqrt("36.0",    16'h5080, 16'h4600, 1, 0, 0, 0);  // sqrt(36) = 6
        test_sqrt("49.0",    16'h5220, 16'h4700, 1, 0, 0, 0);  // sqrt(49) = 7
        test_sqrt("64.0",    16'h5400, 16'h4800, 1, 0, 0, 0);  // sqrt(64) = 8
        test_sqrt("81.0",    16'h5510, 16'h4880, 1, 0, 0, 0);  // sqrt(81) = 9
        test_sqrt("100.0",   16'h5640, 16'h4900, 1, 0, 0, 0);  // sqrt(100) = 10
        
        // ============ POWERS OF 2 ============
        $display("\n--- Powers of 2 ---");
        test_sqrt("0.0625",  16'h2800, 16'h3000, 1, 0, 0, 0);  // sqrt(2^-4) = 2^-2
        test_sqrt("0.125",   16'h3000, 16'h3400, 1, 0, 0, 0);  // sqrt(2^-3) = 2^-1.5
        test_sqrt("0.25",    16'h3400, 16'h3800, 1, 0, 0, 0);  // sqrt(2^-2) = 2^-1
        test_sqrt("0.5",     16'h3800, 16'h3A00, 1, 0, 0, 0);  // sqrt(2^-1) = 2^-0.5
        test_sqrt("2.0",     16'h4000, 16'h3E00, 1, 0, 0, 0);  // sqrt(2^1) = 2^0.5
        test_sqrt("4.0",     16'h4400, 16'h4000, 1, 0, 0, 0);  // sqrt(2^2) = 2^1
        test_sqrt("8.0",     16'h4800, 16'h4200, 1, 0, 0, 0);  // sqrt(2^3) = 2^1.5
        test_sqrt("16.0",    16'h4C00, 16'h4400, 1, 0, 0, 0);  // sqrt(2^4) = 2^2
        test_sqrt("32.0",    16'h5000, 16'h4600, 1, 0, 0, 0);  // sqrt(2^5) = 2^2.5
        test_sqrt("64.0",    16'h5400, 16'h4800, 1, 0, 0, 0);  // sqrt(2^6) = 2^3
        test_sqrt("128.0",   16'h5800, 16'h4A00, 1, 0, 0, 0);  // sqrt(2^7) = 2^3.5
        test_sqrt("256.0",   16'h5C00, 16'h4C00, 1, 0, 0, 0);  // sqrt(2^8) = 2^4
        test_sqrt("512.0",   16'h6000, 16'h4E00, 1, 0, 0, 0);  // sqrt(2^9) = 2^4.5
        test_sqrt("1024.0",  16'h6400, 16'h5000, 1, 0, 0, 0);  // sqrt(2^10) = 2^5
        
        // ============ NON-PERFECT SQUARES (примеры) ============
        $display("\n--- Non-Perfect Squares ---");
        test_sqrt_approx("2.0",   16'h4000, 16'h3DA8, 2);  // sqrt(2) ≈ 1.414 (truncated)
        test_sqrt_approx("3.0",   16'h4200, 16'h3EED, 2);  // sqrt(3) ≈ 1.732 (truncated)
        test_sqrt_approx("5.0",   16'h4500, 16'h4078, 2);  // sqrt(5) ≈ 2.236 (truncated)
        test_sqrt_approx("6.0",   16'h4600, 16'h40E6, 2);  // sqrt(6) ≈ 2.449 (truncated)
        test_sqrt_approx("7.0",   16'h4700, 16'h414A, 2);  // sqrt(7) ≈ 2.646 (truncated)
        test_sqrt_approx("10.0",  16'h4900, 16'h4253, 2);  // sqrt(10) ≈ 3.162 (truncated)
        test_sqrt_approx("12.0",  16'h4A00, 16'h42ED, 2);  // sqrt(12) ≈ 3.464 (truncated)
        test_sqrt_approx("15.0",  16'h4B80, 16'h43BE, 2);  // sqrt(15) ≈ 3.873 (truncated)
        test_sqrt_approx("20.0",  16'h4D00, 16'h4478, 2);  // sqrt(20) ≈ 4.472 (truncated)
        
        // ============ SMALL NUMBERS ============
        $display("\n--- Small Numbers ---");
        test_sqrt_approx("0.1",   16'h2E66, 16'h350F, 5);  // sqrt(0.1) ≈ 0.316 (truncated)
        test_sqrt_approx("0.5",   16'h3800, 16'h39A8, 2);  // sqrt(0.5) ≈ 0.707 (truncated)
        test_sqrt_approx("0.75",  16'h3A00, 16'h3AEC, 2);  // sqrt(0.75) ≈ 0.866 (truncated)
        
        // ============ VERY SMALL NORMAL NUMBERS ============
        $display("\n--- Very Small Normal Numbers ---");
        test_sqrt_approx("2^-14", 16'h0400, 16'h2000, 3);  // sqrt(2^-14) = 2^-7 (exact!)
        test_sqrt_approx("2^-13", 16'h0800, 16'h21A8, 3);  // sqrt(2^-13) = 2^-7 × sqrt(2) (truncated)
        test_sqrt_approx("2^-12", 16'h0C00, 16'h2400, 3);  // sqrt(2^-12) = 2^-6 (exact!)
        test_sqrt_approx("2^-10", 16'h1400, 16'h2800, 3);  // sqrt(2^-10) = 2^-5 (exact!)
        
        // ============ SUBNORMAL NUMBERS ============
        $display("\n--- Subnormal Numbers ---");
        test_sqrt_approx("min",   16'h0001, 16'h0100, 5);  // sqrt(2^-24) = 2^-12 (subnormal out)
        test_sqrt_approx("sub2",  16'h0002, 16'h0160, 5);  // Приблизительно
        test_sqrt_approx("sub4",  16'h0004, 16'h0200, 5);
        test_sqrt_approx("sub8",  16'h0008, 16'h02C0, 5);
        test_sqrt_approx("sub16", 16'h0010, 16'h0400, 5);
        test_sqrt_approx("sub32", 16'h0020, 16'h05A0, 5);
        test_sqrt_approx("sub64", 16'h0040, 16'h0800, 5);
        test_sqrt_approx("max_s", 16'h03FF, 16'h0FF8, 5);  // Max subnormal
        
        // ============ LARGE NUMBERS ============
        $display("\n--- Large Numbers ---");
        test_sqrt_approx("1000",  16'h63E8, 16'h4FF3, 5);  // sqrt(1000) ≈ 31.62 (truncated)
        test_sqrt_approx("2000",  16'h67D0, 16'h5197, 10); // sqrt(2000) ≈ 44.72 (truncated)
        test_sqrt_approx("10000", 16'h70E2, 16'h5640, 5);  // sqrt(10000) = 100 (exact!)
        test_sqrt_approx("max",   16'h7BFF, 16'h5BFF, 15); // sqrt(65504) ≈ 255.9 (truncated)
        
        // ============ ИТОГИ ============
        $display("\n========================================");
        if (errors == 0) begin
            $display("  ALL %0d TESTS PASSED!", test_num);
            $display("========================================\n");
            $finish;
        end else begin
            $display("  FAILED: %0d/%0d tests", errors, test_num);
            $display("========================================\n");
            $fatal(2, "Tests failed");
        end
    end

    // Задача для точных тестов (exact match)
    task test_sqrt;
        input [255:0] name;
        input [15:0] input_val;
        input [15:0] expected_val;
        input check_result;        // Проверять ли RESULT=1
        input expected_nan;
        input expected_pinf;
        input expected_ninf;
        
        integer cycles;
        
        begin
            test_num = test_num + 1;
            
            enable = 1;
            drive_input = 1;
            data_in = input_val;
            
            @(posedge clk);
            @(posedge clk);
            drive_input = 0;
            
            // Ждем RESULT=1
            cycles = 0;
            while (!result && cycles < 100) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            
            if (!result) begin
                $display("Test %0d [%0s] FAIL: Timeout after %0d cycles", test_num, name, cycles);
                errors = errors + 1;
            end else begin
                // Проверка выходного значения
                if (io_data !== expected_val) begin
                    $display("Test %0d [%0s] FAIL: Input=0x%04h Expected=0x%04h Got=0x%04h", 
                             test_num, name, input_val, expected_val, io_data);
                    errors = errors + 1;
                end 
                // Проверка флагов
                else if (is_nan !== expected_nan || is_pinf !== expected_pinf || is_ninf !== expected_ninf) begin
                    $display("Test %0d [%0s] FAIL: Flags NaN=%b(exp:%b) +Inf=%b(exp:%b) -Inf=%b(exp:%b)", 
                             test_num, name, is_nan, expected_nan, is_pinf, expected_pinf, is_ninf, expected_ninf);
                    errors = errors + 1;
                end else begin
                    $display("Test %0d [%0s] PASS: 0x%04h -> 0x%04h (%0d cycles)", 
                             test_num, name, input_val, io_data, cycles);
                end
            end
            
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
        end
    endtask

    // Задача для приблизительных тестов (с допуском ±tolerance LSB)
    task test_sqrt_approx;
        input [255:0] name;
        input [15:0] input_val;
        input [15:0] expected_val;
        input integer tolerance;   // Допуск в LSB (младших битах)
        
        integer cycles;
        integer diff;
        reg match;
        
        begin
            test_num = test_num + 1;
            
            enable = 1;
            drive_input = 1;
            data_in = input_val;
            
            @(posedge clk);
            @(posedge clk);
            drive_input = 0;
            
            // Ждем RESULT=1
            cycles = 0;
            while (!result && cycles < 100) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            
            if (!result) begin
                $display("Test %0d [%0s] FAIL: Timeout after %0d cycles", test_num, name, cycles);
                errors = errors + 1;
            end else begin
                // Вычисляем разницу (учитываем знаковые)
                if (io_data >= expected_val)
                    diff = io_data - expected_val;
                else
                    diff = expected_val - io_data;
                
                match = (diff <= tolerance);
                
                if (!match) begin
                    $display("Test %0d [%0s] FAIL: Input=0x%04h Expected=0x%04h Got=0x%04h (diff=%0d, tol=%0d)", 
                             test_num, name, input_val, expected_val, io_data, diff, tolerance);
                    errors = errors + 1;
                end 
                // Проверка флагов (для обычных чисел должны быть все 0)
                else if (is_nan || is_pinf || is_ninf) begin
                    $display("Test %0d [%0s] FAIL: Unexpected flags NaN=%b +Inf=%b -Inf=%b", 
                             test_num, name, is_nan, is_pinf, is_ninf);
                    errors = errors + 1;
                end else begin
                    $display("Test %0d [%0s] PASS: 0x%04h -> 0x%04h (exp:0x%04h, diff=%0d, %0d cycles)", 
                             test_num, name, input_val, io_data, expected_val, diff, cycles);
                end
            end
            
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
        end
    endtask

    // Таймаут для всей симуляции
    initial begin
        #500000;
        $display("\n!!! GLOBAL TIMEOUT !!!");
        $fatal(2, "Simulation timeout");
    end

endmodule
