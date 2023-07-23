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
            
            // 此处相对于上一条commit的优化：
            // 观察上一条commit的两个if条件，可以发现其中因为down_ready条件的存在，两个if语句是互斥的，因此可以重新写成下面的样子：
            // 这样又减少了1个与门和1个非门
            // 刚才是根据逻辑表达式发现可以这样合并，再从逻辑上再理解一下，发现也很清晰：
            // 只要下游给出ready信号，那么当前clk到达以后，下一个周期自己内部的缓存则一定是空的。
            // 只有在下游接不了，而且上游又握手成功的情况下，才启用自己的内部缓存。
            if (down_ready) begin
                valid_reg <= 0;
            end else if (up_valid && up_ready) begin
                valid_reg <= 1;
                data_reg <= up_data;
            end
            
        end
    end

endmodule