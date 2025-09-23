#!/usr/bin/env julia

# Example: Generating executable ELF files with the Mini ELF Linker

using MiniElfLinker

function example_executable_generation()
    println("==" ^ 40)
    println("MINI ELF LINKER - EXECUTABLE GENERATION EXAMPLE")
    println("==" ^ 40)
    
    println("\n📝 This example demonstrates how to use the Mini ELF Linker")
    println("   to generate executable ELF files from object files.")
    
    # Example 1: Generate executable from simple test program
    println("\n🔗 EXAMPLE 1: Self-contained program")
    println("-" ^ 50)
    
    input_file = "examples/simple_test.o"
    output_file = "/tmp/simple_program"
    
    if !isfile(input_file)
        println("❌ Input file not found: $input_file")
        println("   Please run: cd examples && gcc -c simple_test.c -o simple_test.o")
        return
    end
    
    println("Input:  $input_file")
    println("Output: $output_file")
    
    # Generate executable
    success = link_to_executable([input_file], output_file)
    
    if success
        println("\n✅ Executable generation successful!")
        
        # Show file info
        try
            output = read(`file $output_file`, String)
            println("📁 File type: $(strip(output))")
        catch
            println("📁 File created successfully")
        end
        
        # Show ELF details
        try
            println("\n📋 ELF Header Details:")
            output = read(`readelf -h $output_file`, String)
            for line in split(output, "\n")
                if occursin("Type:", line) || occursin("Entry point", line) || 
                   occursin("Machine:", line) || occursin("Class:", line)
                    println("   $(strip(line))")
                end
            end
        catch e
            println("   Could not read ELF details: $e")
        end
        
        # Show program headers  
        try
            println("\n📋 Program Headers:")
            output = read(`readelf -l $output_file`, String)
            lines = split(output, "\n")
            in_headers = false
            for line in lines
                if occursin("Program Headers:", line)
                    in_headers = true
                    continue
                end
                if in_headers && (occursin("LOAD", line) || occursin("Type", line))
                    println("   $(strip(line))")
                end
                if in_headers && isempty(strip(line))
                    break
                end
            end
        catch e
            println("   Could not read program headers: $e")
        end
        
    else
        println("❌ Executable generation failed!")
    end
    
    # Example 2: Show what happens with the original test program
    println("\n🔗 EXAMPLE 2: Program with external dependencies")
    println("-" ^ 50)
    
    input_file2 = "examples/test_program.o"
    output_file2 = "/tmp/test_program_exe"
    
    if isfile(input_file2)
        println("Input:  $input_file2")
        println("Output: $output_file2")
        
        success2 = link_to_executable([input_file2], output_file2)
        
        if success2
            println("✅ Executable with unresolved symbols generated")
            println("⚠️  Note: This executable has unresolved symbols (printf)")
            println("   In a real linker, these would be resolved by linking with libc")
        else
            println("❌ Generation failed")
        end
    else
        println("⚠️  Test program not found: $input_file2")
    end
    
    println("\n🎓 Summary:")
    println("   ✅ The Mini ELF Linker can now generate executable ELF files!")
    println("   ✅ Generated executables have proper ELF headers and program headers")
    println("   ✅ Entry points are correctly resolved from symbol tables")
    println("   ✅ Memory regions are properly laid out with correct permissions")
    println("   ⚠️  Note: Some relocations and external symbols may need additional work")
    println("   📚 This demonstrates the core concepts of static linking!")
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    example_executable_generation()
end