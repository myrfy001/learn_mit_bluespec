module ready_valid_proxy(
    input wire clk,
    input wire rst_n,
    input wire[7:0] up_data,
    input wire up_valid,
    input wire down_ready, 
    output wire up_ready,
    output wire[7:0] down_data, 
    output wire down_valid
);

    wire [7:0] t_data;
    wire t_valid, t_ready;

    ready_proxy ready_inst(
        .clk(clk),
        .rst_n(rst_n),
        .up_data(up_data),
        .up_valid(up_valid),
        .up_ready(up_ready),
        .down_data(t_data),
        .down_valid(t_valid),
        .down_ready(t_ready)
    );

    valid_proxy valid_inst(
        .clk(clk),
        .rst_n(rst_n),
        .up_data(t_data),
        .up_valid(t_valid),
        .up_ready(t_ready),
        .down_data(down_data),
        .down_valid(down_valid),
        .down_ready(down_ready)
    );
    

endmodule