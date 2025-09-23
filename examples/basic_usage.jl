# Example usage of the Mini ELF Linker

using MiniElfLinker

# Example 1: Parse an ELF file and examine its structure
function example_parse_elf()
    println("=== ELF File Parsing Example ===")
    
    # Create a simple test case by examining the Julia binary itself
    julia_binary = "/usr/bin/julia"  # Adjust path as needed
    
    if isfile(julia_binary)
        try
            println("Parsing ELF header from: $julia_binary")
            header = parse_elf_header(julia_binary)
            
            println("ELF Header Information:")
            println("  Magic: $(header.magic)")
            println("  Class: $(header.class == 2 ? "64-bit" : "32-bit")")
            println("  Data: $(header.data == 1 ? "Little Endian" : "Big Endian")")
            println("  Type: $(header.type)")
            println("  Machine: $(header.machine)")
            println("  Entry Point: 0x$(string(header.entry, base=16))")
            println("  Section Count: $(header.shnum)")
            
        catch e
            println("Error parsing ELF file: $e")
        end
    else
        println("Julia binary not found at expected location")
    end
end

# Example 2: Create a simple dynamic linker and demonstrate its capabilities
function example_dynamic_linker()
    println("\n=== Dynamic Linker Example ===")
    
    # Create a new linker instance
    linker = DynamicLinker(UInt64(0x400000))
    
    println("Created dynamic linker with base address: 0x$(string(linker.base_address, base=16))")
    
    # For demonstration, we'll show how the linker would work with object files
    # In practice, you would load actual .o files like:
    # load_object(linker, "example1.o")
    # load_object(linker, "example2.o")
    
    println("Linker initialized with:")
    println("  Base address: 0x$(string(linker.base_address, base=16))")
    println("  Next address: 0x$(string(linker.next_address, base=16))")
    println("  Loaded objects: $(length(linker.loaded_objects))")
    println("  Global symbols: $(length(linker.global_symbol_table))")
end

# Example 3: Demonstrate symbol resolution
function example_symbol_resolution()
    println("\n=== Symbol Resolution Example ===")
    
    # Create symbols manually for demonstration
    linker = DynamicLinker()
    
    # Simulate adding symbols to the global symbol table
    main_symbol = MiniElfLinker.Symbol("main", 0x401000, 64, MiniElfLinker.STB_GLOBAL, MiniElfLinker.STT_FUNC, 1, true, "main.o")
    printf_symbol = MiniElfLinker.Symbol("printf", 0x0, 0, MiniElfLinker.STB_GLOBAL, MiniElfLinker.STT_FUNC, 0, false, "main.o")
    
    linker.global_symbol_table["main"] = main_symbol
    linker.global_symbol_table["printf"] = printf_symbol
    
    print_symbol_table(linker)
    
    unresolved = resolve_symbols(linker)
    if !isempty(unresolved)
        println("\nUnresolved symbols: $(join(unresolved, ", "))")
    else
        println("\nAll symbols resolved!")
    end
end

# Run examples
function run_examples()
    example_parse_elf()
    example_dynamic_linker()
    example_symbol_resolution()
end

# Allow script to be run directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_examples()
end