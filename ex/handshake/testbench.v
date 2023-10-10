`timescale  1ns / 100ps
module testbench;
    reg clk;
    reg rst_n;
    reg [27:0] up_next_data;
    reg [27:0] up_data;
    reg up_valid;
    reg up_next_valid;
    wire up_ready;
    reg [27:0] up_stall_cnt;

    wire [27:0] down_data;
    reg [27:0] last_down_data;
    wire down_valid;
    reg down_ready;

    integer seed;

    ready_valid_proxy dut(
        .clk(clk),
        .rst_n(rst_n),
        .up_data(up_data),
        .up_valid(up_valid),
        .down_ready(down_ready),
        .up_ready(up_ready),
        .down_data(down_data),
        .down_valid(down_valid)
    );
    
    /*iverilog */
    initial
    begin            
        $dumpfile("wave.vcd");        //生成的vcd文件名称
        $dumpvars(0, testbench);    //tb模块名称
        seed = 111;
    end
    /*iverilog */

    initial begin
        clk = 0;
        rst_n = 1;
        # 1;
        rst_n = 0;
        # 1;
        rst_n = 1;
        
    end

    always #1 clk = ~ clk;



    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            up_data <= 0;
            up_next_data <= 1;
            up_valid <= 0;
            up_next_valid <= 0;
            up_stall_cnt <= 0;
            last_down_data <= 0;
        end else begin
            // master 成功握手条件
            if (up_valid && up_ready) begin
                up_next_data = up_next_data + 1;
                up_stall_cnt <= 0;

            end else begin
                up_stall_cnt <= up_stall_cnt + 1;
            end

            // master可以改变输出条件
            if (!up_valid || up_ready) begin
                up_data <= up_next_data;
                up_valid <= up_next_valid;
            end

            // slave成功握手条件
            if (down_valid && down_ready) begin
                if (last_down_data + 1 != down_data) begin 
                    $display("data out error, expect = %d, get= %d\n", last_down_data + 1, down_data);
                    $finish;
                end else begin
                    last_down_data <= down_data;
                end
                if (down_data == 255) begin
                    $finish;
                end
            end

            // 强制终止条件，程序可能已经卡死
            if (up_stall_cnt == 255) begin
                $finish();
            end
            
            // 以下是各种master输出状态的模拟
            // 第一组testcase
            if (up_data < 20) begin
                // master一直有数据，前10个slave也一直可以接收数据，接下来10个slave每隔一拍接收一个数据
                up_next_valid <= 1;
            end

            if (last_down_data < 10) begin
                down_ready <= 1;
            end else if (last_down_data < 20) begin
                down_ready <= ~down_ready;
            end

            // 第二组testcase
            // master 的valid间隔拉高，slave的ready一直为高
            if (20 <= up_data && up_data < 30 ) begin
                up_next_valid <= ~up_next_valid;
            end

            if (20 <= last_down_data && last_down_data < 30) begin
                down_ready <= 1;
            end

            // 第三组testcase
            // master的valid和salve的ready都是间隔拉高，并且同步
            if (30 <= up_data && up_data < 40 ) begin
                up_next_valid <= down_ready;
            end

            if (30 <= last_down_data && last_down_data < 40) begin
                down_ready <= ~down_ready;
            end

            // 第四组testcase
            // master的valid和salve的ready都是间隔拉高，并且正好反相
            if (40 <= up_data && up_data < 50 ) begin
                up_next_valid <= ~down_ready;
            end

            if (40 <= last_down_data && last_down_data < 50) begin
                down_ready <= ~down_ready;
            end


            // 最后，消耗掉全部的输入数据
            if (50 <= last_down_data && last_down_data < 256) begin
                down_ready <= $random(seed) % 2;
                up_next_valid <= $random(seed) % 2;
            end
        end
    end

endmodule