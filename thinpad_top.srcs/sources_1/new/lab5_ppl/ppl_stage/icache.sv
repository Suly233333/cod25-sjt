// Instruction Cache (ICache) Module
// 2-way set-associative cache with 128 bytes capacity
// Cache organization: 32 sets × 2 ways, 4 bytes per line
// Total cache: 32 sets × 2 ways × 4 bytes = 256 bytes per way

module icache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CACHE_SIZE = 128,  // 128 bytes total
    parameter WAYS = 2            // 2-way set-associative
) (
    input wire clk_i,
    input wire rst_i,
    input wire flush_i,           // Flush entire cache (FENCE.I)

    // Query port
    input wire [ADDR_WIDTH-1:0] pc_i,
    output logic [DATA_WIDTH-1:0] inst_o,
    output logic hit_o,

    // Fill port (from Wishbone bus)
    input wire [ADDR_WIDTH-1:0] fill_addr_i,
    input wire [DATA_WIDTH-1:0] fill_data_i,
    input wire fill_valid_i
);

    // Cache parameters derived from size
    localparam BYTES_PER_LINE = 4;           // 32-bit instruction
    localparam NUM_SETS = CACHE_SIZE / (WAYS * BYTES_PER_LINE);  // 16 sets
    localparam SET_WIDTH = $clog2(NUM_SETS);  // 4 bits for set index
    localparam TAG_WIDTH = ADDR_WIDTH - SET_WIDTH - 2;  // Remaining bits for tag

    // Extract address fields
    wire [TAG_WIDTH-1:0] pc_tag = pc_i[ADDR_WIDTH-1:SET_WIDTH+2];
    wire [SET_WIDTH-1:0] pc_set = pc_i[SET_WIDTH+1:2];
    
    wire [TAG_WIDTH-1:0] fill_tag = fill_addr_i[ADDR_WIDTH-1:SET_WIDTH+2];
    wire [SET_WIDTH-1:0] fill_set = fill_addr_i[SET_WIDTH+1:2];

    // Cache storage - 2D array: [set][way]
    // Each entry contains: valid bit (1), tag (TAG_WIDTH), instruction (32)
    logic [WAYS-1:0] valid_bits [NUM_SETS-1:0];
    logic [TAG_WIDTH-1:0] tags [NUM_SETS-1:0][WAYS-1:0];
    logic [DATA_WIDTH-1:0] data [NUM_SETS-1:0][WAYS-1:0];
    
    // LRU (Least Recently Used) replacement policy
    // For 2-way: 0 = way0 was used recently, 1 = way1 was used recently
    logic lru [NUM_SETS-1:0];

    // Way selection for hit
    logic [WAYS-1:0] way_hit;
    logic hit_found;
    
    always_comb begin
        hit_found = 1'b0;
        for (int w = 0; w < WAYS; w++) begin
            if (valid_bits[pc_set][w] && tags[pc_set][w] == pc_tag) begin
                way_hit[w] = 1'b1;
                hit_found = 1'b1;
            end else begin
                way_hit[w] = 1'b0;
            end
        end
    end

    // Output hit result and instruction
    assign hit_o = hit_found;
    assign inst_o = way_hit[1] ? data[pc_set][1] : data[pc_set][0];

    // Cache update logic
    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            // Initialize cache - all invalid
            for (int s = 0; s < NUM_SETS; s++) begin
                for (int w = 0; w < WAYS; w++) begin
                    valid_bits[s][w] <= 1'b0;
                    tags[s][w] <= '0;
                    data[s][w] <= '0;
                end
                lru[s] <= 1'b0;
            end
        end else if (flush_i) begin
            // Invalidate all cache entries (FENCE.I)
            for (int s = 0; s < NUM_SETS; s++) begin
                for (int w = 0; w < WAYS; w++) begin
                    valid_bits[s][w] <= 1'b0;
                end
            end
        end else if (fill_valid_i) begin
            // Fill cache with new instruction
            // Use LRU policy to select which way to replace
            if (valid_bits[fill_set][0] && valid_bits[fill_set][1]) begin
                // Both ways are valid, replace LRU way
                if (lru[fill_set]) begin
                    // Way 0 is LRU, replace way 0
                    valid_bits[fill_set][0] <= 1'b1;
                    tags[fill_set][0] <= fill_tag;
                    data[fill_set][0] <= fill_data_i;
                    lru[fill_set] <= 1'b1;
                end else begin
                    // Way 1 is LRU, replace way 1
                    valid_bits[fill_set][1] <= 1'b1;
                    tags[fill_set][1] <= fill_tag;
                    data[fill_set][1] <= fill_data_i;
                    lru[fill_set] <= 1'b0;
                end
            end else if (!valid_bits[fill_set][0]) begin
                // Way 0 is empty, fill way 0
                valid_bits[fill_set][0] <= 1'b1;
                tags[fill_set][0] <= fill_tag;
                data[fill_set][0] <= fill_data_i;
                lru[fill_set] <= 1'b1;
            end else begin
                // Way 1 is empty, fill way 1
                valid_bits[fill_set][1] <= 1'b1;
                tags[fill_set][1] <= fill_tag;
                data[fill_set][1] <= fill_data_i;
                lru[fill_set] <= 1'b0;
            end
        end else begin
            // Update LRU on every cache hit for read port
            if (hit_found) begin
                for (int w = 0; w < WAYS; w++) begin
                    if (way_hit[w]) begin
                        // Mark this way as recently used
                        lru[pc_set] <= (w == 0) ? 1'b0 : 1'b1;
                    end
                end
            end
        end
    end

endmodule
