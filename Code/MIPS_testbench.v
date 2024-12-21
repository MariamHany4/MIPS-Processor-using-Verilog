
module MIPS_testbench;

  // Signals
  reg clk,reset;
  reg [31:0] pc, pc_next;
  reg [31:0] instruction_mc_code, read_data1, read_data2, sign_extended, result_of_ALU;
  wire [1:0] ALUOp;
  reg zero_flag;
  reg [31:0] write_data;
  reg [31:0] result;
  reg[3:0] ALU_Control;

  always @(posedge clk or posedge reset) begin
    if (reset)
      pc <= 32'd0;
    else
      pc <= pc_next;
  end

  // Clock generation
  always #5 clk = ~clk;
  // Instruction Memory
  instruction_memory instr_mem(.addr(pc),
                               .clk(clk),                               .instruction(instruction_mc_code));
// Register File
  registers reg1(
    .clk(clk),
    .rs(instruction_mc_code[25:21]),
    .rt(instruction_mc_code[20:16]),
    .rd(instruction_mc_code[15:11]),
    .write_data(MemtoReg?result:result_of_ALU),
    .RegWrite(RegWrite),
    .RegDst(RegDst),
    .read_data1(read_data1),
    .read_data2(read_data2)
  );
  //ALU CONTROLLER
  ALU_Controller AR(instruction_mc_code[5:0],ALUOp,ALU_Control);
 // ALU
  ALU alu(
    .op1(read_data1),
    .op2(read_data2),
    .ALU_Control(ALU_Control),
    .offset(instruction_mc_code[15:0]),
    .ALUSRC(ALUSRC),
    .zero_flag(zero_flag),
    .ALU_result(result_of_ALU)
  );

  // Data Memory
  data_memory data_mem(
    .address(result_of_ALU),
    .write_data(read_data2),
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    .MemtoReg(MemtoReg),
    .ALU_Result(result_of_ALU),
    .rd_data(result)
  );
  // Main Control Unit
  Main_Control_Unit main_ctrl(
    .op_code(instruction_mc_code[31:26]),
    .branch(branch),
    .MemRead(MemRead),
    .MemtoReg(MemtoReg),
    .MemWrite(MemWrite),
    .ALUSRC(ALUSRC),
    .RegWrite(RegWrite),
    .RegDst(RegDst),
    .ALUOp(ALUOp)
  );




  // Program Counter
    program_counter pp(
      .clk(clk),
      .current_pc(pc),
      .offset(instruction_mc_code[15:0]),
      .branch(branch),
      .zero(zero_flag),
      .pc_of_next_instruction(pc_next)
    );

initial begin
    clk = 0;
    reset = 1;


    #10 reset = 0; // Deassert reset after initialization





    $display("==== MIPS Processor Testbench ====");
  $display("\t\t  Time\tPC\tNext PC\t\tInstruction\tReadData1\tReadData2\tResult\t\tALUResult");

    // Test instructions
    repeat (15) begin


      // Fetch instruction
      $display("%d %h\t%h\t%h\t%h\t%h\t%h",
               $time, pc,pc_next, instruction_mc_code, read_data1, read_data2, result,result_of_ALU);

	#10; // Wait for 1 clock cycle
    end

    // Finish simulation
    #150;
    $display("Simulation complete.");
    $finish;
  end
initial begin
   $dumpfile("mips.vcd");
   $dumpvars(0, MIPS_testbench);
end
endmodule
