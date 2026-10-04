module jxli_fp8mul_tb;

  logic clock, reset, enable;
  logic [3:0] data;
  logic [7:0] io_in, io_out;

  assign io_in = {1'b0, data, enable, reset, clock};

  jxli_fp8mul dut(.io_in(io_in), .io_out(io_out));

  initial begin

    clock = 1;
    forever #5 clock = ~clock;
  end

  int errors = 0;

  // Reset, send x then y one nibble per clock, wait for the result and check it.
  // Inputs change on the falling edge so they are stable at the rising edge.
  task automatic multiply(input logic [7:0] x, y, expected, input string name);
    @(negedge clock);
    reset = 1;
    enable = 0;
    @(negedge clock);
    reset = 0;
    enable = 1;
    data = x[7:4];
    @(negedge clock);
    data = x[3:0];
    @(negedge clock);
    data = y[7:4];
    @(negedge clock);
    data = y[3:0];
    @(negedge clock);
    enable = 0;
    // the longest case (denormal result) takes 26 clocks
    repeat (40) @(negedge clock);
    if (io_out !== expected) begin
      $display("FAIL %s: %b * %b = %b, expected %b", name, x, y, io_out, expected);
      errors++;
    end else begin
      $display("ok   %s: %b * %b = %b", name, x, y, io_out);
    end
  endtask

  initial begin
    // 1.111 x 2^(14 - 7) * 1.111 x 2^(14 - 7)
    // = infty
    multiply(8'b0_1110_111, 8'b0_1110_111, 8'b0_1111_000, "240 x 240 = inf");

    // -20 x 3
    // 1.010 x 2^(11 - 7) * 1.100 x 2^(8 - 7)
    // = -1.111 x 2^(12 - 7) = -60
    multiply(8'b1_1011_010, 8'b0_1000_100, 8'b1_1100_111, "-20 x 3 = -60");

    // NaN x Infty = qNaN
    multiply(8'b1_1111_010, 8'b0_1111_000, 8'b1_1111_111, "NaN x inf = NaN");

    // Mantissa product < 2 (used to come out 2x too big)
    multiply(8'b0_0111_000, 8'b0_0111_000, 8'b0_0111_000, "1 x 1 = 1");
    multiply(8'b1_1010_010, 8'b0_1000_100, 8'b1_1011_111, "-10 x 3 = -30");

    // Mantissa product in [2, 4)
    multiply(8'b0_0111_100, 8'b0_0111_100, 8'b0_1000_001, "1.5 x 1.5 = 2.25");
    multiply(8'b0_0111_111, 8'b0_0111_111, 8'b0_1000_110, "1.875 x 1.875 = 3.5 (truncated)");

    // Product 1000_0010: used to hang forever in CALC6
    multiply(8'b0_0111_010, 8'b0_0111_101, 8'b0_1000_000, "1.25 x 1.625 = 2 (truncated)");

    // Denormal input: 0.001 x 2^-6 = 2^-9
    multiply(8'b0_0000_001, 8'b0_1000_000, 8'b0_0000_010, "2^-9 x 2 = 2^-8");

    // Underflow to zero (used to wrap around to inf)
    multiply(8'b0_0000_001, 8'b0_0000_001, 8'b0_0000_000, "2^-9 x 2^-9 = 0");

    if (errors == 0)
      $display("ALL TESTS PASSED");
    else
      $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule
