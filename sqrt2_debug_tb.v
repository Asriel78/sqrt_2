`timescale 1ns / 1ps

module sqrt2_debug_tb;
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

    integer cycle_count;
    
    initial begin
        $dumpfile("sqrt2_debug.vcd");
        $dumpvars(0, sqrt2_debug_tb);
        
        // Monitoring vseh signalov
        $display("\n================================================");
        $display("OTLADKA: Monitoring vseh valid signalov");
        $display("================================================\n");
        
        enable = 0;
        drive_input = 0;
        io_data_in = 0;
        cycle_count = 0;
        
        // Sbros
        repeat(3) @(posedge clk);
        
        $display("--- SBROS ZAVERSHEN ---\n");
        
        // Test 1: Prostoy test sqrt(4.0) = 2.0
        $display("\n=== TEST: sqrt(4.0) = 2.0 ===");
        $display("Vhod: 16'h4400 (4.0)\n");
        
        // VAZHNO: dannye dolzhny byt na shine DO enable=1
        $display(">>> Ustanavlivaem dannye na IO_DATA <<<");
        drive_input = 1;
        io_data_in = 16'h4400;  // 4.0
        
        @(posedge clk);
        $display(">>> Perevodim ENABLE v 1 <<<");
        enable = 1;
        
        @(posedge clk);
        $display(">>> Otpuskaem IO_DATA <<<");
        drive_input = 0;
        cycle_count = 0;
        
        // Monitor 20 taktov
        repeat(20) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
            
            $display("Cycle %2d: ENABLE=%b | l_valid=%b | s_valid=%b | n_valid=%b | it_valid=%b | p_valid=%b | RESULT=%b", 
                     cycle_count, enable,
                     uut.l_valid,
                     uut.s_valid, 
                     uut.n_valid,
                     uut.it_valid,
                     uut.p_valid,
                     result);
            
            $display("          IO_DATA=%h | IS_NAN=%b | IS_PINF=%b | IS_NINF=%b",
                     io_data, is_nan, is_pinf, is_ninf);
            
            // Pokazyvaem vnutrennie sostoyania iterate
            $display("          iterate: active=%b | iter_left=%d | root=%h | mant_out=%h",
                     uut.iter_u.active,
                     uut.iter_u.iter_left,
                     uut.iter_u.root_reg,
                     uut.iter_u.mant_out);
            
            // Pokazyvaem sostoyanie pack
            $display("          pack: drive_en=%b | drive_data=%h | result_reg=%b",
                     uut.drive_en,
                     uut.drive_data,
                     uut.result_reg);
            
            $display("");
            
            if (result) begin
                $display(">>> RESULT=1 obnaruzhen na cikle %d <<<\n", cycle_count);
            end
        end
        
        $display("\n=== ANALIZ VALIDOV ===");
        $display("Esli kakie-to valid ne poyavilis - problema v tom module");
        $display("Esli valid est, no dannye ne peredayutsya - problema v logike");
        
        $display("\n--- Konec otladki ---\n");
        $finish;
    end

    // Timeout
    initial begin
        #10000;
        $display("\n!!! TAIMAUT !!!");
        $finish;
    end

endmodule