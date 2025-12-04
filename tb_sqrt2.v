`timescale 1ns / 1ps

module sqrt2_tb;
    reg clk;
    reg enable;
    wire [15:0] io_data;
    reg [15:0] io_data_in;
    reg drive_input;
    
    wire is_nan;
    wire is_pinf;
    wire is_ninf;
    wire result;

    assign io_data = drive_input ? io_data_in : 16'hzzzz;

    sqrt2 uut (
        .IO_DATA(io_data),
        .IS_NAN(is_nan),
        .IS_PINF(is_pinf),
        .IS_NINF(is_ninf),
        .RESULT(result),
        .CLK(clk),
        .ENABLE(enable)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function [15:0] make_fp16;
        input sign;
        input [4:0] exp;
        input [9:0] frac;
        begin
            make_fp16 = {sign, exp, frac};
        end
    endfunction

    function real fp16_to_real;
        input [15:0] val;
        reg s;
        reg [4:0] e;
        reg [9:0] f;
        real mantissa;
        integer exp_val;
        begin
            s = val[15];
            e = val[14:10];
            f = val[9:0];
            
            if (e == 5'b11111 && f != 0) begin
                fp16_to_real = 0.0/0.0;
            end else if (e == 5'b11111 && f == 0) begin
                fp16_to_real = s ? -1.0/0.0 : 1.0/0.0;
            end else if (e == 0 && f == 0) begin
                fp16_to_real = 0.0;
            end else if (e == 0) begin
                mantissa = f / 1024.0;
                exp_val = -14;
                fp16_to_real = mantissa * (2.0 ** exp_val);
                if (s) fp16_to_real = -fp16_to_real;
            end else begin
                mantissa = 1.0 + (f / 1024.0);
                exp_val = e - 15;
                fp16_to_real = mantissa * (2.0 ** exp_val);
                if (s) fp16_to_real = -fp16_to_real;
            end
        end
    endfunction

    integer errors;
    integer test_num;
    
    initial begin
        $dumpfile("sqrt2_tb.vcd");
        $dumpvars(0, sqrt2_tb);
        
        errors = 0;
        test_num = 0;
        enable = 0;
        drive_input = 0;
        io_data_in = 0;
        
        repeat(5) @(posedge clk);
        enable = 1;
        repeat(2) @(posedge clk);

        $display("\n========================================");
        $display("   Testirovanie modulya sqrt2");
        $display("========================================\n");

        $display("=== Test 1: Osobye sluchai ===");
        test_case("NaN", 16'h7C01, 16'h7C01, 1'b1, 1'b0, 1'b0);
        test_case("+Inf", 16'h7C00, 16'h7C00, 1'b0, 1'b1, 1'b0);
        test_case("-Inf -> NaN", 16'hFC00, 16'hFC01, 1'b1, 1'b0, 1'b0);
        test_case("+0", 16'h0000, 16'h0000, 1'b0, 1'b0, 1'b0);
        test_case("-0", 16'h8000, 16'h8000, 1'b0, 1'b0, 1'b0);

        $display("\n=== Test 2: Stepeni dvoyki ===");
        test_case("sqrt(1.0) = 1.0", 16'h3C00, 16'h3C00, 1'b0, 1'b0, 1'b0);
        test_case("sqrt(4.0) = 2.0", 16'h4400, 16'h4000, 1'b0, 1'b0, 1'b0);
        test_case("sqrt(16.0) = 4.0", 16'h4C00, 16'h4400, 1'b0, 1'b0, 1'b0);
        test_case("sqrt(0.25) = 0.5", 16'h3400, 16'h3800, 1'b0, 1'b0, 1'b0);

        $display("\n=== Test 3: Netrivialnye znacheniya ===");
        test_case_approx("sqrt(2.0)", 16'h4000, 1.414, 0.01);
        test_case_approx("sqrt(3.0)", 16'h4200, 1.732, 0.01);
        test_case_approx("sqrt(0.5)", 16'h3800, 0.707, 0.01);

        $display("\n=== Test 4: Otricatelnye chisla ===");
        test_case("sqrt(-1.0) -> NaN", 16'hBC00, 16'hFC01, 1'b1, 1'b0, 1'b0);
        test_case("sqrt(-4.0) -> NaN", 16'hC400, 16'hFC01, 1'b1, 1'b0, 1'b0);

        $display("\n========================================");
        if (errors == 0) begin
            $display("   VSE TESTY PROYDENY (%0d/%0d)", test_num, test_num);
            $display("========================================\n");
            $finish;
        end else begin
            $display("   OSHIBOK: %0d/%0d", errors, test_num);
            $display("========================================\n");
            $fatal(2, "Testy provaleny");
        end
    end

    task test_case;
        input [255:0] test_name;
        input [15:0] input_val;
        input [15:0] expected;
        input exp_nan;
        input exp_pinf;
        input exp_ninf;
        
        reg [15:0] result_val;
        integer cycles;
        
        begin
            test_num = test_num + 1;
            $display("\nTest %0d: %s", test_num, test_name);
            $display("  Vhod:  %h (%.6f)", input_val, fp16_to_real(input_val));
            
            @(posedge clk);
            drive_input = 1;
            io_data_in = input_val;
            @(posedge clk);
            drive_input = 0;
            
            cycles = 0;
            while (!result && cycles < 30) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            
            if (!result) begin
                $display("  FAIL: Taimaut (net RESULT posle %0d taktov)", cycles);
                errors = errors + 1;
            end else begin
                result_val = io_data;
                $display("  Rezultat: %h (%.6f) [%0d taktov]", 
                         result_val, fp16_to_real(result_val), cycles);
                $display("  Ozhidalos: %h (%.6f)", expected, fp16_to_real(expected));
                
                if (result_val === expected && 
                    is_nan === exp_nan && 
                    is_pinf === exp_pinf && 
                    is_ninf === exp_ninf) begin
                    $display("  PASS");
                end else begin
                    $display("  FAIL");
                    if (result_val !== expected)
                        $display("    Znachenie ne sovpadaet");
                    if (is_nan !== exp_nan)
                        $display("    IS_NAN: polucheno %b, ozhidalos %b", is_nan, exp_nan);
                    if (is_pinf !== exp_pinf)
                        $display("    IS_PINF: polucheno %b, ozhidalos %b", is_pinf, exp_pinf);
                    if (is_ninf !== exp_ninf)
                        $display("    IS_NINF: polucheno %b, ozhidalos %b", is_ninf, exp_ninf);
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

    task test_case_approx;
        input [255:0] test_name;
        input [15:0] input_val;
        input real expected_real;
        input real tolerance;
        
        reg [15:0] result_val;
        real result_real;
        real error;
        integer cycles;
        
        begin
            test_num = test_num + 1;
            $display("\nTest %0d: %s", test_num, test_name);
            $display("  Vhod:  %h (%.6f)", input_val, fp16_to_real(input_val));
            
            // VAZHNO: dannye dolzhny byt na shine DO enable 0->1
            drive_input = 1;
            io_data_in = input_val;
            
            @(posedge clk);
            enable = 1;
            
            @(posedge clk);
            drive_input = 0;
            
            cycles = 0;
            while (!result && cycles < 30) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            
            if (!result) begin
                $display("  FAIL: Taimaut");
                errors = errors + 1;
            end else begin
                result_val = io_data;
                result_real = fp16_to_real(result_val);
                error = result_real - expected_real;
                if (error < 0) error = -error;
                
                $display("  Rezultat: %h (%.6f) [%0d taktov]", 
                         result_val, result_real, cycles);
                $display("  Ozhidalos: %.6f +/- %.6f", expected_real, tolerance);
                
                if (error <= tolerance) begin
                    $display("  PASS (oshibka: %.6f)", error);
                end else begin
                    $display("  FAIL (oshibka: %.6f > %.6f)", error, tolerance);
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
        #50000;
        $display("\n!!! GLOBALNYY TAIMAUT !!!");
        $fatal(2, "Taimaut simulyacii");
    end

endmodule