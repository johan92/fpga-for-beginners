module deserializer_improved #(
  parameter                      PRL_DATA_WIDTH = 10,
  parameter                      PREAMBLE_WIDTH = 4,
  parameter [PREAMBLE_WIDTH-1:0] PREAMBLE       = 4'b1010
) (
  input                             clk_i, 
  input                             rst_i, 

  input                             ser_data_i,    
  input                             ser_data_en_i, 

  output logic [PRL_DATA_WIDTH-1:0] prl_data_o,
  output logic [PRL_DATA_WIDTH-1:0] prl_data_mask_o,
  output logic                      prl_err_o,
  output logic                      prl_en_o
);
localparam PARITY_BIT_WIDTH         = 1;
localparam MIN_DATA_MSG             = 2;
localparam MAX_DATA_MSG             = PRL_DATA_WIDTH;

localparam PRL_DATA_WITH_PARITY_LEN = PRL_DATA_WIDTH + 1; // 1 is parity bit
localparam SHIFT_REG_WIDTH          = ( PREAMBLE_WIDTH > PRL_DATA_WITH_PARITY_LEN ) ? ( PREAMBLE_WIDTH           ):
                                                                                      ( PRL_DATA_WITH_PARITY_LEN );

localparam MAX_SER_DATA_LEN  = PREAMBLE_WIDTH + PRL_DATA_WITH_PARITY_LEN; 
localparam COUNTER_WIDTH     = $clog2(MAX_SER_DATA_LEN + 1);

localparam MIN_COUNTER_IS_OK = PREAMBLE_WIDTH + MIN_DATA_MSG + PARITY_BIT_WIDTH;
localparam MAX_COUNTER_IS_OK = PREAMBLE_WIDTH + MAX_DATA_MSG + PARITY_BIT_WIDTH;

logic                       ser_data_en_d1;
logic                       send_output;
logic [SHIFT_REG_WIDTH-1:0] ser_data_shift_reg;
logic [COUNTER_WIDTH-1:0]   counter;
logic                       counter_is_ok;
logic [PREAMBLE_WIDTH-1:0]  in_preamble;
logic                       in_preamble_done;
logic                       in_preamble_is_ok;
logic                       in_preamble_is_ok_locked;
logic                       parity_bit;
logic                       parity_is_ok;

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i ) 
    ser_data_en_d1 <= 1'b0;
  else
    ser_data_en_d1 <= ser_data_en_i;

assign send_output = ( ser_data_en_i  == 1'b0 ) &&
                     ( ser_data_en_d1 == 1'b1 );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    ser_data_shift_reg <= '0;
  else if( send_output )
    ser_data_shift_reg <= '0;
  else if( in_preamble_done )
    ser_data_shift_reg <= { {{(SHIFT_REG_WIDTH-1)}{1'b0}}          , ser_data_i };
  else if( ser_data_en_i )
    ser_data_shift_reg <= { ser_data_shift_reg[SHIFT_REG_WIDTH-2:0], ser_data_i };
    
always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    counter <= '0;
  else if( send_output )
    counter <= '0;
  else if( ser_data_en_i && ( counter != '1 ) )
    counter <= counter + 1'd1;

assign counter_is_ok     = ( counter >= MIN_COUNTER_IS_OK ) &&
                           ( counter <= MAX_COUNTER_IS_OK );

assign in_preamble       = ser_data_shift_reg[PREAMBLE_WIDTH-1:0];
assign in_preamble_done  = (counter     == PREAMBLE_WIDTH);
assign in_preamble_is_ok = (in_preamble == PREAMBLE      );

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    in_preamble_is_ok_locked <= 1'b0;
  else if( send_output )
    in_preamble_is_ok_locked <= 1'b0;
  else if( in_preamble_done )
    in_preamble_is_ok_locked <= in_preamble_is_ok;

assign parity_bit      = ser_data_shift_reg[0];

assign parity_is_ok    = (^prl_data_o) == parity_bit;

assign prl_data_o      = ser_data_shift_reg[PRL_DATA_WIDTH:1];

always_comb begin
  for( int i = 0; i < PRL_DATA_WIDTH; i++ ) begin
    prl_data_mask_o[i] = i < ( counter - PREAMBLE_WIDTH ); 
  end
end

assign prl_err_o = ( in_preamble_is_ok_locked == 1'b0 ) ||
                   ( counter_is_ok            == 1'b0 ) ||
                   ( parity_is_ok             == 1'b0 );

assign prl_en_o  = send_output;

endmodule
