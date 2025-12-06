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

    // Управление bidirectional шиной
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
                // Special: NaN or Inf
                if (mant != 0)
                    fp16_to_real = 0.0/0.0; // NaN
                else
                    fp16_to_real = sign ? -1.0/0.0 : 1.0/0.0; // ±Inf
            end else if (exp == 5'b00000) begin
                // Subnormal or zero
                if (mant == 0) begin
                    fp16_to_real = sign ? -0.0 : 0.0;
                end else begin
                    e_unbiased = -14;
                    value = mant / 1024.0; // без implicit 1
                    value = value * (2.0 ** e_unbiased);
                    fp16_to_real = sign ? -value : value;
                end
            end else begin
                // Normal
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
        $display("  SQRT2 FULL SYSTEM TESTBENCH");
        $display("========================================\n");
        
        // Начальный сброс
        repeat(3) @(posedge clk);
        
        // ============ ТЕСТЫ SPECIAL СЛУЧАЕВ ============
        $display("--- Special Cases ---");
        test_sqrt("+Inf", 16'h7C00, 16'h7C00, 0, 1, 0);
        test_sqrt("-Inf", 16'hFC00, 16'hFE00, 1, 0, 0);
        test_sqrt("NaN", 16'h7E00, 16'hFE00, 1, 0, 0);
        test_sqrt("sNaN", 16'h7D00, 16'hFE00, 1, 0, 0);
        test_sqrt("+0", 16'h0000, 16'h0000, 0, 0, 0);
        test_sqrt("-0", 16'h8000, 16'h8000, 0, 0, 0);
        
        // ============ ТЕСТЫ ОТРИЦАТЕЛЬНЫХ ЧИСЕЛ ============
        $display("\n--- Negative Numbers ---");
        test_sqrt("-1.0", 16'hBC00, 16'hFE00, 1, 0, 0);
        test_sqrt("-4.0", 16'hC400, 16'hFE00, 1, 0, 0);
        
        // ============ ТЕСТЫ PERFECT SQUARES ============
        $display("\n--- Perfect Squares ---");
        test_sqrt("1.0", 16'h3C00, 16'h3C00, 0, 0, 0);
        test_sqrt("4.0", 16'h4400, 16'h4000, 0, 0, 0);
        test_sqrt("9.0", 16'h4880, 16'h4200, 0, 0, 0);
        test_sqrt("16.0", 16'h4C00, 16'h4400, 0, 0, 0);
        test_sqrt("25.0", 16'h4E40, 16'h4500, 0, 0, 0);
        test_sqrt("0.25", 16'h3400, 16'h3800, 0, 0, 0);
        
        // ============ ТЕСТЫ НЕ-PERFECT SQUARES ============
        $display("\n--- Non-Perfect Squares ---");
        test_sqrt_approx("2.0", 16'h4000, 1.41421, 0.01);
        test_sqrt_approx("3.0", 16'h4200, 1.73205, 0.01);
        test_sqrt_approx("5.0", 16'h4500, 2.23607, 0.01);
        test_sqrt_approx("6.0", 16'h4600, 2.44949, 0.01);
        test_sqrt_approx("7.0", 16'h4700, 2.64575, 0.01);
        test_sqrt_approx("10.0", 16'h4900, 3.16228, 0.01);
        
        // ============ ТЕСТЫ МАЛЫХ ЧИСЕЛ ============
        $display("\n--- Small Numbers ---");
        test_sqrt_approx("0.5", 16'h3800, 0.70711, 0.01);
        test_sqrt_approx("0.0625", 16'h2800, 0.25, 0.01);
        
        // ============ ТЕСТЫ SUBNORMAL ============
        $display("\n--- Subnormal Numbers ---");
        test_sqrt_approx("subnormal_min", 16'h0001, 0.000183, 0.0001);
        test_sqrt_approx("subnormal", 16'h0100, 0.00195, 0.001);
        
        // ============ ТЕСТЫ БОЛЬШИХ ЧИСЕЛ ============
        $display("\n--- Large Numbers ---");
        test_sqrt_approx("100.0", 16'h5640, 10.0, 0.1);
        test_sqrt_approx("1024.0", 16'h6400, 32.0, 0.5);
        
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
            
            // Подаем данные
            enable = 1;
            drive_input = 1;
            data_in = input_val;
            
            @(posedge clk);
            // Держим данные еще один такт, чтобы load успел прочитать
            
            @(posedge clk);
            drive_input = 0; // Теперь отпускаем шину
            
            // Ждем RESULT=1 (не проверяем промежуточные значения)
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
                
                // Проверка результата
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
            
            // Сброс
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
            
            // Подаем данные
            enable = 1;
            drive_input = 1;
            data_in = input_val;
            
            @(posedge clk);
            // Держим данные еще один такт
            
            @(posedge clk);
            drive_input = 0;
            
            // Ждем RESULT=1 (не проверяем промежуточные значения)
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
                
                if (error > tolerance) begin
                    $display("Test %0d [%s] FAIL: Input=0x%04h Expected=%.6f Got=%.6f Error=%.6f", 
                             test_num, name, input_val, expected_real, output_real, error);
                    errors = errors + 1;
                end else if (is_nan || is_pinf || is_ninf) begin
                    $display("Test %0d [%s] FAIL: Unexpected special flags", test_num, name);
                    errors = errors + 1;
                end else begin
                    $display("Test %0d [%s] PASS: 0x%04h -> %.6f (error=%.6f, %0d cycles)", 
                             test_num, name, input_val, output_real, error, cycles);
                end
            end
            
            // Сброс
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
