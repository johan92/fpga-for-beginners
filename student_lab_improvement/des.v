module des(

input rst_i, //reset
input clk_i, //clock
input ser_data_i, //data
input ser_data_en_i, //enable

output reg[9:0] prl_data_o,
output reg err_o,
output reg[9:0] prl_data_mask_o,
output reg en_o,

output reg[10:0] temp_box, //временная для нашей даты + бит паритета
output reg[3:0] temp_pr //temp for preambule
);
integer counter;
reg paritet_bit; //bit паритета
integer i; 

parameter[3:0] PREAMB = 4'b1010;

parameter IDLE  = 3'b001, REC = 3'b010, RUN = 3'b100 ;
//IDLE - ждем начала посылки
//REC - записываем в регистр посылку
//RUN - обрабатываем нашу посылку и записываем в выходные регистры

reg[2:0]          state        ;// Seq part of the FSM
reg[2:0]          next_state   ;// combo part of FSM

always_comb
begin
        case(state)
                IDLE: if(ser_data_en_i == 0)
                                next_state = IDLE;
                          else
                                next_state = REC;
                REC: if(ser_data_en_i == 0) //закончилась посылка
                           next_state = RUN;
                         else
                           next_state = REC;
                RUN: next_state = IDLE;
        endcase
end

always_ff @(posedge clk_i or posedge rst_i)
begin
  if (rst_i == 1'b1) begin
    state <= IDLE;
  end else begin
    state <= next_state;
  end
end


//выставление prl_data_o
always @(*)
begin
  if(state == RUN)
  prl_data_o = temp_box[10:1];
end 
  
//формирование временного регистра для сравнение с преамбулой
always @ (posedge clk_i)
begin
  if(counter < 4 && ser_data_en_i && !rst_i)
    temp_pr = {temp_pr[2:0], ser_data_i};
end

//формирование err_o
  //происходит побитовый xor выходных битов и бита паритета
  //если результат ксорирования = 1, то значит произошла ошибка при передаче, если 0, то значит ошибки нет
  //а так же сравнивание преамбулы принятой посылки и необходимой.
  //выставляет ошибку err_o при наличии хотя бы одной "проблемы-несовпадения"

always @(*)
begin
  if(state==RUN)
  begin
    paritet_bit = temp_box[0];
    err_o = ((^prl_data_o)^paritet_bit)||(PREAMB!=temp_pr);
  end
end


//формирование выходной маски
always @(*)
begin
  if(rst_i == 1)
    prl_data_mask_o = 0;
  else if(state == RUN)
    begin
      for(i=0; i<10; i=i+1)
            begin
              if(i<counter-5)
                    prl_data_mask_o[i] = 1;
                  else
                    prl_data_mask_o[i] = 0;
                  end
    end
end
//

//описание сдвигового регистра для приема информационной части + бита паритета посылки
always_ff @ (posedge clk_i)
begin
  if(next_state == REC && state == IDLE)
    temp_box = 0;
  else if(ser_data_en_i == 1 && counter > 3)
    begin
      temp_box = {temp_box[9:0], ser_data_i};
    end
end
//описание внутреннего счетчика
always_ff @ (posedge clk_i)
begin
  if(rst_i == 1)
    counter = 0;
  else if(ser_data_en_i)
    counter=counter+1;
  else if((ser_data_en_i == 0 && state==IDLE))
    counter = 0;
end

//выставление сигнала en_o, подтверждающий валидность наших данных
always @(*)
begin
  if(rst_i == 1'b1)
    en_o = 0;
  else if (prl_data_mask_o[0]==1 && prl_data_mask_o[1]==1 && state==RUN)
    en_o=clk_i;
        else
        en_o = 0;
end
endmodule
