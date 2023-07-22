`timescale  1ns / 100ps
module testbench;
    reg [7:0] step_cnt;
    reg [7:0] data_cnt;
    reg clk;
    reg rst_n;
    wire [7:0] up_data;
    reg up_valid;
    wire up_ready;
    wire [7:0] down_data;
    wire down_valid;
    reg down_ready;

    assign up_data = data_cnt;


    valid_proxy dut(
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
    end
    /*iverilog */

    initial begin
        clk = 0;
        rst_n = 0;
        # 2;
        rst_n = 1;
        step_cnt = 0;
        data_cnt = 0;
    end

    always #1 clk = ~ clk;

    always @ (posedge clk) begin
        step_cnt <= step_cnt + 1;
        if (step_cnt == 255) begin
            $finish;
        end

        if (step_cnt < 10) begin
            up_valid <= 1;
            down_ready <= 1;
        end else if (step_cnt < 20) begin
            up_valid <= 1;
            down_ready <= ~down_ready;
        end else begin
            up_valid <= ~up_valid;
            down_ready <= 1;
        end

        if (up_valid && up_ready) begin
            data_cnt <= data_cnt + 1;
        end
    end
endmodule