`ifdef BEHAVIOUR
`include "sqrt2_b.sv"
`elsif STRUCTURAL
`include "sqrt2_s.sv"
`else
`error "!mode"
`endif


module sqrt2_tb;

    reg CLK;
    reg ENABLE;
    reg [15:0] data_in;
    wire [15:0] IO_DATA;
    wire IS_NAN;
    wire IS_PINF;
    wire IS_NINF;
    wire RESULT;
    
    integer failed;
    
    reg drive_input;
    assign IO_DATA = drive_input ? data_in : 16'hzzzz;
    
    sqrt2 dut (
        .IO_DATA(IO_DATA),
        .IS_NAN(IS_NAN),
        .IS_PINF(IS_PINF),
        .IS_NINF(IS_NINF),
        .RESULT(RESULT),
        .CLK(CLK),
        .ENABLE(ENABLE)
    );
    
    initial begin
        CLK = 0;
        failed = 0;
        ENABLE = 0;
        drive_input = 0;
        data_in = 16'h0000;

        test_sqrt(16'h7C00, 16'h7C00, 0, 1, 0);  // +inf
        test_sqrt(16'hFC00, 16'hFE00, 1, 0, 0);  // NaN
        test_sqrt(16'h7E00, 16'hFE00, 1, 0, 0);  // NaN
        test_sqrt(16'h7D00, 16'hFE00, 1, 0, 0);  // NaN
        test_sqrt(16'h0000, 16'h0000, 0, 0, 0);  // +0
        test_sqrt(16'h8000, 16'h8000, 0, 0, 0);  // -0

        test_sqrt(16'hBC00, 16'hFE00, 1, 0, 0);  // -NaN / negative
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

        #2;
        
        if (failed) begin
            $fatal(2, "!all passed");
        end
        $finish(2);
    end

    always #1 CLK = ~CLK;

    task test_sqrt;
        input [15:0] input_val;
        input [15:0] expected_val;
        input expected_nan;
        input expected_pinf;
        input expected_ninf;
        
        integer cycles;
        
        begin
            ENABLE = 1;
            drive_input = 1;
            data_in = input_val;
            
            @(posedge CLK);
            @(posedge CLK);
            drive_input = 0;
            
            cycles = 0;
            while (!RESULT && cycles < 100) begin
                @(posedge CLK);
                cycles = cycles + 1;
            end
            
            if (!RESULT) begin
                $display("FAIL: timeout for input %h", input_val);
                failed = 1;
            end else begin
                if (IO_DATA !== expected_val || IS_NAN !== expected_nan || 
                    IS_PINF !== expected_pinf || IS_NINF !== expected_ninf) begin
                    $display("FAIL: in=%h out=%h exp=%h nan=%b/%b pinf=%b/%b ninf=%b/%b", 
                             input_val, IO_DATA, expected_val, 
                             IS_NAN, expected_nan, IS_PINF, expected_pinf, IS_NINF, expected_ninf);
                    failed = 1;
                end
            end
            
            @(posedge CLK);
            ENABLE = 0;
            @(posedge CLK);
            @(posedge CLK);
        end
    endtask

    initial begin
        #500000; 
        $fatal(2, "Simulation timeout");
    end

endmodule