//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

`default_nettype none

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [48:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
    output [12:0] VIDEO_ARX,
    output [12:0] VIDEO_ARY,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,
    output [1:0]  VGA_SL,
    output        VGA_SCALER, // Force VGA scaler

    input  [11:0] HDMI_WIDTH,
    input  [11:0] HDMI_HEIGHT,
    output        HDMI_FREEZE,

`ifdef MISTER_FB
    // Use framebuffer in DDRAM (USE_FB=1 in qsf)
    // FB_FORMAT:
    //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
    //    [3]   : 0=16bits 565 1=16bits 1555
    //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
    //
    // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
    output        FB_EN,
    output  [4:0] FB_FORMAT,
    output [11:0] FB_WIDTH,
    output [11:0] FB_HEIGHT,
    output [31:0] FB_BASE,
    output [13:0] FB_STRIDE,
    input         FB_VBL,
    input         FB_LL,
    output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output  [7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    input  [23:0] FB_PAL_DIN,
    output        FB_PAL_WR,
`endif
`endif

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    // I/O board button press simulation (active high)
    // b[1]: user button
    // b[0]: osd button
    output  [1:0] BUTTONS,

    input         CLK_AUDIO, // 24.576 MHz
    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
    output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

    //ADC
    inout   [3:0] ADC_BUS,

    //SD-SPI
    output        SD_SCK,
    output        SD_MOSI,
    input         SD_MISO,
    output        SD_CS,
    input         SD_CD,

    //High latency DDR3 RAM interface
    //Use for non-critical time purposes
    output        DDRAM_CLK,
    input         DDRAM_BUSY,
    output  [7:0] DDRAM_BURSTCNT,
    output [28:0] DDRAM_ADDR,
    input  [63:0] DDRAM_DOUT,
    input         DDRAM_DOUT_READY,
    output        DDRAM_RD,
    output [63:0] DDRAM_DIN,
    output  [7:0] DDRAM_BE,
    output        DDRAM_WE,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
    //Secondary SDRAM
    //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
    input         SDRAM2_EN,
    output        SDRAM2_CLK,
    output [12:0] SDRAM2_A,
    output  [1:0] SDRAM2_BA,
    inout  [15:0] SDRAM2_DQ,
    output        SDRAM2_nCS,
    output        SDRAM2_nCAS,
    output        SDRAM2_nRAS,
    output        SDRAM2_nWE,
`endif

    input         UART_CTS,
    output        UART_RTS,
    input         UART_RXD,
    output        UART_TXD,
    output        UART_DTR,
    input         UART_DSR,

    // Open-drain User port.
    // 0 - D+/RX
    // 1 - D-/TX
    // 2..6 - USR2..USR6
    // Set USER_OUT to 1 to read from USER_IN.
    input   [6:0] USER_IN,
    output  [6:0] USER_OUT,

    input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_MIX = 0;
assign LED_USER = reset & m68k_a[0] & | sprite_tile ;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV


wire [1:0] aspect_ratio = status[9:8];
wire orientation = ~status[10];
wire [2:0] scan_lines = status[6:4];

assign VIDEO_ARX = (!aspect_ratio) ? (orientation  ? 8'd176 : 8'd135) : (aspect_ratio - 1'd1);
assign VIDEO_ARY = (!aspect_ratio) ? (orientation  ? 8'd135 : 8'd176) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
    "Terra Cresta;;",
    "-;",
    "P1,Video Settings;",
    "P1-;",
    "P1O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
    "P1OA,Orientation,Horz,Vert;",
    "P1-;",
    "P1O46,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    "DIP;",
//    "-;",
//    "P2,Pause options;",
//    "P2OP,Pause when OSD is open,On,Off;",
//    "P2OQ,Dim video after 10s,On,Off;",
    "-;",
    "R0,Reset;",
    "J1,Button 1,Button 2,Button 3,Start,Coin,Pause;",
    "jn,A,B,X,R,L,Start;",           // name mapping
    "V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire [15:0] joy0, joy1;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),

    .buttons(buttons),
    .ps2_key(ps2_key),
    .status(status),
    .status_menumask(direct_video),
    .forced_scandoubler(forced_scandoubler),
    .gamma_bus(gamma_bus),
    .direct_video(direct_video),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joy0),
    .joystick_1(joy1)
);

// INPUT

// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge clk_sys) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wait;
wire        ioctl_wr;
wire  [7:0] ioctl_index;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;

wire [21:0] gamma_bus;

//<buttons names="Fire,Jump,Start,Coin,Pause" default="A,B,R,L,Start" />
reg [15:0] p1 ;
reg [15:0] p2;
reg [15:0] dsw1 ;
reg [15:0] sys ;

always @ (posedge clk_sys) begin
    p1 <= 16'hffff;
    p1[5:0] <= ~{ p1_buttons[1:0], p1_right, p1_left ,p1_down, p1_up};
     
    p2 <= 16'hffff;
    p2[5:0] <= ~{ p2_buttons[1:0], p2_right, p2_left ,p2_down, p2_up};
    
    sys <= 16'hffff;
    sys[8] <= ~p1_start ; // coin [5]
    sys[9] <= ~p2_start ;
    sys[10] <= ~p1_coin ; 
    sys[11] <= ~p2_coin ; 
    sys[13] <= ~sw[3][5] ;
     
    dsw1 <= { sw[1], sw[0] };
end

wire       p1_up      = joy0[3] | key_p1_up;
wire       p1_down    = joy0[2] | key_p1_down;
wire       p1_left    = joy0[1] | key_p1_left;
wire       p1_right   = joy0[0] | key_p1_right;
wire [2:0] p1_buttons = joy0[6:4] | {key_p1_c, key_p1_b, key_p1_a};

wire       p2_up      = joy1[3] | key_p2_up;
wire       p2_down    = joy1[2] | key_p2_down;
wire       p2_left    = joy1[1] | key_p2_left;
wire       p2_right   = joy1[0] | key_p2_right;
wire [2:0] p2_buttons = joy1[6:4] | {key_p2_c, key_p2_b, key_p2_a};

wire p1_start = joy0[6] | key_p1_start;
wire p2_start = joy1[6] | key_p2_start;
wire p1_coin  = joy0[7] | key_p1_coin;
wire p2_coin  = joy1[7] | key_p2_coin;
wire b_pause  = joy0[9] | joy1[9];

// Keyboard handler

wire key_p1_start, key_p2_start, key_p1_coin, key_p2_coin;
wire key_test, key_reset, key_service;

wire key_p1_up, key_p1_left, key_p1_down, key_p1_right, key_p1_a, key_p1_b, key_p1_c;
wire key_p2_up, key_p2_left, key_p2_down, key_p2_right, key_p2_a, key_p2_b, key_p2_c;

wire pressed = ps2_key[9];

// PAUSE SYSTEM
wire    pause_cpu;
wire    hs_pause;

pause #(4,4,4,48) pause (
    .clk_sys(clk_sys),
    .reset(reset),
    .user_button(b_pause),
    .pause_request(hs_pause),
    .options(~status[26:25]),
    .OSD_STATUS(0),
    .r(rgb[11:8]),
    .g(rgb[7:4]),
    .b(rgb[3:0]),
);


reg user_flip;

wire pll_locked;

wire clk_sys;
reg  clk_4M,clk_8M,clk_16M,clk_ym;

pll pll
(
    .refclk(CLK_50M),
    .rst(0),
    .outclk_0(clk_sys),     // 80
    .locked(pll_locked)
);

reg [5:0] clk16_count;
reg [5:0] clk8_count;
reg [5:0] clk4_count;
reg [15:0] clk_ym_count;

always @ (posedge clk_sys) begin
   
    clk_16M <= ( clk16_count == 0 );

    if ( clk16_count == 4 ) begin
        clk16_count <= 0;
    end else begin
        clk16_count <= clk16_count + 1;
    end

    clk_8M <= ( clk8_count == 0 );

    if ( clk8_count == 9 ) begin
        clk8_count <= 0;
    end else begin
        clk8_count <= clk8_count + 1;
    end

    clk_4M <= ( clk4_count == 0 );

    if ( clk4_count == 19 ) begin
        clk4_count <= 0;
    end else begin
        clk4_count <= clk4_count + 1;
    end
     
    clk_ym <= ( clk_ym_count == 0 );

    if ( clk_ym_count == 10239 ) begin  // 4MHz / 512 = 7.8KHz
        clk_ym_count <= 0;
    end else begin
        clk_ym_count <= clk_ym_count + 1;
    end
     
end

wire    reset;
assign  reset = RESET | status[0] | ioctl_download | buttons[1];

//////////////////////////////////////////////////////////////////
wire rotate_ccw = 1;
wire no_rotate = orientation | direct_video;
wire video_rotated ;
wire flip = 0;

reg [23:0]     rgb;

wire hbl;
wire vbl;

wire [8:0] hc;
wire [8:0] vc;

wire hsync;
wire vsync;

reg hbl_delay;
reg vbl_delay;
reg hsync_delay;
reg vsync_delay;

// 4 clock pipeline to make pixel
always @ (posedge clk_sys) begin
    if ( clk_4M == 1 ) begin
        hbl_delay <= hbl;
        vbl_delay <= vbl;

        hsync_delay <= hsync;
        vsync_delay <= vsync;
    end
end

video_timing video_timing (
    .clk(clk_sys),
    .clk_pix(clk_8M),
    .hc(hc),
    .vc(vc),
    .hbl(hbl),
    .vbl(vbl),
    .hsync(hsync),
    .vsync(vsync)
);

screen_rotate screen_rotate (.*);

arcade_video #(256,24) arcade_video
(
        .*,

        .clk_video(clk_sys),
        .ce_pix(clk_8M),

        .RGB_in(rgb[23:0]),

        .HBlank(hbl_delay),
        .VBlank(vbl_delay),
        .HSync(hsync_delay),
        .VSync(vsync_delay),

        .fx(scan_lines)
);

    
reg  [3:0] gfx1_pix ;
reg  [3:0] gfx2_pix ;

wire [9:0] fg_tile = {hc[7:3], vc[7:3] };

wire [9:0] hc_s = hc[7:0] + scroll_x ;
wire [8:0] vc_s = vc[7:0] + scroll_y ;

wire [11:0] bg_tile = {hc_s[9:4], vc_s[8:4] };

// tile attributes
always @ * begin
    fg_ram_addr <= fg_tile ;  // [8:0]
    bg_ram_addr <= bg_tile;
end    

    
//wire [3:0] p = ( gfx1_pix < 4'hf ) ? gfx1_pix : gfx2_pix ;


wire [7:0] gfxc = 8'hc0 + ( (gfx2_pix[3] == 0 ) ? { bg_ram_dout[12:11] , gfx2_pix } : { bg_ram_dout[14:13] , gfx2_pix } );

wire [11:0] spr_pix = sprite_line_buffer[hc];

// prom_s = idx 
wire [7:0]  spr_col_idx = spr_pix[3:0];// { 2'b10, ( spr_pix[3] ? spr_pix[11:10] : spr_pix[9:8] ), prom_s[spr_pix[11:4]][3:0] } ;



wire [7:0] spi = { 2'b10, ( ( spr_pix[3] == 1'b0 ) ? spr_pix[9:8] : spr_pix[11:10] ), prom_s[ spr_pix[7:0] ][3:0] };  //p[3:0];

always @ * begin
    rgb <= ( gfx1_pix < 4'hf ) ? 
        ( ( scroll_x[12] == 1 ) ? 24'b0 : { prom_r[gfx1_pix], 4'b0, prom_g[gfx1_pix], 4'b0, prom_b[gfx1_pix], 4'b0 } ): 
          ( spr_pix == 0  ) ?
        ( ( scroll_x[13] == 1 ) ? 24'b0 : { prom_r[gfxc],     4'b0, prom_g[gfxc],     4'b0, prom_b[gfxc],     4'b0 } ) :
          { prom_r[spi],     4'b0, prom_g[spi],     4'b0, prom_b[spi],     4'b0 };
end

wire    [12:0] gfx1_addr = { fg_ram_dout[7:0], vc[2:0], hc[2:1] };  // tile #.  set of 256 tiles -- fg_ram_dout[7:0]
wire    [7:0]  gfx1_dout;

wire  [15:0] gfx2_addr = { bg_ram_dout[8:0], vc_s[3:0], hc_s[3:1] } ;
wire  [7:0]  gfx2_dout;
wire  [63:0] gfx3_dout;

    
always @ (posedge clk_sys) begin
    if ( reset == 1 ) begin

    end else if ( clk_8M == 1 ) begin
        if ( hc[0] == 0 ) begin 
            gfx1_pix <= gfx1_dout[3:0] ;
        end else begin
            gfx1_pix <= gfx1_dout[7:4] ;
        end

        if ( hc_s[0] == 0 ) begin 
            gfx2_pix <= gfx2_dout[3:0] ;
        end else begin
            gfx2_pix <= gfx2_dout[7:4] ;
        end
        
    end
end
    
    
/// 68k cpu

always @ (posedge clk_sys) begin

    if ( reset == 1 ) begin
        m68k_dtack_n <= 1;
    end else if ( clk_16M == 1 ) begin
        // tell 68k to wait for valid data. 0=ready 1=wait
        // always ack when it's not program rom
        m68k_dtack_n <= 0; 

        // select cpu data input based on what is active 
        m68k_din <=  prog_rom_cs  ? prog_rom_data :
                     m68k_ram_cs  ? ram68k_dout :
                     m68k_ram1_cs ? m68k_ram1_dout :
                     input_p1_cs ? p1 :
                     input_p2_cs ? p2 :
                     input_system_cs ? sys:
                     input_dsw_cs ? dsw1 :
                     16'd0;
    end
end 

//    m68k_cs = ( cpu_a >> width == base_address >> width ) & !m68k_as_n;

wire prog_rom_cs      = ( m68k_a[23:0]  < 24'h020000 ) & !m68k_as_n ;
wire m68k_ram_cs      = ( m68k_a[23:0] >= 24'h020000 && m68k_a[23:0] < 24'h022000) & !m68k_as_n ; // 8k
wire bg_ram_cs        = ( m68k_a[23:0] >= 24'h022000 && m68k_a[23:0] < 24'h023000) & !m68k_as_n ; // 4k
wire m68k_ram1_cs     = ( m68k_a[23:0] >= 24'h023000 && m68k_a[23:0] < 24'h024000) & !m68k_as_n ; // 4k
wire fg_ram_cs        = ( m68k_a[23:0] >= 24'h028000 && m68k_a[23:0] < 24'h028800) & !m68k_as_n ; // 2k

wire input_p1_cs      = ( m68k_a[23:0] >= 24'h024000 && m68k_a[23:0] < 24'h024002) & !m68k_as_n ; // P1
wire input_p2_cs      = ( m68k_a[23:0] >= 24'h024002 && m68k_a[23:0] < 24'h024004) & !m68k_as_n ; // P2
wire input_system_cs  = ( m68k_a[23:0] >= 24'h024004 && m68k_a[23:0] < 24'h024006) & !m68k_as_n ; // SYSTEM
wire input_dsw_cs     = ( m68k_a[23:0] >= 24'h024006 && m68k_a[23:0] < 24'h024008) & !m68k_as_n ; // DSW

wire scroll_x_cs     = ( m68k_a[23:0] >= 24'h026002 && m68k_a[23:0] < 24'h026004) & !m68k_as_n ; // SCROLL X
wire scroll_y_cs     = ( m68k_a[23:0] >= 24'h026004 && m68k_a[23:0] < 24'h026006) & !m68k_as_n ; // SCROLL Y

wire sound_latch_cs  = ( m68k_a[23:0] >= 24'h02600c && m68k_a[23:0] < 24'h02600e) & !m68k_as_n ; // sound latch


reg [15:0] scroll_x;
reg [15:0] scroll_y;
reg [7:0]  sound_latch;


// CPU outputs
wire m68k_rw         ;    // Read = 1, Write = 0
wire m68k_as_n       ;    // Address strobe
wire m68k_lds_n      ;    // Lower byte strobe
wire m68k_uds_n      ;    // Upper byte strobe
wire m68k_E;         
wire [2:0] m68k_fc    ;   // Processor state
wire m68k_reset_n_o  ;    // Reset output signal
wire m68k_halted_n   ;    // Halt output

// CPU busses
wire [15:0] m68k_dout       ;
wire [23:0] m68k_a          ;
reg  [15:0] m68k_din        ;   
assign m68k_a[0] = 1'b0;

// CPU inputs
reg  m68k_dtack_n ;         // Data transfer ack (always ready)
reg  m68k_ipl2_n ;


wire reset_n;
wire m68k_vpa_n = ~int_ack;//( m68k_lds_n == 0 && m68k_fc == 3'b111 ); // int ack

reg int_ack ;
reg [1:0] vbl_sr;

// vblank handling 
// process interrupt and sprite buffering
always @ (posedge clk_sys ) begin
    if ( reset == 1 ) begin
        m68k_ipl2_n <= 1 ;
        int_ack <= 0;
    end else begin
        vbl_sr <= { vbl_sr[0], vbl };

        if ( clk_16M == 1 ) begin
            int_ack <= ( m68k_as_n == 0 ) && ( m68k_fc == 3'b111 ); // cpu acknowledged the interrupt
        end

        if ( vbl_sr == 2'b01 ) begin // rising edge
            // trigger sprite buffer copy
            copy_sprite_state <= 1;
            //  68k vbl interrupt
            m68k_ipl2_n <= 0;
        end else if ( int_ack == 1 || vbl_sr == 2'b10 ) begin
            // deassert interrupt since 68k ack'ed.
            m68k_ipl2_n <= 1 ;
        end
    end

    //   copy sprite list to dedicated sprite list ram
    // start state machine for copy
    if ( copy_sprite_state == 1 ) begin
        sprite_shared_addr <= 0;
        copy_sprite_state <= 2;
        sprite_buffer_addr <= 0;
    end else if ( copy_sprite_state == 2 ) begin
        // address now 0
        sprite_shared_addr <= sprite_shared_addr + 1 ;
        copy_sprite_state <= 3; 
    end else if ( copy_sprite_state == 3 ) begin        
       // address 0 result
        sprite_y_pos <= 240 - sprite_shared_ram_dout;

        sprite_shared_addr <= sprite_shared_addr + 1 ;
        copy_sprite_state <= 4; 
    end else if ( copy_sprite_state == 4 ) begin    
        // address 1 result
        sprite_tile[7:0] <= sprite_shared_ram_dout;

        sprite_shared_addr <= sprite_shared_addr + 1 ;
        copy_sprite_state <= 5; 
    end else if ( copy_sprite_state == 5 ) begin        
            // add 256 to x?
        sprite_x_256 <= sprite_shared_ram_dout[0];
        // add 256 to tile?
        sprite_tile[9:8] <= { 1'b0, sprite_shared_ram_dout[1] };
        // flip x?
        sprite_flip_x <= sprite_shared_ram_dout[2];
        // flip y?
        sprite_flip_y <= sprite_shared_ram_dout[3];
        // colour
        sprite_colour <= sprite_shared_ram_dout[7:4];

       sprite_shared_addr <= sprite_shared_addr + 1 ;

        copy_sprite_state <= 6; 
    end else if ( copy_sprite_state == 6 ) begin        
        sprite_x_pos <=  { sprite_x_256, sprite_shared_ram_dout } - 8'h80 ;

        copy_sprite_state <= 7; 
    end else if ( copy_sprite_state == 7 ) begin                
        sprite_buffer_w <= 1;
        sprite_buffer_din <= {sprite_tile,sprite_x_pos,sprite_y_pos,sprite_colour,sprite_flip_x,sprite_flip_y};
        
        copy_sprite_state <= 8;
    end else if ( copy_sprite_state == 8 ) begin                

        // write is complete
        sprite_buffer_w <= 0;
        // sprite has been buffered.  are we done?
        if ( sprite_buffer_addr < 8'h3f ) begin
            // start on next sprite
            sprite_buffer_addr <= sprite_buffer_addr + 1;
            copy_sprite_state <= 2;
        end else begin
            // we are done, go idle.  
            copy_sprite_state <= 0; 
        end
    end

    if ( draw_sprite_state == 0 && hc > 9'h0ff && next_y > 15  ) begin // 0xe0
        // clear sprite buffer
        sprite_x_ofs <= 0;
        draw_sprite_state <= 1;
        sprite_buffer_addr <= 0;
    end else if (draw_sprite_state == 1) begin
        sprite_line_buffer[sprite_x_ofs] <= 0;
        if ( sprite_x_ofs < 255 ) begin
            sprite_x_ofs <= sprite_x_ofs + 1;
        end else begin
            // sprite buffer now blank
            draw_sprite_state <= 2;
        end
    end else if (draw_sprite_state == 2) begin        
        // get current sprite attributes
        {sprite_tile,sprite_x_pos,sprite_y_pos,sprite_colour,sprite_flip_x,sprite_flip_y} <= sprite_buffer_dout[33:0];
        draw_sprite_state <= 3;
        sprite_x_ofs <= 0;
    end else if (draw_sprite_state == 3) begin    
        draw_sprite_state <= 4;
    end else if (draw_sprite_state == 4) begin                
        draw_sprite_state <= 3; 
        if ( vc >= sprite_y_pos && vc < ( sprite_y_pos + 16 ) && sprite_x_pos < 256 ) begin
            // fetch bitmap 
            if ( p[3:0] > 0 ) begin
                sprite_line_buffer[sprite_x_pos] <= p;
            end
            if ( sprite_x_ofs < 15 ) begin
                sprite_x_pos <= sprite_x_pos + 1;
                sprite_x_ofs <= sprite_x_ofs + 1;
            end else begin
                draw_sprite_state <= 6;
            end
        end else begin
            draw_sprite_state <= 6;
        end
    end else if (draw_sprite_state == 6) begin                        
        // done. next sprite
        if ( sprite_buffer_addr < 63 ) begin
            sprite_buffer_addr <= sprite_buffer_addr + 1;
            draw_sprite_state <= 2;
        end else begin
            // all sprites done
            draw_sprite_state <= 7;
        end
    end else if (draw_sprite_state == 7) begin                        
        // we are done. wait for end of line
        if ( hc == 0 ) begin
            draw_sprite_state <= 0;
        end
    end
end

wire    [3:0] sprite_y_ofs = vc - sprite_y_pos ;

wire    [3:0] flipped_x = ( sprite_flip_x == 0 ) ? sprite_x_ofs : 15 - sprite_x_ofs;
wire    [3:0] flipped_y = ( sprite_flip_y == 0 ) ? sprite_y_ofs : 15 - sprite_y_ofs;

wire   [15:0] gfx3_addr = { flipped_x[1], sprite_tile[8:0], sprite_y_ofs[3:0], flipped_x[3:2] };

wire    [3:0] gfx3_pix = (sprite_x_ofs[0] == 1 ) ? gfx3_dout[7:4] : gfx3_dout[3:0];

// int spr_col = (u[t>>1]<<8) + (c<<4) + pen ;
// prom_u = palette bank lookup
wire   [11:0] p  = { prom_u[sprite_tile[8:1]][3:0], sprite_colour, gfx3_pix};

wire    [7:0] next_y ;
assign next_y = (vc+1'b1);

reg     [7:0] sprite_x_ofs;

reg    [11:0] sprite_line_buffer [255:0];

ram64bx64dp sprite_buffer (
    .clock_a ( clk_sys ),
    .address_a ( sprite_buffer_addr ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( sprite_buffer_dout ),
    
    .clock_b ( clk_sys ),
    .address_b ( sprite_buffer_addr ),
    .wren_b ( sprite_buffer_w ),
    .data_b ( sprite_buffer_din  ),
    .q_b( )

    );

        
reg  [3:0]  copy_sprite_state;
reg  [3:0]  draw_sprite_state;

wire [7:0]  sprite_shared_ram_dout;
reg  [7:0]  sprite_shared_addr;
reg  [5:0]  sprite_buffer_addr;  // 64 sprites
reg  [63:0] sprite_buffer_din;
wire [63:0] sprite_buffer_dout;
reg  sprite_buffer_w;

reg  [9:0]  sprite_tile ;  // terra cresta has 512 tiles ,  HORE HORE Kid has 1024
reg  [7:0]  sprite_y_pos;
reg  [8:0]  sprite_x_pos;
reg  [3:0]  sprite_colour;
reg  sprite_x_256;
reg  sprite_flip_x;
reg  sprite_flip_y;

// clock generation
reg  fx68_phi1 = 0; 

// phases for 68k clock
always @(posedge clk_sys) begin
    if ( clk_16M == 1 ) begin
        fx68_phi1 <= ~fx68_phi1; 
    end
end

fx68k fx68k (
    // input
    .clk( clk_16M ),
    .enPhi1(fx68_phi1),
    .enPhi2(!fx68_phi1),
    .extReset(reset),
    .pwrUp(reset),

    // output
    .eRWn(m68k_rw),
    .ASn( m68k_as_n),
    .LDSn(m68k_lds_n),
    .UDSn(m68k_uds_n),
    .E(),
    .VMAn(),
    .FC0(m68k_fc[0]),
    .FC1(m68k_fc[1]),
    .FC2(m68k_fc[2]),
    .BGn(),
    .oRESETn(m68k_reset_n_o),
    .oHALTEDn(m68k_halted_n),

    // input
    .VPAn( m68k_vpa_n ),  
    .DTACKn( m68k_dtack_n),     
    .BERRn(1'b1), 
    .BRn(1'b1),  
    .BGACKn(1'b1),
    
    .IPL0n(m68k_ipl2_n),
    .IPL1n(1'b1),
    .IPL2n(1'b1),

    // busses
    .iEdb(m68k_din),
    .oEdb(m68k_dout),
    .eab(m68k_a[23:1])
);


// z80 bus
wire    [7:0] z80_rom_data;
wire    [7:0] z80_ram_dout;

wire   [15:0] z80_addr;
reg     [7:0] z80_din;
wire    [7:0] z80_dout;

wire z80_wr_n;
wire z80_rd_n;
reg  z80_wait_n;
reg  z80_irq_n;

wire IORQ_n;
wire MREQ_n;
wire M1_n;

//IORQ gets together with M1-pin active/low. 
always @ (posedge clk_sys) begin
    
    if ( reset == 1 ) begin
        z80_irq_n <= 1;
    end else if ( clk_ym == 1 ) begin
        z80_irq_n <= 0;
    end 
    
    // check for interrupt ack and deassert int
    if ( M1_n == 0 && z80_irq_n == 0 && IORQ_n == 0 ) begin
        z80_irq_n <= 1;
    end
end

T80pa u_cpu(
    .RESET_n    ( ~reset ),
    .CLK        ( clk_8M ),
    .CEN_p      ( 1'b1 ),
    .CEN_n      ( 1'b1 ),
    .WAIT_n     ( z80_wait_n ), // don't wait if data is valid or rom access isn't selected
    .INT_n      ( z80_irq_n ),  // opl timer
    .NMI_n      ( 1'b1 ),
    .BUSRQ_n    ( 1'b1 ),
    .RD_n       ( z80_rd_n ),
    .WR_n       ( z80_wr_n ),
    .A          ( z80_addr ),
    .DI         ( z80_din  ),
    .DO         ( z80_dout ),
    // unused
    .DIRSET     ( 1'b0     ),
    .DIR        ( 212'b0   ),
    .OUT0       ( 1'b0     ),
    .RFSH_n     (),
    .IORQ_n     ( IORQ_n ),
    .M1_n       (),
    .BUSAK_n    (),
    .HALT_n     ( 1'b1 ),
    .MREQ_n     ( MREQ_n ),
    .Stop       (),
    .REG        ()
);

wire z80_rom_cs          = ( MREQ_n == 0 && z80_addr[15:0]  < 16'hc000 );
wire z80_ram_cs          = ( MREQ_n == 0 && z80_addr[15:0] >= 16'hc000 );

wire z80_sound0_cs       = ( IORQ_n == 0 && z80_addr[7:0] == 8'h00 );
wire z80_sound1_cs       = ( IORQ_n == 0 && z80_addr[7:0] == 8'h01 );
wire z80_dac1_cs         = ( IORQ_n == 0 && z80_addr[7:0] == 8'h02 );
wire z80_dac2_cs         = ( IORQ_n == 0 && z80_addr[7:0] == 8'h03 );
wire z80_latch_clr_cs    = ( IORQ_n == 0 && z80_addr[7:0] == 8'h04 );
wire z80_latch_r_cs      = ( IORQ_n == 0 && z80_addr[7:0] == 8'h06 );


reg sound_addr ;
reg  [7:0] sound_data ;

// sound ic write enable
reg sound_wr;

wire [7:0] opl_dout;
wire opl_irq_n;

reg signed [15:0] sample;

assign AUDIO_S = 1'b1 ;

wire opl_sample_clk;

jtopl #(.OPL_TYPE(1)) opl
(
    .rst(reset),
    .clk(clk_4M),
    .cen(1'b1),
    .din(sound_data),
    .addr(sound_addr),
    .cs_n(~( z80_sound0_cs | z80_sound1_cs )),
    .wr_n(~sound_wr),
    .dout(opl_dout),
    .irq_n(opl_irq_n),
    .snd(sample),
    .sample(opl_sample_clk)
);

always @ * begin
    // mix audio
    AUDIO_L <= sample + ($signed({ ~dac1[7], dac1[6:0], 8'b0 }) >>> 1) + ($signed({ ~dac2[7], dac2[6:0], 8'b0 }) >>> 1) ;
    AUDIO_R <= sample + ($signed({ ~dac1[7], dac1[6:0], 8'b0 }) >>> 1) + ($signed({ ~dac2[7], dac2[6:0], 8'b0 }) >>> 1) ;
end

reg [7:0] dac1;
reg [7:0] dac2;

always @ (posedge clk_sys) begin
     if ( clk_4M == 1 ) begin

        z80_wait_n <= 1;
        
        if ( z80_rd_n == 0 ) begin 
            if ( z80_rom_cs ) begin
                z80_din <= z80_rom_data;
            end else if ( z80_ram_cs ) begin
                z80_din <= z80_ram_dout;
            end else if ( z80_latch_clr_cs ) begin
                // todo
                z80_din <= 0;
                      sound_latch <= 8'h0;
                     
            end else if ( z80_latch_r_cs ) begin
                z80_din <= sound_latch;
                // todo
            end else begin
                z80_din <= 8'h00;
            end
        end
        
        sound_wr <= 0 ;
        if ( z80_wr_n == 0 ) begin 
            if ( z80_sound0_cs == 1 || z80_sound1_cs == 1) begin    
                sound_data  <= z80_dout;
                sound_addr <= z80_sound1_cs ; //   opl2 is single bit address
                sound_wr <= 1;
            end else if (z80_dac1_cs == 1 ) begin
                    dac1 <= z80_dout;
                end else if (z80_dac2_cs == 1 ) begin
                    dac2 <= z80_dout;
                end
        end

    end 
     
     if ( clk_16M == 1 ) begin

         if (!m68k_rw & scroll_x_cs ) begin
              scroll_x <= m68k_dout[15:0];
         end

         if (!m68k_rw & scroll_y_cs ) begin
              scroll_y <= m68k_dout[15:0];
         end

         if (!m68k_rw & sound_latch_cs ) begin
              sound_latch <= {m68k_dout[6:0],1'b1};
         end
    end
    
   if ( reset == 1 ) begin
        z80_wait_n <= 0;
        sound_wr <= 0 ;
          sound_latch <= 8'h00;
   end


end


wire [15:0] ram68k_dout;
wire [15:0] prog_rom_data;

// ioctl download addressing    
wire rom_download = ioctl_download && (ioctl_index==0);

wire m68k_rom_h_ioctl_wr = rom_download & ioctl_wr & (ioctl_addr  <  24'h020000) & (ioctl_addr[0] == 1);
wire m68k_rom_l_ioctl_wr = rom_download & ioctl_wr & (ioctl_addr  <  24'h020000) & (ioctl_addr[0] == 0);

wire gfx1_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >=  24'h020000) & (ioctl_addr <  24'h022000) ;
wire gfx2_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >=  24'h030000) & (ioctl_addr <  24'h040000) ;
wire gfx3_ioctl_wr       = rom_download & ioctl_wr & (ioctl_addr >=  24'h050000) & (ioctl_addr <  24'h060000) ;

wire z80_rom_ioctl_wr    = rom_download & ioctl_wr & (ioctl_addr >=  24'h070000) & (ioctl_addr <  24'h07c000) ;

wire prom_r_wr           = rom_download & ioctl_wr & (ioctl_addr >=  24'h07E000) & (ioctl_addr <  24'h07E100) ;
wire prom_g_wr           = rom_download & ioctl_wr & (ioctl_addr >=  24'h07E100) & (ioctl_addr <  24'h07E200) ;
wire prom_b_wr           = rom_download & ioctl_wr & (ioctl_addr >=  24'h07E200) & (ioctl_addr <  24'h07E300) ;
wire prom_s_wr           = rom_download & ioctl_wr & (ioctl_addr >=  24'h07E300) & (ioctl_addr <  24'h07E400) ;
wire prom_u_wr           = rom_download & ioctl_wr & (ioctl_addr >=  24'h07E400) & (ioctl_addr <  24'h07E500) ;

reg [3:0] prom_r [255:0] ;
reg [3:0] prom_g [255:0] ;
reg [3:0] prom_b [255:0] ;
reg [3:0] prom_s [255:0] ;
reg [3:0] prom_u [255:0] ;

always @ (posedge clk_sys) begin

    if ( prom_r_wr == 1 ) begin
        prom_r[ioctl_addr[7:0]] <= ioctl_dout[3:0];
    end
     
    if ( prom_g_wr == 1 ) begin
        prom_g[ioctl_addr[7:0]] <= ioctl_dout[3:0];
    end
     
    if ( prom_b_wr == 1 ) begin
        prom_b[ioctl_addr[7:0]] <= ioctl_dout[3:0];
    end
     
    if ( prom_s_wr == 1 ) begin
        prom_s[ioctl_addr[7:0]] <= ioctl_dout[3:0];
    end

    if ( prom_u_wr == 1 ) begin
        prom_u[ioctl_addr[7:0]] <= ioctl_dout[3:0];
    end
     
end

// main 68k ROM low     
// 3.4d & 4.6d
ram64kx8dp rom64kx8_H (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[16:1] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( prog_rom_data[15:8] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[16:1] ),
    .wren_b ( m68k_rom_h_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )

    );

// main 68k ROM high 
// // rom 1.4b & 2.6b  
ram64kx8dp rom64kx8_L (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[16:1] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( prog_rom_data[7:0] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[16:1] ),
    .wren_b ( m68k_rom_l_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );

// main 68k ram high    
ram4kx8dp ram4kx8_H (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[12:1] ),
    .wren_a ( !m68k_rw & m68k_ram_cs & !m68k_uds_n ),
    .data_a ( m68k_dout[15:8]  ),
    .q_a (  ram68k_dout[15:8] ),
    );

// main 68k ram low     
// 0x200 shared with sound cpu            
ram4kx8dp ram4kx8_L (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[12:1] ),
    .wren_a ( !m68k_rw & m68k_ram_cs & !m68k_lds_n ),
    .data_a ( m68k_dout[7:0]  ),
    .q_a ( ram68k_dout[7:0] ),
     
     .clock_b ( clk_sys ),
    .address_b ( sprite_shared_addr[7:0] ),  // 64 sprites * 4 bytes for each == 256
    .wren_b ( 1'b0 ),
    .data_b ( ),
    .q_b( sprite_shared_ram_dout )
    );
    
// z80 rom (48k)
ram64kx8dp rom_z80 (
    .clock_a ( clk_8M ),
    .address_a ( z80_addr[15:0] ),
    .wren_a ( 1'b0 ),
    .data_a (  ),
    .q_a ( z80_rom_data ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[15:0] ),
    .wren_b ( z80_rom_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );
    
// z80 ram    
ram4kx8dp z80_ram (
    .clock_b ( clk_8M ),  // z80 clock is 4M
    .address_b ( z80_addr[11:0] ),
    .data_b ( z80_dout ),
    .wren_b ( z80_ram_cs & ~z80_wr_n ),
    .q_b ( z80_ram_dout )
    );

    
//  <!-- gfx1       0x020000-0x021fff 8K -->
ram8kx8dp gfx1 (
    .clock_a ( clk_8M ),
    .address_a ( gfx1_addr[12:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( gfx1_dout[7:0] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[12:0] ),
    .wren_b ( gfx1_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );
    
//  <!-- gfx2       0x030000-0x03FFFF 64K -->
ram64kx8dp gfx2 (
    .clock_a ( clk_8M ),
    .address_a ( gfx2_addr[15:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( gfx2_dout[7:0] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[15:0] ),
    .wren_b ( gfx2_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );

//  <!-- gfx3 - starts at 0x50000 -->     
ram64kx8dp gfx3 (
    .clock_a ( clk_sys ),
    .address_a ( gfx3_addr[15:0] ),
    .wren_a ( 1'b0 ),
    .data_a ( ),
    .q_a ( gfx3_dout[7:0] ),
    
    .clock_b ( clk_sys ),
    .address_b ( ioctl_addr[15:0] ),
    .wren_b ( gfx3_ioctl_wr ),
    .data_b ( ioctl_dout  ),
    .q_b( )
    );

reg   [9:0] fg_ram_addr;
wire [15:0] fg_ram_dout;

// 2 x 1k
ram4kx8dp fg_ram_l (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[10:1] ),
    .wren_a ( !m68k_rw & fg_ram_cs & !m68k_lds_n ),
    .data_a ( m68k_dout[7:0]  ),
    .q_a (  ),

    .clock_b ( clk_sys ),
    .address_b ( fg_ram_addr  ),
    .wren_b ( 1'b0 ),
    .data_b (  ),
    .q_b( fg_ram_dout[7:0]  )

    );

ram4kx8dp fg_ram_h (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[10:1] ),
    .wren_a ( !m68k_rw & fg_ram_cs & !m68k_lds_n ),
    .data_a ( m68k_dout[15:8]  ),
    .q_a (  ),
    
    .clock_b ( clk_sys ),
    .address_b ( fg_ram_addr  ),
    .wren_b ( 1'b0 ),
    .data_b (  ),
    .q_b( fg_ram_dout[15:8]  )
    );
    
    
reg  [11:0] bg_ram_addr;
wire [15:0] bg_ram_dout;

ram4kx8dp bg_ram_l (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[11:1] ),
    .wren_a ( !m68k_rw & bg_ram_cs & !m68k_lds_n ),
    .data_a ( m68k_dout[7:0]  ),
    .q_a (  ),

    .clock_b ( clk_sys ),
    .address_b ( bg_ram_addr  ),
    .wren_b ( 1'b0 ),
    .data_b (  ),
    .q_b( bg_ram_dout[7:0]  )

    );

ram4kx8dp bg_ram_h (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[11:1] ),
    .wren_a ( !m68k_rw & bg_ram_cs & !m68k_lds_n ),
    .data_a ( m68k_dout[15:8]  ),
    .q_a (  ),
    
    .clock_b ( clk_sys ),
    .address_b ( bg_ram_addr  ),
    .wren_b ( 1'b0 ),
    .data_b (  ),
    .q_b( bg_ram_dout[15:8]  )
    );    

reg  [11:0] m68k_ram1_addr;
wire [15:0] m68k_ram1_dout;

ram4kx8dp m68k_ram1_l (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[11:1] ),
    .wren_a ( !m68k_rw & m68k_ram1_cs & !m68k_lds_n ),
    .data_a ( m68k_dout[7:0]  ),
    .q_a ( m68k_ram1_dout[7:0] )
    );

ram4kx8dp m68k_ram1_h (
    .clock_a ( clk_16M ),
    .address_a ( m68k_a[11:1] ),
    .wren_a ( !m68k_rw & m68k_ram1_cs & !m68k_lds_n ),
    .data_a ( m68k_dout[15:8]  ),
    .q_a ( m68k_ram1_dout[15:8] )
    );
    
    
endmodule
