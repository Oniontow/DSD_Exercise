module GSIM ( clk, reset, in_en, b_in, out_valid, x_out);
    input   clk ;
    input   reset ;
    input   in_en;
    output  out_valid;
    input   [15:0]  b_in;
    output  [31:0]  x_out;

    integer i;
    localparam N = 16;
    localparam MAX_ITER = 280;

    localparam IDLE = 2'd0, INPUT = 2'd1, COMPUTE = 2'd2, OUTPUT = 2'd3;

    // 48bit reg，小數點 at bit 24
    reg signed [15:0] b_reg [1:N];
    reg signed [47:0] x_reg [1:N];
    reg signed [47:0] sum;
    reg [31:0] x_out_reg;
    reg [1:0] state, next_state;
    reg out_valid_reg;
    reg [3:0] in_count;
    reg [9:0] iter_count;
    reg [1:0] compute_idx;

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
            INPUT:   next_state = (in_count == (N-1) ) ? COMPUTE : INPUT;
            COMPUTE: next_state = (iter_count >= MAX_ITER) ? OUTPUT : COMPUTE;
            OUTPUT:  next_state = OUTPUT;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 1; i <= N; i = i + 1) begin
                x_reg[i] <= 48'b0;
            end
            out_valid_reg <= 1'b0;
            in_count <= 0;
            compute_idx <= 0;
            iter_count <= 0;
        end else begin
            case(state)
                IDLE: begin
                    if(in_en) begin
                        b_reg[16] <= b_in; // 16位整數左移24位，對齊48bit小數點24位
                    end
                end
                INPUT: begin
                    if (in_en) begin
                        for (i = 1; i < N; i = i + 1)
                            b_reg[i] <= b_reg[i+1];
                        b_reg[N] <= b_in; // 16bit sign-extend, shift left 24
                        in_count <= in_count + 1;
                    end
                end
                COMPUTE: begin
                    x_reg[compute_idx+1] <= div_20(compute_sum(compute_idx+1));
                    x_reg[compute_idx+5] <= div_20(compute_sum(compute_idx+5));
                    x_reg[compute_idx+9] <= div_20(compute_sum(compute_idx+9));
                    x_reg[compute_idx+13] <= div_20(compute_sum(compute_idx+13));
                    compute_idx <= compute_idx + 2'd1;
                    iter_count <= iter_count + 1;
                end
                OUTPUT: begin
                    out_valid_reg <= 1'b1;
                    x_out_reg <= x_reg[1][39:8];
                    for (i = 1; i < N; i = i + 1)
                        x_reg[i] <= x_reg[i+1];
                end
            endcase
        end
    end

    
    function signed [47:0] div_20;
        input signed [47:0] in;
        reg signed [47:0] first_stage;
        reg signed [47:0] second_stage;
        reg signed [47:0] third_stage;
        reg signed [47:0] fourth_stage;
        begin
            // a/5 = a*3 / 2^4 (1+2^-4) * (1+2^-8) * (1+2^-16)
            // a/20 = a*(3 / 2^4)/4 (1+2^-4) * (1+2^-8) * (1+2^-16)
            first_stage = ((in >>> 3) + (in >>> 4)) >>> 2; // a*(3 / 2^4)/4
            second_stage = (first_stage >>> 4) + first_stage; // first_stage * (1+2^-4)
            third_stage = (second_stage >>> 8) + second_stage; // second_stage * (1+2^-8)
            fourth_stage = (third_stage >>> 16) + third_stage; // third_stage * (1+2^-16)
            // div_20 = (fourth_stage >>> 32) + fourth_stage; // fourth_stage * (1+2^-32)
            div_20 = fourth_stage; // Final result
        end
    endfunction

    // 48bit * -13
    function signed [47:0] mul_neg13;
        input signed [47:0] in;
        begin
            mul_neg13 = -((in <<< 3) + (in <<< 2) + in); // Multiply by -13
        end
    endfunction

    // 48bit * 6
    function signed [47:0] mul_6;
        input signed [47:0] in;
        begin
            mul_6 = (in <<< 2) + (in <<< 1); // Multiply by 6
        end
    endfunction
    // compute_sum
    function signed [47:0] compute_sum;
        input [4:0] idx;
        reg signed [47:0] tmp_sum;
        begin
            tmp_sum = {{8{b_reg[idx][15]}}, b_reg[idx], 24'b0};
            if (idx > 3)
                tmp_sum = tmp_sum + x_reg[idx-3];
            if (idx > 2)
                tmp_sum = tmp_sum - mul_6(x_reg[idx-2]);
            if (idx > 1)
                tmp_sum = tmp_sum - mul_neg13(x_reg[idx-1]);
            if (idx < N)
                tmp_sum = tmp_sum - mul_neg13(x_reg[idx+1]);
            if (idx < N-1)
                tmp_sum = tmp_sum - mul_6(x_reg[idx+2]);
            if (idx < N-2)
                tmp_sum = tmp_sum + x_reg[idx+3];
            compute_sum = tmp_sum;
        end
    endfunction
endmodule