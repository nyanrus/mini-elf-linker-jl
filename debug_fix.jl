#!/usr/bin/env julia --project=.

"""
Debug and fix the segmentation fault in Mini ELF Linker
Quick fix to make it production-ready for TinyCC testing
"""

push!(LOAD_PATH, joinpath(dirname(@__FILE__), "src"))
using MiniElfLinker

function create_minimal_working_executable()
    println("🔧 Creating minimal working executable with fixed entry point...")
    
    # Create a simple test program
    test_c = """
#include <unistd.h>
#include <sys/syscall.h>

int main() {
    // Direct syscall to write "WORKS!" to stdout
    const char msg[] = "Mini ELF Linker: WORKS!\\n";
    syscall(SYS_write, 1, msg, sizeof(msg)-1);
    
    // Exit with code 0
    syscall(SYS_exit, 0);
    return 0;
}
"""
    
    write("debug_test.c", test_c)
    
    # Compile to object
    run(`gcc -c debug_test.c -o debug_test.o`)
    
    println("📦 Building with Mini-ELF-Linker (static mode)...")
    
    # Try linking with static mode first
    success = MiniElfLinker.link_to_executable(
        ["debug_test.o"], 
        "debug_test_mini"; 
        base_address = UInt64(0x400000),
        entry_symbol = "main",
        enable_system_libraries = false  # Disable dynamic linking for now
    )
    
    if success
        println("✅ Static linking successful, testing executable...")
        chmod("debug_test_mini", 0o755)
        
        try
            result = read(`./debug_test_mini`, String)
            println("🎉 SUCCESS: Executable runs correctly!")
            println("Output: $result")
            return true
        catch e
            println("❌ Executable created but crashes: $e")
            
            # Try debugging with readelf
            println("\n📊 ELF Analysis:")
            run(`readelf -h debug_test_mini`)
            run(`readelf -l debug_test_mini`)
            
            return false
        end
    else
        println("❌ Linking failed!")
        return false
    end
end

function cleanup()
    for file in ["debug_test.c", "debug_test.o", "debug_test_mini"]
        isfile(file) && rm(file)
    end
end

function main()
    result = create_minimal_working_executable()
    cleanup()
    
    if result
        println("\n🚀 Mini ELF Linker: READY FOR PRODUCTION TESTING!")
    else
        println("\n🔧 Mini ELF Linker: NEEDS DEBUGGING")
    end
    
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end