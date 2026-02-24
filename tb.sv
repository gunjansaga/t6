`timescale 1ns/1ps

import atm_pkg::*;

module tb;

logic clk = 0, rst;
logic card_inserted, pin_correct, balance_ok;
logic dispense_cash;

// ⭐ CONNECT STATE FROM DUT
state_t state;

always #5 clk = ~clk;

atm_controller dut (
    .clk(clk),
    .rst(rst),
    .card_inserted(card_inserted),
    .pin_correct(pin_correct),
    .balance_ok(balance_ok),
    .dispense_cash(dispense_cash),
    .state(state)
);

////////////////////////////////////////////////////
// COVERAGE
////////////////////////////////////////////////////
covergroup cg_atm @(posedge clk);

cp_state: coverpoint state {
    bins all_states[] = {IDLE, CHECK_PIN, CHECK_BAL, DISPENSE};
}

cp_trans: coverpoint state {
    bins trans_pin_pass  = (CHECK_PIN => CHECK_BAL);
    bins trans_pin_fail  = (CHECK_PIN => IDLE);
    bins trans_bal_pass  = (CHECK_BAL => DISPENSE);
    bins trans_bal_fail  = (CHECK_BAL => IDLE);
}

endgroup

cg_atm cg;

////////////////////////////////////////////////////
// ASSERTIONS
////////////////////////////////////////////////////
property p_safe_dispense;
@(posedge clk)
dispense_cash |-> (pin_correct && balance_ok);
endproperty

assert property(p_safe_dispense)
else $error("SECURITY FAIL: Cash dispensed illegally!");

property p_return_idle;
@(posedge clk)
(state == DISPENSE) |=> (state == IDLE);
endproperty

assert property(p_return_idle)
else $error("FLOW FAIL: ATM did not return to IDLE.");

////////////////////////////////////////////////////
// WAVEFORM
////////////////////////////////////////////////////
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
end

////////////////////////////////////////////////////
// STIMULUS
////////////////////////////////////////////////////
initial begin

cg = new();

$display("\n--- ATM Verification Started ---");

// RESET
rst = 1;
card_inserted = 0;
pin_correct = 0;
balance_ok = 0;

repeat(3) @(posedge clk);
rst = 0;

////////////////////////////////////////////////
// SCENARIO 1 — SUCCESS
////////////////////////////////////////////////
$display("[Scenario 1] Valid Transaction");

card_inserted = 1;
@(posedge clk);

pin_correct = 1;
@(posedge clk);

balance_ok = 1;
@(posedge clk);

@(posedge clk); // allow dispense

card_inserted = 0;
pin_correct = 0;
balance_ok = 0;

////////////////////////////////////////////////
// SCENARIO 2 — BAD PIN
////////////////////////////////////////////////
$display("[Scenario 2] Invalid PIN");

@(posedge clk);
card_inserted = 1;

@(posedge clk);
pin_correct = 0;

@(posedge clk);

card_inserted = 0;

////////////////////////////////////////////////
// SCENARIO 3 — LOW BALANCE
////////////////////////////////////////////////
$display("[Scenario 3] Insufficient Balance");

@(posedge clk);
card_inserted = 1;

@(posedge clk);
pin_correct = 1;

@(posedge clk);
balance_ok = 0;

@(posedge clk);

card_inserted = 0;
pin_correct = 0;

$display("\nStimulus completed — waiting for timeout...");

end


////////////////////////////////////////////////////
// ⭐ HARD STOP @150ns
////////////////////////////////////////////////////
initial begin
    #150;

    $display("\n==============================");
    $display("AUTO STOP @150ns");
    $display("Final Coverage: %0.2f %%", cg.get_inst_coverage());
    $display("==============================");

    $finish;
end

endmodule
