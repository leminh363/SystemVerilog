
`timescale 1ns/1ps

module mux2to1 (
    input  logic a,
    input  logic b,
    input  logic sel,
    output logic y
);

    assign y = sel ? b : a;

endmodule


module mux4to1 (
    input  logic [3:0] d,
    input  logic [1:0] sel,
    output logic y
);

    logic mux0, mux1;

    mux2to1 m0 (
        .a(d[0]), .b(d[1]),
        .sel(sel[0]), .y(mux0)
    );

    mux2to1 m1 (
        .a(d[2]), .b(d[3]),
        .sel(sel[0]), .y(mux1)
    );

    mux2to1 m2 (
        .a(mux0), .b(mux1),
        .sel(sel[1]), .y(y)
    );

endmodule



module decoder2to4 (
    input  logic [1:0] sel,
    input  logic en,
    output logic [3:0] y
);

    always_comb begin
        y = 4'b0000;

        if (en)
            y[sel] = 1'b1;
    end
endmodule


module priority_encoder (
    input  logic [3:0] in,
    output logic [1:0] code,
    output logic valid
);

    always_comb begin
        code  = 2'b00;
        valid = 1'b1;

        if (in[3]) code = 2'b11;
        else if (in[2]) code = 2'b10;
        else if (in[1]) code = 2'b01;
        else if (in[0]) code = 2'b00;
        else valid = 1'b0;
    end
endmodule



module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);

endmodule

module alu4bit (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic [2:0] opcode,
    output logic [3:0] result,
    output logic carry_out,
    output logic zero
);

    localparam ADD = 3'b000;
    localparam SUB = 3'b001;
    localparam AND = 3'b010;
    localparam OR  = 3'b011;
    localparam XOR = 3'b100;

    logic [3:0] b_operand;
    logic [3:0] sum_result;
    logic [4:0] carry;

    assign b_operand = (opcode == SUB) ? ~b : b;

    assign carry[0] = (opcode == SUB);

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : FA_CHAIN

            full_adder fa (
                .a(a[i]),
                .b(b_operand[i]),
                .cin(carry[i]),
                .sum(sum_result[i]),
                .cout(carry[i+1])
            );

        end
    endgenerate

    always_comb begin

        result    = 4'b0000;
        carry_out = 1'b0;

        case (opcode)

            ADD: begin
                result    = sum_result;
                carry_out = carry[4];
            end

            SUB: begin
                result    = sum_result;
                carry_out = carry[4]; 
            end

            AND: result = a & b;

            OR:  result = a | b;

            XOR: result = a ^ b;

            default: begin
                result    = 4'b0000;
                carry_out = 1'b0;
            end

        endcase

    end

    assign zero = (result == 4'b0000);

endmodule
