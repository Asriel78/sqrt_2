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

    // Функции для работы с half precision
    function [15:0] make_fp16;
        input sign;
        input [4:0] exp;
        input [9:0] mant;
        begin
            make_fp16 = {sign, exp, mant};
        end
    endfunction

    function real fp16_to_real;
        input [15:0] fp;
        reg sign;
        reg [4:0] exp;
        reg [9:0] mant;
        real value;
        integer e_unbiased;
        begin
            sign = fp[15];
            exp = fp[14:10];
            mant = fp[9:0];
            
            if (exp == 5'b11111) begin
                if (mant != 0)
                    fp16_to_real = 0.0/0.0;
                else
                    fp16_to_real = sign ? -1.0/0.0 : 1.0/0.0;
            end else if (exp == 5'b00000) begin
                if (mant == 0) begin
                    fp16_to_real = sign ? -0.0 : 0.0;
                end else begin
                    e_unbiased = -14;
                    value = mant / 1024.0;
                    value = value * (2.0 ** e_unbiased);
                    fp16_to_real = sign ? -value : value;
                end
            end else begin
                e_unbiased = exp - 15;
                value = 1.0 + (mant / 1024.0);
                value = value * (2.0 ** e_unbiased);
                fp16_to_real = sign ? -value : value;
            end
        end
    endfunction

    function real abs_real;
        input real x;
        begin
            abs_real = (x < 0.0) ? -x : x;
        end
    endfunction

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
        $display("  SQRT2 EXTENDED TESTBENCH");
        $display("========================================\n");
        
        repeat(3) @(posedge clk);
        
        // ============ SPECIAL CASES ============
        $display("--- Special Cases ---");
        test_sqrt("+Inf", 16'h7C00, 16'h7C00, 0, 1, 0);
        test_sqrt("-Inf", 16'hFC00, 16'hFE00, 1, 0, 0);
        test_sqrt("NaN", 16'h7E00, 16'hFE00, 1, 0, 0);
        test_sqrt("sNaN", 16'h7D00, 16'hFE00, 1, 0, 0);
        test_sqrt("+0", 16'h0000, 16'h0000, 0, 0, 0);
        test_sqrt("-0", 16'h8000, 16'h8000, 0, 0, 0);
        
        // ============ NEGATIVE NUMBERS ============
        $display("\n--- Negative Numbers ---");
        test_sqrt("-1.0", 16'hBC00, 16'hFE00, 1, 0, 0);
        test_sqrt("-4.0", 16'hC400, 16'hFE00, 1, 0, 0);
        test_sqrt("-0.5", 16'hB800, 16'hFE00, 1, 0, 0);
        test_sqrt("-100", 16'hD640, 16'hFE00, 1, 0, 0);
        
        // ============ PERFECT SQUARES ============
        $display("\n--- Perfect Squares ---");
        test_sqrt("1.0", 16'h3C00, 16'h3C00, 0, 0, 0);
        test_sqrt("4.0", 16'h4400, 16'h4000, 0, 0, 0);
        test_sqrt("9.0", 16'h4880, 16'h4200, 0, 0, 0);
        test_sqrt("16.0", 16'h4C00, 16'h4400, 0, 0, 0);
        test_sqrt("25.0", 16'h4E40, 16'h4500, 0, 0, 0);
        test_sqrt("36.0", 16'h5080, 16'h4600, 0, 0, 0);
        test_sqrt("49.0", 16'h5220, 16'h4700, 0, 0, 0);
        test_sqrt("64.0", 16'h5400, 16'h4800, 0, 0, 0);
        test_sqrt("0.25", 16'h3400, 16'h3800, 0, 0, 0);
        
        // ============ NON-PERFECT SQUARES (SMALL) ============
        $display("\n--- Non-Perfect Squares (Small: 0.1-1.0) ---");
        test_sqrt_approx("0.125", 16'h3000, 0.35355, 0.01);
        test_sqrt_approx("0.1875", 16'h3200, 0.43301, 0.01);
        test_sqrt_approx("0.375", 16'h3600, 0.61237, 0.01);
        test_sqrt_approx("0.5", 16'h3800, 0.70711, 0.01);
        test_sqrt_approx("0.625", 16'h3900, 0.79057, 0.01);
        test_sqrt_approx("0.75", 16'h3A00, 0.86603, 0.01);
        test_sqrt_approx("0.875", 16'h3B00, 0.93541, 0.01);
        
        // ============ NON-PERFECT SQUARES (MEDIUM) ============
        $display("\n--- Non-Perfect Squares (Medium: 1-10) ---");
        test_sqrt_approx("1.5", 16'h3E00, 1.22474, 0.01);
        test_sqrt_approx("2.0", 16'h4000, 1.41421, 0.01);
        test_sqrt_approx("2.5", 16'h4100, 1.58114, 0.01);
        test_sqrt_approx("3.0", 16'h4200, 1.73205, 0.01);
        test_sqrt_approx("3.5", 16'h4300, 1.87083, 0.01);
        test_sqrt_approx("5.0", 16'h4500, 2.23607, 0.01);
        test_sqrt_approx("6.0", 16'h4600, 2.44949, 0.01);
        test_sqrt_approx("7.0", 16'h4700, 2.64575, 0.01);
        test_sqrt_approx("8.0", 16'h4800, 2.82843, 0.01);
        test_sqrt_approx("10.0", 16'h4900, 3.16228, 0.01);
        
        // ============ NON-PERFECT SQUARES (LARGE) ============
        $display("\n--- Non-Perfect Squares (Large: 10-1000) ---");
        test_sqrt_approx("12.0", 16'h4A00, 3.46410, 0.01);
        test_sqrt_approx("15.0", 16'h4B80, 3.87298, 0.01);
        test_sqrt_approx("20.0", 16'h4D00, 4.47214, 0.02);
        test_sqrt_approx("30.0", 16'h4F00, 5.47723, 0.02);
        test_sqrt_approx("50.0", 16'h5140, 7.07107, 0.05);
        test_sqrt_approx("75.0", 16'h52B0, 8.66025, 0.05);
        test_sqrt_approx("100.0", 16'h5640, 10.0, 0.1);
        test_sqrt_approx("150.0", 16'h5960, 12.2474, 0.1);
        test_sqrt_approx("200.0", 16'h5C80, 14.1421, 0.1);
        test_sqrt_approx("500.0", 16'h5FA0, 22.3607, 0.2);
        test_sqrt_approx("1000.0", 16'h63E0, 31.6228, 0.5);
        test_sqrt_approx("1024.0", 16'h6400, 32.0, 0.5);
        
        // ============ VERY SMALL NORMAL NUMBERS ============
        $display("\n--- Very Small Normal Numbers ---");
        test_sqrt_approx("2^-14", 16'h0400, 0.00781, 0.001);  // Smallest normal
        test_sqrt_approx("2^-13", 16'h0800, 0.01106, 0.001);
        test_sqrt_approx("2^-12", 16'h0C00, 0.01563, 0.002);
        test_sqrt_approx("2^-11", 16'h1000, 0.02210, 0.002);
        test_sqrt_approx("2^-10", 16'h1400, 0.03125, 0.002);
        test_sqrt_approx("2^-9", 16'h1800, 0.04419, 0.002);
        test_sqrt_approx("2^-8", 16'h1C00, 0.06250, 0.005);
        
        // ============ SUBNORMAL NUMBERS ============
        $display("\n--- Subnormal Numbers ---");
        test_sqrt_approx("subnorm_min", 16'h0001, 0.000183, 0.0001);  // 2^-24
        test_sqrt_approx("subnorm_2", 16'h0002, 0.000259, 0.0001);
        test_sqrt_approx("subnorm_4", 16'h0004, 0.000366, 0.0001);
        test_sqrt_approx("subnorm_8", 16'h0008, 0.000518, 0.0002);
        test_sqrt_approx("subnorm_16", 16'h0010, 0.000732, 0.0002);
        test_sqrt_approx("subnorm_32", 16'h0020, 0.001035, 0.0003);
        test_sqrt_approx("subnorm_64", 16'h0040, 0.001464, 0.0005);
        test_sqrt_approx("subnorm_128", 16'h0080, 0.002071, 0.0005);
        test_sqrt_approx("subnorm_256", 16'h0100, 0.002930, 0.001);
        test_sqrt_approx("subnorm_512", 16'h0200, 0.004142, 0.001);
        test_sqrt_approx("subnorm_max", 16'h03FF, 0.006104, 0.001);  // Max subnormal
        
        // ============ BOUNDARY CASES ============
        $display("\n--- Boundary Cases ---");
        test_sqrt_approx("near_1", 16'h3BFF, 0.99951, 0.01);  // Чуть меньше 1
        test_sqrt_approx("near_1+", 16'h3C01, 1.00049, 0.01); // Чуть больше 1
        test_sqrt_approx("max_norm", 16'h7BFF, 181.02, 2.0);  // Максимальное нормальное число
        
        // ============ POWERS OF 2 ============
        $display("\n--- Powers of 2 ---");
        test_sqrt_approx("2^1", 16'h4000, 1.41421, 0.01);
        test_sqrt_approx("2^2", 16'h4400, 2.0, 0.01);
        test_sqrt_approx("2^3", 16'h4800, 2.82843, 0.01);
        test_sqrt_approx("2^4", 16'h4C00, 4.0, 0.02);
        test_sqrt_approx("2^5", 16'h5000, 5.65685, 0.05);
        test_sqrt_approx("2^6", 16'h5400, 8.0, 0.05);
        test_sqrt_approx("2^7", 16'h5800, 11.3137, 0.1);
        test_sqrt_approx("2^8", 16'h5C00, 16.0, 0.1);
        test_sqrt_approx("2^9", 16'h6000, 22.6274, 0.2);
        test_sqrt_approx("2^10", 16'h6400, 32.0, 0.5);
        
        // ============ MIXED MANTISSA VALUES ============
        $display("\n--- Mixed Mantissa Values ---");
        test_sqrt_approx("1.1", 16'h3C66, 1.04881, 0.01);
        test_sqrt_approx("1.2", 16'h3CCD, 1.09545, 0.01);
        test_sqrt_approx("1.3", 16'h3D33, 1.14018, 0.01);
        test_sqrt_approx("1.4", 16'h3D99, 1.18322, 0.01);
        test_sqrt_approx("1.6", 16'h3E66, 1.26491, 0.01);
        test_sqrt_approx("1.7", 16'h3ECD, 1.30384, 0.01);
        test_sqrt_approx("1.8", 16'h3F33, 1.34164, 0.01);
        test_sqrt_approx("1.9", 16'h3F99, 1.37840, 0.01);
        
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

    // Задача для точных тестов (perfect squares, special values)
    task test_sqrt;
        input [255:0] name;
        input [15:0] input_val;
        input [15:0] expected_val;
        input expected_nan;
        input expected_pinf;
        input expected_ninf;
        
        real input_real, output_real, expected_real;
        integer cycles;
        
        begin
            test_num = test_num + 1;
            input_real = fp16_to_real(input_val);
            expected_real = fp16_to_real(expected_val);
            
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
                $display("Test %0d [%s] FAIL: Timeout after %0d cycles", test_num, name, cycles);
                errors = errors + 1;
            end else begin
                output_real = fp16_to_real(io_data);
                
                // Проверка результата и флагов
                if (io_data !== expected_val) begin
                    $display("Test %0d [%s] FAIL: Input=0x%04h Expected=0x%04h Got=0x%04h", 
                             test_num, name, input_val, expected_val, io_data);
                    errors = errors + 1;
                end else if (is_nan !== expected_nan || is_pinf !== expected_pinf || is_ninf !== expected_ninf) begin
                    $display("Test %0d [%s] FAIL: Wrong flags NaN=%b(exp:%b) +Inf=%b(exp:%b) -Inf=%b(exp:%b)", 
                             test_num, name, is_nan, expected_nan, is_pinf, expected_pinf, is_ninf, expected_ninf);
                    errors = errors + 1;
                end else begin
                    $display("Test %0d [%s] PASS: 0x%04h -> 0x%04h (%0d cycles)", 
                             test_num, name, input_val, io_data, cycles);
                end
            end
            
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
        end
    endtask

    // Задача для приблизительных тестов (non-perfect squares)
    task test_sqrt_approx;
        input [255:0] name;
        input [15:0] input_val;
        input real expected_real;
        input real tolerance;
        
        real input_real, output_real, error;
        integer cycles;
        
        begin
            test_num = test_num + 1;
            input_real = fp16_to_real(input_val);
            
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
                $display("Test %0d [%s] FAIL: Timeout after %0d cycles", test_num, name, cycles);
                errors = errors + 1;
            end else begin
                output_real = fp16_to_real(io_data);
                error = abs_real(output_real - expected_real);
                
                // Проверка результата
                if (error > tolerance) begin
                    $display("Test %0d [%s] FAIL: Input=0x%04h(%.6f) Expected=%.6f Got=%.6f Error=%.6f", 
                             test_num, name, input_val, input_real, expected_real, output_real, error);
                    errors = errors + 1;
                end 
                // Проверка флагов - для положительных результатов is_ninf всегда должен быть 0
                else if (is_nan || is_pinf || is_ninf) begin
                    $display("Test %0d [%s] FAIL: Unexpected special flags NaN=%b +Inf=%b -Inf=%b", 
                             test_num, name, is_nan, is_pinf, is_ninf);
                    errors = errors + 1;
                end else begin
                    $display("Test %0d [%s] PASS: 0x%04h(%.6f) -> %.6f (error=%.6f, %0d cycles)", 
                             test_num, name, input_val, input_real, output_real, error, cycles);
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