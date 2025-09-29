#!/usr/bin/env julia --project=.

"""
Ultra-minimal test to create a working ELF executable
Let's try the absolute simplest approach
"""

push!(LOAD_PATH, joinpath(dirname(@__FILE__), "src"))
using MiniElfLinker

function create_ultra_minimal_working()
    println("🎯 Creating ultra-minimal working executable...")
    
    # Create the absolute simplest C program
    test_c = """
void _start() {
    asm("mov \$42, %rdi");      // Return code 42
    asm("mov \$60, %rax");      // sys_exit
    asm("syscall");             // Exit syscall
}
"""
    write("ultra_test.c", test_c)
    
    # Compile with no stdlib and use _start directly
    run(`gcc -c ultra_test.c -o ultra_test.o -fno-stack-protector -nostdlib`)
    
    println("📦 Linking ultra-minimal test...")
    
    # Link with Mini ELF Linker using _start directly (no synthetic startup)
    success = false
    try 
        success = MiniElfLinker.link_to_executable(
            ["ultra_test.o"], 
            "ultra_test_mini"; 
            base_address = UInt64(0x400000),
            entry_symbol = "_start",  # Use _start directly, no synthetic injection
            enable_system_libraries = false
        )
    catch e
        println("❌ Linking failed: $e")
        return false
    end
    
    if success
        println("✅ Ultra-minimal linking successful!")
        chmod("ultra_test_mini", 0o755)
        
        # Test the executable
        println("🧪 Testing ultra-minimal executable:")
        try
            result = run(`./ultra_test_mini`)
            if result.exitcode == 42
                println("🎉 SUCCESS: Ultra-minimal approach works!")
                return true
            else
                println("❌ Wrong exit code: $(result.exitcode)")
                return false
            end
        catch e
            if isa(e, ProcessFailedException) && length(e.procs) > 0 && e.procs[1].exitcode == 42
                println("🎉 SUCCESS: Ultra-minimal approach works! (Exit code 42)")
                return true
            else
                println("❌ Failed: $e")
                
                # Check what we generated
                println("🔍 Generated executable analysis:")
                run(`readelf -h ultra_test_mini`)
                run(`readelf -l ultra_test_mini`)
                run(`hexdump -C ultra_test_mini -s 0x1000 -n 32`)
                return false
            end
        end
    else
        println("❌ Ultra-minimal linking failed!")
        return false
    end
end

function cleanup_ultra()
    for file in ["ultra_test.c", "ultra_test.o", "ultra_test_mini"]
        isfile(file) && rm(file)
    end
end

function main()
    result = create_ultra_minimal_working()
    
    if result
        println("\n🚀 BREAKTHROUGH: Ultra-minimal approach successful!")
        println("   ✅ Can generate working executables with direct _start")
        println("   ✅ Issue was with synthetic _start generation")
        println("   🎯 Ready to implement proper C runtime support")
    else
        println("\n🔧 Need deeper ELF structure investigation")
    end
    
    cleanup_ultra()
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end