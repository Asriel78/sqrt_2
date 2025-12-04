`timescale 1ns/1ps
module iterate (
    input  wire        clk,
    input  wire        enable,
    input  wire        n_valid,

    input  wire        sign_in,        // ДОБАВЛЕНО - нужен знак из normalize
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

    localparam ROOT_BITS      = 11;
    localparam ITER_MAX       = ROOT_BITS;
    localparam WORK_MANT_BITS = ROOT_BITS + 1;
    localparam RAD_BITS       = WORK_MANT_BITS + 2*ITER_MAX;
    localparam REM_BITS       = ROOT_BITS + 4;

    reg [RAD_BITS-1:0]        rad_reg = 0;
    reg [REM_BITS-1:0]        rem_reg = 0;
    reg [ROOT_BITS-1:0]       root_reg = 0;
    reg [WORK_MANT_BITS-1:0]  work_mant = 0;
    reg signed [6:0]          work_exp = 0;
    reg [4:0]                 iter_left = 0;
    reg                       active = 0;
    
    // Для хранения знака
    reg                       stored_sign = 0;

    reg [1:0]                top2;
    reg [REM_BITS-1:0]       rem_calc;
    reg [REM_BITS-1:0]       trial_val;
    reg [ROOT_BITS+1:0]      trial_root;
    reg [ROOT_BITS-1:0]      new_root;

    always @(posedge clk) begin
        if (!enable) begin
            active     <= 1'b0;
            iter_left  <= 0;
            rad_reg    <= 0;
            rem_reg    <= 0;
            root_reg   <= 0;
            work_mant  <= 0;
            work_exp   <= 0;
            sign_out   <= 1'b0;
            exp_out    <= 7'sd0;
            mant_out   <= 11'b0;
            it_valid   <= 1'b0;
            result     <= 1'b0;
            stored_sign <= 1'b0;
        end
        else begin
            it_valid <= 1'b0;
            
            // Начало новых вычислений
            if (!active && n_valid) begin
                stored_sign <= sign_in;  // Сохраняем знак
                
                // Обработка особых случаев
                if (is_nan_in) begin
                    sign_out <= 1'b1;
                    exp_out  <= 7'sd16;
                    mant_out <= 11'b10000000000;
                    it_valid <= 1'b1;
                    result   <= 1'b1;
                    active   <= 1'b0;
                end
                else if (is_pinf_in) begin
                    sign_out <= 1'b0;
                    exp_out  <= 7'sd16;
                    mant_out <= 11'b0;
                    it_valid <= 1'b1;
                    result   <= 1'b1;
                    active   <= 1'b0;
                end
                else if (is_ninf_in) begin
                    sign_out <= 1'b1;
                    exp_out  <= 7'sd16;
                    mant_out <= 11'b10000000000;
                    it_valid <= 1'b1;
                    result   <= 1'b1;
                    active   <= 1'b0;
                end
                else if (!is_num) begin  // Ноль
                    sign_out <= sign_in;  // Используем входной знак
                    exp_out  <= -7'sd15;
                    mant_out <= 11'b0;
                    it_valid <= 1'b1;
                    result   <= 1'b1;
                    active   <= 1'b0;
                end
                else begin
                    // Нормальное число - начинаем итерации
                    sign_out <= 1'b0;  // sqrt всегда положительный
                    
                    // Выравнивание экспоненты (должна быть четной)
                    if (exp_in[0] == 1'b1) begin
                        work_mant <= {mant_in, 1'b0};
                        work_exp  <= exp_in - 1;
                    end else begin
                        work_mant <= {1'b0, mant_in};
                        work_exp  <= exp_in;
                    end
                    
                    // ИСПРАВЛЕНО: Инициализация радиканда должна использовать
                    // значение work_mant, но оно еще не обновилось!
                    // Нужно использовать комбинационную логику
                    if (exp_in[0] == 1'b1) begin
                        rad_reg <= {{mant_in, 1'b0}, {(2*ITER_MAX){1'b0}}};
                    end else begin
                        rad_reg <= {{1'b0, mant_in}, {(2*ITER_MAX){1'b0}}};
                    end
                    
                    rem_reg    <= 0;
                    root_reg   <= 0;
                    iter_left  <= ITER_MAX;
                    active     <= 1'b1;
                    
                    // ИСПРАВЛЕНО: Экспонента тоже комбинационно
                    if (exp_in[0] == 1'b1) begin
                        exp_out <= (exp_in - 1) >>> 1;
                    end else begin
                        exp_out <= exp_in >>> 1;
                    end
                end
            end
            
            // Выполнение итераций
            else if (active && (iter_left != 0)) begin
                // Digit-by-digit restoring square root
                top2 = rad_reg[RAD_BITS-1 -: 2];
                rem_calc = (rem_reg << 2) | {{(REM_BITS-2){1'b0}}, top2};
                
                // ИСПРАВЛЕНО: trial_root формируется как (root << 1) | 1
                trial_root = ({2'b00, root_reg} << 1) | {{(ROOT_BITS+1){1'b0}}, 1'b1};
                trial_val  = {{(REM_BITS - (ROOT_BITS+2)){1'b0}}, trial_root};
                
                if (rem_calc >= trial_val) begin
                    rem_reg  <= rem_calc - trial_val;
                    new_root = (root_reg << 1) | 1'b1;
                end else begin
                    rem_reg  <= rem_calc;
                    new_root = (root_reg << 1);
                end
                
                rad_reg  <= rad_reg << 2;
                root_reg <= new_root;
                
                // ИСПРАВЛЕНО: выравниваем биты корня слева (MSB)
                // Сдвигаем влево на количество оставшихся итераций
                mant_out <= new_root << (iter_left - 1);
                
                it_valid <= 1'b1;
                iter_left <= iter_left - 1;
                
                // На последней итерации устанавливаем result
                if (iter_left == 1) begin
                    result <= 1'b1;
                    active <= 1'b0;
                end
            end
            // ВАЖНО: result остается = 1 после завершения
        end
    end

endmodule