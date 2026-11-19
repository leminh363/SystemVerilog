`timescale 1ns/1ps


integer checks = 0;
integer errors = 0;

// setup / hold monitor
// setup: input change -> rising clk >= T_SETUP
// hold: rising clk -> input change >= T_HOLD
module timing_checker1 #(
    parameter NAME = "SIG",
    parameter real T_SETUP = 2.0,
    parameter real T_HOLD = 2.0
)(
    input logic clk,
    input logic sig
);
    realtime last_change = 0.0; // last time input changed
    realtime last_posedge = -1.0e9; // last time positive clock edge

    // set up check
    always @(posedge clk) begin
        if (($realtime - last_change) < T_SETUP) begin
            errors ++;
            $error("[SETUP] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime - last_change, T_SETUP);
        end
        last_posedge = $realtime;
    end

    // hold time check
    always @(sig) begin
        if(($realtime - last_posedge) < T_HOLD) begin
            errors ++;
            $error("[HOLD] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime - last_posedge, T_HOLD);
        end
        last_change = $realtime;
    end 
endmodule

module timing_checker3 #(
    parameter NAME = "SIG",
    parameter real T_SETUP = 2.0,
    parameter real T_HOLD = 2.0
)(
    input logic clk,
    input logic [2:0] sig 
);
    realtime last_change = 0.0; // last time input changed
    realtime last_posedge = -1.0e9; // last time positive clock edge

    // set up check
    always @(posedge clk) begin
        if (($realtime - last_change) < T_SETUP) begin
            errors ++;
            $error("[SETUP] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime - last_change, T_SETUP);
        end
        last_posedge = $realtime;
    end

    // hold time check
    always @(sig[0] or sig[1] or sig[2]) begin
        if(($realtime - last_posedge) < T_HOLD) begin
            errors ++;
            $error("[HOLD] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime - last_posedge, T_HOLD);
        end
        last_change = $realtime;
    end 
endmodule

module tb_regFileWithBypass; 
    //parameters
    parameter real PERIOD  = 10.0;
    parameter real T_SETUP = 2.0; 
    parameter real T_HOLD  = 2.0;  
    parameter real negCLK_updateINPUT = PERIOD/2.0 - T_SETUP;

    // signals to connect input/output signals of the modules 
    logic clk;
    logic regWE;
    logic [2:0] WAddr, RAddr1, RAddr2;
    logic [15:0] DataIn; 
    logic [15:0] DataOut1, DataOut2;

    //signals used to prove the monitors catch violation
    logic v_sig;

    //
    logic [15:0] tb_register [8];

    // other variables
    integer i;

    // Expected-value functions
    function automatic logic [15:0] expected(
        input logic        we,
        input logic [2:0]  waddr,
        input logic [2:0]  raddr,
        input logic [15:0] din
    );
        if (we) tb_register[waddr] = din;
        return tb_register[raddr];
    endfunction

    task automatic check(input string name,input logic [15:0] got, input logic [15:0] exp);
        checks++;
        if (got !== exp) begin
            errors++;
           $error("%s: expected %b, got %b", name, exp, got);
        end
    endtask
    
    // cycles
    task automatic cycle(
        input logic we,
        input logic [2:0] waddr,
        input logic [2:0] ra1,
        input logic [2:0] ra2,
        input logic [15:0] din
    );
        logic [15:0] exp1, exp2;
        @(negedge clk); #(negCLK_updateINPUT);
        regWE  = we;
        WAddr  = waddr;
        RAddr1 = ra1;
        RAddr2 = ra2;
        DataIn = din;

        @(posedge clk); #0.1;
        exp1 = expected(we, waddr, ra1, din);
        exp2 = expected(we, waddr, ra2, din);

        check("DataOut1", DataOut1, exp1);
        check("DataOut2", DataOut2, exp2);

       #(T_HOLD - 0.1);
    endtask

    // timing violation cycle
    task timing_cycle();
        @(negedge clk); #(PERIOD/2 - T_SETUP + 1.0); v_sig = 1'b1; // setup violation
        @(posedge clk); #(T_HOLD-1.0); v_sig = 1'b0; // hold violation

        @(posedge clk); #0.1;
    endtask
    
    // DUTS
    regFileWithBypass u (
        .clk (clk),
        .regWE (regWE),
        .WAddr (WAddr),
        .RAddr1 (RAddr1),
        .RAddr2 (RAddr2),
        .DataIn (DataIn),
        .DataOut1 (DataOut1),
        .DataOut2 (DataOut2)
    );


     // timing monitors
    timing_checker1 #("WE", T_SETUP,T_HOLD) tc_WE (clk,regWE);
    timing_checker3 #("WAddr", T_SETUP,T_HOLD) tc_WAddr (clk,WAddr);
    timing_checker3 #("RAddr1", T_SETUP,T_HOLD) tc_RAddr1 (clk,RAddr1);
    timing_checker3 #("RAddr2", T_SETUP,T_HOLD) tc_RAddr2 (clk,RAddr2);
    timing_checker1 #("TIMINGCHECK.SIG", T_SETUP, T_HOLD) tc_sig (clk,v_sig);

     // Clock
    initial clk = 1'b0;
    always #(PERIOD/2.0) clk = ~clk;

    // MAIN
    
    initial begin
        $dumpfile("regfilewithbypass.vcd");
        $dumpvars(0, tb_regFileWithBypass);

        errors = 0;
        checks = 0;
        regWE  = 1'b0; 
        WAddr = 0; 
        RAddr1 = 0; 
        RAddr2 = 0; 
        DataIn = 16'h0;

        for (int i = 0; i < 8; i++) tb_register[i] = 16'hxxxx;

        $display("=== regFileWithBypass testbench start (PERIOD=%0.1f, T_SETUP=%0.1f ns, T_HOLD=%0.1f ns) ===",
                 PERIOD, T_SETUP, T_HOLD);

        // --- Test 1: initialize every register (registers power up as X) ---
        $display("Test 1: write all registers (bypass checked on write cycle)");
        for (int i = 0; i < 8; i++)
            cycle(1, i[2:0], i[2:0], i[2:0], 16'h1100 + i*16'h0111);

   
        
        // --- Test 2: read back all registers, no write ---
        $display("Test 2: read back all registers on both ports");
        for (int i = 0; i < 8; i++)
            cycle(0, 3'd0, i[2:0], 3'(7 - i), 16'hDEAD);
        
        // --- Test 3: bypass on port 1 only ---
        $display("Test 3: bypass on read port 1");
        cycle(1, 3'd3, 3'd3, 3'd5, 16'hA5A5);
        
        // --- Test 4: bypass on port 2 only ---
        $display("Test 4: bypass on read port 2");
        cycle(1, 3'd6, 3'd1, 3'd6, 16'h5A5A);

        // --- Test 5: bypass on both ports (same address) ---
        $display("Test 5: bypass on both ports");
        cycle(1, 3'd2, 3'd2, 3'd2, 16'hBEEF);

        
        // --- Test 6: WE=0 with matching address must NOT bypass ---
        $display("Test 6: no bypass when regWE = 0");
        cycle(0, 3'd4, 3'd4, 3'd4, 16'hFFFF);
        cycle(0, 3'd0, 3'd5, 3'd0, 16'h4321);
        cycle(0, 3'd7, 3'd7, 3'd7, 16'h1234);
       
        // --- Test 7: write to different address must NOT bypass ---
        $display("Test 7: no bypass when addresses differ");
        cycle(1, 3'd1, 3'd2, 3'd3, 16'h1010);

        // --- Test 8: read-after-write through the array on next cycle ---
        $display("Test 8: read value from array one cycle after write");
        cycle(1, 3'd5, 3'd0, 3'd0, 16'h0F0F);
        cycle(0, 3'd0, 3'd5, 3'd5, 16'h0000);

        // --- Test 9: back-to-back writes to the same register ---
        $display("Test 9: back-to-back writes to same register");
        cycle(1, 3'd7, 3'd7, 3'd7, 16'h0001);
        cycle(1, 3'd7, 3'd7, 3'd7, 16'h0002);
        cycle(1, 3'd7, 3'd7, 3'd7, 16'h0003);
        cycle(0, 3'd0, 3'd7, 3'd7, 16'h0000);

        
        // --- Test 10: both ports read same register, write elsewhere ---
        $display("Test 10: both ports read same register, write elsewhere");
        cycle(1, 3'd0, 3'd4, 3'd4, 16'h7777);

        // --- Test 11: walking-ones data pattern through bypass and array ---
        $display("Test 11: walking-ones data patterns");
        for (int b = 0; b < 16; b++) begin
            cycle(1, 3'd1, 3'd1, 3'd2, 16'(1 << b));
            cycle(0, 3'd0, 3'd1, 3'd1, 16'h0000);
        end
        
        // --- Test 12: all address combinations (write addr x ra1 x ra2) ---
        $display("Test 12: exhaustive address combinations with WE=1 and WE=0");
        for (int w = 0; w < 8; w++)
            for (int r1 = 0; r1 < 8; r1++)
                for (int r2 = 0; r2 < 8; r2++) begin
                    cycle(1, w[2:0], r1[2:0], r2[2:0], 16'($urandom));
                    cycle(0, w[2:0], r1[2:0], r2[2:0], 16'($urandom));
                end

        // --- Test 13: constrained-random regression ---
        $display("Test 13: random regression (5000 cycles)");
        for (int n = 0; n < 5000; n++) begin
            logic        we_r;
            logic [2:0]  wa_r, ra1_r, ra2_r;

            // bias toward address collisions to exercise the bypass
            wa_r  = 3'($urandom);
            ra1_r = ($urandom_range(0, 2) == 0) ? wa_r : 3'($urandom);
            ra2_r = ($urandom_range(0, 2) == 0) ? wa_r : 3'($urandom);
            we_r  = ($urandom_range(0, 3) != 0);   // ~75% writes

            cycle(we_r, wa_r, ra1_r, ra2_r, 16'($urandom));
        end

        timing_cycle();
        $finish;

    end
endmodule
