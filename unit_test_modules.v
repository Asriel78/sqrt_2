`timescale 1ns/1ps

// ========================================
// TEST 1: Modul LOAD
// ========================================
module test_load;
    reg clk, enable;
    reg [15:0] data;
    wire sign;
    wire [4:0] exp;
    wire [9:0] mant;
    wire valid;
    
    load dut (
        .clk(clk),
        .enable(enable),
        .data(data),
        .sign(sign),
        .exp(exp),
        .mant(mant),
        .valid(valid)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $display("\n=== TEST LOAD ===");
        enable = 0;
        data = 0;
        
        repeat(3) @(posedge clk);
        
        // Test: 4.0 = 0_10001_0000000000
        data = 16'h4400;
        enable = 1;
        
        repeat(5) @(posedge clk) begin
            $display("Cycle: enable=%b | valid=%b | sign=%b | exp=%h | mant=%h",
                     enable, valid, sign, exp, mant);
        end
        
        if (valid && sign == 0 && exp == 5'h11 && mant == 10'h000) begin
            $display(">>> LOAD: PASS <<<\n");
        end else begin
            $display(">>> LOAD: FAIL <<<\n");
        end
        
        $finish;
    end
endmodule

// ========================================
// TEST 2: Modul SPECIAL
// ========================================
module test_special;
    reg clk, enable, valid;
    reg sign_in;
    reg [4:0] exp_in;
    reg [9:0] mant_in;
    wire s_valid;
    wire is_nan, is_pinf, is_ninf, is_normal, is_subnormal;
    wire sign_out;
    wire [4:0] exp_out;
    wire [9:0] mant_out;
    
    special dut (
        .clk(clk),
        .enable(enable),
        .valid(valid),
        .sign_in(sign_in),
        .exp_in(exp_in),
        .mant_in(mant_in),
        .s_valid(s_valid),
        .is_nan(is_nan),
        .is_pinf(is_pinf),
        .is_ninf(is_ninf),
        .is_normal(is_normal),
        .is_subnormal(is_subnormal),
        .sign_out(sign_out),
        .exp_out(exp_out),
        .mant_out(mant_out)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $display("\n=== TEST SPECIAL ===");
        enable = 0;
        valid = 0;
        sign_in = 0;
        exp_in = 0;
        mant_in = 0;
        
        repeat(3) @(posedge clk);
        enable = 1;
        
        // Test: normal number 4.0
        @(posedge clk);
        valid = 1;
        sign_in = 0;
        exp_in = 5'h11;  // 17
        mant_in = 10'h000;
        
        @(posedge clk);
        valid = 0;
        
        repeat(3) @(posedge clk) begin
            $display("Cycle: s_valid=%b | is_normal=%b | is_nan=%b | is_pinf=%b",
                     s_valid, is_normal, is_nan, is_pinf);
        end
        
        if (s_valid && is_normal && !is_nan) begin
            $display(">>> SPECIAL: PASS <<<\n");
        end else begin
            $display(">>> SPECIAL: FAIL <<<\n");
        end
        
        $finish;
    end
endmodule

// ========================================
// TEST 3: Modul NORMALIZE
// ========================================
module test_normalize;
    reg clk, enable, s_valid;
    reg sign_in;
    reg [4:0] exp_in;
    reg [9:0] mant_in;
    reg is_normal_in, is_subnormal_in, is_nan_in, is_pinf_in, is_ninf_in;
    wire n_valid;
    wire is_num, is_nan, is_pinf, is_ninf;
    wire sign_out;
    wire signed [6:0] exp_out;
    wire [10:0] mant_out;
    
    normalize dut (
        .clk(clk),
        .enable(enable),
        .s_valid(s_valid),
        .sign_in(sign_in),
        .exp_in(exp_in),
        .mant_in(mant_in),
        .is_normal_in(is_normal_in),
        .is_subnormal_in(is_subnormal_in),
        .is_nan_in(is_nan_in),
        .is_pinf_in(is_pinf_in),
        .is_ninf_in(is_ninf_in),
        .n_valid(n_valid),
        .is_num(is_num),
        .is_nan(is_nan),
        .is_pinf(is_pinf),
        .is_ninf(is_ninf),
        .sign_out(sign_out),
        .exp_out(exp_out),
        .mant_out(mant_out)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $display("\n=== TEST NORMALIZE ===");
        enable = 0;
        s_valid = 0;
        sign_in = 0;
        exp_in = 0;
        mant_in = 0;
        is_normal_in = 0;
        is_subnormal_in = 0;
        is_nan_in = 0;
        is_pinf_in = 0;
        is_ninf_in = 0;
        
        repeat(3) @(posedge clk);
        enable = 1;
        
        // Test: 4.0, exp=17, mant=0
        @(posedge clk);
        s_valid = 1;
        sign_in = 0;
        exp_in = 5'h11;  // 17
        mant_in = 10'h000;
        is_normal_in = 1;
        
        @(posedge clk);
        s_valid = 0;
        
        repeat(3) @(posedge clk) begin
            $display("Cycle: n_valid=%b | is_num=%b | exp_out=%d | mant_out=%h",
                     n_valid, is_num, exp_out, mant_out);
        end
        
        // 4.0: exp=17-15=2, mant=1.0000000000 (11 bits)
        if (n_valid && is_num && exp_out == 2 && mant_out == 11'h400) begin
            $display(">>> NORMALIZE: PASS <<<\n");
        end else begin
            $display(">>> NORMALIZE: FAIL <<<");
            $display("    Ozhidalos: exp_out=2, mant_out=400h\n");
        end
        
        $finish;
    end
endmodule

// ========================================
// TEST 4: Polnaya cep s monitoringom
// ========================================
module test_full_chain;
    reg clk, enable;
    reg [15:0] data_in;
    
    wire sign_l;
    wire [4:0] exp_l;
    wire [9:0] mant_l;
    wire valid_l;
    
    wire s_valid;
    wire is_normal_s, sign_s;
    wire [4:0] exp_s;
    wire [9:0] mant_s;
    
    wire n_valid;
    wire is_num_n, sign_n;
    wire signed [6:0] exp_n;
    wire [10:0] mant_n;
    
    load load_u (
        .clk(clk),
        .enable(enable),
        .data(data_in),
        .sign(sign_l),
        .exp(exp_l),
        .mant(mant_l),
        .valid(valid_l)
    );
    
    special special_u (
        .clk(clk),
        .enable(enable),
        .valid(valid_l),
        .sign_in(sign_l),
        .exp_in(exp_l),
        .mant_in(mant_l),
        .s_valid(s_valid),
        .is_nan(),
        .is_pinf(),
        .is_ninf(),
        .is_normal(is_normal_s),
        .is_subnormal(),
        .sign_out(sign_s),
        .exp_out(exp_s),
        .mant_out(mant_s)
    );
    
    normalize normalize_u (
        .clk(clk),
        .enable(enable),
        .s_valid(s_valid),
        .sign_in(sign_s),
        .exp_in(exp_s),
        .mant_in(mant_s),
        .is_normal_in(is_normal_s),
        .is_subnormal_in(1'b0),
        .is_nan_in(1'b0),
        .is_pinf_in(1'b0),
        .is_ninf_in(1'b0),
        .n_valid(n_valid),
        .is_num(is_num_n),
        .is_nan(),
        .is_pinf(),
        .is_ninf(),
        .sign_out(sign_n),
        .exp_out(exp_n),
        .mant_out(mant_n)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    integer cycle;
    
    initial begin
        $display("\n=== TEST POLNAYA CEP (load->special->normalize) ===");
        $display("Input: 4.0 = 16'h4400\n");
        
        enable = 0;
        data_in = 0;
        cycle = 0;
        
        repeat(3) @(posedge clk);
        enable = 1;
        data_in = 16'h4400;  // 4.0
        
        repeat(10) @(posedge clk) begin
            cycle = cycle + 1;
            $display("Cycle %2d: valid_l=%b | s_valid=%b | n_valid=%b", 
                     cycle, valid_l, s_valid, n_valid);
            if (n_valid) begin
                $display("         NORMALIZE OUTPUT: is_num=%b | sign=%b | exp=%d | mant=%h",
                         is_num_n, sign_n, exp_n, mant_n);
            end
        end
        
        $display("\nOzhidaemyy rezultat posle normalize:");
        $display("  is_num=1, sign=0, exp=2, mant=11'h400 (1.0 * 2^2 = 4.0)");
        $display("\nEsli n_valid ne poyavilsya - problema v cepi validov!\n");
        
        $finish;
    end
endmodule