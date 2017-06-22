`timescale 1ns / 1ps
//*************************************************************************
//   > 文件名: mem.v
//   > 描述  :五级流水CPU的访存模块
//   > 作者  : LOONGSON
//   > 日期  : 2016-04-14
//*************************************************************************
module mem(                          // 访存级
    input              clk,          // 时钟
    input              MEM_valid,    // 访存级有效信号
    input      [156:0] EXE_MEM_bus_r,// EXE->MEM总线
    input      [ 31:0] dm_rdata,     // 访存读数据
    output     [ 31:0] dm_addr,      // 访存读写地址
    output reg [  3:0] dm_wen,       // 访存写使能
    output reg [ 31:0] dm_wdata,     // 访存写数据
    output             MEM_over,     // MEM模块执行完成
    output     [118:0] MEM_WB_bus,   // MEM->WB总线
    
    //5级流水新增接口
    input              MEM_allow_in, // MEM级允许下级进入
    output     [  4:0] MEM_wdest,    // MEM级要写回寄存器堆的目标地址号
     
    //展示PC
    output     [ 31:0] MEM_pc
);
//-----{EXE->MEM总线}begin
    //访存需要用到的load/store信息
    wire [5 :0] mem_control;  //MEM需要使用的控制信号
    wire [31:0] store_data;   //store操作的存的数据
    
    //EXE结果和HI/LO数据
    wire [31:0] exe_result;
    wire [31:0] lo_result;
    wire        hi_write;
    wire        lo_write;
    
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
    
    //pc
    wire [31:0] pc;    
    assign {mem_control,
            store_data,
            exe_result,
            lo_result,
            hi_write,
            lo_write,
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
            pc         } = EXE_MEM_bus_r;  
//-----{EXE->MEM总线}end

//-----{load/store访存}begin
//QQQ目前问题  
//不知道使用的IP有几个端口  是否有其他信号接口  到时候还需要对应  目前只完成最基础的4位字节使能端口
    wire inst_load;  //load操作
    wire inst_store; //store操作
    wire [1:0] ls_word;    //load/store为字节还是字,00:byte;10:word;01:half
    wire lb_sign;    //load一字节为有符号load
    wire lh_sign;    //load半字为有符号load
    assign {inst_load,inst_store,ls_word,lb_sign,lh_sign} = mem_control;

    //访存读写地址
    assign dm_addr = exe_result;
    
    //store操作的写使能
    always @ (*)   // 内存写使能信号 写入数据  同时修改
    begin
        if (MEM_valid && inst_store) // 访存级有效时,且为store操作
        begin
            if (ls_word == 2'b10)
            begin
                dm_wen <= 4'b1111; // 存储字指令，写使能全1
                dm_wdata <= store_data;
            end
            else if(ls_word == 2'b01)
            begin
                case (dm_addr[1:0]) //其他情况不为2的整数倍 会报异常
                    2'b00   : begin
                        dm_wen <= 4'b0011; 
                        dm_wdata <= {16'b0, store_data[15:0]};
                    end
                    2'b10   : begin
                        dm_wen <= 4'b1100;
                        dm_wdata <= {store_data[15:0], 16'b0};
                    end
                    default : dm_wen <= 4'b0000;
                endcase
            end
            else 
            begin // SB指令，需要依据地址底两位，确定对应的写使能
                case (dm_addr[1:0])
                    2'b00   : begin
                        dm_wen <= 4'b0001;
                        dm_wdata <= store_data;
                    end
                    2'b01   : begin
                        dm_wen <= 4'b0010; 
                        dm_wdata <= {16'd0, store_data[7:0], 8'd0};
                    end
                    2'b10   : begin
                        dm_wen <= 4'b0100;
                        dm_wdata <= {8'd0, store_data[7:0], 16'd0};
                    end
                    2'b11   : begin
                        dm_wen <= 4'b1000;
                        dm_wdata <= {store_data[7:0], 24'd0};
                    end
                    default : dm_wen <= 4'b0000;
                endcase
            end
        end
        else
        begin
            dm_wen <= 4'b0000;
        end
    end 
        
     //load读出的数据
     wire        load_sign;
     wire [31:0] load_result;
    assign load_sign = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7] :
                       (dm_addr[1:0]==2'd1) ? dm_rdata[15] :
                       (dm_addr[1:0]==2'd2) ? dm_rdata[23] : dm_rdata[31] ;
    always @ (*) 
    if(ls_word == 2'b10)
    begin
        load_result = dm_rdata;
    end
    else if(ls_word == 2'b01)
    begin
        assign load_result[15:0] = (dm_addr[1:0]==2'd0) ? dm_rdata[ 15:0 ] :
                                   (dm_addr[1:0]==2'd2) ? dm_rdata[31:16] ;
        
        assign load_result[31:16]= {16{lh_sign & load_sign}};   
        
    end
    else
    begin
        assign load_result[7:0] = (dm_addr[1:0]==2'd0) ? dm_rdata[ 7:0 ] :
                                   (dm_addr[1:0]==2'd1) ? dm_rdata[15:8 ] :
                                   (dm_addr[1:0]==2'd2) ? dm_rdata[23:16] :
                                                          dm_rdata[31:24] ;
        assign load_result[31:8]= {24{lb_sign & load_sign}};                                                         
    end

//-----{load/store访存}end

//-----{MEM执行完成}begin
    //由于数据RAM为同步读写的,
    //故对load指令，取数据时，有一拍延时
    //即发地址的下一拍时钟才能得到load的数据
    //故mem在进行load操作时有需要两拍时间才能取到数据
    //而对其他操作，则只需要一拍时间
    reg MEM_valid_r;
    always @(posedge clk)
    begin
        if (MEM_allow_in)
        begin
            MEM_valid_r <= 1'b0;
        end
        else
        begin
            MEM_valid_r <= MEM_valid;
        end
    end
    assign MEM_over = inst_load ? MEM_valid_r : MEM_valid;
    //如果数据ram为异步读的，则MEM_valid即是MEM_over信号，
    //即load一拍完成
//-----{MEM执行完成}end

//-----{MEM模块的dest值}begin
   //只有在MEM模块有效时，其写回目的寄存器号才有意义
    assign MEM_wdest = rf_wdest & {5{MEM_valid}};
//-----{MEM模块的dest值}end

//-----{MEM->WB总线}begin
    wire [31:0] mem_result; //MEM传到WB的result为load结果或EXE结果
    assign mem_result = inst_load ? load_result : exe_result;
    
    assign MEM_WB_bus = {rf_wen,rf_wdest,                   // WB需要使用的信号
                         mem_result,                        // 最终要写回寄存器的数据
                         lo_result,                         // 乘法低32位结果，新增
                         hi_write,lo_write,                 // HI/LO写使能，新增
                         mfhi,mflo,                         // WB需要使用的信号,新增
                         mtc0,mfc0,cp0r_addr,syscall,break,eret,  // WB需要使用的信号,新增
                         pc};                               // PC值
//-----{MEM->WB总线}end

//-----{展示MEM模块的PC值}begin
    assign MEM_pc = pc;
//-----{展示MEM模块的PC值}end
endmodule

