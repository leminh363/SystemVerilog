## Implemented:
- 8 x 16-bit register file 
- Synchronous write port with write enable 
- Two independent read ports 
- Write-to-read bypass (forwarding) on both read ports

## Verification:
- Self-checking testbench with a reference model (tb_register) and check task
- Directed tests: full write/read-back, bypass on port 1, port 2 and both ports, no bypass when regWE = 0 or addresses differ, back-to-back writes, walking-ones data patterns
- Exhaustive address combinations (write address x read address 1 x read address 2) with regWE = 1 and regWE = 0
- Constrained-random regression (5000 cycles, biased toward address collisions, around 75% writes)
- Setup and hold time checks on regWE, WAddr, RAddr1 and RAddr2 (timing_checker1, timing_checker3)
- Intentional setup and hold violation (timing_cycle) to confirm the monitors catch errors
- Check and error counters
- GTKWave waveform inspection 
