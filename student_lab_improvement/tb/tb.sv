module tb;

localparam PREAMBLE = 4'b1010;

bit clk;
bit rst;
bit rst_done;

always #5ns clk = !clk;

initial begin
  rst = 1'b1;
  @(posedge clk);
  @(posedge clk);
  @(negedge clk);
  rst <= 1'b0;

  rst_done = 1'b1;
end

logic ser_data;
logic ser_data_en;

logic [2:0][9:0] dut_prl_data;
logic [2:0][9:0] dut_prl_data_mask;
logic [2:0]      dut_prl_err;
logic [2:0]      dut_prl_en;

task automatic send_raw_data( bit [31:0] _data, int _data_len );
  for( int i = 0; i < _data_len; i++ ) begin
    @(posedge clk);
    ser_data    <= _data[_data_len - i - 1];
    ser_data_en <= 1'b1;
  end

  @(posedge clk);
  ser_data_en <= 1'b0;
  
  @(posedge clk);
endtask

initial begin
  ser_data    = 1'b0;
  ser_data_en = 1'b0;
  
  wait(rst_done);

  send_raw_data( 32'b1010_11_1,     (4+2+1) );
  send_raw_data( 32'b1010_11_1,     (4+2+1) );
  send_raw_data( 32'b1011_11_0,     (4+2+1) );
  send_raw_data( 32'b1010_11111_1,  (4+5+1) );
  send_raw_data( 32'b1010_111111_1, (4+6+1) );

  repeat(10) @(posedge clk);
  $stop();
end

des #(
  .PREAMB                                 ( PREAMBLE              ) 
) dut0 (
  .clk_i                                  ( clk                   ),
  .rst_i                                  ( rst                   ),

  .ser_data_i                             ( ser_data              ),
  .ser_data_en_i                          ( ser_data_en           ),

  .prl_data_o                             ( dut_prl_data      [0] ),
  .prl_data_mask_o                        ( dut_prl_data_mask [0] ),
  .err_o                                  ( dut_prl_err       [0] ),
  .en_o                                   ( dut_prl_en        [0] )
);

deserializer #(
  .PREAMB                                 ( PREAMBLE              )
) dut1 (
  .clk_i                                  ( clk                   ),
  .rst_i                                  ( rst                   ),
 
  .ser_data_i                             ( ser_data              ),
  .ser_data_en_i                          ( ser_data_en           ),

  .prl_data_o                             ( dut_prl_data      [1] ),
  .prl_data_mask_o                        ( dut_prl_data_mask [1] ),
  .err_o                                  ( dut_prl_err       [1] ),
  .en_o                                   ( dut_prl_en        [1] )
);

deserializer_improved #(
  .PRL_DATA_WIDTH                         ( 10                    ),
  .PREAMBLE_WIDTH                         ( 4                     ),
  .PREAMBLE                               ( PREAMBLE              )
) dut2 (
  .clk_i                                  ( clk                   ),
  .rst_i                                  ( rst                   ),

  .ser_data_i                             ( ser_data              ),
  .ser_data_en_i                          ( ser_data_en           ),

  .prl_data_o                             ( dut_prl_data      [2] ),
  .prl_data_mask_o                        ( dut_prl_data_mask [2] ),
  .prl_err_o                              ( dut_prl_err       [2] ),
  .prl_en_o                               ( dut_prl_en        [2] )
);

initial begin
  forever begin
    @(posedge clk);
    for( int i = 0; i < 3; i++ ) begin
      if(dut_prl_en[i]) begin
        $display("%t: %m: DUT%0d: data = 0x%x mask = 0x%x err = 0x%x", $time(), 
                            i,    dut_prl_data[i], dut_prl_data_mask[i], dut_prl_err[i] );
      end
    end
  end
end

endmodule
