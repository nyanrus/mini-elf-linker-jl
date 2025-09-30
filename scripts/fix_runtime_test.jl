#!/usr/bin/env julia

"""
Runtime Fix Testing Script
Compare outputs between clang -fuse-ld=lld and our Mini-ELF-Linker
Iterate to fix runtime issues and make the linker production-ready
"""

using Printf
using Dates

function create_test_program()
    test_dir = "/tmp/runtime_fix_test"
    if isdir(test_dir)
        rm(test_dir, recursive=true)
    end
    mkdir(test_dir)
    
    # Simple test program
    test_c = """
#include <stdio.h>
int main() {
    printf("Hello from Mini-ELF-Linker!\\n");
    return 42;
}
"""
    
    write(joinpath(test_dir, "test.c"), test_c)
    return test_dir
end

function compile_and_link()
    test_dir = create_test_program()
    cd(test_dir)
    
    println("📝 Creating test program in: $test_dir")
    
    # Compile to object file
    println("🔨 Compiling with Clang...")
    run(`clang -c test.c -o test.o`)
    
    # Link with LLD (reference)
    println("🔗 Linking with LLD (reference)...")
    run(`clang -fuse-ld=lld test.o -o test_lld`)
    
    # Link with Mini-ELF-Linker
    println("🔗 Linking with Mini-ELF-Linker...")
    mini_linker_path = abspath(joinpath(@__DIR__, "..", "mini_elf_linker_cli.jl"))
    run(`julia --project=$(dirname(mini_linker_path)) $mini_linker_path -o test_mini test.o`)
    
    return test_dir
end

function compare_binaries(test_dir)
    cd(test_dir)
    
    println("\n🔍 Binary Comparison Analysis:")
    println("=" ^ 60)
    
    # Test execution
    println("\n🏃 Testing Execution:")
    
    print("LLD version: ")
    flush(stdout)
    try
        result = run(`./test_lld`)
        println("✅ Success (exit code: $(result.exitcode))")
    catch e
        println("❌ Failed: $e")
    end
    
    print("Mini-ELF-Linker version: ")
    flush(stdout)
    try
        result = run(`./test_mini`)
        println("✅ Success (exit code: $(result.exitcode))")
    catch e
        println("❌ Failed: $e")
    end
    
    # Compare ELF headers
    println("\n📋 ELF Header Comparison:")
    println("\nLLD Header:")
    run(`readelf -h test_lld`)
    println("\nMini-ELF-Linker Header:")
    run(`readelf -h test_mini`)
    
    # Compare program headers  
    println("\n📋 Program Header Comparison:")
    println("\nLLD Program Headers:")
    run(`readelf -l test_lld`)
    println("\nMini-ELF-Linker Program Headers:")
    run(`readelf -l test_mini`)
    
    # Compare dynamic sections
    println("\n📋 Dynamic Section Comparison:")
    println("\nLLD Dynamic Section:")
    run(`readelf -d test_lld`)
    println("\nMini-ELF-Linker Dynamic Section:")
    run(`readelf -d test_mini`)
end

function debug_with_lldb(test_dir)
    cd(test_dir)
    
    println("\n🔍 LLDB Debugging Analysis:")
    println("=" ^ 40)
    
    if isfile("test_mini")
        println("Debugging Mini-ELF-Linker executable...")
        
        lldb_script = """
target create test_mini
image list -o -f
image dump sections
disassemble --start-address 0x11c0 --count 20
quit
"""
        
        lldb_script_path = "/tmp/debug_script.lldb"
        write(lldb_script_path, lldb_script)
        
        try
            run(`lldb -s $lldb_script_path`)
            rm(lldb_script_path)
        catch e
            println("LLDB analysis failed: $e")
        end
    end
end

function main()
    println("🚀 Runtime Fix Testing Framework")
    println("Comparing clang -fuse-ld=lld vs Mini-ELF-Linker")
    println("Timestamp: $(Dates.now())")
    println()
    
    # Compile and link test programs
    test_dir = compile_and_link()
    
    # Compare the results
    compare_binaries(test_dir)
    
    # Debug with LLDB
    debug_with_lldb(test_dir)
    
    println("\n✅ Analysis completed!")
    println("Check the output above to identify issues to fix.")
    
    return test_dir
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end