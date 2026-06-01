module bilinear_scaler #(
    parameter W_IN = 860,                
    parameter H_IN = 821,                
    parameter W_OUT = 3000,              
    parameter H_OUT = 2160,              
    parameter Channels = 3,              
    parameter INPUT_FILE = "7.hex",      
    parameter OUTPUT_FILE = "7_out.hex",
    parameter IN_MEM_DEPTH = W_IN * H_IN * Channels,   // Total bytes in the input image
    parameter OUT_MEM_DEPTH = W_OUT * H_OUT * Channels,// Total bytes in the output image
    parameter X_Q8 = (W_IN * 256) / W_OUT,             // X-axis scaling step
    parameter Y_Q8 = (H_IN * 256) / H_OUT,             // Y-axis scaling step
    parameter IN_AW = $clog2(IN_MEM_DEPTH + 1),        // Address width for input memory
    parameter OUT_AW = $clog2(OUT_MEM_DEPTH + 1),      // Address width for output memory
    parameter XIN_W = $clog2(W_IN + 2),                // Bit width for input X coordinates
    parameter YIN_W = $clog2(H_IN + 2),                // Bit width for input Y coordinates
    parameter XOUT_W = $clog2(W_OUT + 1),              // Bit width for output X coordinates
    parameter YOUT_W = $clog2(H_OUT + 1)               // Bit width for output Y coordinates
)(
    input clk,                           
    input rst,                           
    output reg done                      
);
    
    //RAM BLOCKS
    reg [7:0] img_in[0:IN_MEM_DEPTH-1];  
    reg [7:0] img_out[0:OUT_MEM_DEPTH-1];

    //PIPELINE STAGE 1: OUTPUT COORDINATES GEN
    reg s1_valid;                        
    reg [XOUT_W-1:0] s1_xout;            // Current X coordinate on the new image
    reg [YOUT_W-1:0] s1_yout;            // Current Y coordinate on the new image

    // PIPELINE STAGE 2: INPUT MAPPING WITH THE OUTPUT
    reg s2_valid;
    reg [XIN_W-1:0] s2_x0, s2_x1;        
    reg [YIN_W-1:0] s2_y0, s2_y1;        
    reg [7:0] s2_a;                      //the fractional part of a                     
    reg [7:0] s2_b;                      //the fractional part of b
    reg [OUT_AW-1:0] s2_obase;           // The starting memory address to save this pixel later
    
    // PIPELINE STAGE 3: MEMORY ADDRESSES
    reg s3_valid;
    reg [7:0] s3_a, s3_b;                // Passing the fractions down the pipeline
    reg [IN_AW-1:0] s3_a00, s3_a01, s3_a10, s3_a11; // Exact memory addresses of the 4 surrounding pixels
    reg [OUT_AW-1:0] s3_obase;           // Passing the output save address down the pipeline

    //PIPELINE STAGE 4: BILINEAR CALC
    reg s4_valid;
    reg [OUT_AW-1:0] s4_obase;           // The output save address arrives at the finish line
    reg [7:0] s4_res[0:Channels-1];      // The final calculated RGB colors to be saved

    //FSM
    localparam IDLE = 2'd0;              
    localparam LOAD = 2'd1;              
    localparam PROCESS = 2'd2;          
    localparam SAVE = 2'd3;              

    reg [1:0] state;                   

   
    reg [XOUT_W-1:0] x_cnt;              // tracks current X output pixel
    reg [YOUT_W-1:0] y_cnt;              // tracks current Y output pixel
    reg feed_sig;                       
    
    reg [OUT_AW:0] out_done;           

    //TEMPORARY MATH VARIABLES
    reg [31:0] xq8, yq8;                 // Fixed-point mapped coordinates
    reg [XIN_W-1:0] tx0, tx1;            // Temporary X coordinates
    reg [YIN_W-1:0] ty0, ty1;            // Temporary Y coordinates
    reg [8:0] a9, b9, na, nb;            // Variables for calculating pixel weights
    reg [17:0] w00, w01, w10, w11;       // The calculated weights for the 4 surrounding pixels
    reg [26:0] sum;                      
    reg [31:0] row_base;                 //variable for calculating memory addresses

    integer i;                           // Used for the RGB channel loop

    always @(posedge clk) begin
        if(!rst) begin
            state <= IDLE;
            done <= 1'b0;
            feed_sig <= 1'b0;
            s1_valid <= 1'b0;
            s2_valid <= 1'b0;
            s3_valid <= 1'b0;
            s4_valid <= 1'b0;
            x_cnt <= 0;
            y_cnt <= 0;
            out_done <= 0;
        end
        else begin
            done <= 1'b0;
            case(state)

                IDLE: begin
                    state <= LOAD;
                end

                LOAD: begin
                    $readmemh(INPUT_FILE, img_in); 
                    x_cnt <= 0;
                    y_cnt <= 0;
                    out_done <= 0;
                    feed_sig <= 1'b1;              
                    s1_valid <= 1'b0;             
                    s2_valid <= 1'b0;
                    s3_valid <= 1'b0;
                    s4_valid <= 1'b0;
                    state <= PROCESS;             
                end

               
                PROCESS: begin
                    
                    s1_valid <= feed_sig;
                    s1_xout <= x_cnt;
                    s1_yout <= y_cnt;
                    

                    if(feed_sig) begin
                        if(x_cnt == W_OUT - 1) begin
                            x_cnt <= 0;                        // Reached the right edge, return to left edge
                            if(y_cnt == H_OUT - 1) begin
                                feed_sig <= 1'b0;              // Reached the very bottom-right pixel, stop feeding!
                                y_cnt <= 0;
                            end else begin
                                y_cnt <= y_cnt + 1;            // Move down one row
                            end 
                        end else begin
                            x_cnt <= x_cnt + 1;                // Move right one pixel
                        end
                    end
                
                
                // STAGE 2: MAP TO INPUT IMAGE
                s2_valid <= s1_valid;
                
                s2_obase <= (s1_yout * W_OUT + s1_xout) * Channels; // (y*width+x)*channels
                
                if(s1_valid) begin
                   
                    xq8 = s1_xout * X_Q8; 
                    yq8 = s1_yout * Y_Q8; 
                    
                    
                    tx0 = xq8[31:8];
                    ty0 = yq8[31:8];
                    
                    
                    tx1 = (tx0 < W_IN - 1) ? tx0 + 1 : W_IN - 1;
                    ty1 = (ty0 < H_IN - 1) ? ty0 + 1 : H_IN - 1;

                    
                    s2_x0 <= tx0;
                    s2_x1 <= tx1;
                    s2_y0 <= ty0;
                    s2_y1 <= ty1;
                    s2_a <= xq8[7:0]; // The fractional X part (used for weight)
                    s2_b <= yq8[7:0]; // The fractional Y part (used for weight)
                end

                
                // STAGE 3: CALCULATE MEMORY ADDRESSES
                s3_valid <= s2_valid;
                s3_a <= s2_a;
                s3_b <= s2_b;
                s3_obase <= s2_obase;
                
                if(s2_valid) begin
                    
                    //calculation the adddress of 4 nearest pixels
                    // Top row addresses
                    row_base = s2_y0 * W_IN;
                    s3_a00 <= (row_base + s2_x0) * Channels; // Top-Left pixel address
                    s3_a10 <= (row_base + s2_x1) * Channels; // Top-Right pixel address
                    
                    // Bottom row addresses
                    row_base = s2_y1 * W_IN;
                    s3_a01 <= (row_base + s2_x0) * Channels; // Bottom-Left pixel address
                    s3_a11 <= (row_base + s2_x1) * Channels; // Bottom-Right pixel address
                end

                
                // STAGE 4: BILINEAR MATH
                
                s4_valid <= s3_valid;
                s4_obase <= s3_obase;
                
                if(s3_valid) begin
                    a9 = {1'b0, s3_a};
                    b9 = {1'b0, s3_b};
                    na = 9'd256 - a9;
                    nb = 9'd256 - b9;
                    
                    // Calculate the percentage of influence each pixel has
                    w00 = na * nb; 
                    w10 = a9 * nb; 
                    w01 = na * b9; 
                    w11 = a9 * b9;

                    
                    for(i = 0; i < Channels; i = i + 1) begin
                        sum = (w00 * img_in[s3_a00+i]) + (w10 * img_in[s3_a10+i]) + (w01 * img_in[s3_a01+i]) + (w11 * img_in[s3_a11+i]);
                        s4_res[i] <= sum[23:16];
                    end
                end

                
                // FINAL WRITE-BACK TO MEMORY
               
                if(s4_valid) begin
                    for(i = 0; i < Channels; i = i + 1) begin
                        img_out[s4_obase+i] <= s4_res[i];
                    end
                    out_done <= out_done + Channels;
                end

                if(s4_valid && (out_done == OUT_MEM_DEPTH - Channels)) begin
                    state <= SAVE; 
                end
                end
                
                // STATE: SAVE
                SAVE: begin
                    $writememh(OUTPUT_FILE, img_out);
                    done <= 1'b1;        
                    state <= IDLE;        
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule