# Simple test to verify the ELF linker functionality

using MiniElfLinker

function test_elf_linker()
    println("Testing Mini ELF Linker...")
    
    # Test 1: Parse ELF file
    print("  ✓ Testing ELF parsing... ")
    try
        elf_file = parse_elf_file("examples/test_program.o")
        @assert length(elf_file.sections) > 0
        @assert length(elf_file.symbols) > 0
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 2: Create linker
    print("  ✓ Testing linker creation... ")
    try
        linker = DynamicLinker()
        @assert linker.base_address == 0x400000
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 3: Load object
    print("  ✓ Testing object loading... ")
    try
        linker = DynamicLinker()
        success = load_object(linker, "examples/test_program.o")
        @assert success
        @assert length(linker.loaded_objects) == 1
        @assert length(linker.global_symbol_table) > 0
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 4: Symbol resolution
    print("  ✓ Testing symbol resolution... ")
    try
        linker = DynamicLinker()
        load_object(linker, "examples/test_program.o")
        unresolved = resolve_symbols(linker)
        @assert "printf" in unresolved  # Should be unresolved
        @assert haskey(linker.global_symbol_table, "main")  # Should be resolved
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 5: Memory allocation
    print("  ✓ Testing memory allocation... ")
    try
        linker = DynamicLinker()
        load_object(linker, "examples/test_program.o")
        MiniElfLinker.allocate_memory_regions!(linker)
        @assert length(linker.memory_regions) > 0
        @assert linker.memory_regions[1].base_address == 0x400000
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 6: Link objects
    print("  ✓ Testing complete linking... ")
    try
        result = link_objects(["examples/test_program.o"])
        @assert length(result.loaded_objects) == 1
        @assert length(result.memory_regions) > 0
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 7: Generate executable
    print("  ✓ Testing executable generation... ")
    try
        output_file = "/tmp/test_linker_executable"
        success = link_to_executable(["examples/test_program.o"], output_file)
        @assert success
        @assert isfile(output_file)
        
        # Check if it's recognized as an ELF executable
        file_output = read(`file $output_file`, String)
        @assert occursin("ELF", file_output) && occursin("executable", file_output)
        
        # Clean up
        rm(output_file)
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    println("\n🎉 All tests passed! The Mini ELF Linker is working correctly.")
    return true
end

# Run tests if script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    test_elf_linker()
end