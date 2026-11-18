module dff (
    input logic clk,
    input logic D,
    output logic Q
);
    always_ff @(posedge clk) begin 
        Q <= D;
    end
endmodule

module dff_enable (
    input logic clk,
    input logic enable,
    input logic D,
    output logic Q
);
    always_ff @(posedge clk) begin
        if(enable) 
            Q <= D;
    end
endmodule

module dff_sync_reset (
    input logic clk,
    input logic rst,
    input logic D,
    output logic Q
);
    always_ff @(posedge clk) begin
        if (rst) 
            Q <= 1'b0;
        else
            Q <= D;
    end
endmodule

module dff_async_reset (
    input logic clk,
    input logic rst,
    input logic D,
    output logic Q
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) 
            Q <= 1'b0;
        else 
            Q <= D;
    end
endmodule

module shift_register (
    input logic clk,
    input logic rst,
    input logic serial_in,
    output logic [3:0] Q 
);
    always_ff @(posedge clk) begin 
        if (rst)
            Q <= 4'b0000;
        else
            Q <= {Q[2:0], serial_in};
    end
endmodule