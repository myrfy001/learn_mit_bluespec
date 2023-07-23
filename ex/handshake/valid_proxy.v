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


    reg [7:0] data_reg;
    reg valid_reg;

    assign down_data = data_reg;
    assign down_valid = valid_reg;

    // 从上游端口来看，ready反应了打拍组件是否还能吃进去一拍数据。
    // 从内部逻辑上说，valid寄存器就代表了data寄存器里是否为空。
    // 有两种条件可以吃数据：
    // 1.自己的寄存器是空的，那么一定可以把数据暂存进来
    // 2.寄存器是满的，但是下游可以接收数据，这就意味着下一拍的时候，寄存器的数据可以更新。
    assign up_ready = down_ready | (~valid_reg);


    
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= 0;
            valid_reg <= 0;
        end else begin

            // 相比于上一个commit，可以看到这里不再分别从上游和下游两个端口来看问题了，而是简化成了只从上游看问题。
            // 上一个commit中，先看下游的状态，根据下游是否消耗掉一个数据先临时修改valid的状态，然后这个valid状态可能在后续根据上游
            // 的状态被覆写掉。
            // 事实上，覆写这个操作是冗余的，可以通过直接接收上游source给出的up_valid状态就可以了。valid相当于是上游source控制的，自己不需要
            // 再倒手处理一遍valid的状态。
            if (up_ready) begin
                valid_reg <= up_valid;
                data_reg <= up_data;
            end 

        end
    end

endmodule