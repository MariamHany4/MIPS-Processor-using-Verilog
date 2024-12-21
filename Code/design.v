
// Instruction Memory
module instruction_memory (input clk,input [31:0] addr,output reg [31:0] instruction);
  reg[31:0] IMemory [0:1023]; //4K instruction memory
  initial begin
    IMemory[0]   <= 32'h02324020; // add $t0, $s1, $s2
    IMemory[4]  <= 32'h00AF8020; //add $s0, $a1, $t7
    IMemory[8]   <= 32'h01294822; //sub $t1,$t1,$t1
	IMemory[12]  <= 32'h00000000; // nop (No operation)
    IMemory[16]  <= 32'h00421822; //sub $v1,$v0,$v0
    IMemory[20]  <= 32'h02749820; //add $s3, $s3, $s4
    IMemory[24]  <= 32'h01404820 ; //add $t1, $t2, $zero
    IMemory[28]  <= 32'h00009020 ; //add $s2, $zero, $zero
    IMemory[32]  <= 32'h11090002; //beq $t0, $t1, L1
    IMemory[36]  <= 32'h8D280000; //lw $t0, 0 ($t1)
    IMemory[40] <=32'h02D6B822; //sub $s7, $s6, $s6
    IMemory[44] <=32'h03194020; //add $t8,$t8,$t9
    IMemory[48]<= 32'hAD8D0000; //sw $t4,$t5(0)
    IMemory[52] <=32'h01A06820; // add $t5,$t5,$0
    IMemory[56] <=32'h10000002; // beq $0,$0,L1
  end
  always @(addr) begin
    instruction <= IMemory[addr];
end
endmodule

// ALU Controller
module ALU_Controller (
  input [5:0] func,
  input [1:0] ALU_Op,
  output reg [3:0] ALU_Control
);

  always @(*) begin
    case(ALU_Op)
      2'b00: ALU_Control = 4'b0010; // ADD for lw and sw
      2'b01: ALU_Control = 4'b0110; // SUB for beq
      2'b10: begin //R format so check func
        case(func)
          6'b100000: ALU_Control = 4'b0010; // ADD
          6'b100010: ALU_Control = 4'b0110; // SUB
          default:   ALU_Control = 4'b0000;
        endcase
      end
      default: ALU_Control = 4'b0000; // Default to NOP
    endcase
  end
endmodule

// Main Control Unit
module Main_Control_Unit (
  input [5:0] op_code,
  output reg branch,
  output reg MemRead,
  output reg MemtoReg,
  output reg MemWrite,
  output reg ALUSRC,
  output reg RegWrite,
  output reg RegDst,
  output reg [1:0] ALUOp
);
  always @(*) begin
    case(op_code)
      6'b000000: begin // R-format
        RegDst = 1;
        branch = 0;
        ALUSRC = 0;
        RegWrite = 1;
        MemRead = 0;
        MemWrite = 0;
        MemtoReg = 0;
        ALUOp = 2'b10;
      end
      6'b100011: begin // lw
        RegDst = 0;
        branch = 0;
        ALUSRC = 1;
        RegWrite = 1;
        MemRead = 1;
        MemWrite = 0;
        MemtoReg = 1;
        ALUOp = 2'b00; // ADD
      end
      6'b101011: begin // sw


        branch = 0;
        ALUSRC = 1;
        RegWrite = 0;
        MemRead = 0;
        MemWrite = 1;
        ALUOp = 2'b00; // ADD
      end
      6'b000100: begin // beq


        branch = 1;
        ALUSRC = 0;
        RegWrite = 0;
        MemRead = 0;
        MemWrite = 0;
        ALUOp = 2'b01; // SUB
      end
      default: begin // Default case
        RegDst = 0;
        branch = 0;
        ALUSRC = 0;
        RegWrite = 0;
        MemRead = 0;
        MemWrite = 0;
        MemtoReg = 0;
        ALUOp = 2'b00;
      end
    endcase
  end
endmodule

// ALU
module ALU (
  input [31:0] op1,
  input [31:0] op2,
  input [3:0] ALU_Control,
  input [15:0] offset,
  input ALUSRC,
  output reg zero_flag,
  output reg [32:0] ALU_result
);
  reg[31:0] operand2;
  initial begin
    operand2<=op2;
     zero_flag <= 1'b0;
  end
  always @(*) begin


    if(ALUSRC==1)
      operand2 <= {{16{offset[15]}}, offset};
    else
      operand2<=op2;
    case(ALU_Control)
      4'b0010: ALU_result <= op1 + operand2; // ADD
      4'b0110: ALU_result <= op1 - operand2; // SUB
      default: ALU_result <= 32'b0;                      // Default case
    endcase
    if (ALU_result == 32'd0)
      zero_flag <= 1'b1;
    else
      zero_flag<=1'b0;
  end
endmodule

// Data Memory
module data_memory (input clk,input [31:0] address,input [31:0] write_data,input MemWrite,input MemRead,input MemtoReg,input[31:0] ALU_Result, output reg [31:0] rd_data);
  reg [31:0] Memory_data [0:4096]; //16K Data Memory
  reg[31:0] read_data;
  int i;
  initial begin
    read_data<=32'd0;
    for(i=0;i<320;i=i+1)
      Memory_data[i]=32'd0;
  end

  always @(posedge clk) begin
    if (MemWrite)
      Memory_data[address] <= write_data;
  end
  always@(*) begin
    if (MemRead)
      read_data <= Memory_data[address];
    else
      read_data <= 32'd0;
    if(MemtoReg)
      rd_data<=read_data;
    else
      rd_data<=ALU_Result;
  end
endmodule

// Registers
module registers (
  input clk,
  input [4:0] rs, rt, rd,
  input [31:0] write_data,
  input RegWrite,
  input RegDst,
  output reg [31:0] read_data1, read_data2
);
  reg [31:0] reg_file [31:0];
  reg [4:0] write_reg;

  initial begin
    write_reg=5'd0;
    reg_file[0] = 32'd0; //$0=0
    reg_file[2] = 32'd1; //$v0=1
    reg_file[3] = 32'd4; //$v1=4
    reg_file[4] = 32'd3; //$a0=3
    reg_file[5] = 32'd0; //$a1=0
    reg_file[6] = 32'd1; //$a2=1
    reg_file[7] = 32'd2; //$a3=2
    reg_file[8] = 32'd2; //$t0=2
    reg_file[9] = 32'd8; //$t1=8
    reg_file[10] = 32'd5; //$t2=5
    reg_file[11] = 32'd6; //$t3=6
    reg_file[12] = 32'd7; //$t4=7
    reg_file[13] = 32'd8; //$t5=8
    reg_file[14] = 32'd9; //$t6=9
    reg_file[15] = 32'd10; //$t7=10
    reg_file[16] = 32'd12; //$s0=12
    reg_file[17] = 32'd11; //$s1=11
    reg_file[18] = 32'd13; //$s2=13
    reg_file[19] = 32'd14; //$s3=14
    reg_file[20] = 32'd15; //$s4=15
    reg_file[21] = 32'd16; //$s5=16
    reg_file[22] = 32'd17; //$s6=17
    reg_file[23] = 32'd18; //$s7=18
    reg_file[24] = 32'd19; //$t8=19
    reg_file[25] = 32'd20; //$t9=20
    read_data1=reg_file[0];
     read_data2=reg_file[0];

  end
always @(*) begin
  read_data1 <= reg_file[rs];
  read_data2 <= reg_file[rt];


end
  always @(posedge clk) begin
    if (RegWrite) begin
      if (RegDst==1'b1)
            write_reg <= rd;
        else
            write_reg <= rt;
      // Prevent writing to $0 as it must be always 0
      //if (write_reg != 5'd0)
        reg_file[write_reg] <= write_data;
    end
  end


endmodule

// Program Counter
module program_counter (
  input clk,
  input [31:0] current_pc,
  input[15:0] offset,
  input branch,
  input zero,
  output reg [31:0] pc_of_next_instruction
);
  reg[31:0] pc;
  reg[31:0] sign_extend;
  initial begin
    pc<=32'd0;
  end
  always @( *) begin
    pc<=current_pc+4;
    if(branch&zero) begin
      sign_extend<={{16{offset[15]}}, offset};
      pc_of_next_instruction<=pc+(sign_extend << 2);
    end
    else
      pc_of_next_instruction <= pc;
  end
endmodule


