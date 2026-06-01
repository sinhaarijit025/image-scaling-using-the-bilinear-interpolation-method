`timescale 1ns/1ps

module tb;

    reg  clk, rst_n;
    wire done;

    initial clk = 0;
    always #5 clk = ~clk;

    bilinear_scaler #(
        .W_IN        (860),
        .H_IN        (821),
        .W_OUT       (3000),
        .H_OUT       (2160),
        .Channels    (3),
        .INPUT_FILE  ("7.hex"), 
        .OUTPUT_FILE ("7_out.hex")
    ) dut (
        .clk   (clk),
        .rst (rst_n),
        .done  (done)
    );

    integer timeout;

    initial begin
        rst_n = 0;
        repeat(2) @(posedge clk);
        @(posedge clk); #1;
        rst_n = 1;

        $display("");
        $display("  Reading input from your custom hex file...");

        timeout = 0;

        while (!done && timeout < 100000000) begin
            @(posedge clk); #1; timeout = timeout + 1;
        end

        if (!done) begin
            $display("FAIL: TIMEOUT"); $finish;
        end

        $display("  Completed in %0d clocks after reset.", timeout);
        $finish;
    end

    initial begin #2_000_000_000; $display("WATCHDOG TIMEOUT"); $finish; end

endmodule