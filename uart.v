`timescale 1ns / 1ps

module top(
    input clk,
    input start,
    input [7:0] txin,
    output reg tx,
    input rx,
    output [7:0] rxout,
    output rxdone, txdone
    );

    parameter clk_value = 100_000;
    parameter baud = 9600;
    parameter wait_count = clk_value / baud;

    reg bitDone = 0;
    integer count = 0;
    
    // TX Logic State Machine Parameters
    localparam idle = 2'b00, send = 2'b01, check = 2'b10;
    reg [1:0] state = idle;
    
    reg [9:0] txData; // 1 start bit, 8 data bits, 1 stop bit
    integer bitIndex = 0;
    reg [9:0] shifttx = 0;

    always @(posedge clk) begin
        // Baud rate timing logic
        if (state == idle) begin
            count <= 0;
        end else if (count == wait_count) begin
            bitDone <= 1'b1;
            count <= 0;
        end else begin
            count <= count + 1;
            bitDone <= 1'b0;
        end

        // TX State Machine
        case (state)
            idle: begin
                tx <= 1'b1; // Idle state, TX is high
                txData <= 0;
                bitIndex <= 0;
                shifttx <= 0;

                if (start == 1'b1) begin
                    txData <= {1'b1, txin, 1'b0}; // Add start and stop bits
                    state <= send;
                end
            end

            send: begin
                tx <= txData[bitIndex]; // Send the current bit
                shifttx <= {txData[bitIndex], shifttx[9:1]}; // Shift the TX data
                state <= check;
            end

            check: begin
                if (bitIndex < 9) begin // 10 bits total, 0-9 index
                    if (bitDone == 1'b1) begin
                        bitIndex <= bitIndex + 1;
                        state <= send;
                    end
                end else begin
                    state <= idle;
                    bitIndex <= 0;
                end
            end

            default: state <= idle;
        endcase
    end

    assign txdone = (bitIndex == 9 && bitDone == 1'b1) ? 1'b1 : 1'b0;

    // RX Logic State Machine Parameters
    localparam ridle = 2'b00, rwait = 2'b01, recv = 2'b10, rcheck = 2'b11;
    reg [1:0] rstate;
    reg [9:0] rxdata;
    integer rcount = 0;
    integer rindex = 0;

    always @(posedge clk) begin
        case (rstate)
            ridle: begin
                rxdata <= 0;
                rindex <= 0;
                rcount <= 0;
                if (rx == 1'b0) begin // Start bit detected (low)
                    rstate <= rwait;
                end
            end

            rwait: begin
                if (rcount < wait_count / 2) begin
                    rcount <= rcount + 1;
                    rstate <= rwait;
                end else begin
                    rcount <= 0;
                    rstate <= recv;
                    rxdata <= {rx, rxdata[9:1]}; // Capture the start bit
                end
            end

            recv: begin
                if (rindex < 9) begin // Receive 8 data bits
                    if (bitDone == 1'b1) begin
                        rindex <= rindex + 1;
                        rxdata <= {rx, rxdata[9:1]}; // Shift in received bit
                        rstate <= rwait;
                    end
                end else begin
                    rstate <= rcheck; // Proceed to check stop bit
                end
            end

            rcheck: begin
                if (bitDone == 1'b1) begin
                    if (rx == 1'b1) begin // Stop bit should be high
                        rstate <= ridle; // Return to idle if stop bit is correct
                    end else begin
                        rstate <= ridle; // Error: stop bit is not high
                    end
                end
            end

            default: rstate <= ridle;
        endcase
    end

    assign rxout = rxdata[8:1]; // Extract 8 data bits (without start/stop)
    assign rxdone = (rindex == 9 && bitDone == 1'b1) ? 1'b1 : 1'b0;

endmodule
