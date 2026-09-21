#include <iostream>
#include <memory>
#include "Vcw305_xheep_bridge.h"
#include "verilated.h"

// Helper function to toggle both clocks
void tick(Vcw305_xheep_bridge* top) {
    top->usb_clk_i = 1;
    top->clk_i = 1;
    top->eval();
    
    top->usb_clk_i = 0;
    top->clk_i = 0;
    top->eval();
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    auto top = std::make_unique<Vcw305_xheep_bridge>();

    // 1. Initialize all inputs
    top->usb_clk_i = 0;
    top->clk_i = 0;
    top->rst_ni = 0;
    top->cw_read_req_i = 0;
    top->cw_write_req_i = 0;
    top->cw_addr_i = 0;
    top->cw_bytecnt_i = 0;
    top->cw_write_data_i = 0;
    top->cw_addrvalid_i = 0;

    // Apply asynchronous reset
    tick(top.get());
    tick(top.get());
    top->rst_ni = 1;
    tick(top.get());

    std::cout << "--- Starting Tests ---" << std::endl;

    // Test 1: Read from 14'h0000 with bytecnt 0
    // Expected behavior: cw_read_data_o = 0x55
    top->cw_read_req_i = 1;
    top->cw_addr_i = 0x0000;
    top->cw_bytecnt_i = 0x00;
    tick(top.get());
    std::cout << "Read 0x0000 (byte 0): 0x" << std::hex << (int)top->cw_read_data_o 
              << " (Expected: 0x55)" << std::endl;

    // Test 2: Read from 14'h0000 with bytecnt 1
    // Expected behavior: cw_read_data_o = 0x66
    top->cw_bytecnt_i = 0x01;
    tick(top.get());
    std::cout << "Read 0x0000 (byte 1): 0x" << std::hex << (int)top->cw_read_data_o 
              << " (Expected: 0x66)" << std::endl;

    // Test 3: Write to a non-zero address to capture 32'hAABBCCDD into mailbox_read_addr
    top->cw_read_req_i = 0;
    top->cw_write_req_i = 1;
    top->cw_addr_i = 0x0004; 
    tick(top.get());
    top->cw_write_req_i = 0;

    // Test 4: Read the captured mailbox data from 14'h0004
    // Expected behavior: bytecnt 0 -> 0xDD, bytecnt 1 -> 0xCC, bytecnt 2 -> 0xBB, bytecnt 3 -> 0xAA
    top->cw_read_req_i = 1;
    top->cw_addr_i = 0x0004;
    
    for (int byte = 0; byte < 4; byte++) {
        top->cw_bytecnt_i = byte;
        tick(top.get());
        std::cout << "Read 0x0004 (byte " << byte << "): 0x" << std::hex << (int)top->cw_read_data_o << std::endl;
    }

    // Clean up
    top->final();
    std::cout << "--- Tests Complete ---" << std::endl;
    return 0;
}
