module demo_1(
   input clk,
   input rst,
   input zero,
   input fast,
   input slow,
   inout wire PS2_DATA,
   inout wire PS2_CLK,
   output [3:0] vgaRed,
   output [3:0] vgaGreen,
   output [3:0] vgaBlue,
   output hsync,
   output vsync,
   output audio_mclk, // master clock
   output audio_lrck, // left-right clock
   output audio_sck,  // serial clock
   output audio_sdin, // serial audio data input
   output wire [3:0] DIGIT,
   output wire [6:0] DISPLAY
    );
    //reg [15:0] nums1;
    wire [15:0] nums;
    wire clk_25MHz;
    wire valid;
    wire [9:0] h_cnt; //640
    wire [9:0] v_cnt;  //480
    reg [13:0] my_cnt;
    wire [13:0] my_cnt2;
    
    wire [511:0] key_down;
    wire [8:0] last_change;
    wire been_ready;
    assign my_cnt2=my_cnt-1;
    
    reg myclk;
    
    clock_divider #(.n(2)) clock_2(.clk(clk), .clk_div(clk_25MHz));
    clock_divider #(.n(19)) clock_19(.clk(clk), .clk_div(clkDiv19));
    clock_divider #(.n(18)) clock_18(.clk(clk), .clk_div(clkDiv18));
    clock_divider #(.n(20)) clock_20(.clk(clk), .clk_div(clkDiv20));
    
    always@(*)begin
        if(fast && !slow) myclk = clkDiv18;
        else if(slow && !fast) myclk = clkDiv20;
        else if(fast && slow) myclk = clkDiv19;
        else myclk=clkDiv19;
    end
    
    always@(posedge myclk)begin
        if(zero||my_cnt==0) my_cnt<=14'b10100101100100;
        else begin
            my_cnt<=my_cnt2;
        end
        //nums1<=(my_cnt+420)/60;
    end
    
    // Internal Signal
    wire [15:0] audio_in_left, audio_in_right;

    wire [11:0] ibeatNum;               // Beat counter
    wire [31:0] freqL, freqR;           // Raw frequency, produced by music module
    wire [21:0] freq_outL, freq_outR;    // Processed frequency, adapted to the clock rate of Basys3
    // clkDiv22
    wire clkDiv22, clkDiv15;
    clock_divider #(.n(22)) clock_22(.clk(clk), .clk_div(clkDiv22)); 
    clock_divider #(.n(15)) clock_15(.clk(clk), .clk_div(clkDiv15));    // for keyboard and audio   // for keyboard and audio
    
    KeyboardDecoder key_de (
		.key_down(key_down),
		.last_change(last_change),
		.key_valid(been_ready),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);
	
   pixel_gen pixel_gen_inst(
       .zero(zero),
       .key_down(key_down),
	   .last_change(last_change),
       .my_cnt(my_cnt),
       .v_cnt(v_cnt),
       .h_cnt(h_cnt),
       .valid(valid),
       .vgaRed(vgaRed),
       .vgaGreen(vgaGreen),
       .vgaBlue(vgaBlue),
        .toneL(freqL),
        .toneR(freqR)
    );

    vga_controller   vga_inst(
      .pclk(clk_25MHz),
      .reset(rst),
      .hsync(hsync),
      .vsync(vsync),
      .valid(valid),
      .h_cnt(h_cnt),
      .v_cnt(v_cnt)
    );
    
    
//    assign nums[15:12]=nums1/1000;
//    assign nums[11:8]=(nums1%1000)/100;
//    assign nums[7:4]=((nums1%1000)%100)/10;
//    assign nums[3:0]=(nums1%1000)%10;
    assign nums=(my_cnt+420)/60-7;
    
    SevenSegment S0(
	.nums(nums),
	.rst(rst),
	.clk(clk),
	.DISPLAY(DISPLAY),
	.DIGIT(DIGIT)
    );
    
//    my_player_control #(.LEN(512)) playerCtrl_00 ( 
//    .clk(clkDiv22),
//    .reset(rst),
//    .ibeat(ibeatNum)  
//    );
   // Note generation
// [in]  processed frequency
// [out] audio wave signal (using square wave here)
    note_gen noteGen_00(
        .clk(clk), 
        .rst(rst), 
        .volume(3'd5),
        .note_div_left(freq_outL), 
        .note_div_right(freq_outR), 
        .audio_left(audio_in_left),     // left sound audio
        .audio_right(audio_in_right)    // right sound audio
    );  
     
    // Speaker controller
    speaker_control sc(
        .clk(clk), 
        .rst(rst), 
        .audio_in_left(audio_in_left),      // left channel audio data input
        .audio_in_right(audio_in_right),    // right channel audio data input
        .audio_mclk(audio_mclk),            // master clock
        .audio_lrck(audio_lrck),            // left-right clock
        .audio_sck(audio_sck),              // serial clock
        .audio_sdin(audio_sdin)             // serial audio data input
    ); 
    
   // freq_outL, freq_outR
// Note gen makes no sound, if freq_out = 50000000 / `silence = 1
assign freq_outL = 50000000 / freqL;
assign freq_outR = 50000000 / freqR;
     
endmodule
`define c   32'd262   // C3
`define d   32'd294
`define e   32'd330
`define f   32'd349
`define g   32'd392   // G3
`define a   32'd440
`define b   32'd494   // B3
`define hc  32'd523   // C4
`define hd  32'd587   // D4
`define he  32'd659   // E4
`define hf  32'd698   // F4
`define hg  32'd784   // G4
`define ha  32'd880   // G4

`define sil   32'd50000000 // slience
module pixel_gen(
   input zero,
   input [511:0] key_down,
   input [8:0] last_change,
   input [13:0] my_cnt,
   input [9:0] v_cnt,
   input [9:0] h_cnt,
   input valid,
   output reg [3:0] vgaRed,
   output reg [3:0] vgaGreen,
   output reg [3:0] vgaBlue,
   
   //audio
   output reg [31:0] toneL,
   output reg [31:0] toneR
   );
   
parameter black=2'd0;
parameter white=2'd1;
reg [3:0] my_music[0:300];
reg [300:0] used1=301'd0;
reg [300:0] used2=301'd0;
reg [300:0] used3=301'd0;
reg [300:0] used4=301'd0;
reg [300:0] used5=301'd0;
       initial begin
            toneL = `sil;
            toneR = `sil;
            my_music[0]=5;my_music[1]=5;
            my_music[2]=5;my_music[3]=5;
            my_music[4]=5;my_music[5]=5;
            my_music[6]=5;my_music[7]=5;
            my_music[8]=5;my_music[9]=5;
            my_music[10]=5;my_music[11]=5;
            my_music[12]=5;my_music[13]=5;
            my_music[14]=5;my_music[15]=5;
            my_music[16]=4;my_music[17]=3;
            my_music[18]=1;my_music[19]=5;
            my_music[20]=4;my_music[21]=5;
            my_music[22]=1;my_music[23]=2;
            my_music[24]=3;
            my_music[25]=5;my_music[26]=5;
            my_music[27]=5;my_music[28]=3;
            my_music[29]=4;my_music[30]=5;
            my_music[31]=1;my_music[32]=0;
            my_music[33]=5;my_music[34]=0;
            my_music[35]=5;my_music[36]=1;
            my_music[37]=0;my_music[38]=4;
            my_music[39]=5;my_music[40]=5;
            my_music[41]=5;my_music[42]=2;
            my_music[43]=4;my_music[44]=1;
            my_music[45]=4;my_music[46]=2;
            my_music[47]=1;my_music[48]=3;
            my_music[49]=5;my_music[50]=0;
            my_music[51]=2;my_music[52]=1;
            my_music[53]=5;my_music[54]=0;
            my_music[55]=4;my_music[56]=5;
            my_music[57]=3;my_music[58]=2;
            my_music[59]=5;my_music[60]=2;
            my_music[61]=0;my_music[62]=5;
            my_music[63]=5;my_music[64]=0;
            my_music[65]=1;my_music[66]=5;
            my_music[67]=3;my_music[68]=4;
            my_music[69]=5;my_music[70]=1;
            my_music[71]=2;my_music[72]=5;
            my_music[73]=4;my_music[74]=5;
            my_music[75]=1;my_music[76]=5;
            my_music[77]=3;my_music[78]=5;
            my_music[79]=5;my_music[80]=5;
            my_music[81]=2;my_music[82]=1;
            my_music[83]=0;my_music[84]=2;
            my_music[85]=0;my_music[86]=4;
            my_music[87]=0;my_music[88]=3;
            my_music[89]=3;my_music[90]=2;
            my_music[91]=2;my_music[92]=5;
            my_music[93]=5;my_music[94]=1;
            my_music[95]=3;my_music[96]=5;
            my_music[97]=5;my_music[98]=4;
            my_music[99]=2;my_music[100]=4;
            my_music[101]=1;my_music[102]=5;
            my_music[103]=2;my_music[104]=5;
            my_music[105]=2;my_music[106]=5;
            my_music[107]=0;my_music[108]=5;
            my_music[109]=2;my_music[110]=5;
            my_music[111]=4;my_music[112]=5;
            my_music[113]=3;my_music[114]=1;
            my_music[115]=5;my_music[116]=3;
            my_music[117]=1;my_music[118]=5;
            my_music[119]=1;my_music[120]=2;
            my_music[121]=5;my_music[122]=5;
            my_music[123]=5;my_music[124]=5;
            my_music[125]=1;my_music[126]=2;
            my_music[127]=5;my_music[128]=3;
            my_music[129]=1;my_music[130]=5;
            my_music[131]=1;my_music[132]=0;
            my_music[133]=5;my_music[134]=3;
            my_music[135]=5;my_music[136]=4;
            my_music[137]=5;my_music[138]=2;
            my_music[139]=5;my_music[140]=5;
            my_music[141]=5;my_music[142]=2;
            my_music[143]=2;my_music[144]=3;
            my_music[145]=1;my_music[146]=4;
            my_music[147]=1;my_music[148]=0;
            my_music[149]=4;my_music[150]=0;
            my_music[151]=2;my_music[152]=3;
            
       end
       
       always @(*) begin
       if(used1[(my_cnt+420)/60]==1||used2[(my_cnt+420)/60]==1||used3[(my_cnt+420)/60]==1||used4[(my_cnt+420)/60]==1||used5[(my_cnt+420)/60]==1)begin
       case((my_cnt+420)/60)
       152:begin
       toneR = `hf;
       toneL = `hf;
       end
       151:begin
       toneR = `hf;
       toneL = `hf;
       end
       150:begin
       toneR = `hf;
       toneL = `hf;
       end
       149:begin
       toneR = `hf;
       toneL = `hf;
       end
       148:begin
       toneR = `hf;
       toneL = `hf;
       end
       147:begin
       toneR = `hf;
       toneL = `hf;
       end
       146:begin
       toneR = `hf;
       toneL = `hf;
       end
       145:begin
       toneR = `he;
       toneL = `he;
       end
       144:begin
       toneR = `hd;
       toneL = `hd;
       end
       143:begin
       toneR = `he;
       toneL = `he;
       end
       142:begin
       toneR = `he;
       toneL = `he;
       end
       138:begin
       toneR = `g;
       toneL = `g;
       end
       136:begin
       toneR = `hc;
       toneL = `hc;
       end
       134:begin
       toneR = `ha;
       toneL = `ha;
       end
       132:begin
       toneR = `ha;
       toneL = `ha;
       end
       131:begin
       toneR = `hg;
       toneL = `hg;
       end
       129:begin
       toneR = `hg;
       toneL = `hg;
       end
       128:begin
       toneR = `hg;
       toneL = `hg;
       end
       126:begin
       toneR = `he;
       toneL = `he;
       end
       125:begin
       toneR = `hg;
       toneL = `hg;
       end
       120:begin
       toneR = `he;
       toneL = `he;
       end
       119:begin
       toneR = `hf;
       toneL = `hf;
       end
       117:begin
       toneR = `hg;
       toneL = `hg;
       end
       116:begin
       toneR = `hg;
       toneL = `hg;
       end
       114:begin
       toneR = `hf;
       toneL = `hf;
       end
       113:begin
       toneR = `hf;
       toneL = `hf;
       end
       111:begin
       toneR = `he;
       toneL = `he;
       end
       109:begin
       toneR = `hd;
       toneL = `hd;
       end
       107:begin
       toneR = `g;
       toneL = `g;
       end
       105:begin
       toneR = `hc;
       toneL = `hc;
       end
       103:begin
       toneR = `hg;
       toneL = `hg;
       end
       101:begin
       toneR = `hg;
       toneL = `hg;
       end
       100:begin
       toneR = `hf;
       toneL = `hf;
       end
       99:begin
       toneR = `hf;
       toneL = `hf;
       end
       98:begin
       toneR = `he;
       toneL = `he;
       end
       95:begin
       toneR = `hf;
       toneL = `hf;
       end
       94:begin
       toneR = `hd;
       toneL = `hd;
       end
       84:begin
       toneR = `he;
       toneL = `he;
       end
       83:begin
       toneR = `hd;
       toneL = `hd;
       end
       82:begin
       toneR = `he;
       toneL = `he;
       end
       81:begin
       toneR = `he;
       toneL = `he;
       end
       77:begin
       toneR = `g;
       toneL = `g;
       end
       75:begin
       toneR = `hc;
       toneL = `hc;
       end
       73:begin
       toneR = `ha;
       toneL = `ha;
       end
       71:begin
       toneR = `ha;
       toneL = `ha;
       end
       70:begin
       toneR = `hg;
       toneL = `hg;
       end
       68:begin
       toneR = `hg;
       toneL = `hg;
       end
       67:begin
       toneR = `hg;
       toneL = `hg;
       end
       65:begin
       toneR = `he;
       toneL = `he;
       end
       64:begin
       toneR = `hg;
       toneL = `hg;
       end
       61:begin
       toneR = `he;
       toneL = `he;
       end
       60:begin
       toneR = `hf;
       toneL = `hf;
       end
       58:begin
       toneR = `hg;
       toneL = `hg;
       end
       57:begin
       toneR = `hg;
       toneL = `hg;
       end
       55:begin
       toneR = `hf;
       toneL = `hf;
       end
       54:begin
       toneR = `hf;
       toneL = `hf;
       end
       52:begin
       toneR = `a;
       toneL = `a;
       end
       51:begin
       toneR = `hc;
       toneL = `hc;
       end
       50:begin
       toneR = `hg;
       toneL = `hg;
       end
       48:begin
       toneR = `hg;
       toneL = `hg;
       end
       47:begin
       toneR = `hf;
       toneL = `hf;
       end
       46:begin
       toneR = `he;
       toneL = `he;
       end
       45:begin
       toneR = `he;
       toneL = `he;
       end
       44:begin
       toneR = `hf;
       toneL = `hf;
       end
       43:begin
       toneR = `hd;
       toneL = `hd;
       end
       42:begin
       toneR = `hd;
       toneL = `hd;
       end
       38:begin
       toneR = `hd;
       toneL = `hd;
       end
       37:begin
       toneR = `he;
       toneL = `he;
       end
       36:begin
       toneR = `hf;
       toneL = `hf;
       end
       34:begin
       toneR = `he;
       toneL = `he;
       end
       32:begin
       toneR = `hd;
       toneL = `hd;
       end
       31:begin
       toneR = `hd;
       toneL = `hd;
       end
       29:begin
       toneR = `hc;
       toneL = `hc;
       end
       28:begin
       toneR = `hc;
       toneL = `hc;
       end
       24:begin
       toneR = `hd;
       toneL = `hd;
       end
       23:begin
       toneR = `he;
       toneL = `he;
       end
       22:begin
       toneR = `hf;
       toneL = `hf;
       end
       20:begin
       toneR = `he;
       toneL = `he;
       end
       18:begin
       toneR = `hd;
       toneL = `hd;
       end
       17:begin
       toneR = `hc;
       toneL = `hc;
       end
       16:begin
       toneR = `hc;
       toneL = `hc;
       end
       default:begin
       toneR = `hf;
       toneL = `hf;
       end
       endcase
       end
       else begin
       toneR = `sil;
       toneL = `sil;
       end
       if(!valid)
             {vgaRed, vgaGreen, vgaBlue} = 12'h0;
        else if(h_cnt<3) {vgaRed, vgaGreen, vgaBlue} = 12'h099;
        else if(h_cnt>630) {vgaRed, vgaGreen, vgaBlue} = 12'h099;
        else if(h_cnt < 128&& h_cnt>0)begin //°ò·Ç½u§PÂ_
            if(v_cnt<=421&&v_cnt>=419)begin
            if(key_down[last_change]==1&&last_change==9'b0_0010_0011&&used1[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'h00f;
            else if(key_down[last_change]==1&&last_change==9'b0_0010_0011) {vgaRed, vgaGreen, vgaBlue} = 12'hf00;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hfff;
            end
            else if(v_cnt<3||v_cnt>476) {vgaRed, vgaGreen, vgaBlue} = 12'h099;
            else if(((my_cnt+v_cnt)/60)<153)begin
                if(my_music[(my_cnt+v_cnt)/60]==0)begin
                    if(((my_cnt+v_cnt)/60)==(my_cnt+420)/60)begin
                        if(key_down[last_change]==1&&last_change==9'b0_0010_0011&&(used1[(my_cnt+v_cnt)/60]==0)) begin
                            used1[(my_cnt+v_cnt)/60]=1;
                            toneR = `hf;
                            toneL = `hf;
                            end
                        if(key_down[last_change]==1&&last_change==9'b0_0010_0011&&used1[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                        else if(used1[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                        else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                   end
                   else if(key_down[last_change]==1&&last_change==9'b0_0010_0011&&used1[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                   else if(used1[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                   else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                end
                else if(key_down[last_change]==1&&last_change==9'b0_0010_0011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
            end
            else if(key_down[last_change]==1&&last_change==9'b0_0010_0011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
             end
        else if(h_cnt < 256)begin
        if(v_cnt<=421&&v_cnt>=419)begin
            if(key_down[last_change]==1&&last_change==9'b0_0010_1011&&used2[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'h00f;
            else if(key_down[last_change]==1&&last_change==9'b0_0010_1011) {vgaRed, vgaGreen, vgaBlue} = 12'hf00;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hfff;
            end
        else if(v_cnt<3||v_cnt>476) {vgaRed, vgaGreen, vgaBlue} = 12'h099;
        else if(((my_cnt+v_cnt)/60)<153)begin
                if(my_music[(my_cnt+v_cnt)/60]==1)begin
                    if(((my_cnt+v_cnt)/60)==(my_cnt+420)/60)begin
                        if(key_down[last_change]==1&&last_change==9'b0_0010_1011&&(used2[(my_cnt+v_cnt)/60]==0)) begin
                            used2[(my_cnt+v_cnt)/60]=1;
                            end
                        if(key_down[last_change]==1&&last_change==9'b0_0010_1011&&used2[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                        else if(used2[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                        else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                    end
                    else if(key_down[last_change]==1&&last_change==9'b0_0010_1011&&used2[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                    else if(used2[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                    else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                end
                else if(key_down[last_change]==1&&last_change==9'b0_0010_1011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
            end
            else if(key_down[last_change]==1&&last_change==9'b0_0010_1011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
        end
             
        else if(h_cnt < 384)begin
        if(v_cnt<=421&&v_cnt>=419)begin
            if(key_down[last_change]==1&&last_change==9'b0_0011_0100&&used3[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'h00f;
            else if(key_down[last_change]==1&&last_change==9'b0_0011_0100) {vgaRed, vgaGreen, vgaBlue} = 12'hf00;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hfff;
            end
        else if(v_cnt<3||v_cnt>476) {vgaRed, vgaGreen, vgaBlue} = 12'h099;
        else if(((my_cnt+v_cnt)/60)<153)begin
                if(my_music[(my_cnt+v_cnt)/60]==2)begin
                    if(((my_cnt+v_cnt)/60)==(my_cnt+420)/60)begin
                        if(key_down[last_change]==1&&last_change==9'b0_0011_0100&&(used3[(my_cnt+v_cnt)/60]==0)) begin
//                            {vgaRed, vgaGreen, vgaBlue} = 12'hf00;
                        used3[(my_cnt+v_cnt)/60]=1;
                        end
                        if(key_down[last_change]==1&&last_change==9'b0_0011_0100&&used3[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                        else if(used3[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                        else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                    end
                    else if(key_down[last_change]==1&&last_change==9'b0_0011_0100&&used3[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                    else if(used3[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                    else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                end
                else if(key_down[last_change]==1&&last_change==9'b0_0011_0100) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
            end
            else if(key_down[last_change]==1&&last_change==9'b0_0011_0100) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
             end
        else if(h_cnt < 512)begin
        if(v_cnt<=421&&v_cnt>=419)begin
            if(key_down[last_change]==1&&last_change==9'b0_0011_0011&&used4[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'h00f;
            else if(key_down[last_change]==1&&last_change==9'b0_0011_0011) {vgaRed, vgaGreen, vgaBlue} = 12'hf00;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hfff;
            end
        else if(v_cnt<3||v_cnt>476) {vgaRed, vgaGreen, vgaBlue} = 12'h099;
        else if(((my_cnt+v_cnt)/60)<153)begin
                if(my_music[(my_cnt+v_cnt)/60]==3)begin
                    if(((my_cnt+v_cnt)/60)==(my_cnt+420)/60)begin
                        if(key_down[last_change]==1&&last_change==9'b0_0011_0011&&(used4[(my_cnt+v_cnt)/60]==0)) begin
                        used4[(my_cnt+v_cnt)/60]=1;
                        end
                        if(key_down[last_change]==1&&last_change==9'b0_0011_0011&&used4[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                        else if(used4[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                        else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                    end
                    else if(key_down[last_change]==1&&last_change==9'b0_0011_0011&&used4[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                    else if(used4[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                    else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                end
                else if(key_down[last_change]==1&&last_change==9'b0_0011_0011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
            end
            else if(key_down[last_change]==1&&last_change==9'b0_0011_0011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
            end              
        else if(h_cnt < 640)begin
        if(v_cnt<=421&&v_cnt>=419)begin
            if(key_down[last_change]==1&&last_change==9'b0_0011_1011&&used5[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'h00f;
            else if(key_down[last_change]==1&&last_change==9'b0_0011_1011) {vgaRed, vgaGreen, vgaBlue} = 12'hf00;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hfff;
            end
        else if(v_cnt<3||v_cnt>476) {vgaRed, vgaGreen, vgaBlue} = 12'h099;
        else if(((my_cnt+v_cnt)/60)<153)begin
                if(my_music[(my_cnt+v_cnt)/60]==4)begin
                    if(((my_cnt+v_cnt)/60)==(my_cnt+420)/60)begin
                        if(key_down[last_change]==1&&last_change==9'b0_0011_1011&&(used5[(my_cnt+v_cnt)/60]==0)) begin
                        used5[(my_cnt+v_cnt)/60]=1;
                        end
                        if(key_down[last_change]==1&&last_change==9'b0_0011_1011&&used5[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                        else if(used5[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                        else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                    end
                    else if(key_down[last_change]==1&&last_change==9'b0_0011_1011&&used5[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                    else if(used5[(my_cnt+v_cnt)/60]==1) {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
                    else {vgaRed, vgaGreen, vgaBlue} = 12'h000;
                end
                else if(key_down[last_change]==1&&last_change==9'b0_0011_1011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
                else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
            end
            else if(key_down[last_change]==1&&last_change==9'b0_0011_1011) {vgaRed, vgaGreen, vgaBlue} = 12'hf0a;
            else {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
             end
        else
             {vgaRed, vgaGreen, vgaBlue} = 12'hf0f;
   end
endmodule
`timescale 1ns/1ps
/////////////////////////////////////////////////////////////////
// Module Name: vga
/////////////////////////////////////////////////////////////////

module vga_controller (
    input wire pclk, reset,
    output wire hsync, vsync, valid,
    output wire [9:0]h_cnt,
    output wire [9:0]v_cnt
    );

    reg [9:0]pixel_cnt;
    reg [9:0]line_cnt;
    reg hsync_i,vsync_i;

    parameter HD = 640;
    parameter HF = 16;
    parameter HS = 96;
    parameter HB = 48;
    parameter HT = 800; 
    parameter VD = 480;
    parameter VF = 10;
    parameter VS = 2;
    parameter VB = 33;
    parameter VT = 525;
    parameter hsync_default = 1'b1;
    parameter vsync_default = 1'b1;

    always @(posedge pclk)
        if (reset)
            pixel_cnt <= 0;
        else
            if (pixel_cnt < (HT - 1))
                pixel_cnt <= pixel_cnt + 1;
            else
                pixel_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            hsync_i <= hsync_default;
        else
            if ((pixel_cnt >= (HD + HF - 1)) && (pixel_cnt < (HD + HF + HS - 1)))
                hsync_i <= ~hsync_default;
            else
                hsync_i <= hsync_default; 

    always @(posedge pclk)
        if (reset)
            line_cnt <= 0;
        else
            if (pixel_cnt == (HT -1))
                if (line_cnt < (VT - 1))
                    line_cnt <= line_cnt + 1;
                else
                    line_cnt <= 0;

    always @(posedge pclk)
        if (reset)
            vsync_i <= vsync_default; 
        else if ((line_cnt >= (VD + VF - 1)) && (line_cnt < (VD + VF + VS - 1)))
            vsync_i <= ~vsync_default; 
        else
            vsync_i <= vsync_default; 

    assign hsync = hsync_i;
    assign vsync = vsync_i;
    assign valid = ((pixel_cnt < HD) && (line_cnt < VD));

    assign h_cnt = (pixel_cnt < HD) ? pixel_cnt : 10'd0;
    assign v_cnt = (line_cnt < VD) ? line_cnt : 10'd0;

endmodule
module clock_divider(clk, clk_div);   
    parameter n = 26;     
    input clk;   
    output clk_div;   
    
    reg [n-1:0] num;
    wire [n-1:0] next_num;
    
    always@(posedge clk)begin
    	num<=next_num;
    end
    
    assign next_num = num +1;
    assign clk_div = num[n-1];
    
endmodule
module SevenSegment(
	output reg [6:0] DISPLAY,
	output reg [3:0] DIGIT,
	input wire [15:0] nums,
	input wire rst,
	input wire clk
    );
    
    reg [15:0] clk_divider;
    reg [3:0] display_num;
    
    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		clk_divider <= 15'b0;
    	end else begin
    		clk_divider <= clk_divider + 15'b1;
    	end
    end
    
    always @ (posedge clk_divider[15], posedge rst) begin
    	if (rst) begin
    		display_num <= 4'b0000;
    		DIGIT <= 4'b1111;
    	end else begin
    		case (DIGIT)
    			4'b1110 : begin
    					display_num <= nums[7:4];
//                        display_num <= (nums%100)/10;
    					DIGIT <= 4'b1101;
    				end
    			4'b1101 : begin
						display_num <= nums[11:8];
//						display_num <= (nums%1000)/100;
						DIGIT <= 4'b1011;
					end
    			4'b1011 : begin
						display_num <= nums[15:12];
//						display_num <= nums/1000;
						DIGIT <= 4'b0111;
					end
    			4'b0111 : begin
						display_num <= nums[3:0];
//                        display_num <= nums%10;
						DIGIT <= 4'b1110;
					end
    			default : begin
						display_num <= nums[3:0];
						DIGIT <= 4'b1110;
					end				
    		endcase
    	end
    end
    
    always @ (*) begin
    	case (display_num)
    		0 : DISPLAY = 7'b1000000;	//0000
			1 : DISPLAY = 7'b1111001;   //0001                                                
			2 : DISPLAY = 7'b0100100;   //0010                                                
			3 : DISPLAY = 7'b0110000;   //0011                                             
			4 : DISPLAY = 7'b0011001;   //0100                                               
			5 : DISPLAY = 7'b0010010;   //0101                                               
			6 : DISPLAY = 7'b0000010;   //0110
			7 : DISPLAY = 7'b1111000;   //0111
			8 : DISPLAY = 7'b0000000;   //1000
			9 : DISPLAY = 7'b0010000;	//1001
			10: DISPLAY = 7'b0100000;
			11: DISPLAY = 7'b0000011;
			12: DISPLAY = 7'b0100111;
			13: DISPLAY = 7'b0100001;
			14: DISPLAY = 7'b0000110;
			15: DISPLAY = 7'b0001110;
			default : DISPLAY = 7'b1000000;
    	endcase
    end
    
endmodule
`define silence   32'd50000000
module speaker_control(
    clk,  // clock from the crystal
    rst,  // active high reset
    audio_in_left, // left channel audio data input
    audio_in_right, // right channel audio data input
    audio_mclk, // master clock
    audio_lrck, // left-right clock, Word Select clock, or sample rate clock
    audio_sck, // serial clock
    audio_sdin // serial audio data input
);

    // I/O declaration
    input clk;  // clock from the crystal
    input rst;  // active high reset
    input [15:0] audio_in_left; // left channel audio data input
    input [15:0] audio_in_right; // right channel audio data input
    output audio_mclk; // master clock
    output audio_lrck; // left-right clock
    output audio_sck; // serial clock
    output audio_sdin; // serial audio data input
    reg audio_sdin;

    // Declare internal signal nodes 
    wire [8:0] clk_cnt_next;
    reg [8:0] clk_cnt;
    reg [15:0] audio_left, audio_right;

    // Counter for the clock divider
    assign clk_cnt_next = clk_cnt + 1'b1;

    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            clk_cnt <= 9'd0;
        else
            clk_cnt <= clk_cnt_next;

    // Assign divided clock output
    assign audio_mclk = clk_cnt[1];
    assign audio_lrck = clk_cnt[8];
    assign audio_sck = 1'b1; // use internal serial clock mode

    // audio input data buffer
    always @(posedge clk_cnt[8] or posedge rst)
        if (rst == 1'b1)
            begin
                audio_left <= 16'd0;
                audio_right <= 16'd0;
            end
        else
            begin
                audio_left <= audio_in_left;
                audio_right <= audio_in_right;
            end
   always @*
        case (clk_cnt[8:4])
            5'b00000: audio_sdin = audio_right[0];
            5'b00001: audio_sdin = audio_left[15];
            5'b00010: audio_sdin = audio_left[14];
            5'b00011: audio_sdin = audio_left[13];
            5'b00100: audio_sdin = audio_left[12];
            5'b00101: audio_sdin = audio_left[11];
            5'b00110: audio_sdin = audio_left[10];
            5'b00111: audio_sdin = audio_left[9];
            5'b01000: audio_sdin = audio_left[8];
            5'b01001: audio_sdin = audio_left[7];
            5'b01010: audio_sdin = audio_left[6];
            5'b01011: audio_sdin = audio_left[5];
            5'b01100: audio_sdin = audio_left[4];
            5'b01101: audio_sdin = audio_left[3];
            5'b01110: audio_sdin = audio_left[2];
            5'b01111: audio_sdin = audio_left[1];
            5'b10000: audio_sdin = audio_left[0];
            5'b10001: audio_sdin = audio_right[15];
            5'b10010: audio_sdin = audio_right[14];
            5'b10011: audio_sdin = audio_right[13];
            5'b10100: audio_sdin = audio_right[12];
            5'b10101: audio_sdin = audio_right[11];
            5'b10110: audio_sdin = audio_right[10];
            5'b10111: audio_sdin = audio_right[9];
            5'b11000: audio_sdin = audio_right[8];
            5'b11001: audio_sdin = audio_right[7];
            5'b11010: audio_sdin = audio_right[6];
            5'b11011: audio_sdin = audio_right[5];
            5'b11100: audio_sdin = audio_right[4];
            5'b11101: audio_sdin = audio_right[3];
            5'b11110: audio_sdin = audio_right[2];
            5'b11111: audio_sdin = audio_right[1];
            default: audio_sdin = 1'b0;
        endcase

endmodule

module note_gen(
    clk, // clock from crystal
    rst, // active high reset
    volume,
    note_div_left, // div for note generation
    note_div_right,
    audio_left,
    audio_right
);

    input clk;  
    input rst; 
    input [2:0] volume;
    input [21:0] note_div_left, note_div_right; // div for note generation
    output [15:0] audio_left, audio_right;

    reg [21:0] clk_cnt_next, clk_cnt, clk_cnt_next_2, clk_cnt_2;
    reg b_clk, b_clk_next, c_clk, c_clk_next;

    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            begin
                clk_cnt <= 22'd0;
                clk_cnt_2 <= 22'd0;
                b_clk <= 1'b0;
                c_clk <= 1'b0;
            end
        else
            begin
                clk_cnt <= clk_cnt_next;
                clk_cnt_2 <= clk_cnt_next_2;
                b_clk <= b_clk_next;
                c_clk <= c_clk_next;
            end
    
    always @*
        if (clk_cnt == note_div_left)
            begin
                clk_cnt_next = 22'd0;
                b_clk_next = ~b_clk;
            end
        else
            begin
                clk_cnt_next = clk_cnt + 1'b1;
                b_clk_next = b_clk;
            end

    always @*
        if (clk_cnt_2 == note_div_right)
            begin
                clk_cnt_next_2 = 22'd0;
                c_clk_next = ~c_clk;
            end
        else
            begin
                clk_cnt_next_2 = clk_cnt_2 + 1'b1;
                c_clk_next = c_clk;
            end

    reg [15:0] neg_volume_value [0:5] = { 16'h0000, 16'hFE00, 16'hFC00, 16'hF800,16'hF000, 16'hE000};
    
    reg [15:0] pos_volume_value [0:5] = {16'h0000,16'h0200, 16'h0400,16'h0800, 16'h1000, 16'h2000};

    assign audio_left = (note_div_left == 22'd1) ? 16'h0000 : 
                                (b_clk == 1'b1) ? pos_volume_value[volume] : neg_volume_value[volume];
    assign audio_right = (note_div_right == 22'd1) ? 16'h0000 : 
                                (c_clk == 1'b0) ? pos_volume_value[volume] : neg_volume_value[volume];
endmodule
//module my_player_control (
//	input clk, 
//	input reset, 
//	output reg [11:0] ibeat,
//);
//	parameter LEN = 4095;
	
//	parameter PLAY = 1'd0;
//	parameter DEMO = 1'd1;
//    reg [11:0] next_ibeat;
    
//	always @(posedge clk, posedge reset) begin
//		if (reset) begin
//			ibeat <= 0;
//		end else begin
//            ibeat <= next_ibeat;
//		end
//	end

//    always @* begin
//        next_ibeat = (ibeat + 1 < LEN) ? (ibeat + 1) : 0;
//            next_ibeat = ibeat;
//        if(_play == 0) begin
//            next_ibeat = ibeat;
//        end

//    end
//endmodule
`define silence   32'd50000000
module speaker_control(
    clk,  // clock from the crystal
    rst,  // active high reset
    audio_in_left, // left channel audio data input
    audio_in_right, // right channel audio data input
    audio_mclk, // master clock
    audio_lrck, // left-right clock, Word Select clock, or sample rate clock
    audio_sck, // serial clock
    audio_sdin // serial audio data input
);

    // I/O declaration
    input clk;  // clock from the crystal
    input rst;  // active high reset
    input [15:0] audio_in_left; // left channel audio data input
    input [15:0] audio_in_right; // right channel audio data input
    output audio_mclk; // master clock
    output audio_lrck; // left-right clock
    output audio_sck; // serial clock
    output audio_sdin; // serial audio data input
    reg audio_sdin;

    // Declare internal signal nodes 
    wire [8:0] clk_cnt_next;
    reg [8:0] clk_cnt;
    reg [15:0] audio_left, audio_right;

    // Counter for the clock divider
    assign clk_cnt_next = clk_cnt + 1'b1;

    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            clk_cnt <= 9'd0;
        else
            clk_cnt <= clk_cnt_next;

    // Assign divided clock output
    assign audio_mclk = clk_cnt[1];
    assign audio_lrck = clk_cnt[8];
    assign audio_sck = 1'b1; // use internal serial clock mode

    // audio input data buffer
    always @(posedge clk_cnt[8] or posedge rst)
        if (rst == 1'b1)
            begin
                audio_left <= 16'd0;
                audio_right <= 16'd0;
            end
        else
            begin
                audio_left <= audio_in_left;
                audio_right <= audio_in_right;
            end
   always @*
        case (clk_cnt[8:4])
            5'b00000: audio_sdin = audio_right[0];
            5'b00001: audio_sdin = audio_left[15];
            5'b00010: audio_sdin = audio_left[14];
            5'b00011: audio_sdin = audio_left[13];
            5'b00100: audio_sdin = audio_left[12];
            5'b00101: audio_sdin = audio_left[11];
            5'b00110: audio_sdin = audio_left[10];
            5'b00111: audio_sdin = audio_left[9];
            5'b01000: audio_sdin = audio_left[8];
            5'b01001: audio_sdin = audio_left[7];
            5'b01010: audio_sdin = audio_left[6];
            5'b01011: audio_sdin = audio_left[5];
            5'b01100: audio_sdin = audio_left[4];
            5'b01101: audio_sdin = audio_left[3];
            5'b01110: audio_sdin = audio_left[2];
            5'b01111: audio_sdin = audio_left[1];
            5'b10000: audio_sdin = audio_left[0];
            5'b10001: audio_sdin = audio_right[15];
            5'b10010: audio_sdin = audio_right[14];
            5'b10011: audio_sdin = audio_right[13];
            5'b10100: audio_sdin = audio_right[12];
            5'b10101: audio_sdin = audio_right[11];
            5'b10110: audio_sdin = audio_right[10];
            5'b10111: audio_sdin = audio_right[9];
            5'b11000: audio_sdin = audio_right[8];
            5'b11001: audio_sdin = audio_right[7];
            5'b11010: audio_sdin = audio_right[6];
            5'b11011: audio_sdin = audio_right[5];
            5'b11100: audio_sdin = audio_right[4];
            5'b11101: audio_sdin = audio_right[3];
            5'b11110: audio_sdin = audio_right[2];
            5'b11111: audio_sdin = audio_right[1];
            default: audio_sdin = 1'b0;
        endcase

endmodule

module note_gen(
    clk, // clock from crystal
    rst, // active high reset
    volume,
    note_div_left, // div for note generation
    note_div_right,
    audio_left,
    audio_right
);

    input clk;  
    input rst; 
    input [2:0] volume;
    input [21:0] note_div_left, note_div_right; // div for note generation
    output [15:0] audio_left, audio_right;

    reg [21:0] clk_cnt_next, clk_cnt, clk_cnt_next_2, clk_cnt_2;
    reg b_clk, b_clk_next, c_clk, c_clk_next;

    always @(posedge clk or posedge rst)
        if (rst == 1'b1)
            begin
                clk_cnt <= 22'd0;
                clk_cnt_2 <= 22'd0;
                b_clk <= 1'b0;
                c_clk <= 1'b0;
            end
        else
            begin
                clk_cnt <= clk_cnt_next;
                clk_cnt_2 <= clk_cnt_next_2;
                b_clk <= b_clk_next;
                c_clk <= c_clk_next;
            end
    
    always @*
        if (clk_cnt == note_div_left)
            begin
                clk_cnt_next = 22'd0;
                b_clk_next = ~b_clk;
            end
        else
            begin
                clk_cnt_next = clk_cnt + 1'b1;
                b_clk_next = b_clk;
            end

    always @*
        if (clk_cnt_2 == note_div_right)
            begin
                clk_cnt_next_2 = 22'd0;
                c_clk_next = ~c_clk;
            end
        else
            begin
                clk_cnt_next_2 = clk_cnt_2 + 1'b1;
                c_clk_next = c_clk;
            end

    reg [15:0] neg_volume_value [0:5] = { 16'h0000, 16'hFE00, 16'hFC00, 16'hF800,16'hF000, 16'hE000};
    
    reg [15:0] pos_volume_value [0:5] = {16'h0000,16'h0200, 16'h0400,16'h0800, 16'h1000, 16'h2000};

    assign audio_left = (note_div_left == 22'd1) ? 16'h0000 : 
                                (b_clk == 1'b1) ? pos_volume_value[volume] : neg_volume_value[volume];
    assign audio_right = (note_div_right == 22'd1) ? 16'h0000 : 
                                (c_clk == 1'b0) ? pos_volume_value[volume] : neg_volume_value[volume];
endmodule
//module my_player_control (
//	input clk, 
//	input reset, 
//	output reg [11:0] ibeat,
//);
//	parameter LEN = 4095;
	
//	parameter PLAY = 1'd0;
//	parameter DEMO = 1'd1;
//    reg [11:0] next_ibeat;
    
//	always @(posedge clk, posedge reset) begin
//		if (reset) begin
//			ibeat <= 0;
//		end else begin
//            ibeat <= next_ibeat;
//		end
//	end

//    always @* begin
//        next_ibeat = (ibeat + 1 < LEN) ? (ibeat + 1) : 0;
//            next_ibeat = ibeat;
//        if(_play == 0) begin
//            next_ibeat = ibeat;
//        end

//    end
//endmodule