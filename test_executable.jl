#!/usr/bin/env julia

# Test executable generation from the mini ELF linker

using MiniElfLinker

function test_executable_generation()
    println("=== Testing Executable Generation ===")
    
    # Try to link the test program to an executable
    input_file = "examples/test_program.o"
    output_file = "/tmp/test_executable"
    
    println("Linking $input_file to $output_file...")
    
    success = link_to_executable([input_file], output_file)
    
    if success
        println("✓ Executable generation successful!")
        
        # Check if the file was created
        if isfile(output_file)
            println("✓ Output file exists: $output_file")
            
            # Check if it's executable
            try
                stat_info = stat(output_file)
                mode = stat_info.mode
                if (mode & 0o111) != 0
                    println("✓ File has execute permissions")
                else
                    println("⚠ File does not have execute permissions")
                end
            catch e
                println("⚠ Could not check file permissions: $e")
            end
            
            # Try to check the ELF header
            try
                run(`file $output_file`)
                println("✓ File type check completed")
            catch e
                println("⚠ Could not run file command: $e")
            end
            
        else
            println("❌ Output file was not created!")
            return false
        end
    else
        println("❌ Executable generation failed!")
        return false
    end
    
    return true
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    test_executable_generation()
end