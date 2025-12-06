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

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg [31:0] errors;
    reg [31:0] test_count;

    initial begin
        $dumpfile("sqrt2_tb.vcd");
        $dumpvars(0, sqrt2_tb);
        
        errors = 0;
        test_count = 0;
        enable = 0;
        drive_input = 0;
        data_in = 16'h0000;
        
        repeat(3) @(posedge clk);
        
        $display("Starting tests...");
        
        test_sqrt(16'h7C00, 16'h7C00, 0, 1, 0);
        test_sqrt(16'hFC00, 16'hFE00, 1, 0, 0);
        test_sqrt(16'h7E00, 16'hFE00, 1, 0, 0);
        test_sqrt(16'h7D00, 16'hFE00, 1, 0, 0);
        test_sqrt(16'h0000, 16'h0000, 0, 0, 0);
        test_sqrt(16'h8000, 16'h8000, 0, 0, 0);
        
        test_sqrt(16'hBC00, 16'hFE00, 1, 0, 0);
        test_sqrt(16'hC400, 16'hFE00, 1, 0, 0);
        test_sqrt(16'hB800, 16'hFE00, 1, 0, 0);
        
        test_sqrt(16'h3400, 16'h3800, 0, 0, 0);
        test_sqrt(16'h3C00, 16'h3C00, 0, 0, 0);
        test_sqrt(16'h4400, 16'h4000, 0, 0, 0);
        test_sqrt(16'h4880, 16'h4200, 0, 0, 0);
        test_sqrt(16'h4C00, 16'h4400, 0, 0, 0);
        test_sqrt(16'h4E40, 16'h4500, 0, 0, 0);
        test_sqrt(16'h5080, 16'h4600, 0, 0, 0);
        test_sqrt(16'h5220, 16'h4700, 0, 0, 0);
        test_sqrt(16'h5400, 16'h4800, 0, 0, 0);
        test_sqrt(16'h5510, 16'h4880, 0, 0, 0);
        test_sqrt(16'h5640, 16'h4900, 0, 0, 0);
        
        test_sqrt(16'h2800, 16'h31A8, 0, 0, 0);
        test_sqrt(16'h3000, 16'h35A8, 0, 0, 0);
        test_sqrt(16'h3400, 16'h3800, 0, 0, 0);
        test_sqrt(16'h3800, 16'h39A8, 0, 0, 0);
        test_sqrt(16'h4000, 16'h3DA8, 0, 0, 0);
        test_sqrt(16'h4400, 16'h4000, 0, 0, 0);
        test_sqrt(16'h4800, 16'h41A8, 0, 0, 0);
        test_sqrt(16'h4C00, 16'h4400, 0, 0, 0);
        test_sqrt(16'h5000, 16'h45A8, 0, 0, 0);
        test_sqrt(16'h5400, 16'h4800, 0, 0, 0);
        test_sqrt(16'h5800, 16'h49A8, 0, 0, 0);
        test_sqrt(16'h5C00, 16'h4C00, 0, 0, 0);
        test_sqrt(16'h6000, 16'h4DA8, 0, 0, 0);
        test_sqrt(16'h6400, 16'h5000, 0, 0, 0);
        
        test_sqrt(16'h4200, 16'h3EED, 0, 0, 0);
        test_sqrt(16'h4500, 16'h4078, 0, 0, 0);
        test_sqrt(16'h4600, 16'h40E6, 0, 0, 0);
        test_sqrt(16'h4700, 16'h414A, 0, 0, 0);
        test_sqrt(16'h4900, 16'h4253, 0, 0, 0);
        test_sqrt(16'h4A00, 16'h42ED, 0, 0, 0);
        test_sqrt(16'h4B80, 16'h43BE, 0, 0, 0);
        test_sqrt(16'h4D00, 16'h4478, 0, 0, 0);
        
        test_sqrt(16'h2E66, 16'h350F, 0, 0, 0);
        test_sqrt(16'h3A00, 16'h3AED, 0, 0, 0);
        
        test_sqrt(16'h0400, 16'h2000, 0, 0, 0);
        test_sqrt(16'h0800, 16'h21A8, 0, 0, 0);
        test_sqrt(16'h0C00, 16'h2400, 0, 0, 0);
        test_sqrt(16'h1400, 16'h2800, 0, 0, 0);
        
        test_sqrt(16'h0001, 16'h0C00, 0, 0, 0);
        test_sqrt(16'h0002, 16'h0DA8, 0, 0, 0);
        test_sqrt(16'h0004, 16'h1000, 0, 0, 0);
        test_sqrt(16'h0008, 16'h11A8, 0, 0, 0);
        test_sqrt(16'h0010, 16'h1400, 0, 0, 0);
        test_sqrt(16'h0020, 16'h15A8, 0, 0, 0);
        test_sqrt(16'h0040, 16'h1800, 0, 0, 0);
        test_sqrt(16'h03FF, 16'h1FFE, 0, 0, 0);
        
        test_sqrt(16'h63E8, 16'h4FF3, 0, 0, 0);
        test_sqrt(16'h67D0, 16'h5197, 0, 0, 0);
        test_sqrt(16'h70E2, 16'h5640, 0, 0, 0);
        test_sqrt(16'h7BFF, 16'h5BFF, 0, 0, 0);
        
        $display("Tests completed: %0d passed, %0d failed", test_count - errors, errors);
        
        if (errors == 0) begin
            $finish;
        end else begin
            $fatal(2, "Tests failed");
        end
    end

    task test_sqrt;
        input [15:0] input_val;
        input [15:0] expected_val;
        input expected_nan;
        input expected_pinf;
        input expected_ninf;
        
        reg [31:0] cycles;
        
        begin
            test_count = test_count + 1;
            enable = 1;
            drive_input = 1;
            data_in = input_val;
            
            @(posedge clk);
            @(posedge clk);
            drive_input = 0;
            
            cycles = 0;
            while (!result && cycles < 100) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            
            if (!result) begin
                $display("FAIL: Test %0d timeout", test_count);
                errors = errors + 1;
            end else begin
                if (io_data !== expected_val || is_nan !== expected_nan || 
                    is_pinf !== expected_pinf || is_ninf !== expected_ninf) begin
                    $display("FAIL: Test %0d - in=%h out=%h exp=%h nan=%b/%b pinf=%b/%b ninf=%b/%b", 
                             test_count, input_val, io_data, expected_val, 
                             is_nan, expected_nan, is_pinf, expected_pinf, is_ninf, expected_ninf);
                    errors = errors + 1;
                end else begin
                    $display("PASS: Test %0d - in=%h out=%h nan=%b pinf=%b ninf=%b", 
                             test_count, input_val, io_data, is_nan, is_pinf, is_ninf);
                end
            end
            
            @(posedge clk);
            enable = 0;
            repeat(2) @(posedge clk);
        end
    endtask

    initial begin
        #500000;
        $fatal(2, "Simulation timeout");
    end

endmodule
