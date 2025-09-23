# Demonstration of glibc and musl libc support in MiniElfLinker
# This example shows how the linker can now detect and link against system libraries

using MiniElfLinker
using Printf

function demonstrate_library_support()
    println("🔧 Mini ELF Linker - Library Support Demonstration")
    println("=" ^ 60)
    
    # Phase 1: Library Detection
    println("\n📚 PHASE 1: LIBRARY DETECTION")
    println("-" ^ 40)
    
    println("Scanning system for C libraries...")
    libraries = find_system_libraries()
    
    if isempty(libraries)
        println("❌ No system libraries detected")
        return
    end
    
    println("✅ Found $(length(libraries)) system libraries:")
    for (i, lib) in enumerate(libraries)
        lib_type_str = lib.type == GLIBC ? "glibc" : 
                      lib.type == MUSL ? "musl" : "unknown"
        println("  [$i] $lib_type_str: $(lib.path)")
        println("      Version: $(lib.version)")
        println("      Available symbols: $(length(lib.symbols)) common libc functions")
        if i == 1  # Show some symbols for the first library
            sample_symbols = collect(lib.symbols)[1:min(5, length(lib.symbols))]
            println("      Sample symbols: ", join(sample_symbols, ", "), "...")
        end
    end
    
    # Phase 2: Symbol Resolution Comparison
    println("\n🔍 PHASE 2: SYMBOL RESOLUTION COMPARISON")
    println("-" ^ 40)
    
    # Create two linkers - one with system library support, one without
    println("Loading test program with printf calls...")
    
    println("\nWithout system library support:")
    linker_no_libs = DynamicLinker()
    load_object(linker_no_libs, "examples/test_program.o")
    unresolved_no_libs = resolve_symbols(linker_no_libs)
    
    printf_status = "printf" in unresolved_no_libs ? "❌ UNRESOLVED" : "✅ RESOLVED"
    println("  printf symbol: $printf_status")
    
    println("\nWith system library support:")
    linker_with_libs = DynamicLinker()
    load_object(linker_with_libs, "examples/test_program.o")
    initial_unresolved = resolve_symbols(linker_with_libs)
    remaining_unresolved = resolve_unresolved_symbols!(linker_with_libs, libraries)
    
    if "printf" in initial_unresolved && !("printf" in remaining_unresolved)
        providing_lib = linker_with_libs.global_symbol_table["printf"].source_file
        println("  printf symbol: ✅ RESOLVED (against $providing_lib)")
    else
        println("  printf symbol: ❌ FAILED TO RESOLVE")
    end
    
    # Phase 3: Complete Linking Demo
    println("\n🔗 PHASE 3: COMPLETE LINKING DEMONSTRATION")
    println("-" ^ 40)
    
    println("Linking with system library support enabled...")
    try
        result = link_objects(["examples/test_program.o"], enable_system_libraries=true)
        
        # Check symbol table
        total_symbols = length(result.global_symbol_table)
        resolved_symbols = count(sym -> sym.defined, values(result.global_symbol_table))
        
        println("✅ Linking completed successfully!")
        println("  Total symbols: $total_symbols")
        println("  Resolved symbols: $resolved_symbols")
        
        # Show symbol table
        println("\n📋 Symbol Table Summary:")
        println("Name                  | Status    | Source")
        println("-" ^ 50)
        
        for (name, symbol) in sort(collect(result.global_symbol_table), by=x->x[1])
            status = symbol.defined ? "RESOLVED" : "UNRESOLVED"
            source = symbol.defined ? basename(symbol.source_file) : "N/A"
            @printf("%-20s | %-9s | %s\\n", 
                   name[1:min(20, length(name))], status, source)
        end
        
    catch e
        println("❌ Linking failed: $e")
        return
    end
    
    # Phase 4: Executable Generation
    println("\n🏗️  PHASE 4: EXECUTABLE GENERATION")
    println("-" ^ 40)
    
    output_file = "/tmp/demo_executable_with_libs"
    println("Generating executable with system library linking...")
    
    try
        success = link_to_executable(["examples/test_program.o"], output_file,
                                    enable_system_libraries=true)
        
        if success && isfile(output_file)
            file_size = filesize(output_file)
            println("✅ Executable generated successfully!")
            println("  Output file: $output_file")
            println("  File size: $file_size bytes")
            
            # Check if it's a valid ELF file
            magic_bytes = open(output_file, "r") do io
                read(io, 4)
            end
            
            if magic_bytes == [0x7f, UInt8('E'), UInt8('L'), UInt8('F')]
                println("  Format: ✅ Valid ELF executable")
            else
                println("  Format: ⚠️  Invalid ELF magic number")
            end
        else
            println("❌ Failed to generate executable")
        end
    catch e
        println("❌ Executable generation failed: $e")
    end
    
    # Phase 5: Configuration Options
    println("\n⚙️  PHASE 5: CONFIGURATION OPTIONS")
    println("-" ^ 40)
    
    println("The linker now supports the following options:")
    println("  • enable_system_libraries=true/false (default: true)")
    println("  • Automatic detection of glibc and musl libraries")
    println("  • Symbol resolution against detected system libraries")
    println("  • Backward compatibility with existing code")
    
    println("\nExample usage:")
    println("  # With system library support (new default)")
    println("  link_objects([\"file.o\"], enable_system_libraries=true)")
    println("  ")
    println("  # Without system library support (old behavior)")
    println("  link_objects([\"file.o\"], enable_system_libraries=false)")
    
    println("\n🎓 DEMONSTRATION COMPLETE")
    println("=" ^ 60)
    println("The Mini ELF Linker now supports both glibc and musl libc!")
    println("Unresolved symbols can now be automatically resolved against")
    println("system libraries, making the linker more practical for real use.")
end

# Run the demonstration
if abspath(PROGRAM_FILE) == @__FILE__
    demonstrate_library_support()
end