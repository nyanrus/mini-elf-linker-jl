#!/usr/bin/env julia

"""
Binary-Level LLD Compatibility Testing Script
Compares clang -fuse-ld=lld output with Mini-ELF-Linker output at binary level
LLD optimizations are disabled for fair comparison
"""

using Printf
using Dates

function compile_test_program()
    test_dir = "/tmp/binary_comparison_test"
    if isdir(test_dir)
        rm(test_dir, recursive=true)
    end
    mkdir(test_dir)
    
    # Create a simple test program
    test_c = """
#include <stdio.h>

int main() {
    printf("Hello from test!\\n");
    return 0;
}
"""
    
    write(joinpath(test_dir, "test.c"), test_c)
    
    cd(test_dir)
    
    println("📝 Compiling test program...")
    # Compile with clang to object file  
    run(`clang -c test.c -o test.o`)
    
    return test_dir
end

function link_with_lld_no_opt(test_dir)
    cd(test_dir)
    
    println("🔗 Linking with LLD (optimizations disabled)...")
    
    # Use clang with -fuse-ld=lld to ensure proper library paths
    # Disable LLD optimizations with -Wl,--no-relax and other flags
    try
        run(`clang -fuse-ld=lld -o test_lld test.o -Wl,--no-relax`)
        println("✅ LLD linking successful")
        return true
    catch e
        println("❌ LLD linking failed: $e")
        return false
    end
end

function link_with_mini_linker(test_dir)
    cd(test_dir)
    
    println("🔗 Linking with Mini-ELF-Linker...")
    
    mini_linker_path = abspath(joinpath(@__DIR__, "..", "mini_elf_linker_cli.jl"))
    
    try
        run(`julia --project=$(dirname(mini_linker_path)) $mini_linker_path -o test_mini test.o`)
        println("✅ Mini-ELF-Linker linking successful")
        return true
    catch e
        println("❌ Mini-ELF-Linker linking failed: $e")
        return false
    end
end

function compare_elf_headers(test_dir)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("ELF HEADER COMPARISON")
    println("=" ^ 70)
    
    println("\n--- LLD Output ---")
    run(`readelf -h test_lld`)
    
    println("\n--- Mini-ELF-Linker Output ---")
    run(`readelf -h test_mini`)
    
    # Save to files for diffing
    run(pipeline(`readelf -h test_lld`, stdout="lld_header.txt"))
    run(pipeline(`readelf -h test_mini`, stdout="mini_header.txt"))
    
    println("\n--- Differences ---")
    try
        run(`diff -u lld_header.txt mini_header.txt`)
    catch
        # diff returns non-zero when files differ
    end
end

function compare_program_headers(test_dir)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("PROGRAM HEADER COMPARISON")
    println("=" ^ 70)
    
    println("\n--- LLD Output ---")
    run(`readelf -l test_lld`)
    
    println("\n--- Mini-ELF-Linker Output ---")
    run(`readelf -l test_mini`)
    
    # Save for diffing
    run(pipeline(`readelf -l test_lld`, stdout="lld_pheaders.txt"))
    run(pipeline(`readelf -l test_mini`, stdout="mini_pheaders.txt"))
    
    println("\n--- Differences ---")
    try
        run(`diff -u lld_pheaders.txt mini_pheaders.txt`)
    catch
    end
end

function compare_dynamic_section(test_dir)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("DYNAMIC SECTION COMPARISON")
    println("=" ^ 70)
    
    println("\n--- LLD Output ---")
    run(`readelf -d test_lld`)
    
    println("\n--- Mini-ELF-Linker Output ---")
    run(`readelf -d test_mini`)
    
    # Save for diffing
    run(pipeline(`readelf -d test_lld`, stdout="lld_dynamic.txt"))
    run(pipeline(`readelf -d test_mini`, stdout="mini_dynamic.txt"))
    
    println("\n--- Differences ---")
    try
        run(`diff -u lld_dynamic.txt mini_dynamic.txt`)
    catch
    end
end

function compare_relocations(test_dir)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("RELOCATION COMPARISON")
    println("=" ^ 70)
    
    println("\n--- LLD Output ---")
    run(`readelf -r test_lld`)
    
    println("\n--- Mini-ELF-Linker Output ---")
    run(`readelf -r test_mini`)
    
    println("\n--- Mini-ELF-Linker Dynamic Relocations ---")
    try
        run(`readelf --use-dynamic -r test_mini`)
    catch e
        println("Error reading dynamic relocations: $e")
    end
end

function compare_symbols(test_dir)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("SYMBOL TABLE COMPARISON")
    println("=" ^ 70)
    
    println("\n--- LLD Output ---")
    run(`readelf -s test_lld`)
    
    println("\n--- Mini-ELF-Linker Output (section-based) ---")
    try
        run(`readelf -s test_mini`)
    catch e
        println("Section-based symbol table not available")
    end
    
    println("\n--- Mini-ELF-Linker Output (dynamic) ---")
    try
        run(`readelf --dyn-syms test_mini`)
    catch e
        println("Error reading dynamic symbols: $e")
    end
end

function test_execution(test_dir)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("EXECUTION TESTS")
    println("=" ^ 70)
    
    println("\n--- LLD Executable ---")
    try
        result = read(`./test_lld`, String)
        println("Output: $result")
        println("✅ LLD executable runs successfully")
    catch e
        println("❌ LLD executable failed: $e")
    end
    
    println("\n--- Mini-ELF-Linker Executable ---")
    try
        result = read(`./test_mini`, String)
        println("Output: $result")
        println("✅ Mini-ELF-Linker executable runs successfully")
    catch e
        println("❌ Mini-ELF-Linker executable failed: $e")
    end
end

function debug_with_lldb(test_dir)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("LLDB DEBUGGING ANALYSIS")
    println("=" ^ 70)
    
    if !isfile("test_mini")
        println("⚠️  test_mini not found, skipping LLDB analysis")
        return
    end
    
    # Create LLDB script for comprehensive debugging
    lldb_script = """
target create test_mini
image list -o -f
image dump sections test_mini
disassemble --name _start
process launch
bt
quit
"""
    
    lldb_script_path = "/tmp/debug_mini.lldb"
    write(lldb_script_path, lldb_script)
    
    println("\n--- Debugging test_mini ---")
    try
        run(`lldb -s $lldb_script_path`)
    catch e
        println("LLDB failed: $e")
    end
    
    # Cleanup
    rm(lldb_script_path, force=true)
end

function hexdump_comparison(test_dir, max_bytes=512)
    cd(test_dir)
    
    println("\n" * "=" ^ 70)
    println("HEXDUMP COMPARISON (first $max_bytes bytes)")
    println("=" ^ 70)
    
    println("\n--- LLD Output ---")
    run(`hexdump -C test_lld -n $max_bytes`)
    
    println("\n--- Mini-ELF-Linker Output ---")
    run(`hexdump -C test_mini -n $max_bytes`)
end

function main()
    println("=" ^ 70)
    println("BINARY-LEVEL LLD COMPATIBILITY TEST")
    println("LLD optimizations disabled for fair comparison")
    println("Timestamp: $(Dates.now())")
    println("=" ^ 70)
    
    # Compile test program
    test_dir = compile_test_program()
    
    # Link with both linkers
    lld_success = link_with_lld_no_opt(test_dir)
    mini_success = link_with_mini_linker(test_dir)
    
    if !lld_success
        println("\n❌ LLD linking failed, cannot proceed with comparison")
        return
    end
    
    if !mini_success
        println("\n❌ Mini-ELF-Linker linking failed, cannot proceed with comparison")
        return
    end
    
    # Compare outputs
    compare_elf_headers(test_dir)
    compare_program_headers(test_dir)
    compare_dynamic_section(test_dir)
    compare_relocations(test_dir)
    compare_symbols(test_dir)
    test_execution(test_dir)
    debug_with_lldb(test_dir)
    hexdump_comparison(test_dir)
    
    println("\n" * "=" ^ 70)
    println("ANALYSIS COMPLETE")
    println("=" ^ 70)
    println("\nTest directory: $test_dir")
    println("Review the output above to identify binary-level differences")
    
    return test_dir
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
