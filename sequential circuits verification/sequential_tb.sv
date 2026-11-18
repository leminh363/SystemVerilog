`timescale 1ns/1ps 

// setup / hold monitor
// setup: input change -> rising clk >= T_SETUP
// hold: rising clk -> input change >= T_HOLD
module timing_checker #(
    parameter NAME = "SIG",
    parameter real T_SETUP = 2.0,
    parameter real T_HOLD = 2.0
)(
    input logic clk,
    input logic sig
);
    realtime last_change = 0.0; // last time input changed
    realtime last_posedge = -1.0e9; // last time positive clock edge
    integer setup_errors = 0;
    integer hold_errors = 0;

    // set up check
    always @(posedge clk) begin
        if (($realtime - last_change) < T_SETUP) begin
            setup_errors ++;
            $error("[SETUP] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime - last_change, T_SETUP);
        end
        last_posedge = $realtime;
    end

    // hold time check
    always @(sig) begin
        if(($realtime - last_posedge) < T_HOLD) begin
            hold_errors ++;
            $error("[HOLD] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime - last_posedge, T_HOLD);
        end
        last_change = $realtime;
    end 
endmodule

// Recovery/removal monitor 
// recovery: deassert rst -> rising clk >= T_RECOVERY
// removal: rising clk -> deassert rst >= T_REMOVAL
module reset_checker #(
    parameter NAME = "RST",
    parameter real T_RECOVERY = 2.0,
    parameter real T_REMOVAL = 2.0
)(
    input logic clk,
    input logic rst
);
    realtime last_deassert = -1.0e9;
    realtime last_posedge = -1.0e9;
    integer recovery_errors = 0;
    integer removal_errors = 0;

    //recovery check
    always @(posedge clk) begin
        if (($realtime - last_deassert) < T_RECOVERY) begin
            recovery_errors ++;
            $error("[RECOVERY] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime - last_deassert, T_RECOVERY);
        end
        last_posedge = $realtime;
    end

    //removal check
    always @(negedge rst) begin
        if (($realtime - last_posedge) < T_REMOVAL) begin
            removal_errors ++;
            $error("[REMOVAL] %s @%0.3f ns: %0.3f < %0.3f", NAME, $realtime, $realtime-last_posedge, T_REMOVAL);
        end
        last_deassert = $realtime;
    end
endmodule

module tb_sequential;

    //parameters 
    parameter real PERIOD = 10.0;
    parameter real T_SETUP = 2.0;
    parameter real T_HOLD = 2.0;
    parameter real T_RECOVERY = 2.0;
    parameter real T_REMOVAL = 2.0;
    parameter integer N_RANDOM = 20;

    // 
    localparam real negCLK_updateINPUT = PERIOD/2.0 - T_SETUP;
    // signals to connect input/output signals of the modules 
    logic clk;
    logic D_dff;
    logic D_enable, enable;
    logic D_sync, rst_sync;
    logic D_async, rst_async;
    logic rst_shift, serial_in;

    logic Q_dff;
    logic Q_enable;
    logic Q_sync;
    logic Q_async;
    logic[3:0] Q_shift;

    //signals used to prove the monitors catch violation
    logic v_sig, v_rst;

    // other variables
    integer checks = 0;
    integer errors = 0;
    integer i;



    // Expected-value functions
    function automatic logic dff_expected(input logic d);
        return d;
    endfunction

    function automatic logic enable_expected(input logic en, input logic d, input logic q_prev);
        return en ? d : q_prev;
    endfunction

    function automatic logic sync_reset_expected(input logic rst, input logic d);
        return rst ? 1'b0 : d;
    endfunction

    function automatic logic async_reset_expected(input logic rst, input logic d);
        return rst ? 1'b0 : d;
    endfunction

    function automatic logic [3:0] shift_expected(input logic rst, input logic sin, input logic [3:0] q_prev);
        return rst ? 4'b0000 : {q_prev[2:0], sin};
    endfunction

    task automatic check(input string name, input logic[3:0] got, input logic [3:0] exp);
        checks ++;
        if (got !== exp) begin
            errors ++;
            $error("%s: expected %b, got %b", name, exp, got);
        end
    endtask
    // cycles
    task automatic dff_cycle(input logic d);
        logic exp;
        @(negedge clk); #(negCLK_updateINPUT);
        D_dff = d;
        @(posedge clk); #0.1;
        exp = dff_expected(d);
        check("DFF",Q_dff,exp);
        #(T_HOLD - 0.1);
    endtask

    task automatic enable_cycle(input logic en, input logic d, input logic q_prev);
        logic exp;
        @(negedge clk); #(negCLK_updateINPUT);
        D_enable = d;
        enable = en;
        @(posedge clk); #0.1;
        exp = enable_expected(en, d, q_prev);
        check("Enable DFF",Q_enable,exp);
        #(T_HOLD - 0.1);
    endtask

    task automatic sync_cycle(input logic rst, input logic d);
        logic exp;
        @(negedge clk); #(negCLK_updateINPUT);
        rst_sync = rst;
        D_sync = d;
        @(posedge clk); #0.1;
        exp = sync_reset_expected(rst,d);
        check("Sync reset DFF",Q_sync,exp);
        #(T_HOLD - 0.1);
    endtask

    task automatic async_cycle(input logic rst, input logic d);
        logic exp;
        @(negedge clk); 
        rst_async = 1'b1; 
        #0.1;
        check("ASYNC clears without clk", Q_async, 1'b0);
        #1;
        rst_async = 1'b0;
        #0.1;
        check("ASYNC holds 0 after release", Q_async, 1'b0);
        #(PERIOD/2 - 1.2 - T_RECOVERY);
        D_async = d;
        rst_async = rst;
        @(posedge clk); #0.1;
        exp = async_reset_expected(rst,d);
        check("Async reset DFF",Q_async,exp);
        #(T_REMOVAL - 0.1);
        rst_async = 1'b0;
    endtask

    task automatic shift_cycle(input logic rst, input logic sin, input logic [3:0] q_prev);
        logic[3:0] exp;
        @(negedge clk); #(negCLK_updateINPUT);
        rst_shift = rst;
        serial_in = sin;
        @(posedge clk); #0.1;
        exp = shift_expected(rst,sin,q_prev);
        if(q_prev !== 4'bx) check("Shift register",Q_shift,exp);
        #(T_HOLD - 0.1);
    endtask

    // timing violation cycle
    task timing_cycle();
        @(negedge clk); #(PERIOD/2 - T_SETUP + 1.0); v_sig = 1'b1; // setup violation
        @(posedge clk); #(T_HOLD-1.0); v_sig = 1'b0; // hold violation

        @(negedge clk); v_rst = 1'b1;
        @(posedge clk); #(T_REMOVAL - 1.0); v_rst = 1'b0; // removal violation

        @(negedge clk); v_rst = 1'b1;
        #(PERIOD/2.0 - T_RECOVERY + 1.0); v_rst = 1'b0;
        @(posedge clk); #0.1;
    endtask

    // DUTs
    dff u1(.clk(clk), .D(D_dff), .Q(Q_dff));
    dff_enable u2(.clk(clk), .enable(enable), .D(D_enable), .Q(Q_enable));
    dff_sync_reset u3(.clk(clk), .rst(rst_sync), .D(D_sync), .Q(Q_sync));
    dff_async_reset u4(.clk(clk), .rst(rst_async), .D(D_async), .Q(Q_async));
    shift_register u5(.clk(clk), .rst(rst_shift), .serial_in(serial_in), .Q(Q_shift));

    // timing monitors
    timing_checker #("dff_D", T_SETUP,T_HOLD) tc_dff_d (clk,D_dff);
    timing_checker #("dff_enable_enable", T_SETUP,T_HOLD) tc_dff_enable_enable (clk,enable);
    timing_checker #("dff_enable_D", T_SETUP,T_HOLD) tc_dff_enable_D (clk,D_enable);
    timing_checker #("dff_sync_reset_rst", T_SETUP,T_HOLD) tc_dff_sync_reset_rst (clk,rst_sync);
    timing_checker #("dff_sync_reset_D", T_SETUP,T_HOLD) tc_dff_sync_reset_D (clk,D_sync);
    reset_checker #("dff_async_reset_rst", T_RECOVERY,T_REMOVAL) rc_dff_async_reset_rst (clk,rst_async);
    timing_checker #("dff_async_reset_D", T_SETUP,T_HOLD) rc_dff_async_reset_D (clk,D_async);
    timing_checker #("shift_register_rst", T_SETUP,T_HOLD) tc_shift_register_rst (clk,rst_shift);
    timing_checker #("shift_register_serial_in", T_SETUP,T_HOLD) tc_shift_register_serial_in (clk,serial_in);

    timing_checker #("TIMINGCHECK.SIG", T_SETUP, T_HOLD) tc_sig (clk,v_sig);
    reset_checker #("RESETTIMINGCHECK.RST", T_RECOVERY, T_REMOVAL) rc_rst (clk, v_rst);

    // clock
    initial clk = 0;
    always #(PERIOD/2.0) clk = ~clk;

    // MAIN
    initial begin 
        $dumpfile("sequential.vcd");
        $dumpvars(0, tb_sequential);

        D_dff = 1'b0;
        D_enable = 1'b0; 
        enable = 1'b0;
        D_sync = 1'b0;
        rst_sync = 1'b1;
        D_async = 1'b0;
        rst_async = 1'b1;
        rst_shift = 1'b1;
        serial_in = 4'b0;

        $display("\n    DFF ");
        dff_cycle(0);
        dff_cycle(1);
        dff_cycle(0);
        dff_cycle(0);
        dff_cycle(1);
        dff_cycle(1);
        for(i=0; i< N_RANDOM; i++) dff_cycle($urandom % 2);

        $display("\n    DFF ENABLE ");
        enable_cycle(0, $urandom % 2, Q_enable);
        enable_cycle(1, $urandom % 2, Q_enable);
        enable_cycle(0, $urandom % 2, Q_enable);
        enable_cycle(0, $urandom % 2, Q_enable);
        enable_cycle(1, $urandom % 2, Q_enable);
        enable_cycle(1, $urandom % 2, Q_enable);

        enable_cycle($urandom % 2, 0, Q_enable);
        enable_cycle($urandom % 2, 1, Q_enable);
        enable_cycle($urandom % 2, 0, Q_enable);
        enable_cycle($urandom % 2, 0, Q_enable);
        enable_cycle($urandom % 2, 1, Q_enable);
        enable_cycle($urandom % 2, 1, Q_enable);
        for(i=0; i< N_RANDOM; i++) enable_cycle($urandom % 2,$urandom % 2,Q_enable);

        $display("\n    DFF SYNC RESET ");
        sync_cycle($urandom % 2, 0);
        sync_cycle($urandom % 2, 1);
        sync_cycle($urandom % 2, 0);
        sync_cycle($urandom % 2, 0);
        sync_cycle($urandom % 2, 1);
        sync_cycle($urandom % 2, 1);

        sync_cycle(0, $urandom % 2);
        sync_cycle(1, $urandom % 2);
        sync_cycle(0, $urandom % 2);
        sync_cycle(0, $urandom % 2);
        sync_cycle(1, $urandom % 2);
        sync_cycle(1, $urandom % 2);
        for(i=0; i< N_RANDOM; i++) sync_cycle($urandom % 2,$urandom % 2);

        $display("\n    DFF ASYNC RESET ");
        async_cycle($urandom % 2, 0);
        async_cycle($urandom % 2, 1);
        async_cycle($urandom % 2, 0);
        async_cycle($urandom % 2, 0);
        async_cycle($urandom % 2, 1);
        async_cycle($urandom % 2, 1);

        async_cycle(0, $urandom % 2);
        async_cycle(1, $urandom % 2);
        async_cycle(0, $urandom % 2);
        async_cycle(0, $urandom % 2);
        async_cycle(1, $urandom % 2);
        async_cycle(1, $urandom % 2);
        for(i=0; i< N_RANDOM; i++) async_cycle($urandom % 2,$urandom % 2);

        $display("\n    SHIFT REGISTER ");
        shift_cycle($urandom % 2, 0 ,Q_shift);
        shift_cycle($urandom % 2, 1 ,Q_shift);
        shift_cycle($urandom % 2, 0 ,Q_shift);
        shift_cycle($urandom % 2, 0 ,Q_shift);
        shift_cycle($urandom % 2, 1 ,Q_shift);
        shift_cycle($urandom % 2, 1 ,Q_shift);

        shift_cycle(0, $urandom % 2 ,Q_shift);
        shift_cycle(1, $urandom % 2 ,Q_shift);
        shift_cycle(0, $urandom % 2 ,Q_shift);
        shift_cycle(0, $urandom % 2 ,Q_shift);
        shift_cycle(1, $urandom % 2 ,Q_shift);
        shift_cycle(1, $urandom % 2 ,Q_shift);
        for(i=0; i< N_RANDOM; i++) shift_cycle($urandom % 2,$urandom % 2,Q_shift);

        timing_cycle();
        $finish;

    end
endmodule


