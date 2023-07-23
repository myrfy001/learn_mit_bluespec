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

            // 将打拍模块从中间一分为二，从下游看的逻辑。
            //如果下游观察到valid/ready握手成功，则认为寄存器数据排空了，因此将valid置为无效
            if (down_ready && down_valid) begin
                valid_reg <= 0;
            end


            // 从上游端口观察，如果观察到valid/ready握手成功，则认为上游的数据应该进入到寄存器中
            // 这里非常依赖up_ready信号的生成，隐含条件是如果现在寄存器没有排空，则up_ready不成立
            // 按照书写优先级，这里的data_reg赋值操作会覆盖上面的操作，从FIFO的角度理解，上一个if是出队，
            // 这个if是入队，也就是先出队再入队的pipeline fifo
            if (up_ready && up_valid) begin
                valid_reg <= up_valid;
                data_reg <= up_data;
            end 

        end
    end

endmodule