# Implemented:
- 2:1 Multiplexer (mux2to1)
- 4:1 Multiplexer (mux4to1)
- 2-to-4 Decoder with enable (decoder2to4)
- 4-bit Priority Encoder with valid output (priority_encoder)
- Full Adder (full_adder)
- 4-bit ALU (alu4bit) with ADD, SUB, AND, OR, XOR, carry-out and zero flag

# Verification:
- Self-checking testbench (tb_combinational) with an error counter and pass/fail summary
- Exhaustive testing of all input combinations for the MUXes, decoder, priority encoder and full adder
- Exhaustive ALU testing (all 16 x 16 operand pairs for each of the 5 operations)
- Result checks against expected values computed in the testbench
- Carry and borrow checks for ADD and SUB 
- Zero flag check on every ALU operation
- Priority encoder checks for the highest-priority input and the all-zero (invalid) case
- GTKWave waveform inspection
