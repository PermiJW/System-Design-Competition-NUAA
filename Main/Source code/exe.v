`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: exe.v
//   > 描述  :五级流水CPU的执行模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module exe(                         // 执行级
    input              EXE_valid,   // 执行级有效信号
    input      [202:0] ID_EXE_bus_r,// ID->EXE总线
    output             EXE_over,    // EXE模块执行完成
    output     [180:0] EXE_MEM_bus, // EXE->MEM总线
    
     //5级流水新增
     input             clk,       // 时钟
     output     [  4:0] EXE_wdest,   // EXE级要写回寄存器堆的目标地址号
 
    //展示PC
    output     [ 31:0] EXE_pc
    //转发
    output             cal_r_E,
    output             cal_i_E,
    output             lui_E,
    output             mf_E,
    output             load_E
);
//-----{ID->EXE总线}begin
    //EXE需要用到的信息
    wire multiply;         //乘法
    wire divide;           //除法
    wire sign_exe;         //乘除法有无符号
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire [12:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;

    //访存需要用到的load/store信息
    wire [5:0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data;  //store操作的存的数据
                          
    //写回需要用到的信息
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall和eret在写回级有特殊的操作
    wire       break; 
    wire       eret;
    wire       rf_wen;    //写回的寄存器写使能
    wire [4:0] rf_wdest;  //写回的目的寄存器

    //转发
    wire [4:0] rs;
    wire [4:0] rt;
    wire [4:0] rd;
    wire       cal_r_E;
    wire       cal_i_E;
    wire       store_E;
    wire       load_E;
    wire       jump_E;
    wire       mt_E;
    wire [2:0] beq_E;
    wire       b_type;
    wire       b_zero;
    wire       mf_E;
    wire       lui_E;
    wire       inst_j_link_E;
    wire       sa;    
    
    //pc
    wire [31:0] pc;
    assign {
            sa,
            inst_j_link_E,
            rs,rt,rd,
            cal_r_E,cal_i_E,store_E,load_E,jump_E,mt_E,beq_E,b_type,b_zero,mf_E,lui_E,        
            multiply,
            divide,
            sign_exe,
            mthi,
            mtlo,
            alu_control,
            alu_operand1,
            alu_operand2,
            mem_control,
            store_data,
            mfhi,
            mflo,
            mtc0,
            mfc0,
            cp0r_addr,
            syscall,
            break,
            eret,
            rf_wen,
            rf_wdest,
            pc          } = ID_EXE_bus_r;
//-----{ID->EXE总线}end

//-----{ALU}begin
    wire [31:0] alu_result;

    alu alu_module(
        .alu_control  (alu_control ),  // I, 12, ALU控制信号
        .alu_src1     (alu_operand1),  // I, 32, ALU操作数1
        .alu_src2     (alu_operand2),  // I, 32, ALU操作数2
        .alu_result   (alu_result  )   // O, 32, ALU结果
    );
//-----{ALU}end

//-----{乘法器}begin
//乘法器采用直接IP调用 利用 * /两种运算方式
//QQQ 现在不确定乘除法是否并行  可以在一个周期内出结果  先按可以来进行  
//商放在前面  余数放在后面
//   wire        mult_begin; 
//   wire        mult_end;
    wire [63:0] product; 

    wire [65:0] Unproduct;
    wire [32:0] Unalu_operand1;
    wire [32:0] Unalu_operand2;

    assign Unalu_operand1 = {1'd0,alu_operand1};
    assign Unalu_operand2 = {1'd0,alu_operand2};

    always @ (*) 
    begin
        if(sign_exe)
        begin
            if(multiply)
            begin
                assign product = alu_operand1 * alu_operand2;
            end
            if(divide)
            begin
                assign product = alu_operand1 / alu_operand2;
            end
        end
        else
        begin
            if(multiply)
            begin
                assign Unproduct = Unalu_operand1 * Unalu_operand2;
                assign product = Unproduct[63:0];
            end
            if(divide)
            begin
                assign Unproduct = Unalu_operand1 / Unalu_operand2;
                assign product = Unproduct[63:0];
            end
        end
    end

//-----{乘法器}end

//-----{EXE执行完成}begin
    //对于ALU操作，都是1拍可完成，
    //但对于乘法操作，需要多拍完成
    assign EXE_over = EXE_valid     // & (~multiply | mult_end);
//-----{EXE执行完成}end

//-----{EXE模块的dest值}begin
   //只有在EXE模块有效时，其写回目的寄存器号才有意义
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXE模块的dest值}end

//-----{EXE->MEM总线}begin
    wire [31:0] exe_result;   //在exe级能确定的最终写回结果
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    //要写入HI的值放在exe_result里，包括MULT和MTHI指令,
    //要写入LO的值放在lo_result里，包括MULT和MTLO指令,
    assign exe_result = mthi     ? alu_operand1 :
                        mtc0     ? alu_operand2 : 
                        multiply ? product[63:32] : 
                        divide   ? product[63:32] : alu_result;
    assign lo_result  = mtlo ? alu_operand1 : product[31:0];
    assign hi_write   = multiply | mthi | divide;
    assign lo_write   = multiply | mtlo | divide;
    
    assign EXE_MEM_bus = {
                          inst_j_link_E,
                          rs,rt,rd,
                          cal_r_E,cal_i_E,store_E,load_E,jump_E,mt_E,mf_E,lui_E,        
                          mem_control,store_data,          //load/store信息和store数据
                          exe_result,                      //exe运算结果
                          lo_result,                       //乘法低32位结果，新增
                          hi_write,lo_write,               //HI/LO写使能，新增
                          mfhi,mflo,                       //WB需用的信号,新增
                          mtc0,mfc0,cp0r_addr,syscall,break,eret,//WB需用的信号,新增
                          rf_wen,rf_wdest,                 //WB需用的信号
                          pc};                             //PC
//-----{EXE->MEM总线}end

//-----{展示EXE模块的PC值}begin
    assign EXE_pc = pc;
//-----{展示EXE模块的PC值}end
endmodule
