# Advanced Example: Analyzing an actual ELF object file

using MiniElfLinker
using Printf

function analyze_test_object()
    println("=== Analyzing test_program.o ===")
    
    # Parse the ELF file
    elf_file = parse_elf_file("examples/test_program.o")
    
    println("ELF Header:")
    println("  Type: $(elf_file.header.type == 1 ? "Relocatable" : "Other")")
    println("  Machine: $(elf_file.header.machine == 62 ? "x86-64" : "Other")")
    println("  Sections: $(length(elf_file.sections))")
    println("  Symbols: $(length(elf_file.symbols))")
    println("  Relocations: $(length(elf_file.relocations))")
    
    # Show section information
    println("\nSections:")
    for (i, section) in enumerate(elf_file.sections)
        if section.size > 0  # Skip empty sections
            section_name = MiniElfLinker.get_string_from_table(elf_file.string_table, section.name)
            if !isempty(section_name)
                flags_str = ""
                flags_str *= (section.flags & MiniElfLinker.SHF_ALLOC) != 0 ? "A" : ""
                flags_str *= (section.flags & MiniElfLinker.SHF_WRITE) != 0 ? "W" : ""
                flags_str *= (section.flags & MiniElfLinker.SHF_EXECINSTR) != 0 ? "X" : ""
                
                @printf("  [%2d] %-15s  Size: 0x%04x  Flags: %s\n", 
                        i-1, section_name, section.size, flags_str)
            end
        end
    end
    
    # Show symbol information
    println("\nSymbols:")
    for (i, symbol) in enumerate(elf_file.symbols)
        if symbol.name != 0
            symbol_name = MiniElfLinker.get_string_from_table(elf_file.symbol_string_table, symbol.name)
            if !isempty(symbol_name)
                binding = MiniElfLinker.st_bind(symbol.info)
                sym_type = MiniElfLinker.st_type(symbol.info)
                
                binding_str = binding == MiniElfLinker.STB_GLOBAL ? "GLOBAL" :
                             binding == MiniElfLinker.STB_LOCAL ? "LOCAL" :
                             binding == MiniElfLinker.STB_WEAK ? "WEAK" : "OTHER"
                
                type_str = sym_type == MiniElfLinker.STT_FUNC ? "FUNC" :
                          sym_type == MiniElfLinker.STT_OBJECT ? "OBJECT" :
                          sym_type == MiniElfLinker.STT_NOTYPE ? "NOTYPE" : "OTHER"
                
                @printf("  [%2d] %-15s  %-6s %-6s  Value: 0x%08x  Size: %d\n",
                        i-1, symbol_name, binding_str, type_str, symbol.value, symbol.size)
            end
        end
    end
    
    # Show relocation information
    if !isempty(elf_file.relocations)
        println("\nRelocations:")
        for (i, reloc) in enumerate(elf_file.relocations)
            rel_type = MiniElfLinker.elf64_r_type(reloc.info)
            sym_index = MiniElfLinker.elf64_r_sym(reloc.info)
            
            type_str = rel_type == MiniElfLinker.R_X86_64_64 ? "R_X86_64_64" :
                      rel_type == MiniElfLinker.R_X86_64_PC32 ? "R_X86_64_PC32" :
                      rel_type == MiniElfLinker.R_X86_64_PLT32 ? "R_X86_64_PLT32" : "OTHER"
            
            @printf("  [%2d] Offset: 0x%08x  Type: %-15s  Symbol: %d  Addend: %d\n",
                    i-1, reloc.offset, type_str, sym_index, reloc.addend)
        end
    end
end

function demonstrate_linking()
    println("\n=== Demonstrating Dynamic Linking Process ===")
    
    # Create linker and load object
    linker = DynamicLinker()
    success = load_object(linker, "examples/test_program.o")
    
    if success
        println("\nSymbol table after loading:")
        print_symbol_table(linker)
        
        # Check for unresolved symbols
        unresolved = resolve_symbols(linker)
        if !isempty(unresolved)
            println("\nUnresolved symbols that would need to be provided by libraries:")
            for sym in unresolved
                println("  - $sym")
            end
        end
        
        # Allocate memory (simulated)
        println("\nAllocating memory regions...")
        MiniElfLinker.allocate_memory_regions!(linker)
        
        println("\nMemory layout:")
        print_memory_layout(linker)
        
        # Perform relocations
        println("\nPerforming relocations...")
        MiniElfLinker.perform_relocations!(linker)
        
        println("\nLinking process completed!")
    else
        println("Failed to load object file!")
    end
end

# Run the analysis
if abspath(PROGRAM_FILE) == @__FILE__
    analyze_test_object()
    demonstrate_linking()
end