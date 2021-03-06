`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: decode.v
//   > 描述  :五级流水CPU的译码模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module decode(                      // 译码级
    input              ID_valid,    // 译码级有效信号
    input      [ 63:0] IF_ID_bus_r, // IF->ID总线
    input      [ 31:0] rs_value,    // 第一源操作数值
    input      [ 31:0] rt_value,    // 第二源操作数值
    output     [  4:0] rs,          // 第一源操作数地址 
    output     [  4:0] rt,          // 第二源操作数地址
    output     [ 32:0] jbr_bus,     // 跳转总线
//  output             inst_jbr,    // 指令为跳转分支指令,五级流水不需要
    output             ID_over,     // ID模块执行完成
    output     [202:0] ID_EXE_bus,  // ID->EXE总线
    
    //5级流水新增
    input              IF_over,     //对于分支指令，需要该信号
    input      [  4:0] EXE_wdest,   // EXE级要写回寄存器堆的目标地址号
    input      [  4:0] MEM_wdest,   // MEM级要写回寄存器堆的目标地址号
    input      [  4:0] WB_wdest,    // WB级要写回寄存器堆的目标地址号
    

    input             cal_r_E,
    input             cal_i_E,
    input             lui_E,
    input             mf_E,
    input             load_E,
    input             mf_M,
    input             load_M,
    input             Q,
    //展示PC
    output     [ 31:0] ID_pc
);
//-----{IF->ID总线}begin
    wire [31:0] pc;
    wire [31:0] inst;
    assign {pc, inst} = IF_ID_bus_r;  // IF->ID总线传PC和指令
//-----{IF->ID总线}end

//-----{指令译码}begin
    wire [5:0] op;       
    wire [4:0] rd;       
    wire [4:0] sa;      
    wire [5:0] funct;    
    wire [15:0] imm;     
    wire [15:0] offset;  
    wire [25:0] target;  
    wire [2:0] cp0r_sel;

    assign op     = inst[31:26];  // 操作码
    assign rs     = inst[25:21];  // 源操作数1
    assign rt     = inst[20:16];  // 源操作数2
    assign rd     = inst[15:11];  // 目标操作数
    assign sa     = inst[10:6];   // 特殊域，可能存放偏移量
    assign funct  = inst[5:0];    // 功能码
    assign imm    = inst[15:0];   // 立即数
    assign offset = inst[15:0];   // 地址偏移量
    assign target = inst[25:0];   // 目标地址
    assign cp0r_sel= inst[2:0];   // cp0寄存器的select域

    // 实现指令列表
    wire inst_ADDU, inst_SUBU , inst_SLT , inst_AND;
    wire inst_ADD , inst_SUB  , inst_ADDI, inst_DIV;
    wire inst_NOR , inst_OR   , inst_XOR , inst_SLL;
    wire inst_SRL , inst_ADDIU, inst_BEQ , inst_BNE;
    wire inst_LW  , inst_SW   , inst_LUI , inst_J;
    wire inst_SLTU, inst_JALR , inst_JR  , inst_SLLV;
    wire inst_SRA , inst_SRAV , inst_SRLV, inst_SLTIU;
    wire inst_SLTI, inst_BGEZ , inst_BGTZ, inst_BLEZ;
    wire inst_BLTZ, inst_LB   , inst_LBU , inst_SB;
    wire inst_ANDI, inst_ORI  , inst_XORI, inst_JAL;
    wire inst_MULT, inst_MFLO , inst_MFHI, inst_MTLO;
    wire inst_MTHI, inst_MFC0 , inst_MTC0;
    wire inst_MULTU, inst_DIVU;
    wire inst_LH, inst_LHU, inst_SH;
    wire inst_ERET, inst_SYSCALL, inst_BREAK;
    wire inst_BLTZAL, inst_BGEZAL;


    wire op_zero;  // 操作码全0
    wire sa_zero;  // sa域全0
    assign op_zero = ~(|op);
    assign sa_zero = ~(|sa);
    assign inst_ADDU  = op_zero & sa_zero    & (funct == 6'b100001);//无符号加法
    assign inst_SUBU  = op_zero & sa_zero    & (funct == 6'b100011);//无符号减法
    assign inst_ADD   = op_zero & sa_zero    & (funct == 6'b100000);//有符号加法
    assign inst_SUB   = op_zero & sa_zero    & (funct == 6'b100010);//有符号减法
    assign inst_SLT   = op_zero & sa_zero    & (funct == 6'b101010);//小于则置位
    assign inst_SLTU  = op_zero & sa_zero    & (funct == 6'b101011);//无符号小则置
    assign inst_JALR  = op_zero & (rt==5'd0) & (rd==5'd31)
                      & sa_zero & (funct == 6'b001001);         //跳转寄存器并链接
    assign inst_JR    = op_zero & (rt==5'd0) & (rd==5'd0 )
                      & sa_zero & (funct == 6'b001000);             //跳转寄存器
    assign inst_AND   = op_zero & sa_zero    & (funct == 6'b100100);//与运算
    assign inst_NOR   = op_zero & sa_zero    & (funct == 6'b100111);//或非运算
    assign inst_OR    = op_zero & sa_zero    & (funct == 6'b100101);//或运算
    assign inst_XOR   = op_zero & sa_zero    & (funct == 6'b100110);//异或运算
    assign inst_SLL   = op_zero & (rs==5'd0) & (funct == 6'b000000);//逻辑左移
    assign inst_SLLV  = op_zero & sa_zero    & (funct == 6'b000100);//变量逻辑左移
    assign inst_SRA   = op_zero & (rs==5'd0) & (funct == 6'b000011);//算术右移
    assign inst_SRAV  = op_zero & sa_zero    & (funct == 6'b000111);//变量算术右移
    assign inst_SRL   = op_zero & (rs==5'd0) & (funct == 6'b000010);//逻辑右移
    assign inst_SRLV  = op_zero & sa_zero    & (funct == 6'b000110);//变量逻辑右移
    assign inst_MULT  = op_zero & (rd==5'd0)
                      & sa_zero & (funct == 6'b011000);             //乘法
    assign inst_MULTU  = op_zero & (rd==5'd0)
                      & sa_zero & (funct == 6'b011001);             //无符号数乘法
    assign inst_DIV   = op_zero & (rd==5'd0)
                      & sa_zero & (funct == 6'b011010);             //除法
    assign inst_DIVU  = op_zero & (rd==5'd0)
                      & sa_zero & (funct == 6'b011011);             //无符号除法               
    assign inst_MFLO  = op_zero & (rs==5'd0) & (rt==5'd0)
                      & sa_zero & (funct == 6'b010010);             //从LO读取
    assign inst_MFHI  = op_zero & (rs==5'd0) & (rt==5'd0)
                      & sa_zero & (funct == 6'b010000);             //从HI读取
    assign inst_MTLO  = op_zero & (rt==5'd0) & (rd==5'd0)
                      & sa_zero & (funct == 6'b010011);             //向LO写数据
    assign inst_MTHI  = op_zero & (rt==5'd0) & (rd==5'd0)
                      & sa_zero & (funct == 6'b010001);             //向HI写数据
    assign inst_ADDIU = (op == 6'b001001);             //立即数无符号加法
    assign inst_ADDI  = (op == 6'b001000);			   //立即数加法
    assign inst_SLTI  = (op == 6'b001010);             //小于立即数则置位
    assign inst_SLTIU = (op == 6'b001011);             //小于立即数则置位（无符号）
    assign inst_BEQ   = (op == 6'b000100);             //判断相等跳转
    assign inst_BGEZ  = (op == 6'b000001) & (rt==5'd1);//大于等于0跳转
    assign inst_BGTZ  = (op == 6'b000111) & (rt==5'd0);//大于0跳转
    assign inst_BLEZ  = (op == 6'b000110) & (rt==5'd0);//小于等于0跳转
    assign inst_BLTZ  = (op == 6'b000001) & (rt==5'd0);//小于0跳转
    assign inst_BNE   = (op == 6'b000101);             //判断不等跳转
    assign inst_LW    = (op == 6'b100011);             //从内存装载字
    assign inst_SW    = (op == 6'b101011);             //向内存存储字
    assign inst_LB    = (op == 6'b100000);             //load字节（符号扩展）
    assign inst_LBU   = (op == 6'b100100);             //load字节（无符号扩展）
    assign inst_SB    = (op == 6'b101000);             //向内存存储字节
    assign inst_LH    = (op == 6'b100001);             //从内存装载半字（符号扩展）
    assign inst_LHU   = (op == 6'b100101);             //从内存装载半字（无符号扩展）
    assign inst_SH    = (op == 6'b101001);             //向内存存储字
    assign inst_ANDI  = (op == 6'b001100);             //立即数与
    assign inst_LUI   = (op == 6'b001111) & (rs==5'd0);//立即数装载高半字节
    assign inst_ORI   = (op == 6'b001101);             //立即数或
    assign inst_XORI  = (op == 6'b001110);             //立即数异或
    assign inst_J     = (op == 6'b000010);             //跳转
    assign inst_JAL   = (op == 6'b000011);             //跳转和链接
    assign inst_MFC0    = (op == 6'b010000) & (rs==5'd0) 
                        & sa_zero & (funct[5:3] == 3'b000); // 从cp0寄存器装载
    assign inst_MTC0    = (op == 6'b010000) & (rs==5'd4)
                        & sa_zero & (funct[5:3] == 3'b000); // 向cp0寄存器存储
    assign inst_SYSCALL = (op == 6'b000000) & (funct == 6'b001100); // 系统调用
    assign inst_ERET    = (op == 6'b010000) & (rs==5'd16) & (rt==5'd0)
                        & (rd==5'd0) & sa_zero & (funct == 6'b011000);//异常返回

    assign inst_BREAK  = (op == 6'b000000) & (funct == 6'b001101); //触发断点例外

    assign inst_BLTZAL = (op == 6'b000001)& (rt==5'b10000);//小于零跳转并将31号寄存器保存
    assign inst_BGEZAL = (op == 6'b000001)& (rt==5'b10001);//大于等于零跳转并将31号寄存器保存
            
            //缺少break bltzal bgezal的定义
    
    //跳转分支指令
    wire inst_jr;    //寄存器跳转指令
    wire inst_j_link;//链接跳转指令
    wire inst_jbr;   //所有分支跳转指令
    assign inst_jr     = inst_JALR | inst_JR;
    assign inst_j_link = inst_JAL | inst_JALR |inst_BLTZAL | inst_BGEZAL;
    assign inst_jbr = inst_J    | inst_JAL  | inst_jr
                    | inst_BEQ  | inst_BNE  | inst_BGEZ
                    | inst_BGTZ | inst_BLEZ | inst_BLTZ
                    | inst_BLTZAL | inst_BGEZAL;
        
    //load store
    wire inst_load;
    wire inst_store;
    assign inst_load  = inst_LW | inst_LB | inst_LBU | inst_LH | inst_LHU;  // load指令
    assign inst_store = inst_SW | inst_SB | inst_SH;                        // store指令
    
    //alu操作分类
    wire inst_add, inst_sub, inst_slt,inst_sltu;
    wire inst_and, inst_nor, inst_or, inst_xor;
    wire inst_sll, inst_srl, inst_sra,inst_lui;
    wire inst_overflow;

    assign inst_add = inst_ADDU | inst_ADDIU | inst_load
                    | inst_store | inst_j_link |inst_ADD
                    | inst_ADDI; 			              // 做加法
    assign inst_sub = inst_SUBU | inst_SUB;                // 减法
    assign inst_slt = inst_SLT | inst_SLTI;                // 有符号小于置位
    assign inst_sltu= inst_SLTIU | inst_SLTU;              // 无符号小于置位
    assign inst_and = inst_AND | inst_ANDI;                // 逻辑与
    assign inst_nor = inst_NOR;                            // 逻辑或非
    assign inst_or  = inst_OR  | inst_ORI;                 // 逻辑或
    assign inst_xor = inst_XOR | inst_XORI;                // 逻辑异或
    assign inst_sll = inst_SLL | inst_SLLV;                // 逻辑左移
    assign inst_srl = inst_SRL | inst_SRLV;                // 逻辑右移
    assign inst_sra = inst_SRA | inst_SRAV;                // 算术右移
    assign inst_lui = inst_LUI;                            // 立即数装载高位
    assign inst_overflow = inst_ADDI | inst_ADD |inst_SUB; // 有符号溢出
    
    //使用sa域作为偏移量的移位指令
    wire inst_shf_sa;
    assign inst_shf_sa =  inst_SLL | inst_SRL | inst_SRA;
    
    //依据立即数扩展方式分类
    wire inst_imm_zero; //立即数0扩展
    wire inst_imm_sign; //立即数符号扩展
    assign inst_imm_zero = inst_ANDI  | inst_LUI  | inst_ORI | inst_XORI;
    assign inst_imm_sign = inst_ADDIU |  inst_SLTI | inst_SLTIU
                         | inst_load | inst_store | inst_ADDI;
    
    //依据目的寄存器号分类
    wire inst_wdest_rt;  // 寄存器堆写入地址为rt的指令
    wire inst_wdest_31;  // 寄存器堆写入地址为31的指令  
    wire inst_wdest_rd;  // 寄存器堆写入地址为rd的指令
    assign inst_wdest_rt = inst_imm_zero | inst_ADDIU | inst_SLTI | inst_ADDI
                         | inst_SLTIU | inst_load | inst_MFC0;
    assign inst_wdest_31 = inst_JAL |inst_BLTZAL | inst_BGEZAL;
    assign inst_wdest_rd = inst_ADDU | inst_SUBU | inst_SLT  | inst_SLTU
                         | inst_JALR | inst_AND  | inst_NOR  | inst_OR 
                            | inst_XOR  | inst_SLL  | inst_SLLV | inst_SRA 
                         | inst_SRAV | inst_SRL  | inst_SRLV
                         | inst_MFHI | inst_MFLO | inst_ADD | inst_SUB;
                         
    //依据源寄存器号分类
    wire inst_no_rs;  //指令rs域非0，且不是从寄存器堆读rs的数据
    wire inst_no_rt;  //指令rt域非0，且不是从寄存器堆读rt的数据
    assign inst_no_rs = inst_MTC0 | inst_SYSCALL | inst_ERET | inst_BREAK;
    assign inst_no_rt = inst_ADDIU | inst_SLTI | inst_SLTIU
                      | inst_BGEZ  | inst_load | inst_imm_zero
                      | inst_J     | inst_JAL  | inst_MFC0
                      | inst_SYSCALL | inst_ADDI |inst_BLTZAL | inst_BGEZAL | inst_BREAK;
//-----{指令译码}end

//-----{分支指令执行}begin
   //bd_pc,分支跳转指令参与计算的为延迟槽指令的PC值，即当前分支指令的PC+4
    wire [31:0] bd_pc;   //延迟槽指令PC值
    assign bd_pc = pc + 3'b100;
    
    //无条件跳转
    wire        j_taken;
    wire [31:0] j_target;
    assign j_taken = inst_J | inst_JAL | inst_jr;
    //寄存器跳转地址为rs_value,其他跳转为{bd_pc[31:28],target,2'b00}
    assign j_target = inst_jr ? rs_value : {bd_pc[31:28],target,2'b00};

    //branch指令
    wire rs_equql_rt;
    wire rs_ez;
    wire rs_ltz;
    assign rs_equql_rt = (rs_value == rt_value);  // GPR[rs]==GPR[rt]
    assign rs_ez       = ~(|rs_value);            // rs寄存器值为0
    assign rs_ltz      = rs_value[31];            // rs寄存器值小于0
    wire br_taken;
    wire [31:0] br_target;
    assign br_taken = inst_BEQ  & rs_equql_rt       // 相等跳转
                    | inst_BNE  & ~rs_equql_rt      // 不等跳转
                    | (inst_BGEZ | inst_BGEZAL) & ~rs_ltz           // 大于等于0跳转
                    | inst_BGTZ & ~rs_ltz & ~rs_ez  // 大于0跳转
                    | inst_BLEZ & (rs_ltz | rs_ez)  // 小于等于0跳转
                    | (inst_BLTZ | inst_BLTZAL) & rs_ltz;           // 小于0跳转
    // 分支跳转目标地址：PC=PC+offset<<2
    assign br_target[31:2] = bd_pc[31:2] + {{14{offset[15]}}, offset};  
    assign br_target[1:0]  = bd_pc[1:0];
    
    //jump and branch指令
    wire jbr_taken;
    wire [31:0] jbr_target;
    assign jbr_taken = (j_taken | br_taken) & ID_over; 
    assign jbr_target = j_taken ? j_target : br_target;
    
    //ID到IF的跳转总线
    assign jbr_bus = {jbr_taken, jbr_target};
//-----{分支指令执行}end

//-----{ID执行完成}begin
    //由于是流水的，存在数据相关
    //wire rs_wait;
    //wire rt_wait;
    /*assign rs_wait = ~inst_no_rs & (rs!=5'd0)
                   & ( (rs==EXE_wdest) | (rs==MEM_wdest) | (rs==WB_wdest) );
    assign rt_wait = ~inst_no_rt & (rt!=5'd0)
                   & ( (rt==EXE_wdest) | (rt==MEM_wdest) | (rt==WB_wdest) );*/
    
    //对于分支跳转指令，只有在IF执行完成后，才可以算ID完成；
    //否则，ID级先完成了，而IF还在取指令，则next_pc不能锁存到PC里去，
    //那么等IF完成，next_pc能锁存到PC里去时，jbr_bus上的数据已变成无效，
    //导致分支跳转失败
    //(~inst_jbr | IF_over)即是(~inst_jbr | (inst_jbr & IF_over))
    assign ID_over = ID_valid & stall & (~inst_jbr | IF_over);
//-----{ID执行完成}end

//-----{ID->EXE总线}begin
    //这个总线其实是集中式与分布式组合的思想，虽然信号都在ID阶段生成，但是生成的每个信号只在一个阶段使用，将信号按阶段区分开，当然在每个阶段中还有信号的增添
    //EXE需要用到的信息
    wire multiply;         //乘法MULT
    wire divide;           //除法DIV
    wire sign_exe;         //乘除法有无符号数判断
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    assign multiply = inst_MULT | inst_MULTU;
    assign divide = inst_DIV | inst_DIVU;
    assign sign_exe = inst_MULT | inst_DIV;
    assign mthi     = inst_MTHI ;
    assign mtlo     = inst_MTLO;

    //ALU两个源操作数和控制信号
    wire [12:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;
    
    //所谓链接跳转是将跳转返回的PC值存放到31号寄存器里
    //在流水CPU里，考虑延迟槽，故链接跳转需要计算PC+8，存放到31号寄存器里
    assign alu_operand1 = inst_j_link ? pc : 
                          inst_shf_sa ? {27'd0,sa} : rs_value;
    assign alu_operand2 = inst_j_link ? 32'd8 :  
                          inst_imm_zero ? {16'd0, imm} :
                          inst_imm_sign ?  {{16{imm[15]}}, imm} : rt_value;
    assign alu_control = {inst_overflow,    // ALU操作码，独热编码
                          inst_add,        
                          inst_sub,
                          inst_slt,
                          inst_sltu,
                          inst_and,
                          inst_nor,
                          inst_or, 
                          inst_xor,
                          inst_sll,
                          inst_srl,
                          inst_sra,
                          inst_lui
                          };

    //访存需要用到的load/store信息
    wire       lb_sign;  //load一字节为有符号load
    wire       lh_sign;  //load半字为有符号load
    wire [1:0] ls_word;  //load/store为字节还是字还是半字,00:byte;10:word;half:01
    wire [5:0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data;  //store操作的存的数据
    assign lb_sign = inst_LB ;
    assign lh_sign = inst_LH ;
    assign ls_word = {inst_LW | inst_SW, inst_LH | inst_SH};
    assign mem_control = {inst_load,
                          inst_store,
                          ls_word,
                          lb_sign,
                          lh_sign};
                          
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作 
    wire       eret;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器
    assign syscall  = inst_SYSCALL;
    assign break    = inst_BREAK;//增加一个对于break的控制信号
    assign eret     = inst_ERET;
    assign mfhi     = inst_MFHI;
    assign mflo     = inst_MFLO;
    assign mtc0     = inst_MTC0;
    assign mfc0     = inst_MFC0;
    assign cp0r_addr= {rd,cp0r_sel};
    assign rf_wen   = inst_wdest_rt | inst_wdest_31 | inst_wdest_rd;
    assign rf_wdest = inst_wdest_rt ? rt :     //在不写寄存器堆时设置为0
                      inst_wdest_31 ? 5'd31 :  //以便能准确判断数据相关
                      inst_wdest_rd ? rd : 5'd0;
    assign store_data = rt_value;
    assign ID_EXE_bus = {
                         outsa,
                         inst_j_link,
                         rs,rt,rd,
                         cal_r_D,cal_i_D,store_D,load_D,jump_D,mt_D,CMPOp, ID_b_type,ID_b_zero,
                         mf_D,lui_D,
                         multiply,divide,sign_exe,mthi,mtlo,   //EXE需用的信息,新增
                         alu_control,alu_operand1,alu_operand2,//EXE需用的信息
                         mem_control,store_data,               //MEM需用的信号
                         mfhi,mflo,                            //WB需用的信号,新增
                         mtc0,mfc0,cp0r_addr,syscall,break,eret,     //WB需用的信号,新增
                         rf_wen, rf_wdest,                     //WB需用的信号
                         pc                                   //PC值
                        };    

//-----{ID->EXE总线}end

//-----{展示ID模块的PC值}begin
    assign ID_pc = pc;
//-----{展示ID模块的PC值}end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//stall模块
wire stall;
wire stall_cal_r;
wire stall_cal_i;
wire stall_beq;
wire stall_jump;
wire stall_load;
wire stall_store;
wire stall_mt;

wire cal_r_D;
wire cal_i_D;
wire store_D;
wire load_D;
wire jump_D;
wire mt_D;
wire beq_D;
wire mf_D;
wire lui_D;

wire ID_b_type;
wire ID_b_zero;
wire [4:0] outsa;
wire sl;

assign sl = inst_sll | inst_srl | inst_sra ;
assign jump_D = inst_jr;
assign cal_r_D = inst_ADD | inst_ADDU | inst_SUB |inst_SUBU |inst_SLTU | inst_SLT | inst_DIV |inst_DIVU | inst_MULT | inst_MULTU | inst_AND |inst_NOR |inst_OR | inst_XOR | inst_SLLV |inst_SLL |inst_SRAV |inst_SRA | inst_SRLV |inst_SRL;
assign cal_i_D = inst_ADDI | inst_ADDIU | inst_SLTIU | inst_SLTI | inst_ANDI |inst_ORI | inst_XORI;
assign beq_D = inst_BEQ | inst_BNE |inst_BGEZ |inst_BGTZ |inst_BLEZ |inst_BLTZ |inst_BGEZAL |inst_BLTZAL;
assign load_D = inst_LB | inst_LBU | inst_LH |inst_LHU |inst_LW;
assign store_D = inst_SB |inst_SH |inst_SW;
assign mt_D = inst_MTHI |inst_MTLO ;
assign lui_D = inst_LUI;
assign mf_D = inst_MFLO | inst_MFHI;
assign ID_b_type = inst_BEQ | inst_BNE;
assign ID_b_zero = inst_BGEZ | inst_BGTZ |inst_BLEZ |inst_BLTZ |inst_BGEZAL |inst_BLTZAL;

assign stall_beq = beq_D & ( (cal_r_E & ((rs == EXE_wdest) | (rt == EXE_wdest))) | 
                             (cal_i_E & ((rs == EXE_wdest) | (rt == EXE_wdest))) | 
                             (lui_E   & ((rs == EXE_wdest) | (rt == EXE_wdest))) |
                             (mf_E    & ((rs == EXE_wdest) | (rt == EXE_wdest))) | 
                             (load_E  & ((rs == EXE_wdest) | (rt == EXE_wdest))) |
                             (mf_M    & ((rs == MEM_wdest) | (rt == MEM_wdest))) |
                             (load_M  & ((rs == MEM_wdest) | (rt == MEM_wdest)))
                           );

assign stall_cal_r  = cal_r_D & (
                                  (mf_E    & ((rs == EXE_wdest) | (rt == EXE_wdest))) |
                                  (load_E  & ((rs == EXE_wdest) | (rt == EXE_wdest))) 
                                ); 
assign stall_cal_i  = cal_i_D & (
                                  (mf_E    & (rs == EXE_wdest)) |
                                  (load_E  & (rs == EXE_wdest)) 
                                );
assign stall_load   = load_D  & (
                                  (mf_E    & (rs == EXE_wdest)) |
                                  (load_E  & (rs == EXE_wdest))    
                                );
assign stall_store  = store_D & (
                                  (mf_E    & (rs == EXE_wdest)) |
                                  (load_E  & (rs == EXE_wdest))    
                                );
assign stall_jump   = jump_D  & (
                                    (cal_r_E & (rs == EXE_wdest)) | 
                                    (cal_i_E & (rs == EXE_wdest)) | 
                                    (lui_E   & (rs == EXE_wdest)) |
                                    (mf_E    & (rs == EXE_wdest)) | 
                                    (load_E  & (rs == EXE_wdest)) |
                                    (mf_M    & (rs == MEM_wdest)) |
                                    (load_M  & (rs == MEM_wdest))
                                );
assign  stall_mt    = mt_D    & (
                                    (cal_r_E & (rs == EXE_wdest)) | 
                                    (cal_i_E & (rs == EXE_wdest)) | 
                                    (lui_E   & (rs == EXE_wdest)) |
                                    (mf_E    & (rs == EXE_wdest)) | 
                                    (load_E  & (rs == EXE_wdest)) |
                                    (mf_M    & (rs == MEM_wdest)) |
                                    (load_M  & (rs == MEM_wdest))
                                );
assign stall =  stall_cal_r | stall_cal_i | stall_beq | stall_jump | stall_load | stall_store | stall_mt;

assign outsa =  (sl) ? sa : 5'b0;
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign CMPOp =  inst_BEQ  ? 3'b000 :
                inst_BNE  ? 3'b001 :
                inst_BLEZ ? 3'b010 :
                inst_BGTZ ? 3'b011 :
                inst_BLTZ ? 3'b100 :
                inst_BGEZ ? 3'b101 :
                inst_BLTZAL? 3'b110:
                inst_BGEZAL? 3'b111;
wire PCSel;
wire Flush;

assign PCSel = ( inst_jr  )                                 ? 2 :
               ( inst_J    ||  inst_JAL ||  (beq_D && Q ))  ? 1 : 
                                                              0 ;
assign Flush = (PCSel == 1)||(PCSel == 2);




endmodule
