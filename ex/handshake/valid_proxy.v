module valid_proxy(
    input wire clk,
    input wire rst_n,
    input wire[7:0] up_data,
    input wire up_valid,
    input wire down_ready, 
    output wire up_ready,
    output wire[7:0] down_data, 
    output wire down_valid
);

    assign down_data = up_data;
    assign down_valid = up_valid;
    assign up_ready = down_ready;

endmodule