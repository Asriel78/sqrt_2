`timescale 1ns/1ps

module iterate (
    input  wire        clk,
    input  wire        enable,
    input  wire        n_valid,

    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,
    input  wire        is_num,

    input  wire        sign_in,
    input  wire [10:0] mant_in,
    input  wire signed [6:0] exp_in,

    output reg         it_valid,
    output reg         result,

    output reg         sign_out,
    output reg signed [6:0] exp_out,
    output reg [10:0]  mant_out,
    
    output reg         is_nan_out,
    output reg         is_pinf_out,
    output reg         is_ninf_out
);

    localparam ITER_MAX = 11;
    
    reg active;
    reg [3:0] iter_left;
    
    // Регистры для digit-by-digit алгоритма
    reg [33:0] radicand;
    reg [22:0] remainder;
    reg [11:0] root;
    
    // Регистры для запоминания special флагов
    reg is_special;
    reg stored_is_nan;
    reg stored_is_pinf;
    reg stored_is_ninf;

    // Комбинационная логика для trial
    wire [22:0] trial_comb;
    wire [22:0] remainder_next;
    wire [11:0] root_next;
    
    assign trial_comb = {root[10:0], 2'b01};
    assign remainder_next = {remainder[20:0], radicand[33:32]};
    assign root_next = (remainder_next >= trial_comb) ? {root[10:0], 1'b1} : {root[10:0], 1'b0};

    reg [11:0] work_mant;
    reg signed [6:0] work_exp;
    wire is_zero;
    
    assign is_zero = (exp_in == -7'sd15) && (mant_in == 11'd0);

    always @(posedge clk) begin
        if (!enable) begin
            active     <= 1'b0;
            it_valid   <= 1'b0;
            result     <= 1'b0;
            sign_out   <= 1'b0;
            exp_out    <= 7'sd0;
            mant_out   <= 11'd0;
            iter_left  <= 4'd0;
            radicand   <= 34'd0;
            remainder  <= 23'd0;
            root       <= 12'd0;
            is_special <= 1'b0;
            stored_is_nan  <= 1'b0;
            stored_is_pinf <= 1'b0;
            stored_is_ninf <= 1'b0;
            is_nan_out  <= 1'b0;
            is_pinf_out <= 1'b0;
            is_ninf_out <= 1'b0;
        end else begin
            it_valid <= 1'b0;
            result   <= 1'b0;

            if (n_valid && !active) begin
                // Случай 1: ±0 -> возвращаем ±0 сразу
                if (is_zero) begin
                    it_valid <= 1'b1;
                    result   <= 1'b1;
                    active   <= 1'b0;
                    is_special <= 1'b1;
                    
                    stored_is_nan  <= 1'b0;
                    stored_is_pinf <= 1'b0;
                    stored_is_ninf <= 1'b0;
                    
                    is_nan_out  <= 1'b0;
                    is_pinf_out <= 1'b0;
                    is_ninf_out <= 1'b0;
                    
                    sign_out <= sign_in;  // сохраняем знак
                    exp_out  <= -7'sd15;
                    mant_out <= 11'd0;
                end
                // Случай 2: Special случаи (NaN, Inf)
                else if (!is_num || is_nan_in || is_pinf_in || is_ninf_in) begin
                    it_valid <= 1'b1;
                    result   <= 1'b1;
                    active   <= 1'b0;
                    is_special <= 1'b1;
                    
                    // Временно сохраняем входные флаги
                    // (могут быть переопределены ниже для -Inf)
                    stored_is_nan  <= is_nan_in;
                    stored_is_pinf <= is_pinf_in;
                    stored_is_ninf <= is_ninf_in;
                    
                    is_nan_out  <= is_nan_in;
                    is_pinf_out <= is_pinf_in;
                    is_ninf_out <= is_ninf_in;
                    
                    if (is_nan_in) begin
                        // Входящий NaN -> тихий NaN с sign=1
                        sign_out <= 1'b1;
                        exp_out  <= 7'sd16;
                        mant_out <= 11'b10000000000;
                    end else if (is_pinf_in) begin
                        // +Inf -> +Inf
                        sign_out <= 1'b0;
                        exp_out  <= 7'sd16;
                        mant_out <= 11'd0;
                    end else if (is_ninf_in) begin
                        // -Inf -> NaN (меняем флаги!)
                        sign_out <= 1'b1;
                        exp_out  <= 7'sd16;
                        mant_out <= 11'b10000000000;
                        // Переопределяем флаги
                        stored_is_nan  <= 1'b1;
                        stored_is_pinf <= 1'b0;
                        stored_is_ninf <= 1'b0;
                        is_nan_out  <= 1'b1;
                        is_pinf_out <= 1'b0;
                        is_ninf_out <= 1'b0;
                    end else begin
                        // !is_num но не special -> NaN
                        sign_out <= 1'b1;
                        exp_out  <= 7'sd16;
                        mant_out <= 11'b10000000000;
                    end
                end 
                // Случай 3: Обычное число - начинаем итерации
                else begin
                    is_special <= 1'b0;
                    stored_is_nan  <= 1'b0;
                    stored_is_pinf <= 1'b0;
                    stored_is_ninf <= 1'b0;
                    is_nan_out  <= 1'b0;
                    is_pinf_out <= 1'b0;
                    is_ninf_out <= 1'b0;
                    
                    sign_out <= 1'b0;  // sqrt всегда положительный
                    
                    // Для нечетной экспоненты: сдвигаем мантиссу влево (умножаем на 2)
                    // чтобы получить четную экспоненту
                    if (exp_in[0]) begin
                        work_mant = {mant_in, 1'b0};  // mant * 2
                        work_exp  = exp_in - 7'sd1;   // exp - 1
                    end else begin
                        // Для четной экспоненты: используем мантиссу как есть
                        work_mant = mant_in;
                        work_exp  = exp_in;
                    end
                    
                    exp_out <= work_exp >>> 1;
                    
                    radicand  <= {work_mant, 22'd0};
                    remainder <= 23'd0;
                    root      <= 12'd0;
                    iter_left <= ITER_MAX;
                    active    <= 1'b1;
                end
            end
            
            // Итерационный процесс
            if (active) begin
                radicand <= {radicand[31:0], 2'b00};
                
                remainder <= (remainder_next >= trial_comb) ? 
                             (remainder_next - trial_comb) : 
                             remainder_next;
                root      <= root_next;
                
                it_valid <= 1'b1;
                
                // Выдаем флаги (для нормальных чисел все 0)
                is_nan_out  <= 1'b0;
                is_pinf_out <= 1'b0;
                is_ninf_out <= 1'b0;
                
                if (iter_left > 4'd1)
                    mant_out <= root_next[10:0] << (iter_left - 4'd1);
                else
                    mant_out <= root_next[10:0];
                
                if (iter_left == 4'd1) begin
                    result    <= 1'b1;
                    active    <= 1'b0;
                    iter_left <= 4'd0;
                end else begin
                    iter_left <= iter_left - 4'd1;
                end
            end
            
            // Если это был special случай, продолжаем выдавать флаги пока не сброс
            if (is_special && !active) begin
                is_nan_out  <= stored_is_nan;
                is_pinf_out <= stored_is_pinf;
                is_ninf_out <= stored_is_ninf;
            end
        end
    end

endmodule