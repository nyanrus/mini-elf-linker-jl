# Test for glibc and musl libc support

using MiniElfLinker

function test_library_detection()
    println("Testing library detection and resolution...")
    
    # Test 1: Basic library detection
    print("  ✓ Testing library detection... ")
    try
        libraries = find_system_libraries()
        @assert length(libraries) > 0
        
        # Should find at least one glibc library on this system
        glibc_found = any(lib -> lib.type == GLIBC, libraries)
        @assert glibc_found
        
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 2: Symbol resolution with libraries
    print("  ✓ Testing symbol resolution with system libraries... ")
    try
        linker = DynamicLinker()
        load_object(linker, "examples/test_program.o")
        
        # Get initial unresolved symbols
        initial_unresolved = resolve_symbols(linker)
        @assert "printf" in initial_unresolved
        
        # Try to resolve with system libraries
        libraries = find_system_libraries()
        remaining_unresolved = resolve_unresolved_symbols!(linker, libraries)
        
        # printf should now be resolved
        @assert !("printf" in remaining_unresolved)
        @assert haskey(linker.global_symbol_table, "printf")
        @assert linker.global_symbol_table["printf"].defined
        
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 3: Linking with system library resolution enabled
    print("  ✓ Testing complete linking with system libraries... ")
    try
        result = link_objects(["examples/test_program.o"], enable_system_libraries=true)
        
        # printf should be resolved
        @assert haskey(result.global_symbol_table, "printf")
        @assert result.global_symbol_table["printf"].defined
        
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 4: Linking with system library resolution disabled
    print("  ✓ Testing linking with system libraries disabled... ")
    try
        result = link_objects(["examples/test_program.o"], enable_system_libraries=false)
        
        # printf should still be unresolved
        @assert haskey(result.global_symbol_table, "printf")
        @assert !result.global_symbol_table["printf"].defined
        
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 5: Executable generation with system libraries
    print("  ✓ Testing executable generation with system libraries... ")
    try
        output_file = "/tmp/test_with_system_libs"
        success = link_to_executable(["examples/test_program.o"], output_file, 
                                    enable_system_libraries=true)
        @assert success
        @assert isfile(output_file)
        
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    return true
end

function test_library_type_detection()
    println("Testing library type detection...")
    
    # Test known glibc libraries
    glibc_paths = [
        "/usr/lib/x86_64-linux-gnu/libc.so.6",
        "/lib/x86_64-linux-gnu/libc.so.6"
    ]
    
    for path in glibc_paths
        if isfile(path)
            print("  ✓ Testing $path... ")
            detected_type = detect_libc_type(path)
            if detected_type == GLIBC
                println("PASSED (detected as GLIBC)")
            else
                println("FAILED (detected as $detected_type, expected GLIBC)")
                return false
            end
        end
    end
    
    # Test non-existent file
    print("  ✓ Testing non-existent file... ")
    detected_type = detect_libc_type("/non/existent/file")
    if detected_type == UNKNOWN
        println("PASSED")
    else
        println("FAILED (expected UNKNOWN, got $detected_type)")
        return false
    end
    
    return true
end

function run_library_tests()
    println("Testing Mini ELF Linker Library Support...")
    
    success = true
    success &= test_library_type_detection()
    success &= test_library_detection()
    
    if success
        println("\n🎉 All library support tests passed!")
    else
        println("\n❌ Some tests failed!")
    end
    
    return success
end

# Allow script to be run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_library_tests()
end