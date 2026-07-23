module tb_ahb_lite_master;
    // DUT Signals
    reg         HCLK;
    reg         HRESETn;

    reg         HREADY;
    reg         HRESP;
    reg [31:0]  HRDATA;

    reg         VALID;
    reg         MID;
    reg         WRITE;
    reg [31:0]  ADDR;
    reg [31:0]  WDATA;
    reg [2:0]   SIZE;

    wire [31:0] HADDR;
    wire        HWRITE;
    wire [2:0]  HSIZE;
    wire [2:0]  HBURST;
    wire [3:0]  HPROT;
    wire [1:0]  HTRANS;
    wire        HMASTLOCK;
    wire [31:0] HWDATA;

    wire        ACCEPT;
    wire [31:0] RDATA;
    wire        RESP;
    wire        RVALID;



    integer pass_cnt;
    integer fail_cnt;


    ahb_lite_master dut (
        .HCLK(HCLK),
        .HRESETn(HRESETn),

        .HADDR(HADDR),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),
        .HBURST(HBURST),
        .HPROT(HPROT),
        .HTRANS(HTRANS),
        .HMASTLOCK(HMASTLOCK),
        .HWDATA(HWDATA),

        .HREADY(HREADY),
        .HRESP(HRESP),
        .HRDATA(HRDATA),

        .VALID(VALID),
        .MID(MID),
        .WRITE(WRITE),
        .ADDR(ADDR),
        .WDATA(WDATA),
        .SIZE(SIZE),

        .ACCEPT(ACCEPT),
        .RDATA(RDATA),
        .RESP(RESP),
        .RVALID(RVALID)
    );


    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end



    task check;
        input condition;
        input string msg;
        begin
            $display("time = %0t", $time);
            if(condition) begin
                pass_cnt = pass_cnt + 1;
                $display("PASS");
            end
            else begin
                fail_cnt = fail_cnt + 1;
                $display("FAIL");
            end
            $display("%s",msg);
        end
    endtask



    task send_req;
        input wr;
        input mid_i;
        input [31:0] addr_i;
        input [31:0] data_i;
        input [2:0] size_i;

        begin
            VALID <= 1;
            MID   <= mid_i;
            WRITE <= wr;
            ADDR  <= addr_i;
            WDATA <= data_i;
            SIZE  <= size_i;

            @(negedge HCLK);
        end
    endtask



    task do_reset;
    begin
        HRESETn = 0;

        VALID = 0;
        MID   = 0;
        WRITE = 0;
        ADDR  = 0;
        WDATA = 0;
        SIZE  = 0;

        HREADY = 1;
        HRESP  = 0;
        HRDATA = 0;

        repeat(3) @(negedge HCLK);

        HRESETn = 1;

        @(negedge HCLK);

        check(HTRANS==2'b00, "Reset puts FSM in IDLE");
    end
    endtask


    initial begin

        pass_cnt = 0;
        fail_cnt = 0;

        do_reset();

        
        // TEST 1 : BYTE BURST
        $display("=== BYTE BURST ===");

        send_req(1,0,32'h1000,32'h11,3'b000);

        check(ACCEPT,"BYTE burst first beat accepted");


        send_req(1,1,32'hxxxx,32'h22,3'b000);

        check(HADDR==32'h1001, "Byte increment = 1");


        send_req(1,1,32'hxxxx,32'h33,3'b000);

        check(HADDR==32'h1002, "Byte increment = 2");

        @(negedge HCLK);

        
        // TEST 2 : HALFWORD BURST
        $display("=== HALFWORD BURST ===");

        send_req(1,0,32'h2000,32'hAAAA,3'b001);

        send_req(1,1,32'hxxxx,32'hBBBB,3'b001);


        check(HADDR==32'h2002, "Halfword increment = +2");

        send_req(1,1,32'hxxxx,32'hCCCC,3'b001);


        check(HADDR==32'h2004, "Halfword increment = +4");

        VALID <= 0;
        MID   <= 0;

        @(negedge HCLK);


        // TEST 3 : WORD BURST
        $display("=== WORD BURST ===");

        send_req(1,0,32'h3000,32'h11111111,3'b010);

        send_req(1,1,32'hxxxx,32'h22222222,3'b010);


        check(HADDR==32'h3004, "Word increment = +4");

        send_req(1,1,32'hxxxx,32'h33333333,3'b010);


        check(HADDR==32'h3008, "Word increment = +8");

        VALID <= 0;
        MID   <= 0;


        // TEST 4 : BUSY STATE
        $display("\n=== BUSY TEST ===");

        send_req(1,0,32'h4000,32'h1234,3'b010);

        VALID <= 0;
        MID   <= 1;

        @(negedge HCLK);

        check(HTRANS==2'b01, "FSM entered BUSY");

        VALID <= 1;
        MID   <= 1;

        @(negedge HCLK);

        check(HTRANS==2'b11, "BUSY -> SEQ");

        VALID <= 0;
        MID   <= 0;


        // TEST 5 : WAIT STATES
        $display("\n=== WAIT STATE TEST ===");

        send_req(1,0,32'h5000,32'hDEADBEEF,3'b010);

        HREADY <= 0;

        repeat(3) begin
            @(negedge HCLK);

            check(HTRANS==2'b10, "State held during wait");
        end

        HREADY <= 1;

        @(negedge HCLK);

        VALID <= 0;


        // TEST 6 : READ DATA RETURN
        $display("\n=== READ TEST ===");

        send_req(0,0,32'h6000,32'h0,3'b010);

        HRDATA <= 32'hCAFEBABE;

        @(negedge HCLK);

        check(RVALID==1, "RVALID asserted");

        check(RDATA==32'hCAFEBABE, "Read data matched");

        VALID <= 0;


        // TEST 7 : ERROR RESPONSE
        $display("\n=== ERROR TEST ===");

        send_req(0,0,32'h7000,32'h0,3'b010);

        HRESP <= 1;

        @(negedge HCLK);

        check(RESP==1, "ERROR response propagated");


        check(HTRANS==2'b00,
              "FSM returned to IDLE after error");



        repeat(5) @(negedge HCLK);

        $display("=================================");
        $display("PASSED = %0d", pass_cnt);
        $display("FAILED = %0d", fail_cnt);


        $finish;

    end

endmodule