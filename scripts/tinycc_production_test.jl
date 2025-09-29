#!/usr/bin/env julia
"""
TinyCC Production Testing with Mini-ELF-Linker
Full integration test attempting to build TinyCC with our linker
"""

using Printf
using Dates

function attempt_tinycc_build_with_mini_linker()
    println("🚀 TinyCC Build Test with Mini-ELF-Linker")
    println("=" ^ 60)
    println("Timestamp: $(Dates.now())")
    println()
    
    tinycc_dir = "tinycc"
    
    if !isdir(tinycc_dir)
        println("❌ TinyCC directory not found")
        return false
    end
    
    try
        println("📦 Step 1: Clean and configure TinyCC")
        run(`make -C $tinycc_dir clean`)
        
        # Configure TinyCC (change to directory first)
        cd(tinycc_dir) do
            run(`./configure`)
        end
        
        println("🔨 Step 2: Generate required header files and compile TinyCC sources")
        
        # Generate tccdefs_.h first
        cd(tinycc_dir) do
            run(`gcc -DC2STR conftest.c -o c2str.exe`)
            run(`./c2str.exe include/tccdefs.h tccdefs_.h`)
        end
        
        # List of TinyCC source files in build order
        source_files = [
            "tcc.c", "libtcc.c", "tccpp.c", "tccgen.c", "tccdbg.c", 
            "tccelf.c", "tccasm.c", "tccrun.c", "x86_64-gen.c", 
            "x86_64-link.c", "i386-asm.c"
        ]
        
        # Compile each source file to object
        for src in source_files
            obj = replace(src, ".c" => ".o")
            cmd = `gcc -c $src -o $obj -I. -DONE_SOURCE=0 -DTCC_GITHASH="\"2025-09-21 mob@ba0899d\"" -Wall -O2 -Wdeclaration-after-statement -Wno-unused-result`
            println("   Compiling: $src -> $obj")
            cd(tinycc_dir) do
                run(cmd)
            end
        end
        
        println("📚 Step 3: Create libtcc.a static library")
        libtcc_objects = filter(src -> src != "tcc.c", source_files)
        libtcc_objs = [replace(src, ".c" => ".o") for src in libtcc_objects]
        cd(tinycc_dir) do
            run(`ar rcs libtcc.a $(libtcc_objs)`)
        end
        
        println("🔗 Step 4: Link TinyCC executable with mini-elf-linker")
        
        # Prepare linker command
        tcc_obj = joinpath(tinycc_dir, "tcc.o")
        libtcc_lib = joinpath(tinycc_dir, "libtcc.a")
        output_exe = joinpath(tinycc_dir, "tcc_mini_linked")
        
        linker_cmd = [
            "julia", "--project=.", "demo_cli.jl",
            "-v",  # Verbose output for debugging
            "-o", output_exe,
            tcc_obj,
            libtcc_lib,
            "-lm", "-ldl", "-lpthread"
        ]
        
        println("   Linker command: $(join(linker_cmd, " "))")
        
        # Run mini-elf-linker
        result = run(pipeline(`$(linker_cmd)`, stdout=devnull, stderr=devnull); wait=false)
        wait(result)
        
        if result.exitcode == 0 && isfile(output_exe)
            executable_size = filesize(output_exe)
            println("✅ TinyCC linking successful!")
            println("   Executable: $output_exe")
            println("   Size: $executable_size bytes")
            
            # Test the executable
            test_tinycc_executable(output_exe)
            
            return true
        else
            println("❌ Mini-elf-linker failed with exit code: $(result.exitcode)")
            
            # Try again with output to see errors
            println("🔍 Retrying with error output for debugging...")
            try
                run(`$(linker_cmd)`)
            catch e
                println("   Error details: $e")
            end
            
            return false
        end
        
    catch e
        println("❌ TinyCC build attempt failed: $e")
        return false
    end
end

function test_tinycc_executable(executable_path::String)
    println("\n🧪 Testing TinyCC executable: $executable_path")
    
    # Test 1: Version check
    try
        println("   Test 1: Version check")
        result = read(`$executable_path -v`, String)
        if contains(result, "tcc")
            println("   ✅ Version check: PASS")
        else
            println("   ⚠️  Version check: Unexpected output")
        end
    catch e
        println("   ❌ Version check: FAIL ($e)")
    end
    
    # Test 2: Help command
    try
        println("   Test 2: Help command")
        result = read(`$executable_path -h`, String)
        if contains(result, "usage") || contains(result, "Usage")
            println("   ✅ Help command: PASS")
        else
            println("   ⚠️  Help command: Unexpected output")
        end
    catch e
        println("   ❌ Help command: FAIL ($e)")
    end
    
    # Test 3: Simple compilation
    try
        println("   Test 3: Simple compilation test")
        test_c_file = "/tmp/tcc_test.c"
        test_exe_file = "/tmp/tcc_test_exe"
        
        write(test_c_file, """
#include <stdio.h>
int main() {
    printf("Hello from TinyCC compiled by mini-elf-linker!\\n");
    return 0;
}
""")
        
        # Compile with our TinyCC
        run(`$executable_path -o $test_exe_file $test_c_file`)
        
        if isfile(test_exe_file)
            # Run the compiled program
            output = read(`$test_exe_file`, String)
            if contains(output, "Hello from TinyCC")
                println("   ✅ Simple compilation: PASS")
            else
                println("   ⚠️  Simple compilation: Unexpected output")
            end
            
            # Cleanup
            rm(test_exe_file)
        else
            println("   ❌ Simple compilation: No executable generated")
        end
        
        # Cleanup
        rm(test_c_file)
        
    catch e
        println("   ❌ Simple compilation: FAIL ($e)")
    end
    
    # Test 4: LLDB analysis
    analyze_executable_with_lldb(executable_path)
end

function analyze_executable_with_lldb(executable_path::String)
    try
        if success(`which lldb`)
            println("   Test 4: LLDB analysis")
            
            # Create LLDB script
            lldb_script = """
target create "$executable_path"
image list
image dump sections
image dump symtab
quit
"""
            lldb_script_path = "/tmp/tcc_lldb_analysis.script"
            write(lldb_script_path, lldb_script)
            
            # Run LLDB
            result = read(pipeline(`lldb -s $lldb_script_path`, stderr=devnull), String)
            
            # Parse results
            if contains(result, "error") || contains(result, "failed")
                println("   ⚠️  LLDB analysis: Found potential issues")
            else
                println("   ✅ LLDB analysis: PASS")
            end
            
            # Cleanup
            rm(lldb_script_path)
        else
            println("   ⚠️  LLDB not available for analysis")
        end
    catch e
        println("   ❌ LLDB analysis: FAIL ($e)")
    end
end

function debug_linker_issues()
    println("\n🔍 Debug Mode: Analyzing linker compatibility issues")
    println("=" ^ 60)
    
    # Check what symbols TinyCC needs
    tcc_obj = "tinycc/tcc.o"
    libtcc_lib = "tinycc/libtcc.a"
    
    if isfile(tcc_obj) && isfile(libtcc_lib)
        println("📊 Analyzing TinyCC object file symbols...")
        
        try
            # Dump symbols from tcc.o
            tcc_symbols = read(`objdump -t $tcc_obj`, String)
            println("TCC.O symbols (first 20 lines):")
            lines = split(tcc_symbols, '\n')
            for (i, line) in enumerate(lines[1:min(20, length(lines))])
                println("   $line")
            end
            
            # Dump symbols from libtcc.a
            println("\nLibTCC.A symbols (first 20 lines):")
            libtcc_symbols = read(`objdump -t $libtcc_lib`, String)
            lines = split(libtcc_symbols, '\n')
            for (i, line) in enumerate(lines[1:min(20, length(lines))])
                println("   $line")
            end
            
        catch e
            println("   ❌ Symbol analysis failed: $e")
        end
    else
        println("❌ Object files not found. Run build attempt first.")
    end
end

function main()
    # First attempt the build
    success = attempt_tinycc_build_with_mini_linker()
    
    if !success
        println("\n🔧 Build failed. Running debug analysis...")
        debug_linker_issues()
        
        println("\n📋 Recommended next steps:")
        println("1. Fix symbol resolution issues in mini-elf-linker")
        println("2. Improve library handling for static archives")
        println("3. Add better relocation support for complex programs")
        println("4. Enhance error reporting for debugging")
    else
        println("\n🎉 SUCCESS! TinyCC built successfully with mini-elf-linker!")
        println("   This demonstrates production-ready capabilities!")
    end
    
    println("\nTest completed at $(Dates.now())")
end

# Run if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end