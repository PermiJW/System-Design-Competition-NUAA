`timescale 1ns / 1ps
//*************************************************************************
//   > �ļ���: exe.v
//   > ����  :�弶��ˮCPU��ִ��ģ��
//   > ����  : LOONGSON
//   > ����  : 2016-04-14
//*************************************************************************
module exe(                         // ִ�м�
    input              EXE_valid,   // ִ�м���Ч�ź�
    input      [172:0] ID_EXE_bus_r,// ID->EXE����
    output             EXE_over,    // EXEģ��ִ�����
    output     [156:0] EXE_MEM_bus, // EXE->MEM����
    
     //5����ˮ����
     input             clk,       // ʱ��
     output     [  4:0] EXE_wdest,   // EXE��Ҫд�ؼĴ����ѵ�Ŀ���ַ��
 
    //չʾPC
    output     [ 31:0] EXE_pc
);
//-----{ID->EXE����}begin
    //EXE��Ҫ�õ�����Ϣ
    wire multiply;         //�˷�
    wire divide;           //����
    wire sign_exe;         //�˳������޷���
    wire mthi;             //MTHI
    wire mtlo;             //MTLO
    wire [12:0] alu_control;
    wire [31:0] alu_operand1;
    wire [31:0] alu_operand2;

    //�ô���Ҫ�õ���load/store��Ϣ
    wire [5:0] mem_control;  //MEM��Ҫʹ�õĿ����ź�
    wire [31:0] store_data;  //store�����Ĵ������
                          
    //д����Ҫ�õ�����Ϣ
    wire mfhi;
    wire mflo;
    wire mtc0;
    wire mfc0;
    wire [7 :0] cp0r_addr;
    wire       syscall;   //syscall��eret��д�ؼ�������Ĳ���
    wire       break; 
    wire       eret;
    wire       rf_wen;    //д�صļĴ���дʹ��
    wire [4:0] rf_wdest;  //д�ص�Ŀ�ļĴ���
    
    //pc
    wire [31:0] pc;
    assign {multiply,
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
//-----{ID->EXE����}end

//-----{ALU}begin
    wire [31:0] alu_result;

    alu alu_module(
        .alu_control  (alu_control ),  // I, 12, ALU�����ź�
        .alu_src1     (alu_operand1),  // I, 32, ALU������1
        .alu_src2     (alu_operand2),  // I, 32, ALU������2
        .alu_result   (alu_result  )   // O, 32, ALU���
    );
//-----{ALU}end

//-----{�˷���}begin
//�˷�������ֱ��IP���� ���� * /�������㷽ʽ
//QQQ ���ڲ�ȷ���˳����Ƿ���  ������һ�������ڳ����  �Ȱ�����������  
//�̷���ǰ��  �������ں���
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

//-----{�˷���}end

//-----{EXEִ�����}begin
    //����ALU����������1�Ŀ���ɣ�
    //�����ڳ˷���������Ҫ�������
    assign EXE_over = EXE_valid     // & (~multiply | mult_end);
//-----{EXEִ�����}end

//-----{EXEģ���destֵ}begin
   //ֻ����EXEģ����Чʱ����д��Ŀ�ļĴ����Ų�������
    assign EXE_wdest = rf_wdest & {5{EXE_valid}};
//-----{EXEģ���destֵ}end

//-----{EXE->MEM����}begin
    wire [31:0] exe_result;   //��exe����ȷ��������д�ؽ��
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    //Ҫд��HI��ֵ����exe_result�����MULT��MTHIָ��,
    //Ҫд��LO��ֵ����lo_result�����MULT��MTLOָ��,
    assign exe_result = mthi     ? alu_operand1 :
                        mtc0     ? alu_operand2 : 
                        multiply ? product[63:32] : 
                        divide   ? product[63:32] : alu_result;
    assign lo_result  = mtlo ? alu_operand1 : product[31:0];
    assign hi_write   = multiply | mthi | divide;
    assign lo_write   = multiply | mtlo | divide;
    
    assign EXE_MEM_bus = {mem_control,store_data,          //load/store��Ϣ��store����
                          exe_result,                      //exe������
                          lo_result,                       //�˷���32λ���������
                          hi_write,lo_write,               //HI/LOдʹ�ܣ�����
                          mfhi,mflo,                       //WB���õ��ź�,����
                          mtc0,mfc0,cp0r_addr,syscall,break,eret,//WB���õ��ź�,����
                          rf_wen,rf_wdest,                 //WB���õ��ź�
                          pc};                             //PC
//-----{EXE->MEM����}end

//-----{չʾEXEģ���PCֵ}begin
    assign EXE_pc = pc;
//-----{չʾEXEģ���PCֵ}end
endmodule
