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

    // Registers and wires
    reg signed [31:0] b_reg [1:N];   // 16 bit 2sc with bit 0 ~ 15 = 0
    reg signed [31:0] x_reg [1:N];   // 32 bit 2sc, bit 31 ~ 16 are integer part
    assign x_out = x_reg[1]; // Output the result
    
    // Sequential logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers
            for (i = 1; i <= N; i = i + 1) begin
                b_reg[i] <= 32'b0;
                x_reg[i] <= 32'b0;
            end

        end else begin
            if(in_en) begin
                // Shift and read the input data
                for (i = 1; i <= N-1; i = i + 1) begin
                    b_reg[i] <= b_reg[i+1]; 
                end
                b_reg[N] <= {b_in, 16'b0}; // Shift to fit fp precision
            end else if (out_valid) begin
                // Output the result
                for (i = 1; i <= N-1; i = i + 1) begin
                    x_reg[i] <= x_reg[i+1]; 
                end
            end
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