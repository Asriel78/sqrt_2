

`timescale 1ns/1ps

module iterate (
    input  wire        clk,
    input  wire        enable,
    input  wire        n_valid,

    input  wire        is_nan_in,
    input  wire        is_pinf_in,
    input  wire        is_ninf_in,
    input  wire        is_num,

    input  wire [10:0] mant_in,
    input  wire signed [6:0] exp_in,

    output reg         it_valid,
    output reg         result,

    output reg         sign_out,
    output reg signed [6:0] exp_out,
    output reg [10:0]  mant_out
);

    localparam ITER_MAX = 11;
    
    // Внутренние регистры для алгоритма
    reg active;
    reg [3:0] iter_left;
    
    // Регистры для digit-by-digit алгоритма
    reg [33:0] radicand;
    reg [22:0] remainder;
    reg [11:0] root;

    // Комбинационная логика для trial
    wire [22:0] trial_comb;
    wire [22:0] remainder_next;
    wire [11:0] root_next;
    
    assign trial_comb = {root[10:0], 2'b01};  // (root << 1) | 1
    assign remainder_next = {remainder[20:0], radicand[33:32]};
    assign root_next = (remainder_next >= trial_comb) ? {root[10:0], 1'b1} : {root[10:0], 1'b0};

    // Локальные переменные для инициализации
    reg [11:0] work_mant;
    reg signed [6:0] work_exp;

    always @(posedge clk) begin
        if (!enable) begin
            // Полный сброс
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
        end else begin
            // По умолчанию
            it_valid <= 1'b0;
            result   <= 1'b0;

            // Запуск нового вычисления
            if (n_valid && !active) begin
                // Обработка special случаев - выдача за 1 такт
                if (!is_num || is_nan_in || is_pinf_in || is_ninf_in) begin
                    // Special случай
                    it_valid <= 1'b1;
                    result   <= 1'b1;
                    active   <= 1'b0;
                    
                    if (is_nan_in) begin
                        // NaN: sign=1, exp=16 (внутреннее представление), quiet bit
                        sign_out <= 1'b1;
                        exp_out  <= 7'sd16;  // 31 - 15 = 16 в unbiased
                        mant_out <= 11'b10000000000;  // quiet bit на позиции 10
                    end else if (is_pinf_in) begin
                        // +Inf
                        sign_out <= 1'b0;
                        exp_out  <= 7'sd16;
                        mant_out <= 11'd0;
                    end else if (is_ninf_in) begin
                        // -Inf -> NaN (sqrt из отрицательного)
                        sign_out <= 1'b1;
                        exp_out  <= 7'sd16;
                        mant_out <= 11'b10000000000;
                    end else begin
                        // is_num=0 но не special - тоже NaN
                        sign_out <= 1'b1;
                        exp_out  <= 7'sd16;
                        mant_out <= 11'b10000000000;
                    end
                end else begin
                    // Начинаем итерационное вычисление
                    sign_out <= 1'b0;  // sqrt всегда положительный
                    
                    // Проверка четности экспоненты
                    if (exp_in[0]) begin
                        // Нечетная экспонента - сдвигаем мантиссу влево
                        work_mant = {mant_in, 1'b0};  // mant_in << 1
                        work_exp  = exp_in - 7'sd1;
                    end else begin
                        // Четная экспонента
                        work_mant = {1'b0, mant_in};
                        work_exp  = exp_in;
                    end
                    
                    // Экспонента результата = exp/2
                    exp_out <= work_exp >>> 1;  // арифметический сдвиг вправо
                    
                    // Инициализация для алгоритма
                    radicand  <= {work_mant, 22'd0};  // work_mant << 22
                    remainder <= 23'd0;
                    root      <= 12'd0;
                    iter_left <= ITER_MAX;
                    active    <= 1'b1;
                end
            end
            
            // Итерационный процесс
            if (active) begin
                // Обновляем radicand (сдвиг на 2 бита влево)
                radicand <= {radicand[31:0], 2'b00};
                
                // Обновляем remainder и root используя комбинационную логику
                remainder <= (remainder_next >= trial_comb) ? 
                             (remainder_next - trial_comb) : 
                             remainder_next;
                root      <= root_next;
                
                // Выдаем промежуточный результат
                it_valid <= 1'b1;
                
                // Формируем выходную мантиссу (текущая оценка sqrt)
                if (iter_left > 4'd1)
                    mant_out <= root_next[10:0] << (iter_left - 4'd1);
                else
                    mant_out <= root_next[10:0];
                
                // Проверяем завершение
                if (iter_left == 4'd1) begin
                    result    <= 1'b1;
                    active    <= 1'b0;
                    iter_left <= 4'd0;
                end else begin
                    iter_left <= iter_left - 4'd1;
                end
            end
        end
    end

endmodule
