#!/usr/bin/env julia

# TCC Scenario Testing - Compare mini-elf-linker vs LLD
# Test various scenarios that TCC would encounter

using Printf

cd(dirname(@__FILE__))

function test_scenario(name::String, obj_files::Vector{String})
    println("=" ^ 60)
    println("Testing: $name")
    println("=" ^ 60)
    
    # Test with mini-elf-linker
    println("\n🔧 Mini ELF Linker:")
    mini_cmd = `../../bin/mini-elf-linker -o $(name)_mini --no-system-libs $(obj_files)`
    println("Command: $mini_cmd")
    
    try
        run(mini_cmd)
        if isfile("$(name)_mini")
            println("✅ Executable created successfully")
            
            # Test execution
            try
                result = run(pipeline(`./$(name)_mini`, devnull))
                exit_code = result.exitcode
                println("✅ Execution successful, exit code: $exit_code")
            catch e
                println("❌ Execution failed: $e")
            end
        else
            println("❌ Executable not created")
        end
    catch e
        println("❌ Linking failed: $e")
    end
    
    # Test with GCC+LLD for comparison
    println("\n🔧 GCC + LLD:")
    c_files = [replace(obj, ".o" => ".c") for obj in obj_files]
    gcc_cmd = `gcc -O0 -fuse-ld=lld $(c_files) -o $(name)_gcc_lld`
    println("Command: $gcc_cmd")
    
    try
        run(gcc_cmd)
        if isfile("$(name)_gcc_lld")
            println("✅ Executable created successfully")
            
            # Test execution
            try
                result = run(pipeline(`./$(name)_gcc_lld`, devnull))
                exit_code = result.exitcode
                println("✅ Execution successful, exit code: $exit_code")
            catch e
                println("❌ Execution failed: $e")
            end
        else
            println("❌ Executable not created")
        end
    catch e
        println("❌ Linking failed: $e")
    end
    
    println()
end

# Test scenarios
test_scenario("simple_math", ["simple_math.o"])
test_scenario("multi_file", ["multi_file_main.o", "multi_file_lib.o"])

# Analysis with readelf
println("=" ^ 60)
println("ELF Analysis")
println("=" ^ 60)

for exe in ["simple_math_mini", "simple_math_gcc_lld", "multi_file_mini", "multi_file_gcc_lld"]
    if isfile(exe)
        println("\n📊 Analysis of $exe:")
        try
            run(`readelf -h $exe`)
        catch e
            println("Failed to analyze $exe: $e")
        end
    end
end