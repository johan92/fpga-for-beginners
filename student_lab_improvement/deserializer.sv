module deserializer #(
  parameter [3:0] PREAMB = 4'b1010
) (
  input              clk_i, 
  input              rst_i, 

  input              ser_data_i,    
  input              ser_data_en_i, 

  output logic [9:0] prl_data_o,
  output logic [9:0] prl_data_mask_o,
  output logic       err_o,
  output logic       en_o
);
logic [31:0] counter;
logic        parity_bit; 
logic [10:0] temp_box; 
logic [3:0]  temp_pr; 
logic        mismatch_parity_bit;
logic        mismatch_preamb;

enum logic [2:0] {
  IDLE_S  = 3'b001,  // waiting for start of message
  REC_S   = 3'b010,  // recording message to register
  RUN_S   = 3'b100   // send message to output
} state, next_state;

always_comb begin
  next_state = state;

  case( state )
    IDLE_S: begin
      if( ser_data_en_i )
        next_state = REC_S;
    end

    REC_S: begin
      if( ser_data_en_i == 1'b0 )
        next_state = RUN_S;
    end

    RUN_S: begin
      next_state = IDLE_S;
    end

    default: begin
      next_state = IDLE_S;
    end
  endcase
end

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )   
    state <= IDLE_S;
  else 
    state <= next_state;

logic in_preamb;

assign in_preamb = counter < 4; 

always_ff @ ( posedge clk_i or posedge rst_i )
  if( rst_i )
    temp_pr <= '0;
  else if( ser_data_en_i && in_preamb )
    temp_pr <= { temp_pr[2:0], ser_data_i };

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i ) 
    temp_box <= '0;
  else if( ( state == IDLE_S ) && ( next_state == REC_S ) )
    temp_box <= '0;
  else if( ser_data_en_i && (!in_preamb) )
    temp_box <= { temp_box[9:0], ser_data_i };

always_ff @( posedge clk_i or posedge rst_i )
  if( rst_i )
    counter <= '0;
  else if( ser_data_en_i )
    counter <= counter + 1'd1;
  else if( ( ser_data_en_i == 1'b0 ) && ( next_state == IDLE_S ) )
    counter <= '0;

assign parity_bit          = temp_box[0];

assign mismatch_parity_bit = ( parity_bit  != (^prl_data_o) );
assign mismatch_preamb     = ( PREAMB      != temp_pr       );

assign prl_data_o = temp_box[10:1];

always_comb begin
  for( int i = 0; i < 10; i = i + 1 ) begin
    prl_data_mask_o[i] = (i < (counter - 5));
  end
end

assign en_o  = ( state == RUN_S ) && prl_data_mask_o[0] && prl_data_mask_o[1];

assign err_o = mismatch_parity_bit || 
               mismatch_preamb;

endmodule
