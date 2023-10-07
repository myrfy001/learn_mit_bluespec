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
            
            if (down_ready) begin
                valid_reg <= 0;
            end else if (up_ready) begin   // 此处相对于上一条commit的优化：进一步减少了一个与门，但是可能对up侧的要求更严格，即上游master的valid拉高以后，除非握手成功，否则不能改变。
                                           // 而前一个commit的写法里面，对master的行为不规范有一定的容忍度。
                                           // 这里的`up_ready`实际上是`~valid_reg`，也就是说，只要缓存区是空的，就可以让新的状态进来，如果进来的valid状态是0，那么相当于
                                           // 状态没有改变，可以继续等待数据进来，一旦进来的valid状态是1，那么这个时刻的data和valid就被锁存到缓存区了，并且在排空之前不会接收新的数据进来。
                                           // 再换一个角度理解，就从`up_ready`的字面意思理解，就是从上游角度来看，下游已经给出了ready信号，那么这个时候显然是可以接收数据的。
                valid_reg <= up_valid;
                data_reg <= up_data;
            end
            
        end
    end

endmodule