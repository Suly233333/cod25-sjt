# BTB Testing and Validation Guide

## Test Framework Overview

The Branch Target Buffer (BTB) requires systematic testing across multiple levels:
1. **Unit tests** - Individual BTB module behavior
2. **Integration tests** - BTB within pipeline
3. **System tests** - Real instruction sequences
4. **Performance tests** - Throughput and prediction accuracy

## Unit Testing (btb.sv Module)

### Test 1: Initial State Verification
**Objective**: Verify BTB initializes correctly
```systemverilog
// Check: All entries should be invalid on reset
initial begin
    for (int i = 0; i < 64; i++) begin
        assert (btb_table[i].valid == 1'b0) 
            else $error("Entry %d not initialized to invalid", i);
    end
end
```

### Test 2: Query Operation (Combinational)
**Objective**: Verify prediction generation is combinational
```systemverilog
task test_query(input logic [31:0] pc, input logic [31:0] target, 
                input logic [1:0] counter);
    // Load entry manually
    btb_table[pc[7:2]].valid = 1'b1;
    btb_table[pc[7:2]].target_pc = target;
    btb_table[pc[7:2]].sat_counter = counter;
    
    #0 begin  // No delay - combinational
        // Counter in bits [1] says taken if == 1
        if (counter[1] == 1'b1) begin
            assert (pred_taken_o == 1'b1) 
                else $error("Query failed for counter=%b", counter);
            assert (pred_target_o == target)
                else $error("Target mismatch: got %h, expected %h", 
                           pred_target_o, target);
        end else begin
            assert (pred_taken_o == 1'b0)
                else $error("Query should not predict taken for counter=%b", counter);
        end
    end
endtask

initial begin
    // Test all 4 counter states
    test_query(32'h0000_0000, 32'h0000_0004, 2'b00);  // WNT
    test_query(32'h0000_0004, 32'h0000_1000, 2'b01);  // Weak taken
    test_query(32'h0000_0008, 32'h0000_2000, 2'b10);  // Weak taken (border)
    test_query(32'h0000_000C, 32'h0000_3000, 2'b11);  // Strongly taken
    
    // Invalid entry should not predict
    test_query(32'h0000_0040, 32'h0000_4000, 2'b11);  // Not valid, shouldn't predict
end
```

### Test 3: Saturation Counter State Machine
**Objective**: Verify counter transitions
```systemverilog
task test_counter_transition(
    input logic [1:0] initial_state,
    input logic actual_taken,
    input logic [1:0] expected_next
);
    @(posedge clk_i);
    
    // Set initial state
    btb_table[0].valid = 1'b1;
    btb_table[0].sat_counter = initial_state;
    
    // Apply update
    update_valid_i = 1'b1;
    update_index = 0;
    actual_taken_i = actual_taken;
    update_target_i = 32'h1000;
    
    @(posedge clk_i);
    
    // Check result
    assert (btb_table[0].sat_counter == expected_next)
        else $error("Counter transition failed: %b + taken=%b -> got %b, expected %b",
                   initial_state, actual_taken, 
                   btb_table[0].sat_counter, expected_next);
    
    update_valid_i = 1'b0;
endtask

initial begin
    // Taken transitions
    test_counter_transition(2'b00, 1'b1, 2'b01);  // 00→01 taken
    test_counter_transition(2'b01, 1'b1, 2'b10);  // 01→10 taken
    test_counter_transition(2'b10, 1'b1, 2'b11);  // 10→11 taken
    test_counter_transition(2'b11, 1'b1, 2'b00);  // 11→00 taken (wrap)
    
    // Not taken transitions
    test_counter_transition(2'b00, 1'b0, 2'b00);  // 00→00 not-taken
    test_counter_transition(2'b01, 1'b0, 2'b00);  // 01→00 not-taken
    test_counter_transition(2'b10, 1'b0, 2'b01);  // 10→01 not-taken
    test_counter_transition(2'b11, 1'b0, 2'b10);  // 11→10 not-taken
end
```

### Test 4: Multi-Entry Management
**Objective**: Verify independent entry management
```systemverilog
initial begin
    // Update entry 0
    update_valid_i = 1'b1;
    update_index = 0;
    actual_taken_i = 1'b1;
    @(posedge clk_i);
    
    // Update entry 1
    update_index = 1;
    actual_taken_i = 1'b0;
    @(posedge clk_i);
    
    // Verify both updated correctly
    assert (btb_table[0].sat_counter == 2'b01) 
        else $error("Entry 0 not updated");
    assert (btb_table[1].sat_counter == 2'b11)
        else $error("Entry 1 not updated");
    
    // Query both simultaneously (if supported)
    // ...
end
```

### Test 5: FENCE.I Flush Operation
**Objective**: Verify all entries invalidated on flush
```systemverilog
initial begin
    // Populate BTB with several entries
    for (int i = 0; i < 16; i++) begin
        btb_table[i].valid = 1'b1;
        btb_table[i].sat_counter = 2'b11;
        @(posedge clk_i);
    end
    
    // Issue flush
    flush_i = 1'b1;
    @(posedge clk_i);
    flush_i = 1'b0;
    
    // Verify all cleared
    @(posedge clk_i);
    for (int i = 0; i < 64; i++) begin
        assert (btb_table[i].valid == 1'b0)
            else $error("Entry %d not flushed", i);
    end
end
```

## Integration Testing (Pipeline Level)

### Test 6: BTB with IF Stage
**Objective**: Verify IF stage correctly uses BTB prediction
```systemverilog
// Setup
initial begin
    // Pre-populate BTB entry for PC 0x1000 → target 0x2000
    setup_btb_entry(32'h1000, 32'h2000, 2'b11);  // Strongly taken
end

task verify_predicted_fetch;
    logic [31:0] pc;
    logic [31:0] predicted_target;
    
    // IF stage at PC 0x1000
    pc = 32'h1000;
    
    // Query BTB combinationally
    #1;  // Small delay for combinational logic
    
    // Check PC mux selected predicted target
    assert (if_next_pc == 32'h2000)
        else $error("IF didn't use BTB prediction: got %h, expected 0x2000", 
                   if_next_pc);
end

initial begin
    verify_predicted_fetch();
end
```

### Test 7: Mismatch Detection
**Objective**: Verify mismatch when actual ≠ predicted
```systemverilog
task verify_mismatch_detection(
    logic [31:0] predicted_pc,
    logic [31:0] actual_pc
);
    // Setup: BTB predicts predicted_pc
    // Simulate: EXE produces actual_pc as jump target
    
    // Check: pred_mismatch_o should be 1
    assert (pred_mismatch_o == 1'b1)
        else $error("Mismatch not detected: predicted %h, actual %h",
                   predicted_pc, actual_pc);
end

initial begin
    // Case 1: Predicted taken, but actually not taken
    verify_mismatch_detection(32'h2000,  // Would fetch from here (target)
                             32'h1004);  // But actually PC+4, not jump
    
    // Case 2: Predicted not taken (PC+4), but actually jumped
    verify_mismatch_detection(32'h1004,  // Sequential
                             32'h3000);  // But actually jumped to different target
    
    // Case 3: Predicted with wrong target
    verify_mismatch_detection(32'h2000,  // Predicted this target
                             32'h2004);  // But actual target is different
end
```

## System-Level Testing

### Test 8: Tight Loop (Highly Predictable)
**Objective**: Test BTB learning on loop branch
```asm
# Test: Loop that iterates 100 times
# BTB should learn "strongly taken" for backward branch
# Expected: After few iterations, no pipeline flushes

LOOP:
    addi a0, a0, -1           # Decrement counter
    bne a0, x0, LOOP          # Branch back if not zero
    addi a1, a1, 1            # (outside loop) 
```

Trace analysis:
- Iteration 1: BNE mispredicts (not yet in BTB) - FLUSH
- Iteration 2: BNE counter = 01 (weak taken) - may FLUSH
- Iteration 3: BNE counter = 10 (weak taken) - may FLUSH  
- Iteration 4+: BNE counter = 11 (strong taken) - NO FLUSH
- Final: Predicted taken but BNE NOT taken - FLUSH

Expected flushes: ~4-5 out of 100 = ~95% accuracy

### Test 9: Alternating Pattern (Unpredictable)
**Objective**: Test BTB on random pattern
```asm
# Simulate alternating branch (taken/not-taken/taken/...)
# Expected: Poor accuracy, flushes on each direction change

BNE_1:  taken → counter 00→01 → flush
BNE_2:  not-taken → counter 01→00 → flush
BNE_3:  taken → counter 00→01 → flush
...
```

Expected flushes: ~50% (poor but expected for random patterns)

### Test 10: FENCE.I Clearing Behavior
**Objective**: Test self-modifying code handling
```asm
# Code generator example
    li a0, CODE_ADDR
    # Write modified instructions
    sw new_instr, 0(a0)
    fence.i                # Clear caches and BTB
    jalr x1, 0(a0)         # Execute new code
    # Should not use stale BTB predictions
```

Expected behavior:
- Before FENCE.I: BTB has predictions from old code
- FENCE.I: All BTB entries invalidated
- After FENCE.I: First branch after fence will mispredicts (cold start)
- Subsequent branches: BTB learns new pattern

## Performance Metrics

### Metric 1: Prediction Accuracy
```
Accuracy = (Total Branches - Mispredictions) / Total Branches

# Measured from:
mispredictions = exe_flush_o triggered by pred_mismatch_i
```

Target: ≥80% for typical workloads

### Metric 2: Pipeline Throughput with BTB
```
Throughput = Completed Instructions / Total Cycles

# Example: 100-iteration loop
Without BTB: ~50% (flush every branch)
With BTB:    ~80% (flush only on mismatch)
```

### Metric 3: Flush Latency
```
Flush latency = pipeline depth = 5 cycles (IF to WB)

# On prediction mismatch:
- Cycle N: Mismatch detected in EXE
- Cycle N+1: IF/ID/EXE contain bubbles
- Cycle N+2: New IF fetches correct instruction
```

## Testbench Structure

```systemverilog
module btb_tb();
    // Clock and reset
    logic clk_i, rst_i;
    
    // BTB interface
    logic [31:0] query_pc;
    logic query_valid;
    logic pred_taken_o;
    logic [31:0] pred_target_o;
    
    logic update_valid_i;
    logic [31:0] update_pc;
    logic actual_taken_i;
    logic [31:0] actual_target_i;
    logic flush_i;
    
    // Instantiate DUT
    btb dut (.*);
    
    // Clock generation
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i;  // 100 MHz
    end
    
    // Test suites
    initial begin
        rst_i = 1;
        @(posedge clk_i);
        rst_i = 0;
        
        // Run unit tests
        test_initial_state();
        test_query_operation();
        test_counter_transitions();
        test_multi_entry();
        test_flush();
        
        $display("All tests completed!");
        $finish;
    end
    
    // Helper tasks
    task setup_btb_entry(logic [31:0] pc, logic [31:0] target, 
                         logic [1:0] counter);
        // Manually set entry (in simulation)
        dut.btb_table[pc[7:2]].valid = 1'b1;
        dut.btb_table[pc[7:2]].target_pc = target;
        dut.btb_table[pc[7:2]].sat_counter = counter;
    endtask
endmodule
```

## Regression Test Suite

Create comprehensive test that validates:
1. ✅ All counter transitions work
2. ✅ Queries return correct predictions
3. ✅ Updates learn branch patterns
4. ✅ FENCE.I clears all entries
5. ✅ Multiple entries don't interfere
6. ✅ Integration with IF/EXE produces correct PC
7. ✅ Prediction mismatches trigger flushes

## Known Limitations and Edge Cases

### Edge Case 1: PC Aliasing
Multiple PCs map to same BTB entry (PC[7:2]):
```
PC = 0x1000 → index = 0x40
PC = 0x1400 → index = 0x50  (different)
PC = 0x1044 → index = 0x41  (different)
```
No issue - direct indexing prevents aliasing in lower bits

### Edge Case 2: Update During Query
If update and query occur same cycle:
- Query: Uses old entry value (synchronous update)
- Update: Applied on next clock edge

### Edge Case 3: Rapid Context Switch
If multiple processes run with different branch patterns:
- BTB doesn't distinguish processes
- Predictions may be incorrect for new process
- Solution: FENCE.I after context switch

## Verification Checklist

- [ ] Unit: All 64 entries initialize to invalid
- [ ] Unit: Query is combinational (no delay)
- [ ] Unit: All 8 counter transitions verified
- [ ] Unit: FENCE.I clears all entries
- [ ] Integration: IF stage uses BTB prediction for next PC
- [ ] Integration: Mismatch detected when prediction ≠ actual
- [ ] Integration: exe_flush_o set on mismatch
- [ ] System: Loop accuracy >90%
- [ ] System: Random pattern accuracy 40-60%
- [ ] System: After FENCE.I, cold start behavior
- [ ] Performance: Throughput improvement on loops
- [ ] Synthesis: Timing path <10 ns

## Next Steps

After validation passes:
1. Synthesis and place-and-route
2. FPGA implementation testing
3. Performance benchmarking on real instruction traces
4. Fine-tuning saturation counter (could use different weights)
5. Consider enhancement: 2-level BTB or pattern history table
