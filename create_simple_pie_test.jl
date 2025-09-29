#!/usr/bin/env julia --project=.
"""
Create a simple static executable to test if PIE format works
"""

using MiniElfLinker

function create_static_executable()
    println("🔬 Creating simple static executable to isolate PIE issue")
    
    # Create a simple C program that doesn't need dynamic libraries
    simple_c = """
int main() {
    return 42;
}
"""
    
    write("simple_static.c", simple_c)
    
    # Compile to object file
    run(`gcc -c simple_static.c -o simple_static.o`)
    
    println("📦 Linking static program with mini-elf-linker...")
    
    # Link with mini-elf-linker in static mode (no dynamic libraries)
    try
        # Force static linking
        success = link_to_executable(["simple_static.o"], "simple_static_mini"; 
                                    enable_system_libraries=false)
        
        if success && isfile("simple_static_mini")
            println("✅ Static linking successful!")
            
            # Test the executable
            println("🧪 Testing static executable...")
            try
                result = run(`./simple_static_mini`; wait=false)
                wait(result)
                println("Exit code: $(result.exitcode)")
                if result.exitcode == 42
                    println("✅ Static executable works perfectly!")
                    return true
                else
                    println("⚠️  Unexpected exit code")
                    return false
                end
            catch e
                println("❌ Static test FAILED: $e")
                
                # Analyze the executable
                println("\n🔍 Analyzing static executable...")
                run(`readelf -h simple_static_mini`)
                return false
            end
        else
            println("❌ Static linking failed!")
            return false
        end
    catch e
        println("❌ Linking error: $e")
        return false
    end
end

function main()
    success = create_static_executable()
    
    # Cleanup
    for file in ["simple_static.c", "simple_static.o", "simple_static_mini"]
        isfile(file) && rm(file)
    end
    
    if success
        println("\n🎉 SUCCESS: Static executable generation works!")
        println("   Issue is specifically with dynamic/PIE executable format")
    else
        println("\n🔧 FAILURE: Basic executable generation has issues")
        println("   Need to fix fundamental executable generation")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end