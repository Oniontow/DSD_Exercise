// `timescale 1ns/10ps
module GSIM ( clk, reset, in_en, b_in, out_valid, x_out);
    input   clk ;
    input   reset ;
    input   in_en;
    output  out_valid;
    input   [15:0]  b_in;
    output  [31:0]  x_out;

    // Parameters and variables
    integer i;
    localparam N = 16;
    
    // State parameters
    localparam IDLE = 2'd0;
    localparam INPUT = 2'd1;
    localparam COMPUTE = 2'd2; 
    localparam OUTPUT = 2'd3;
    
    // Registers and wires
    reg signed [31:0] b_reg [1:N];   // Store input values
    reg signed [31:0] x_reg [1:N];   // Store computed x values
    reg [1:0] state, next_state;
    reg out_valid_reg;
    reg [4:0] count; // Counter for input/output indices
    reg [6:0] iter_count; // Iteration counter (increased to allow more iterations)
    
    assign x_out = x_reg[count+1]; // Output the current result according to count
    assign out_valid = out_valid_reg;
    
    // State machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case(state)
            IDLE: begin
                if (in_en)
                    next_state = INPUT;
                else
                    next_state = IDLE;
            end
            INPUT: begin
                if (!in_en && count == N) // All inputs received
                    next_state = COMPUTE;
                else if (in_en)
                    next_state = INPUT;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                if (iter_count >= 64) // Increased to 64 iterations for better convergence
                    next_state = OUTPUT;
                else
                    next_state = COMPUTE;
            end
            OUTPUT: begin
                if (count >= N-1) // All outputs sent
                    next_state = IDLE;
                else
                    next_state = OUTPUT;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic for computation and control
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers
            for (i = 1; i <= N; i = i + 1) begin
                b_reg[i] <= 32'b0;
                x_reg[i] <= 32'b0;
            end
            out_valid_reg <= 1'b0;
            count <= 0;
            iter_count <= 0;
        end else begin
            case(state)
                IDLE: begin
                    out_valid_reg <= 1'b0;
                    iter_count <= 0;
                    count <= 0;
                    
                    if(in_en) begin
                        b_reg[1] <= {b_in, 16'b0}; // First input
                        count <= 1;
                    end
                end
                
                INPUT: begin
                    if(in_en) begin
                        // Store inputs in sequence
                        b_reg[count+1] <= {b_in, 16'b0}; // Shift to fit fp precision
                        count <= count + 1;
                    end
                end
                
                COMPUTE: begin
                    // Initialize x with b values if first iteration
                    if (iter_count == 0) begin
                        for (i = 1; i <= N; i = i + 1) begin
                            x_reg[i] <= div_20(b_reg[i]); // Initialize with b/20
                        end
                        iter_count <= iter_count + 1;
                    end 
                    // Gauss-Seidel iteration to solve Mx = b
                    else if (iter_count < 64) begin
                        // First equation (special case)
                        x_reg[1] <= div_20(b_reg[1] + mul_neg13(x_reg[2]) + mul_6(x_reg[3]) - x_reg[4]);
                        
                        // Second equation (special case)
                        x_reg[2] <= div_20(b_reg[2] + mul_neg13(x_reg[1]) + mul_neg13(x_reg[3]) + mul_6(x_reg[4]) - x_reg[5]);
                        
                        // Third equation (special case)
                        x_reg[3] <= div_20(b_reg[3] + mul_6(x_reg[1]) + mul_neg13(x_reg[2]) + mul_neg13(x_reg[4]) + mul_6(x_reg[5]) - x_reg[6]);
                        
                        // Middle equations
                        for (i = 4; i <= N-3; i = i + 1) begin
                            x_reg[i] <= div_20(b_reg[i] - x_reg[i-3] + mul_6(x_reg[i-2]) + mul_neg13(x_reg[i-1]) + 
                                             mul_neg13(x_reg[i+1]) + mul_6(x_reg[i+2]) - x_reg[i+3]);
                        end
                        
                        // Special cases for last three equations
                        x_reg[N-2] <= div_20(b_reg[N-2] - x_reg[N-5] + mul_6(x_reg[N-4]) + mul_neg13(x_reg[N-3]) + 
                                          mul_neg13(x_reg[N-1]) + mul_6(x_reg[N]));
                        
                        x_reg[N-1] <= div_20(b_reg[N-1] - x_reg[N-4] + mul_6(x_reg[N-3]) + mul_neg13(x_reg[N-2]) + 
                                          mul_neg13(x_reg[N]));
                        
                        x_reg[N] <= div_20(b_reg[N] - x_reg[N-3] + mul_6(x_reg[N-2]) + mul_neg13(x_reg[N-1]));
                        
                        iter_count <= iter_count + 1;
                    end else begin
                        count <= 0; // Reset counter for output state
                    end
                end
                
                OUTPUT: begin
                    out_valid_reg <= 1'b1;
                    
                    // Output values one by one
                    if (count < N-1) begin
                        count <= count + 1;
                    end
                end
            endcase
        end
    end

    // SOME FUNCTIONS
    // Functions of division by 20
    function signed [31:0] div_20;
        input signed [31:0] in;
        reg signed [31:0] first_stage;
        reg signed [31:0] second_stage;
        reg signed [31:0] third_stage;
        reg signed [31:0] fourth_stage;
        begin
            // a/5 = a*3 / 2^4 (1+2^-4) * (1+2^-8) * (1+2^-16)
            // a/20 = a*(3 / 2^4)/4 (1+2^-4) * (1+2^-8) * (1+2^-16)
            first_stage = ((in >>> 3) + (in >>> 4)) >>> 2; // a*(3 / 2^4)/4
            second_stage = (first_stage >>> 4) + first_stage; // first_stage * (1+2^-4)
            third_stage = (second_stage >>> 8) + second_stage; // second_stage * (1+2^-8)
            fourth_stage = (third_stage >>> 16) + third_stage; // third_stage * (1+2^-16)
            div_20 = fourth_stage; // Final result
        end
    endfunction
    
    // Function of multiply by -13
    function signed [31:0] mul_neg13;
        input signed [31:0] in;
        begin
            mul_neg13 = -( (in << 3) + (in << 2) + in ); // Multiply by -13
        end
    endfunction
    
    // Function of multiply by 6
    function signed [31:0] mul_6;
        input signed [31:0] in;
        begin
            mul_6 = (in << 2) + (in << 1); // Multiply by 6
        end
    endfunction

endmodule