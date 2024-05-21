`timescale 1ns / 1ps


interface register_interface;
    logic        clk;
    logic        reset;
    logic        en;
    logic [15:0] in;

    logic [15:0] out;
endinterface


class transaction;
    rand logic [15:0] in;

    logic [15:0] out;

    task display(string name);
        $display("[%s] in:%d, out:%d", name, in, out);
    endtask
endclass


class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event genNextEvent;

    function new();
        tr = new();
    endfunction

    task run();
        repeat (10_000_000) begin
            assert (tr.randomize())
            else $error("Randomize Gen Error!!");

            gen2drv_mbox.put(tr);
            tr.display("GEN");
            @(genNextEvent);
        end
    endtask
endclass


class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event monNextEvent;

    virtual register_interface register_intf;

    function new(virtual register_interface register_intf);
        this.register_intf = register_intf;
    endfunction

    task reset();
        register_intf.en <= 1'b0;
        register_intf.in <= 16'b0;
        register_intf.reset <= 1'b1;
        repeat (5) @(posedge register_intf.clk);
        register_intf.reset <= 1'b0;
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);

            register_intf.in <= tr.in;
            register_intf.en <= 1'b1;
            tr.display("DRV");
            @(posedge register_intf.clk) 
            register_intf.en <= 1'b0;
            @(posedge register_intf.clk)
            ->monNextEvent;
        end
    endtask

endclass


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event monNextEvent;

    virtual register_interface register_intf;

    function new(virtual register_interface register_intf);
        this.register_intf = register_intf;
        tr = new();
    endfunction

    task run();
        forever begin
            @(monNextEvent);
            tr.in  = register_intf.in;
            tr.out = register_intf.out;
            mon2scb_mbox.put(tr);
            tr.display("MON");
        end
    endtask
endclass


class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event genNextEvent;

    int total_cnt, pass_cnt, fail_cnt;
    
    function new();
        total_cnt = 0;
        pass_cnt = 0;
        fail_cnt = 0;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);

            tr.display("SCB");
            if(tr.in == tr.out)begin
                $display("   --> PASS! %d -> %d", tr.in, tr.out);
                pass_cnt++;
            end else begin
                $display("   --> FAIL! %d -> %d", tr.in, tr.out);
                fail_cnt++;
            end
            total_cnt++;
            -> genNextEvent;
        end
    endtask 
endclass


module tb_register ();

    register_interface register_intf ();
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event genNextEvent;
    event monNextEvent;

    register DUT (
        .clk(register_intf.clk),
        .reset(register_intf.reset),
        .en(register_intf.en),
        .in(register_intf.in),

        .out(register_intf.out)
    );

    always #5 register_intf.clk = ~register_intf.clk;

    initial begin
        register_intf.clk   = 1'b0;
        register_intf.reset = 1'b1;
    end


    initial begin
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new();
        drv = new(register_intf);
        mon = new(register_intf);
        scb = new();

        gen.gen2drv_mbox = gen2drv_mbox;
        drv.gen2drv_mbox = gen2drv_mbox;
        mon.mon2scb_mbox = mon2scb_mbox;
        scb.mon2scb_mbox = mon2scb_mbox;

        gen.genNextEvent = genNextEvent;
        scb.genNextEvent = genNextEvent;
        drv.monNextEvent = monNextEvent;
        mon.monNextEvent = monNextEvent;

        drv.reset();

        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any


        $display("=============================");
        $display("===      Final Report     ===");
        $display("=============================");
        $display("Total Test : %d", scb.total_cnt);
        $display("Pass Count : %d", scb.pass_cnt);
        $display("Fail Count : %d", scb.fail_cnt);
        $display("=============================");
        $display("== test bench is finished! ==");
        $display("=============================");
        #10 $finish;
    end

endmodule
