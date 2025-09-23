#!/usr/bin/env julia

# Debug the symbol resolution

using MiniElfLinker

function debug_symbols()
    println("=== Debug Symbol Resolution ===")
    
    linker = DynamicLinker()
    load_object(linker, "examples/test_program.o")
    
    println("\nSymbols before allocation:")
    print_symbol_table(linker)
    
    println("\nAllocating memory...")
    MiniElfLinker.allocate_memory_regions!(linker)
    
    println("\nSymbols after allocation:")
    print_symbol_table(linker)
end

debug_symbols()