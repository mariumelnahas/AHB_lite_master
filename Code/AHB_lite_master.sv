module ahb_lite_master (
    // Global signals
    input  wire        HCLK,
    input  wire        HRESETn,

    // AHB-Lite side
    output reg  [31:0] HADDR,
    output wire        HWRITE,
    output wire [2:0]  HSIZE,
    output wire [2:0]  HBURST,
    output wire [3:0]  HPROT,
    output wire [1:0]  HTRANS,
    output wire        HMASTLOCK,
    output reg  [31:0] HWDATA,

    input  wire        HREADY,
    input  wire        HRESP,
    input  wire [31:0] HRDATA,

    // Processor side
    input  wire        VALID,      
    input  wire        MID,       
    input  wire        WRITE,      
    input  wire [31:0] ADDR,
    input  wire [31:0] WDATA,
    input  wire [2:0]  SIZE,

    output wire        ACCEPT,     
    output wire [31:0] RDATA,
    output wire        RESP,
    output wire        RVALID      
);


    localparam [1:0] ST_IDLE   = 2'b00,
                     ST_BUSY   = 2'b01,
                     ST_NONSEQ = 2'b10,
                     ST_SEQ    = 2'b11;

    reg [1:0] state, next_state;


    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            state <= ST_IDLE;
        else
            state <= next_state;
    end


    always @(*) begin
        next_state = ST_IDLE;
        case (state)
            ST_IDLE: begin
                if (!HREADY || !VALID)
                    next_state = ST_IDLE;
                else
                    next_state = ST_NONSEQ;
            end

            ST_BUSY, ST_NONSEQ, ST_SEQ: begin
                if (HRESP)
                    next_state = ST_IDLE;
                else if (!HREADY)
                    next_state = state;
                else begin
                    case ({VALID, MID})
                        2'b00: next_state = ST_IDLE;
                        2'b01: next_state = ST_BUSY;
                        2'b10: next_state = ST_NONSEQ;
                        2'b11: next_state = ST_SEQ;
                        default: next_state = ST_IDLE;
                    endcase
                end
            end

            default: next_state = ST_IDLE;
        endcase
    end


    assign HTRANS = state;



    reg fresh_accept, burst_advance;

    always @(*) begin
        fresh_accept  = 1'b0;
        burst_advance = 1'b0;
        if (HREADY && !HRESP) begin
            if (state == ST_IDLE) begin
                fresh_accept = VALID; 
            end else begin
                if (MID)
                    burst_advance = 1'b1;
                else if (VALID)
                    fresh_accept = 1'b1;
            end
        end
    end

    reg  [31:0] addr_r;
    reg  [2:0]  size_r;
    reg         write_r;

    wire [31:0] incr_bytes = 32'd1 << size_r;

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_r  <= 32'd0;
            size_r  <= 3'd0;
            write_r <= 1'b0;
        end else if (fresh_accept) begin
            addr_r  <= ADDR;
            size_r  <= SIZE;
            write_r <= WRITE;
        end else if (burst_advance) begin
            addr_r  <= addr_r + incr_bytes;
        end
    end

    always @(*) begin
        HADDR = addr_r;
    end

    assign HWRITE = write_r;
    assign HSIZE  = size_r;

    assign ACCEPT = HREADY & ~HRESP & VALID;

    always @(posedge HCLK) begin
        if (ACCEPT)
            HWDATA <= WDATA;
    end

    assign RVALID = (state == ST_NONSEQ || state == ST_SEQ) & HREADY;
    assign RDATA  = HRDATA;
    assign RESP   = HRESP;

    assign HBURST    = 3'b001;  //for simplicty we will assume that any transfer in INCR and if it is a single burst it will do just one beat
    assign HPROT     = 4'b0011; //unsupported
    assign HMASTLOCK  = 1'b0;   //insupported

endmodule