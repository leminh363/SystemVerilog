
`timescale 1ns/1ps

module tb_combinational;


// SIGNAL DECLARATIONS
// MUX 2:1
logic a, b, sel;
logic mux2_out;

// MUX 4:1
logic [3:0] d;
logic [1:0] mux4_sel;
logic mux4_out;

// Decoder
logic [1:0] dec_sel;
logic dec_en;
logic [3:0] dec_out;

// Priority Encoder
logic [3:0] enc_in;
logic [1:0] enc_code;
logic enc_valid;

// Full Adder
logic fa_a, fa_b, cin;
logic sum, cout;

// ALU
logic [3:0] alu_a, alu_b;
logic [2:0] opcode;
logic [3:0] alu_result;
logic alu_carry, alu_zero;

integer i, j, k;
integer errors;
integer expected;
integer expected_code;
integer expected_valid;

// DUT INSTANTIATIONS

mux2to1 mux2 (
    .a(a), .b(b), .sel(sel), .y(mux2_out)
);

mux4to1 mux4 (
    .d(d), .sel(mux4_sel), .y(mux4_out)
);

decoder2to4 decoder (
    .sel(dec_sel), .en(dec_en), .y(dec_out)
);

priority_encoder encoder (
    .in(enc_in),
    .code(enc_code),
    .valid(enc_valid)
);

full_adder fa (
    .a(fa_a), .b(fa_b), .cin(cin),
    .sum(sum), .cout(cout)
);

alu4bit alu (
    .a(alu_a),
    .b(alu_b),
    .opcode(opcode),
    .result(alu_result),
    .carry_out(alu_carry),
    .zero(alu_zero)
);

// TESTING
initial begin

    $dumpfile("combinational.vcd");
    $dumpvars(0, tb_combinational);

    errors = 0;

    // TEST 1: 2:1 MUX

    $display("\n===== TEST 1: 2:1 MUX =====");

    for (i = 0; i < 2; i++) begin
        for (j = 0; j < 2; j++) begin
            for (k = 0; k < 2; k++) begin

                a = i;
                b = j;
                sel = k;

                #1;

                expected = k ? j : i;

                if (mux2_out !== expected[0]) begin
                    $display("MUX2 ERROR: a=%b b=%b sel=%b",
                             a, b, sel);
                    errors++;
                end

            end
        end
    end

    $display("MUX2 testing completed.");

    // TEST 2: 4:1 MUX

    $display("\n===== TEST 2: 4:1 MUX =====");

    for (i = 0; i < 16; i++) begin
        for (j = 0; j < 4; j++) begin

            d = i;
            mux4_sel = j;

            #1;

            if (mux4_out !== d[j]) begin
                $display("MUX4 ERROR: d=%b sel=%d",
                         d, mux4_sel);
                errors++;
            end

        end
    end

    $display("MUX4 testing completed.");


    // TEST 3: DECODER


    $display("\n===== TEST 3: DECODER =====");

    for (i = 0; i < 2; i++) begin
        for (j = 0; j < 4; j++) begin

            dec_en = i;
            dec_sel = j;

            #1;

            expected = i ? (1 << j) : 0;

            if (dec_out !== expected[3:0]) begin
                $display("DECODER ERROR: en=%b sel=%b",
                         dec_en, dec_sel);
                errors++;
            end

        end
    end

    $display("DECODER testing completed.");

    // TEST 4: PRIORITY ENCODER

    $display("\n===== TEST 4: PRIORITY ENCODER =====");

    for (i = 0; i < 16; i++) begin

        enc_in = i;

        #1;

        // Highest priority: in[3]
        if (enc_in[3]) begin
            expected_code = 3;
            expected_valid = 1;
        end
        else if (enc_in[2]) begin
            expected_code = 2;
            expected_valid = 1;
        end
        else if (enc_in[1]) begin
            expected_code = 1;
            expected_valid = 1;
        end
        else if (enc_in[0]) begin
            expected_code = 0;
            expected_valid = 1;
        end
        else begin
            expected_code = 0;
            expected_valid = 0;
        end

        if (enc_code !== expected_code[1:0] ||
            enc_valid !== expected_valid[0]) begin

            $display("ENCODER ERROR: in=%b code=%b valid=%b",
                     enc_in, enc_code, enc_valid);
            errors++;

        end

    end

    $display("PRIORITY ENCODER testing completed.");

 
    // TEST 5: FULL ADDER


    $display("\n===== TEST 5: FULL ADDER =====");

    for (i = 0; i < 2; i++) begin
        for (j = 0; j < 2; j++) begin
            for (k = 0; k < 2; k++) begin

                fa_a = i;
                fa_b = j;
                cin = k;

                #1;

                expected = i + j + k;

                if (sum !== expected[0] ||
                    cout !== expected[1]) begin

                    $display("FULL ADDER ERROR: a=%b b=%b cin=%b",
                             fa_a, fa_b, cin);
                    errors++;

                end

            end
        end
    end

    $display("FULL ADDER testing completed.");


    // TEST 6: ALU

    $display("\n===== TEST 6: ALU =====");

    for (i = 0; i < 16; i++) begin
        for (j = 0; j < 16; j++) begin
            for (k = 0; k < 5; k++) begin

                alu_a = i;
                alu_b = j;
                opcode = k;

                #1;

                case (k)

                    0: begin
                        expected = i + j;

                        if (alu_result !== expected[3:0]) begin
                            $display("ALU ADD RESULT ERROR: a=%d b=%d",
                                     i, j);
                            errors++;
                        end

                        if (alu_carry !== (expected > 15)) begin
                            $display("ALU ADD CARRY ERROR");
                            errors++;
                        end
                    end

                    1: begin
                        expected = (i - j) & 15;

                        if (alu_result !== expected[3:0]) begin
                            $display("ALU SUB RESULT ERROR: a=%d b=%d",
                                     i, j);
                            errors++;
                        end

                        // Carry = 1 means no borrow
                        if (alu_carry !== (i >= j)) begin
                            $display("ALU SUB CARRY ERROR");
                            errors++;
                        end
                    end

                    2: begin
                        expected = i & j;

                        if (alu_result !== expected[3:0]) begin
                            $display("ALU AND ERROR");
                            errors++;
                        end
                    end

                    3: begin
                        expected = i | j;

                        if (alu_result !== expected[3:0]) begin
                            $display("ALU OR ERROR");
                            errors++;
                        end
                    end

                    4: begin
                        expected = i ^ j;

                        if (alu_result !== expected[3:0]) begin
                            $display("ALU XOR ERROR");
                            errors++;
                        end
                    end

                endcase

                // Check zero flag for every operation
                if (alu_zero !== (alu_result == 0)) begin
                    $display("ALU ZERO FLAG ERROR");
                    errors++;
                end

            end
        end
    end

    // FINAL RESULT
    $display("ALU testing completed.");
    $display("\n================================");
    if (errors == 0)
        $display("ALL TESTS PASSED!");
    else
        $display("TEST FAILED: %0d errors", errors);
    $display("================================\n");
    $finish;

end

endmodule
