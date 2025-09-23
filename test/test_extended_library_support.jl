# Test for extended library support

using MiniElfLinker

function test_library_search_paths()
    println("Testing library search paths...")
    
    # Test 1: Basic library discovery with no arguments (should find all)
    print("  ✓ Testing basic library discovery... ")
    try
        libraries = find_libraries()
        @assert length(libraries) > 0
        println("PASSED (found $(length(libraries)) libraries)")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 2: Search for specific libraries 
    print("  ✓ Testing specific library search... ")
    try
        libraries = find_libraries(String[]; library_names=["c", "m"])
        @assert length(libraries) > 0
        
        # Should find at least libc and libm
        lib_names = Set([lib.name for lib in libraries])
        @assert "c" in lib_names
        @assert "m" in lib_names
        
        println("PASSED (found libraries: $(collect(lib_names)))")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 3: Custom search paths
    print("  ✓ Testing custom search paths... ")
    try
        custom_paths = ["/usr/local/lib", "/usr/lib"]
        libraries = find_libraries(custom_paths; library_names=["c"])
        @assert length(libraries) > 0
        
        println("PASSED (found $(length(libraries)) libc instances)")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 4: Library type detection
    print("  ✓ Testing library type detection... ")
    try
        libraries = find_libraries(String[]; library_names=["c"])
        types_found = Set([lib.type for lib in libraries])
        
        # Should find at least GLIBC or MUSL libc
        has_libc = GLIBC in types_found || MUSL in types_found
        @assert has_libc
        
        println("PASSED (found types: $(collect(types_found)))")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test 5: Symbol extraction
    print("  ✓ Testing symbol extraction... ")
    try
        libraries = find_libraries(String[]; library_names=["c", "m"])
        
        for lib in libraries
            if lib.name == "c"
                @assert "printf" in lib.symbols
                @assert "malloc" in lib.symbols
            elseif lib.name == "m"
                @assert "sin" in lib.symbols
                @assert "cos" in lib.symbols
            end
        end
        
        println("PASSED")
    catch e
        println("FAILED: $e")
        return false
    end
    
    return true
end

function test_linker_integration()
    println("Testing linker integration with library search...")
    
    # Test that the linker accepts the new parameters
    print("  ✓ Testing linker parameter acceptance... ")
    try
        # This should not crash even if no object files exist
        # We're just testing parameter acceptance
        custom_paths = ["/usr/lib"]
        library_names = ["c", "m"]
        
        # Test that the function signature works
        # Note: This will fail because we don't have actual object files,
        # but it should fail at the object loading stage, not parameter parsing
        try
            result = link_objects(["nonexistent.o"]; 
                                library_search_paths=custom_paths,
                                library_names=library_names)
        catch e
            # Expected to fail due to missing object file
            if occursin("nonexistent.o", string(e))
                println("PASSED (failed at expected stage)")
            else
                println("FAILED: Unexpected error: $e")
                return false
            end
        end
    catch e
        println("FAILED: $e")
        return false
    end
    
    return true
end

function test_backward_compatibility()
    println("Testing backward compatibility...")
    
    # Test that old function still works
    print("  ✓ Testing find_system_libraries still works... ")
    try
        libraries = find_system_libraries()
        @assert length(libraries) > 0
        
        # Should still only find libc libraries
        for lib in libraries
            @assert lib.name == "c"
            @assert lib.type in [GLIBC, MUSL]
        end
        
        println("PASSED (found $(length(libraries)) libc libraries)")
    catch e
        println("FAILED: $e")
        return false
    end
    
    # Test that old linker interface still works
    print("  ✓ Testing old linker interface... ")
    try
        # Test that function signature without new parameters works
        try
            result = link_objects(["nonexistent.o"])
        catch e
            # Expected to fail due to missing object file
            if occursin("nonexistent.o", string(e))
                println("PASSED (failed at expected stage)")
            else
                println("FAILED: Unexpected error: $e")
                return false
            end
        end
    catch e
        println("FAILED: $e")
        return false
    end
    
    return true
end

function run_extended_library_tests()
    println("=== Extended Library Support Tests ===")
    
    success = true
    success &= test_library_search_paths()
    success &= test_linker_integration() 
    success &= test_backward_compatibility()
    
    if success
        println("✅ All extended library tests passed!")
    else
        println("❌ Some extended library tests failed!")
    end
    
    return success
end

# Allow running this file directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_extended_library_tests()
end