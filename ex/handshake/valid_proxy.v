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


    reg [7:0] data;
    reg valid;

    assign down_data = data;
    assign down_valid = valid;
    assign up_ready = down_ready;


    // 最简单的打拍实现，对于下游可以连续接收的情况（下游ready一直为高）时可以正常工作，但是，一旦下游阻塞，则会丢数据
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data <= 0;
            valid <= 0;
        end else begin
            data <= up_data;
            valid <= up_valid;
        end
    end

endmodule