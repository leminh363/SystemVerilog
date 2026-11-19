module regFileWithBypass (
    input logic clk, regWE,
    input logic[2:0] WAddr, RAddr1, RAddr2,
    input logic[15:0] DataIn,
    output logic[15:0] DataOut1, DataOut2);

logic[15:0] registers[8];

assign DataOut1 = (regWE==1 && WAddr==RAddr1) ? DataIn : registers[RAddr1];
assign DataOut2 = (regWE==1 && WAddr==RAddr2) ? DataIn : registers[RAddr2];

always_ff @(posedge clk)
    if (regWE)
        registers[WAddr] <= DataIn;
endmodule
