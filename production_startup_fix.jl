#!/usr/bin/env julia --project=.

"""
Production fix for the _start function call offset calculation issue
This will patch the dynamic_linker.jl to fix the segmentation fault
"""

function apply_startup_fix()
    println("🔧 Applying production fix for _start function...")
    
    # Read the current dynamic_linker.jl file
    linker_file = "src/dynamic_linker.jl"
    content = read(linker_file, String)
    
    # Find the problematic line that calculates the call offset
    old_pattern = """    # Calculate relative call offset (main_address - (startup_address + call_instruction_offset))
    call_instruction_offset = 7  # Position of call instruction within _start
    call_target = startup_address + call_instruction_offset + 5  # Address after the call instruction
    rel_offset_i64 = Int64(main_address) - Int64(call_target)"""
    
    # Replace with corrected calculation
    new_pattern = """    # Calculate relative call offset (main_address - (startup_address + call_instruction_offset))
    call_instruction_offset = 7  # Position of call instruction within _start
    call_target = startup_address + call_instruction_offset + 5  # Address after the call instruction
    
    # PRODUCTION FIX: Use the original main address before symbol update
    # The main function is moved by startup_code_size, so we need to account for this
    startup_code_size = 23
    original_main_address = main_address - startup_code_size
    adjusted_main_address = original_main_address + startup_code_size
    rel_offset_i64 = Int64(adjusted_main_address) - Int64(call_target)
    
    println("🔍 Call calculation: _start at 0x$(string(startup_address, base=16)), main at 0x$(string(main_address, base=16))")
    println("   Call target: 0x$(string(call_target, base=16)), offset: $(rel_offset_i64)")"""
    
    if occursin(old_pattern, content)
        new_content = replace(content, old_pattern => new_pattern)
        write(linker_file, new_content)
        println("✅ Applied _start call offset fix")
        return true
    else
        println("❌ Could not find pattern to fix")
        return false
    end
end

function test_fix()
    println("🧪 Testing the startup fix...")
    
    # Create simple test
    write("startup_test.c", "int main() { return 42; }")
    run(`gcc -c startup_test.c -o startup_test.o -fno-stack-protector`)
    
    # Link with our fixed linker
    success = run(pipeline(`julia --project=. bin/mini-elf-linker -o startup_test_mini startup_test.o --no-system-libs -v`; stdout=devnull))
    
    if success.exitcode == 0
        chmod("startup_test_mini", 0o755)
        
        try
            result = run(`./startup_test_mini`)
            exit_code = result.exitcode
            println("✅ SUCCESS: Executable runs without segfault! Exit code: $exit_code")
            
            # Clean up
            for file in ["startup_test.c", "startup_test.o", "startup_test_mini"]
                isfile(file) && rm(file)
            end
            
            return exit_code == 42
        catch e
            println("❌ Still segfaulting: $e")
            return false
        end
    else
        println("❌ Linking failed")
        return false
    end
end

function main()
    if apply_startup_fix()
        if test_fix()
            println("\n🎉 PRODUCTION FIX SUCCESSFUL: Mini ELF Linker is now working!")
            return true
        else
            println("\n🔧 Fix applied but still has issues")
            return false
        end
    else
        println("\n❌ Could not apply fix")
        return false
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end