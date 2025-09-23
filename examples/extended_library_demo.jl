# Example demonstrating extended library search functionality

using MiniElfLinker

function demo_library_search()
    println("🔍 Library Search Demo")
    println("=" ^ 50)
    
    # Demo 1: Find all libraries (like lld default behavior)
    println("\n1️⃣  Finding all available libraries...")
    all_libs = find_libraries()
    println("   Found $(length(all_libs)) total libraries")
    
    # Show some examples
    lib_types = Dict{LibraryType, Int}()
    for lib in all_libs
        lib_types[lib.type] = get(lib_types, lib.type, 0) + 1
    end
    
    println("   Library type distribution:")
    for (type, count) in lib_types
        println("     - $type: $count libraries")
    end
    
    # Demo 2: Search for specific libraries (equivalent to -l option)
    println("\n2️⃣  Searching for specific libraries (-l equivalent)...")
    specific_libs = find_libraries(String[]; library_names=["c", "m", "pthread", "dl"])
    
    println("   Found libraries for -l c -l m -l pthread -l dl:")
    for lib in specific_libs
        println("     - $(lib.name) ($(lib.type)): $(basename(lib.path))")
    end
    
    # Demo 3: Custom search paths (equivalent to -L option)
    println("\n3️⃣  Using custom search paths (-L equivalent)...")
    custom_paths = ["/usr/local/lib", "/opt/lib"]  # These might not exist, but shows the concept
    
    # Search in custom paths + system paths
    custom_search_libs = find_libraries(custom_paths; library_names=["c"])
    
    println("   Searching with -L /usr/local/lib -L /opt/lib -l c:")
    println("   Found $(length(custom_search_libs)) libc instances:")
    for lib in custom_search_libs
        println("     - $(lib.name) ($(lib.type)): $(lib.path)")
    end
    
    # Demo 4: Show symbol information
    println("\n4️⃣  Library symbol information...")
    math_libs = find_libraries(String[]; library_names=["m"])
    if !isempty(math_libs)
        lib = math_libs[1]  # Take first math library
        println("   Symbols in $(lib.name) library ($(length(lib.symbols)) total):")
        symbols = collect(lib.symbols)
        for sym in symbols[1:min(10, length(symbols))]
            println("     - $sym")
        end
        if length(symbols) > 10
            println("     ... and $(length(symbols) - 10) more")
        end
    end
    
    # Demo 5: Backward compatibility
    println("\n5️⃣  Backward compatibility with find_system_libraries...")
    old_style_libs = find_system_libraries()
    println("   Old function found $(length(old_style_libs)) system libraries:")
    for lib in old_style_libs
        println("     - $(lib.name) ($(lib.type)): $(basename(lib.path))")
    end
    
    println("\n✅ Demo completed!")
end

function demo_linker_integration()
    println("\n🔗 Linker Integration Demo")
    println("=" ^ 50)
    
    println("This demo shows how to use the new library search with the linker.")
    println("(Note: We can't run actual linking without object files)")
    
    # Show the new function signatures
    println("\n📋 New function signatures:")
    println("   link_objects(files; library_search_paths=[\"/custom/lib\"], library_names=[\"math\", \"pthread\"])")
    println("   link_to_executable(files, output; library_search_paths=[\"/opt/lib\"], library_names=[\"c\", \"m\"])")
    
    # Example of how it would be used
    println("\n💡 Example usage:")
    println("   # Equivalent to: ld -L/opt/mylib -L/usr/local/lib -lmath -lpthread file1.o file2.o")
    println("   link_objects([\"file1.o\", \"file2.o\"];")
    println("                library_search_paths=[\"/opt/mylib\", \"/usr/local/lib\"],")
    println("                library_names=[\"math\", \"pthread\"])")
    
    println("\n   # For executable generation:")
    println("   link_to_executable([\"main.o\", \"utils.o\"], \"myprogram\";")
    println("                      library_search_paths=[\"/custom/lib\"],")
    println("                      library_names=[\"c\", \"m\", \"pthread\"])")
    
    println("\n🔄 Backward compatibility:")
    println("   # Old calls still work exactly the same:")
    println("   link_objects([\"file.o\"])  # Uses system libraries automatically")
    println("   link_to_executable([\"main.o\"], \"program\")  # Same as before")
    
    println("\n✅ Integration demo completed!")
end

function main()
    demo_library_search()
    demo_linker_integration()
    
    println("\n🎯 Summary")
    println("=" ^ 50)
    println("✓ Extended library support beyond just libc (glibc/musl)")
    println("✓ Support for -L style library search paths")
    println("✓ Support for -l style library name specification")
    println("✓ LLD-compatible library discovery with comprehensive search paths")
    println("✓ Backward compatibility with existing code")
    println("✓ Enhanced symbol extraction for common libraries")
    println("✓ Mathematical specification updated")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end