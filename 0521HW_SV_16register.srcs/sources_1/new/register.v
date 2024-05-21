`timescale 1ns / 1ps

module register (
    input        clk,
    input        reset,
    input        en,
    input [15:0] in,

    output [15:0] out
);

    reg [15:0] out_reg, out_next;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            out_reg <= 0;
        end else begin
            out_reg <= out_next;
        end
    end

    always @(*) begin
        out_next = out_reg;

        if (en) begin
            out_next = in;
        end
    end

    assign out = out_reg;

endmodule
