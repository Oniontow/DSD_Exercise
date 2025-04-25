module GSIM ( clk, reset, in_en, b_in, out_valid, x_out);
    input   clk ;
    input   reset ;
    input   in_en;
    output  out_valid;
    input   [15:0]  b_in;
    output  [31:0]  x_out;

    integer i;
    localparam N = 16;
    localparam MAX_ITER = 279;

    localparam IDLE = 2'd0, INPUT = 2'd1, COMPUTE = 2'd2, OUTPUT = 2'd3;

    // 44 bit reg，小數點 at bit 20
    reg signed [15:0] b_reg [1:N+4];
    reg signed [37:0] x_reg [1:N+4];
    reg x_valid [1:N+4];
    wire [37:0] computed_result [1:5];
    wire [37:0] partial_sum_1 [1:5];
    wire [37:0] partial_sum_2 [1:5];
    wire [37:0] partial_sum_3 [1:5];
    reg [31:0] x_out_reg;
    reg [1:0] state, next_state;
    reg out_valid_reg;
    reg [8:0] iter_count;
    

    assign x_out = x_out_reg;
    assign out_valid = out_valid_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case(state)
            IDLE:    next_state = in_en ? INPUT : IDLE;
            INPUT:   next_state = !in_en ? COMPUTE : INPUT;
            COMPUTE: next_state = (iter_count >= MAX_ITER) ? OUTPUT : COMPUTE;
            OUTPUT:  next_state = OUTPUT;
            default: next_state = IDLE;
        endcase
    end
    assign partial_sum_1[1] = {{8{b_reg[1][15]}}, b_reg[1], 19'b0} + x_reg[18] + x_reg[4];
    assign partial_sum_2[1] = -mul_6(x_reg[19] + x_reg[3]);
    assign partial_sum_3[1] = mul_13(x_reg[20] + x_reg[2]);
    assign computed_result[1] = x_valid[1] ? partial_sum_1[1] + partial_sum_2[1] + partial_sum_3[1] : 0;
    assign partial_sum_1[2] = {{8{b_reg[5][15]}}, b_reg[5], 19'b0} + x_reg[2] + x_reg[8];
    assign partial_sum_2[2] = -mul_6(x_reg[3] + x_reg[7]);
    assign partial_sum_3[2] = mul_13(x_reg[4] + x_reg[6]);
    assign computed_result[2] = x_valid[5] ? partial_sum_1[2] + partial_sum_2[2] + partial_sum_3[2] : 0;
    assign partial_sum_1[3] = {{8{b_reg[9][15]}}, b_reg[9], 19'b0} + x_reg[6] + x_reg[12];
    assign partial_sum_2[3] = -mul_6(x_reg[7] + x_reg[11]);
    assign partial_sum_3[3] = mul_13(x_reg[8] + x_reg[10]);
    assign computed_result[3] = x_valid[9] ? partial_sum_1[3] + partial_sum_2[3] + partial_sum_3[3] : 0;
    assign partial_sum_1[4] = {{8{b_reg[13][15]}}, b_reg[13], 19'b0} + x_reg[10] + x_reg[16];
    assign partial_sum_2[4] = -mul_6(x_reg[11] + x_reg[15]);
    assign partial_sum_3[4] = mul_13(x_reg[12] + x_reg[14]);
    assign computed_result[4] = x_valid[13] ? partial_sum_1[4] + partial_sum_2[4] + partial_sum_3[4] : 0;
    assign partial_sum_1[5] = {{8{b_reg[17][15]}}, b_reg[17], 19'b0} + x_reg[14] + x_reg[20];
    assign partial_sum_2[5] = -mul_6(x_reg[15] + x_reg[19]);
    assign partial_sum_3[5] = mul_13(x_reg[16] + x_reg[18]);
    assign computed_result[5] = x_valid[17] ? partial_sum_1[5] + partial_sum_2[5] + partial_sum_3[5] : 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 1; i <= N+4; i = i + 1)
                x_reg[i] <= 0;
            for (i = 1; i <= N; i = i + 1)
                x_valid[i] <= 1;
            for (i = N+1; i <= N+4; i = i + 1) begin
                x_valid[i] <= 0;
            end
            out_valid_reg <= 1'b0;
            iter_count <= 0;
        end else begin
            case(state)
                IDLE: begin
                    if(in_en) begin
                        b_reg[N] <= b_in; 
                    end
                end
                INPUT: begin
                    if (in_en) begin
                        for (i = 1; i < N; i = i + 1)
                            b_reg[i] <= b_reg[i+1];
                        b_reg[N] <= b_in; 
                    end
                end
                COMPUTE: begin
                    x_reg[1] <= x_reg[2];
                    x_reg[2] <= x_reg[3];
                    x_reg[3] <= x_reg[4];
                    x_reg[4] <= div_20(computed_result[2]);
                    x_reg[5] <= x_reg[6];
                    x_reg[6] <= x_reg[7];
                    x_reg[7] <= x_reg[8];
                    x_reg[8] <= div_20(computed_result[3]);
                    x_reg[9] <= x_reg[10];
                    x_reg[10] <= x_reg[11];
                    x_reg[11] <= x_reg[12];
                    x_reg[12] <= div_20(computed_result[4]);
                    x_reg[13] <= x_reg[14];
                    x_reg[14] <= x_reg[15];
                    x_reg[15] <= x_reg[16];
                    x_reg[16] <= div_20(computed_result[5]);
                    x_reg[17] <= x_reg[18];
                    x_reg[18] <= x_reg[19];
                    x_reg[19] <= x_reg[20];
                    x_reg[20] <= div_20(computed_result[1]);
                    for (i = 1; i < N+4; i = i + 1) begin
                        x_valid[i] <= x_valid[i+1];
                        b_reg[i] <= b_reg[i+1];
                    end
                    x_valid[N+4] <= x_valid[1];
                    b_reg[N+4] <= b_reg[1];
                    iter_count <= iter_count + 1;
                end
                OUTPUT: begin
                    out_valid_reg <= 1'b1;
                    x_out_reg <= x_reg[1][34:3];
                    for (i = 1; i < N; i = i + 1)
                        x_reg[i] <= x_reg[i+1];
                end
            endcase
        end
    end

    // / 20
    function signed [37:0] div_20;
        input signed [37:0] in;
        reg signed [37:0] first_stage;
        reg signed [37:0] second_stage;
        reg signed [37:0] third_stage;
        reg signed [37:0] fourth_stage;
        begin
            first_stage = in + (in >>> 4);
            second_stage = first_stage + (first_stage >>> 8);
            third_stage = second_stage + (second_stage >>> 16);
            fourth_stage = ((third_stage >>> 3) + (third_stage >>> 4)) >>> 2;

            // a/5 = a*3 / 2^4 (1+2^-4) * (1+2^-8) * (1+2^-16)
            // a/20 = a*(3 / 2^4)/4 (1+2^-4) * (1+2^-8) * (1+2^-16)

            // first_stage = ((in >>> 3) + (in >>> 4)) >>> 2; // a*(3 / 2^4)/4
            // second_stage = (first_stage >>> 4) + first_stage; // first_stage * (1+2^-4)
            // third_stage = (second_stage >>> 8) + second_stage; // second_stage * (1+2^-8)
            // fourth_stage = (third_stage >>> 16) + third_stage; // third_stage * (1+2^-16)
            // // div_20 = (fourth_stage >>> 32) + fourth_stage; // fourth_stage * (1+2^-32)

            div_20 = fourth_stage; // Final result
        end
    endfunction

    // * -13
    function signed [37:0] mul_13;
        input signed [37:0] in;
        begin
            mul_13 = (in <<< 3) + (in <<< 2) + in; // Multiply by -13
        end
    endfunction

    // * 6
    function signed [37:0] mul_6;
        input signed [37:0] in;
        begin
            mul_6 = (in <<< 2) + (in <<< 1); // Multiply by 6
        end
    endfunction
endmodule