# Educational Example: Step-by-step ELF Linking Process
# This example demonstrates each phase of the linking process in detail

using MiniElfLinker
using Printf

function educational_linking_walkthrough()
    println("=" ^ 80)
    println("MINI ELF LINKER - EDUCATIONAL WALKTHROUGH")
    println("=" ^ 80)
    
    # Phase 1: ELF File Analysis
    println("\n📂 PHASE 1: ELF FILE ANALYSIS")
    println("-" ^ 40)
    
    filename = "examples/test_program.o"
    println("Analyzing file: $filename")
    
    # Parse the ELF file
    elf_file = parse_elf_file(filename)
    
    # Show basic file information
    println("\n🔍 Basic File Information:")
    magic_str = join([string(b, base=16, pad=2) for b in elf_file.header.magic], " ")
    println("  Magic: $magic_str ($(String([elf_file.header.magic[2], elf_file.header.magic[3], elf_file.header.magic[4]])))")
    println("  Class: $(elf_file.header.class == 2 ? "64-bit" : "32-bit")")
    println("  Endianness: $(elf_file.header.data == 1 ? "Little Endian" : "Big Endian")")
    println("  Type: $(elf_file.header.type == 1 ? "Relocatable Object" : "Other ($(elf_file.header.type))")")
    println("  Machine: $(elf_file.header.machine == 62 ? "x86-64" : "Other ($(elf_file.header.machine))")")
    
    # Phase 2: Section Analysis
    println("\n📋 PHASE 2: SECTION ANALYSIS")
    println("-" ^ 40)
    
    println("Found $(length(elf_file.sections)) sections:")
    
    important_sections = []
    for (i, section) in enumerate(elf_file.sections)
        if section.size > 0
            section_name = MiniElfLinker.get_string_from_table(elf_file.string_table, section.name)
            if !isempty(section_name)
                flags_str = ""
                flags_str *= (section.flags & MiniElfLinker.SHF_ALLOC) != 0 ? "A" : "-"
                flags_str *= (section.flags & MiniElfLinker.SHF_WRITE) != 0 ? "W" : "-"
                flags_str *= (section.flags & MiniElfLinker.SHF_EXECINSTR) != 0 ? "X" : "-"
                
                type_name = section.type == MiniElfLinker.SHT_PROGBITS ? "PROGBITS" :
                           section.type == MiniElfLinker.SHT_SYMTAB ? "SYMTAB" :
                           section.type == MiniElfLinker.SHT_STRTAB ? "STRTAB" :
                           section.type == MiniElfLinker.SHT_RELA ? "RELA" :
                           "OTHER"
                
                @printf("  [%2d] %-20s %8s  Size: %6d  Flags: %s\n", 
                        i-1, section_name, type_name, section.size, flags_str)
                
                if section_name in [".text", ".data", ".rodata", ".symtab", ".strtab"]
                    push!(important_sections, (section_name, section))
                end
            end
        end
    end
    
    # Phase 3: Symbol Analysis
    println("\n🏷️  PHASE 3: SYMBOL ANALYSIS")
    println("-" ^ 40)
    
    println("Symbol table contains $(length(elf_file.symbols)) entries:")
    
    global_symbols = []
    undefined_symbols = []
    
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
                          sym_type == MiniElfLinker.STT_NOTYPE ? "NOTYPE" :
                          sym_type == MiniElfLinker.STT_FILE ? "FILE" : "OTHER"
                
                defined = symbol.shndx != 0
                status = defined ? "DEFINED" : "UNDEFINED"
                
                @printf("  [%2d] %-15s  %-6s %-7s %-9s  Value: 0x%08x\n",
                        i-1, symbol_name, binding_str, type_str, status, symbol.value)
                
                if binding == MiniElfLinker.STB_GLOBAL
                    if defined
                        push!(global_symbols, symbol_name)
                    else
                        push!(undefined_symbols, symbol_name)
                    end
                end
            end
        end
    end
    
    println("\n📊 Symbol Summary:")
    println("  Global defined symbols: $(join(global_symbols, ", "))")
    println("  Undefined symbols: $(join(undefined_symbols, ", "))")
    
    # Phase 4: Relocation Analysis
    println("\n🔗 PHASE 4: RELOCATION ANALYSIS")
    println("-" ^ 40)
    
    println("Found $(length(elf_file.relocations)) relocations:")
    
    reloc_types = Dict{UInt32, Int}()
    for (i, reloc) in enumerate(elf_file.relocations)
        rel_type = MiniElfLinker.elf64_r_type(reloc.info)
        sym_index = MiniElfLinker.elf64_r_sym(reloc.info)
        
        type_name = rel_type == MiniElfLinker.R_X86_64_64 ? "R_X86_64_64" :
                   rel_type == MiniElfLinker.R_X86_64_PC32 ? "R_X86_64_PC32" :
                   rel_type == MiniElfLinker.R_X86_64_PLT32 ? "R_X86_64_PLT32" :
                   "TYPE_$(rel_type)"
        
        symbol_name = ""
        if sym_index > 0 && sym_index <= length(elf_file.symbols)
            symbol_name = MiniElfLinker.get_string_from_table(elf_file.symbol_string_table, 
                                                             elf_file.symbols[sym_index].name)
        end
        
        @printf("  [%2d] %-16s  Symbol: %-12s  Offset: 0x%08x  Addend: %d\n",
                i-1, type_name, symbol_name, reloc.offset, reloc.addend)
        
        reloc_types[rel_type] = get(reloc_types, rel_type, 0) + 1
    end
    
    println("\n📈 Relocation Type Summary:")
    for (type_id, count) in reloc_types
        type_name = type_id == MiniElfLinker.R_X86_64_PC32 ? "PC-relative 32-bit" :
                   type_id == MiniElfLinker.R_X86_64_PLT32 ? "PLT 32-bit" :
                   type_id == MiniElfLinker.R_X86_64_64 ? "Direct 64-bit" : "Other"
        println("  $(type_name): $count relocations")
    end
    
    # Phase 5: Dynamic Linking Process
    println("\n🔄 PHASE 5: DYNAMIC LINKING PROCESS")
    println("-" ^ 40)
    
    # Create linker
    println("Creating dynamic linker...")
    linker = DynamicLinker()
    
    # Load object
    println("Loading object file...")
    success = load_object(linker, filename)
    
    if !success
        println("❌ Failed to load object file!")
        return
    end
    
    println("✅ Object loaded successfully!")
    
    # Show loaded symbols
    println("\n🏷️  Loaded Symbols:")
    if isempty(linker.global_symbol_table)
        println("  No global symbols found")
    else
        for (name, symbol) in sort(collect(linker.global_symbol_table), by=x->x[1])
            status = symbol.defined ? "✅ RESOLVED" : "❌ UNRESOLVED"
            @printf("  %-15s  %s\n", name, status)
        end
    end
    
    # Symbol resolution
    println("\n🔍 Symbol Resolution:")
    unresolved = resolve_symbols(linker)
    if isempty(unresolved)
        println("  ✅ All symbols resolved!")
    else
        println("  ❌ Unresolved symbols: $(join(unresolved, ", "))")
        println("  Note: These would typically be provided by system libraries")
    end
    
    # Memory allocation
    println("\n💾 Memory Allocation:")
    println("Allocating memory regions...")
    MiniElfLinker.allocate_memory_regions!(linker)
    
    total_size = sum(region.size for region in linker.memory_regions)
    println("  Total allocated: $total_size bytes across $(length(linker.memory_regions)) regions")
    
    for (i, region) in enumerate(linker.memory_regions)
        perm_str = ""
        perm_str *= (region.permissions & 0x1) != 0 ? "R" : "-"
        perm_str *= (region.permissions & 0x2) != 0 ? "W" : "-"
        perm_str *= (region.permissions & 0x4) != 0 ? "X" : "-"
        
        @printf("  Region %d: 0x%08x-0x%08x  %s  (%d bytes)\n",
                i, region.base_address, region.base_address + region.size - 1,
                perm_str, region.size)
    end
    
    # Relocation processing
    println("\n🔧 Relocation Processing:")
    println("Applying relocations...")
    MiniElfLinker.perform_relocations!(linker)
    println("  ✅ Relocation processing completed")
    
    # Final summary
    println("\n" * repeat("=", 80))
    println("LINKING SUMMARY")
    println(repeat("=", 80))
    println("✅ ELF file successfully parsed and analyzed")
    println("✅ $(length(global_symbols)) global symbols defined")
    println("⚠️  $(length(undefined_symbols)) symbols need external resolution")
    println("✅ $(length(elf_file.relocations)) relocations processed")
    println("✅ $total_size bytes of memory allocated")
    println("\n🎓 This demonstrates the core concepts of dynamic linking!")
    println("   The unresolved symbols would be satisfied by linking with")
    println("   system libraries (like libc for printf) in a real linker.")
end

# Run the educational walkthrough
if abspath(PROGRAM_FILE) == @__FILE__
    educational_linking_walkthrough()
end