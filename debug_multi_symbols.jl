#!/usr/bin/env julia

# Debug symbol loading for multiple object files

using MiniElfLinker

function debug_symbol_loading()
    println("=== Debug Symbol Loading ===")
    
    linker = DynamicLinker()
    
    println("\nLoading test_program.o...")
    load_object(linker, "examples/test_program.o")
    println("Symbols after loading test_program.o:")
    print_symbol_table(linker)
    
    println("\nLoading printf_stub.o...")  
    load_object(linker, "examples/printf_stub.o")
    println("Symbols after loading printf_stub.o:")
    print_symbol_table(linker)
    
    println("\nResolving symbols...")
    unresolved = resolve_symbols(linker)
    println("Unresolved symbols: $unresolved")
end

debug_symbol_loading()