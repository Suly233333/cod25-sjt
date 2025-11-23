# BTB (Branch Target Buffer) Usage Guide

## Quick Start

The BTB is automatically integrated into the CPU pipeline. Here's how it works transparently:

### 1. **Automatic Prediction** (No user action needed)
Each cycle in the IF stage:
1. BTB queries the predicted PC with current program counter
2. If prediction says "taken", fetch from predicted target
3. If prediction says "not taken", fetch sequentially (PC+4)
4. No pipeline stall or delay - all combinational

### 2. **Automatic Learning** (EXE stage)
When a branch completes in EXE:
1. Actual branch direction is known
2. BTB entry is updated with saturation counter increment/decrement
3. Target address is recorded for next prediction
4. On mismatch: IF/ID stages are flushed (penalty: 3 cycles)

### 3. **Automatic Invalidation** (FENCE.I)
When FENCE.I instruction executes:
1. All 64 BTB entries are cleared
2. Ensures correct behavior after self-modifying code
3. Used by OS after dynamic code generation

## Performance Tuning

### Measuring Prediction Accuracy
To determine your code's branch prediction rate:
```asm
# Count branches
# Count mispredictions (pipeline flushes from EXE stage)
accuracy = (branches - mispredictions) / branches
```

Typical values:
- Sequential code: ~95% (mostly loop branches, highly predictable)
- If/else heavy: ~80% (mixed patterns)
- Indirect branches: ~60% (less predictable without history)

### Code Patterns That Benefit Most
✅ **High prediction gain**:
- Loops (saturation counter learns pattern quickly)
- Conditional forward branches (often not-taken)
- Backward branches in conditionals (often taken)

⚠️ **Moderate gain**:
- Alternating patterns (BNT, BT, BNT, BT)
- Unpredictable conditionals

❌ **No prediction gain**:
- Random branch patterns
- Branches dependent on untrackable external input

## Integration Details

### Signals to Understand

#### BTB Query (IF Stage → BTB)
```systemverilog
logic [31:0] pc_next;           // Next PC to fetch
// Query uses PC[7:2] as index automatically
```

#### BTB Prediction (BTB → IF Stage)
```systemverilog
logic btb_pred_taken;           // Prediction: is branch taken?
logic [31:0] btb_pred_target;   // Prediction: target address
```

#### BTB Update (EXE Stage → BTB)
```systemverilog
logic btb_update_valid;         // Enable BTB update
logic [31:0] btb_update_pc;     // PC of branch instruction
logic btb_actual_taken;         // Actual branch direction
logic [31:0] btb_actual_target; // Actual target address
```

#### Mismatch Detection (IF → EXE Flush Control)
```systemverilog
logic pred_mismatch;            // Prediction was wrong
// Used to trigger: exe_flush_o = pred_mismatch ? 1'b1 : 1'b0;
```

### PC Multiplexer Priority (in IF stage)
```
1. Jump from EXE (highest priority)    → pc_jump_i
2. Not BTB prediction                  → pc_next (PC + 4)
3. BTB prediction                       → btb_pred_target
4. Sequential fetch (lowest priority)  → pc_next
```

Conceptually: If EXE says jump, use that. Else if BTB says taken, use target. Else go sequential.

## Common Issues and Debugging

### Issue 1: Pipeline Flushing on Every Branch
**Symptom**: High misprediction rate even on simple loops
**Cause**: BTB saturation counter not converging to correct prediction
**Debug**:
- Check that EXE properly sets `btb_actual_taken` based on branch result
- Verify saturation counter state machine logic
- Ensure BTB update is enabled for all branch types

**Fix**: Add tracing to observe saturation counter values:
```systemverilog
// In simulation/debug
$monitor("BTB PC=%h taken=%b counter=%b", 
         btb_update_pc, btb_actual_taken, 
         btb_table[btb_index].sat_counter);
```

### Issue 2: Mispredictions Not Triggering Flush
**Symptom**: Incorrect instructions fetch but pipeline doesn't flush
**Cause**: `pred_jump_o` not properly generated or connected
**Fix**: Verify in IF_master:
```systemverilog
// Mismatch detection
if (btb_pred_taken && last_fetched_pc != pc_jump_i) begin
    pred_jump_o = 1'b1;
end else if (!btb_pred_taken && (last_fetched_pc + 4) != pc_jump_i) begin
    pred_jump_o = 1'b1;
end else begin
    pred_jump_o = 1'b0;
end
```

### Issue 3: FENCE.I Not Clearing BTB
**Symptom**: After self-modifying code, old branch predictions still used
**Cause**: `btb_flush_i` not connected or not working
**Fix**: 
- Verify `icache_flush_o` from EXE is routed to `btb_flush_i`
- Check FENCE.I instruction is recognized correctly
- Validate reset logic in BTB module

## Behavioral Verification

### Test Case 1: Loop Prediction
```
Loop: beq r1, r0, End      (backward branch, predicted taken)
      addi r1, r1, -1
      jal r0, Loop         (unconditional jump, always flushed)
End:
```
Expected BTB behavior:
- Iteration 1: BEQ mispredicts (counter=00), flush happens
- Iteration 2: BEQ counter=01 (weak taken), may still mispredicts
- Iteration 3+: BEQ counter reaches 10/11, predicts correctly, NO FLUSH

### Test Case 2: Branch with Alternating Pattern
```
Cond: bne r2, r3, True
      # false path
      jal r0, Cond
True: # true path
      jal r0, Cond
```
Expected: Saturation counter oscillates, prediction quality ~50%

### Test Case 3: FENCE.I Clearing
```
# Before: BTB filled with predictions
fence.i              # Clears all 64 BTB entries
# After: First branch back to BTB will be misprediction
```
Monitor BTB valid bits - should all become 0 on FENCE.I

## Synthesis Considerations

### Resource Usage
- **SRAM/BRAM**: 256 bytes total (64 entries × 4 bytes)
  - On many FPGAs: Uses distributed RAM or a small block RAM
  - On ASIC: Can be custom SRAM macro

- **Combinational Logic**: ~800 LUTs (estimated)
  - PC indexing: ~10 LUTs
  - Saturation counter FSM: ~20 LUTs
  - 2-to-1 mux for next PC: ~30 LUTs
  - Valid bit check: ~5 LUTs
  - Multiplied by 64 entries: ~3200 LUTs without optimization
  - After synthesis: Typically ~800-1000 LUTs actual

### Timing Path
**Critical path** (usually NOT bottleneck):
- PC[7:2] generation → ~2 ns
- SRAM lookup → ~2-3 ns (depends on SRAM macro)
- 2-to-1 mux → ~0.5 ns
- Total: ~5-6 ns (easily meets most clock frequencies)

**Note**: Actual IF stage latency is dominated by ICache lookup (~2-3 ns) and memory arbitration

## Instruction-by-Instruction Behavior

### Conditional Branches (beq, bne, blt, bge, bltu, bgeu)
```
Cycle N (IF):   Fetch branch from BTB prediction
Cycle N+1 (ID): Decode branch, no stall
Cycle N+2 (EXE):
  - Evaluate condition
  - Update BTB with actual direction
  - If mispredicted: exe_flush_o=1
Cycle N+3 (MEM): 
  - If flushed: IF/ID/EXE now have bubble instruction
  - Otherwise: Fetch continues normally
```

### Unconditional Jumps (jal, jalr)
```
Cycle N (IF):    Fetch next instruction (no BTB, jump decoded in ID/EXE)
Cycle N+1 (ID):  Decode jal, generate target in imm
Cycle N+2 (EXE): Jump_o = 1, causes immediate flush
Cycle N+3 (IF):  Fetch from jump target
```

**Note**: JAL/JALR always flush (not predicted), but target is known by EXE so refetch is from correct address.

## Performance Analysis Examples

### Example 1: Fibonacci (Recursive)
```
fibonacci:
    ...
    blt a0, a1, not_recursive  ← BTB learns: usually taken
    ...
    bne return_addr, r0, ...   ← Highly unpredictable
    ...
```
Prediction accuracy: ~60-70% (conditional branch learns, but many branch types)

### Example 2: Tight Nested Loops
```
outer_loop:
    addi a0, a0, 1
    blt a0, a2, outer_loop    ← BTB: strongly taken (learned quickly)
    
    addi a1, a1, 1
    blt a1, a3, outer_loop    ← BTB: strongly not-taken (exit condition)
```
Prediction accuracy: ~95%+ (loop branches are very predictable)

### Example 3: Pipeline Throughput
Without BTB:
```
Time:  1    2    3    4    5    6    7    8
IF:    I1   I2   I3   I4   I5   BNE  X    X
ID:    I1   I2   I3   I4   BNE  X    X
EX:    I1   I2   I3   BNE  X
Throughput: 3/6 = 50%
```

With BTB (correct prediction):
```
Time:  1    2    3    4    5    6    7    8
IF:    I1   I2   I3   I4   I5   I6   I7   I8
ID:    I1   I2   I3   I4   I5   I6   I7
EX:    I1   I2   I3   I4   I5   I6
Throughput: 6/8 = 75%
```

## Reference Implementation

For modifying or extending BTB functionality:

### Adding Confidence Bits
```systemverilog
// Track prediction confidence
logic [1:0] confidence;  // 00=low, 11=high

if (update_valid_i) begin
    if (correct_prediction) begin
        confidence <= confidence + 1;  // Increase confidence
    end else begin
        confidence <= 2'b00;  // Reset to low on mismatch
    end
end

// Use confidence to decide between BTB and other predictors
pred_taken = entry.valid && (confidence > 2'b01) && 
             (entry.sat_counter[1] == 1'b1);
```

### Adding Return Stack Buffer
```systemverilog
// Detect return (jalr x0, 0(x1))
if (is_return) begin
    pred_target = return_stack_pop();
    pred_taken = 1'b1;
end else if (btb_hit) begin
    pred_target = btb_pred_target;
    pred_taken = btb_pred_taken;
end
```

## Related Components
- **ICache** (`icache.sv`): Instruction cache that works alongside BTB
- **IF_master** (`IF_master.sv`): Fetch unit integrating both BTB and ICache
- **EXE** (`EXE.sv`): Generates BTB updates and mismatch signals
- **FENCE.I**: Clears both ICache and BTB when executed
