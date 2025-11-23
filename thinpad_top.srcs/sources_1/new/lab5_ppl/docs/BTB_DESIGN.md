# Branch Target Buffer (BTB) Design Documentation

## Overview
The Branch Target Buffer (BTB) is a branch prediction mechanism integrated into the 5-stage pipelined RISC-V CPU. It predicts branch direction and target address before the branch is evaluated in the EXE stage, reducing pipeline flushes on correct predictions and improving throughput.

## Architecture

### BTB Module (`btb.sv`)
- **Type**: Direct-mapped cache
- **Entries**: 64 entries (indexing by PC[7:2])
- **Entry Structure**:
  ```systemverilog
  typedef struct packed {
      logic [31:0] target_pc;      // Predicted branch target address
      logic [1:0]  sat_counter;    // 2-bit saturation counter
      logic        valid;          // Entry validity flag
  } btb_entry_t;
  ```

### Saturation Counter Design
The 2-bit saturation counter implements a 4-state finite state machine:

| State | Binary | Meaning |
|-------|--------|---------|
| 00    | 00     | Weakly Not-Taken (WNT) |
| 01    | 01     | Weakly Taken (WT) |
| 10    | 10     | Strongly Taken (ST) |
| 11    | 11     | Strongly Not-Taken (SNT) |

**State Transitions**:
- **On Taken Branch**:
  - 00 (WNT) → 01 (WT)
  - 01 (WT) → 10 (ST)
  - 10 (ST) → 11 (SNT) [wraps]
  - 11 (SNT) → 00 (WNT) [wraps]

- **On Not-Taken Branch**:
  - 00 (WNT) → 00 (WNT)
  - 01 (WT) → 00 (WNT)
  - 10 (ST) → 01 (WT)
  - 11 (SNT) → 10 (ST)

### BTB Operations

#### 1. **Combinational Query** (in IF stage)
```systemverilog
always_comb begin
    btb_entry_t entry = btb_table[query_index];
    pred_taken = entry.valid && (entry.sat_counter[1] == 1'b1);
    pred_target = entry.target_pc;
end
```
- **Latency**: Combinational (0 delay)
- **Prediction Rule**: Branch is predicted taken if counter state is 10 or 11
- **Output**: `pred_taken_o`, `pred_target_o`

#### 2. **Synchronous Update** (on clock edge)
```systemverilog
always_ff @(posedge clk_i) begin
    if (update_valid_i) begin
        btb_table[update_index].target_pc = update_target_i;
        btb_table[update_index].valid = 1'b1;
        // Saturation counter transition
        if (actual_taken_i) begin
            sat_counter <= sat_counter + 1;  // Saturating increment
        end else begin
            sat_counter <= sat_counter - 1;  // Saturating decrement
        end
    end
end
```
- **Trigger**: From EXE stage after branch evaluation
- **Inputs**: 
  - `btb_update_valid_i`: Enable BTB update
  - `btb_update_pc_i`: Branch instruction PC
  - `btb_actual_taken_i`: Actual branch direction
  - `btb_actual_target_i`: Actual target address

#### 3. **Flush on FENCE.I**
```systemverilog
if (flush_i) begin
    for (int i = 0; i < 64; i++) begin
        btb_table[i].valid <= 1'b0;
    end
end
```
- Clears all BTB entries on FENCE.I instruction
- Ensures memory consistency after self-modifying code

## Integration with Pipeline

### IF Stage (IF_master)
**Query Phase**:
1. On each cycle, compute next PC: `pc_next = pc + 4`
2. Query BTB with `pc_next` as index
3. If BTB predicts taken: `next_pc = btb_pred_target`
4. Otherwise: `next_pc = pc_next` (sequential)

**Mismatch Detection**:
- Compare last fetched PC with actual jump PC from EXE
- If mismatch: Set `pred_jump_o = 1'b1`

```systemverilog
if (btb_pred_taken && last_fetched_pc != pc_jump_i) begin
    pred_jump_o = 1'b1;  // Predicted taken but wrong target
end else if (!btb_pred_taken && (last_fetched_pc + 4) != pc_jump_i) begin
    pred_jump_o = 1'b1;  // Predicted not-taken but actually jumped
end
```

### EXE Stage (EXE)
**Conditional Flush**:
```systemverilog
exe_flush_o = pred_jump_i ? 1'b1 : 1'b0;
```
- Only flush IF/ID stages on prediction mismatch
- Correct predictions: No pipeline flush (throughput improvement)

**BTB Update for All Branches**:
- Always update BTB with actual branch direction
- Support all branch types: BEQ, BNE, BLT, BGE, BLTU, BGEU

### Top-Level Connections (lab5_top_ppl.sv)
```systemverilog
// BTB signal routing
.btb_flush_i(icache_flush_o),                    // From FENCE.I
.btb_update_valid_i(btb_update_valid),           // From EXE
.btb_update_pc_i(btb_update_pc),                 // From EXE
.btb_actual_taken_i(btb_actual_taken),           // From EXE
.btb_actual_target_i(btb_actual_target),         // From EXE
.pred_jump_o(pred_mismatch)                  // To EXE flush control
```

## Performance Impact

### Throughput Improvement
- **Without BTB**: Every branch causes pipeline flush → max ~33% throughput (1 out of 3 stages)
- **With BTB**: Correct predictions have no flush
  - Assuming 80% prediction accuracy: ~87% throughput

### Example: Loop Execution
```asm
LOOP:
    add r1, r1, r2
    bne r1, r3, LOOP
    ...
```
**Without BTB**: Every loop iteration flushes pipeline (branch always causes stall)
**With BTB**: After 1-2 iterations, BTB saturates to "strongly taken" and predicts correctly

## Design Decisions

### Why Direct-Mapped?
- **Simple indexing** from PC[7:2] - no complex hash
- **Fast combinational lookup** - critical for IF stage latency
- **Energy efficient** - single entry access per cycle
- **Sufficient capacity** - 64 entries for typical workloads

### Why 2-Bit Saturation Counter?
- **Hysteresis effect** - resists single mispredictions
- **Good accuracy** - handles pattern changes
- **Low overhead** - only 2 bits per entry
- **Standard design** - proven in industry (e.g., x86 BTBs)

### Why Combinational Query?
- **Zero latency** - prediction available same cycle as PC
- **Enables speculative fetch** - if predicted taken, fetch from target immediately
- **Avoids pipeline stall** - IF stage doesn't wait for BTB lookup

## Entry Format (4 bytes per entry × 64 = 256 bytes total)
```
[31:0]   target_pc    (32 bits)
[33:32]  sat_counter  (2 bits)
[34]     valid        (1 bit)
         padding      (29 bits) - for word alignment
```

## Initialization
- On reset: All entries marked invalid (valid = 0)
- BTB learns branch patterns during first executions
- Entries remain valid until explicitly flushed (FENCE.I) or overwritten

## Future Enhancements
1. **2-level BTB** - L1 (4 entries, fast) + L2 (64 entries, larger)
2. **Pattern History Table** - Track branch history for better prediction
3. **Return Stack Buffer** - Specialized prediction for function returns
4. **Adaptive replacement** - LRU or pseudo-LRU instead of direct-mapped
5. **Confidence bits** - Track prediction confidence for speculative execution control

## Testing Considerations
- Verify saturation counter transitions on branch updates
- Test mismatch detection with various branch patterns
- Validate FENCE.I flush operation
- Simulate branch-heavy loops to measure prediction accuracy
- Check for timing violations in combinational query path
