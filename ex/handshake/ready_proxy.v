module ready_proxy(
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

    // valid_reg寄存器的作用只有一个：记录内部的data_reg是否缓存了多出来的一拍数据。
    // 因此，只要内部data_reg还有空间能缓存下一个数据，那么对上游来说就可以呈现出ready
    // 而且可以看到，这里up_ready是寄存器取反后输出，取反操作认为开销极小，且这是一个1bit的信号，就近似认为是
    // 寄存器直接输出了。这里体现了对ready信号的打拍。
    // 这里理解上需要注意，对ready信号打拍，并不是直观的说要在ready信号的路径上加一个寄存器，相反，
    // 理解为根据其他寄存器状态新生成了一个给到上游的信号，这样更好理解。
    assign up_ready = ~valid_reg;

    // 对于下游端口来说，无论是上游有数据，还是自己内部缓存了数据，都是有数据，所以这里只需要将两个信号或在一起即可。
    // 这里有上游到下游的组合直通逻辑。
    assign down_valid = valid_reg || up_valid;

    // 优先级策略，如果自己有缓存的数据，那么就一定先给出自己缓存的数据。
    assign down_data = valid_reg ? data_reg : up_data;

    
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= 0;
            valid_reg <= 0;
        end else begin
            
            // 这里可以把3个判断条件分成2组来看，其中(up_valid && up_ready)表示上游握手成功。
            // 如果握手成功，那么数据必须向后流动，有两条路，一条是直通下游，另一条就是进寄存器缓存。
            // 后面的~down_ready则表示下游接收不了，所以只能进寄存器。
            // 此处的隐含条件：上游能握手成功，则up_ready一定为0，而根据前面up_ready的定义可以知道此时
            // 缓存寄存器一定为空，因此不会丢失数据。
            if (up_valid && up_ready && ~down_ready) begin
                valid_reg <= 1;
                data_reg <= up_data;
            end

            // 如果下游满足握手条件，那么，由于缓存寄存器里面的数据一定优先排空，所以只要握手成功，就可以
            // 把valid_reg清零了。如果原来就是0，清零也没有副作用。
            if (down_valid && down_ready) begin
                valid_reg <= 0;
            end            
        end
    end

endmodule