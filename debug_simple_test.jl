#!/usr/bin/env julia --project=.
"""
Simple Test to Debug Mini-ELF-Linker Issues
Create a minimal working executable first, then debug TinyCC
"""

using MiniElfLinker

function create_simple_test()
    println("🔍 Creating simple test case for debugging")
    
    # Create a very simple C program
    simple_c = """
#include <stdio.h>
int main() {
    printf("Hello from mini-elf-linker!\\n");
    return 42;
}
"""
    
    write("debug_simple.c", simple_c)
    
    # Compile to object file
    run(`gcc -c debug_simple.c -o debug_simple.o`)
    
    println("📦 Linking simple program with mini-elf-linker...")
    
    # Link with mini-elf-linker
    success = link_to_executable(["debug_simple.o"], "debug_simple_mini")
    
    if success && isfile("debug_simple_mini")
        println("✅ Simple linking successful!")
        
        # Test the executable
        println("🧪 Testing simple executable...")
        try
            result = read(`./debug_simple_mini`, String)
            println("Output: $result")
            if contains(result, "Hello from mini-elf-linker")
                println("✅ Simple test PASSED!")
                return true
            else
                println("⚠️  Unexpected output")
                return false
            end
        catch e
            println("❌ Simple test FAILED: $e")
            
            # Debug with objdump
            println("\n🔍 Debugging with objdump...")
            try
                println("ELF header:")
                run(`readelf -h debug_simple_mini`)
                println("\nProgram headers:")
                run(`readelf -l debug_simple_mini`)
                println("\nSymbols:")
                run(`objdump -t debug_simple_mini`)
            catch debug_e
                println("Debug analysis failed: $debug_e")
            end
            
            return false
        end
    else
        println("❌ Simple linking failed!")
        return false
    end
end

function compare_with_gcc()
    println("\n📊 Comparing with GCC linker...")
    
    # Create GCC version
    run(`gcc debug_simple.o -o debug_simple_gcc`)
    
    if isfile("debug_simple_gcc") && isfile("debug_simple_mini")
        gcc_size = filesize("debug_simple_gcc")
        mini_size = filesize("debug_simple_mini")
        
        println("GCC version:  $gcc_size bytes")
        println("Mini version: $mini_size bytes")
        println("Ratio: $(round(mini_size/gcc_size, digits=2))x")
        
        # Test GCC version
        println("\n🧪 Testing GCC version:")
        try
            gcc_result = read(`./debug_simple_gcc`, String)
            println("GCC output: $gcc_result")
        catch e
            println("GCC test failed: $e")
        end
        
        # Compare structure
        println("\n🔍 Structure comparison:")
        println("GCC ELF header:")
        run(`readelf -h debug_simple_gcc`)
        println("\nMini ELF header:")
        run(`readelf -h debug_simple_mini`)
    end
end

function main()
    println("🚀 Mini-ELF-Linker Debug Analysis")
    println("=" ^ 50)
    
    success = create_simple_test()
    
    if success
        println("\n🎉 Simple test passed! Mini-linker basic functionality works.")
        println("   TinyCC segfault may be due to complex program requirements.")
    else
        println("\n🔧 Simple test failed - basic functionality needs fixing.")
    end
    
    compare_with_gcc()
    
    # Cleanup
    for file in ["debug_simple.c", "debug_simple.o", "debug_simple_gcc", "debug_simple_mini"]
        isfile(file) && rm(file)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end