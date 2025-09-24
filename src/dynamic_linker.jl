# Dynamic Linker Implementation
# Mathematical model: Δ: D → R where D = ELF objects × Symbol tables × Memory layouts
# Core functionality for linking ELF objects following rigorous mathematical specification

using Printf

"""
    Symbol

Mathematical model: Symbol ∈ Σ where Σ: String → Symbol
Represents a symbol in the linker's global symbol table.

Fields correspond to mathematical symbol properties:
- name ∈ String: symbol identifier in global namespace
- value ∈ ℕ₆₄: memory address or offset  
- size ∈ ℕ₆₄: symbol memory footprint
- binding ∈ {STB_LOCAL, STB_GLOBAL, STB_WEAK}: symbol visibility
- type ∈ {STT_NOTYPE, STT_OBJECT, STT_FUNC, ...}: symbol classification
- section ∈ ℕ₁₆: containing section index
- defined ∈ {true, false}: definition availability
- source_file ∈ String: originating object file
"""
struct Symbol
    name::String
    value::UInt64
    size::UInt64
    binding::UInt8
    type::UInt8
    section::UInt16
    defined::Bool
    source_file::String
end

"""
    MemoryRegion

Mathematical model: m ∈ M where M = {m_j}_{j=1}^k
Represents a memory region for loaded sections with non-overlap constraint:
∀m_i, m_j ∈ M: i ≠ j ⟹ [α_base(m_i), α_base(m_i) + size(m_i)) ∩ [α_base(m_j), α_base(m_j) + size(m_j)) = ∅

Fields:
- data ∈ Vector{UInt8}: raw section content
- base_address ∈ ℕ₆₄: virtual memory address α_base(m)
- size ∈ ℕ₆₄: memory region size
- permissions ∈ ℕ₈: read/write/execute flags
"""
mutable struct MemoryRegion
    data::Vector{UInt8}
    base_address::UInt64
    size::UInt64
    permissions::UInt8  # Read/Write/Execute flags
end

"""
    DynamicLinker

Mathematical model: S_Δ = ⟨O, Σ, M, α_base, α_next, T⟩
Main dynamic linker state representing the complete linking context.

State space components:
- loaded_objects ∈ Vector{ElfFile}: O = {o_i}_{i=1}^n loaded ELF objects
- global_symbol_table ∈ Dict{String, Symbol}: Σ: String → Symbol mapping
- memory_regions ∈ Vector{MemoryRegion}: M = {m_j}_{j=1}^k memory allocations
- base_address ∈ ℕ₆₄: α_base virtual memory base
- next_address ∈ ℕ₆₄: α_next next available address
- temp_files ∈ Vector{String}: T temporary file cleanup set
"""
mutable struct DynamicLinker
    loaded_objects::Vector{ElfFile}           # ↔ O = {o_i}
    global_symbol_table::Dict{String, Symbol} # ↔ Σ: String → Symbol  
    memory_regions::Vector{MemoryRegion}      # ↔ M = {m_j}
    base_address::UInt64                      # ↔ α_base ∈ ℕ₆₄
    next_address::UInt64                      # ↔ α_next ∈ ℕ₆₄
    temp_files::Vector{String}                # ↔ T cleanup set
end

"""
    DynamicLinker(base_address::UInt64 = UInt64(0x400000)) -> DynamicLinker

Mathematical model: S_Δ initialization
Create a new dynamic linker instance with initial state S_Δ = ⟨∅, ∅, ∅, α_base, α_base, ∅⟩

Base address α_base defaults to 0x400000 (standard Linux executable base).
"""
function DynamicLinker(alpha_base::UInt64 = UInt64(0x400000))
    # Initialize linker state: S_Δ = ⟨O, Σ, M, α_base, α_next, T⟩
    return DynamicLinker(
        ElfFile[],                    # ↔ O = ∅ (empty object set)
        Dict{String, Symbol}(),       # ↔ Σ = ∅ (empty symbol table)
        MemoryRegion[],              # ↔ M = ∅ (empty memory regions)
        alpha_base,                   # ↔ α_base virtual memory base
        alpha_base,                   # ↔ α_next = α_base initially
        String[]                      # ↔ T = ∅ (empty temp files)
    )
end

"""
    load_object(linker::DynamicLinker, filename::String) -> Bool

Mathematical model: δ_load: ElfFile × S_Δ → S_Δ'
Load an ELF object file or archive file into the linker state.

File type dispatch function:
```math
δ_load(linker, file) = \\begin{cases}
δ_{load\\_elf}(linker, file) & \\text{if } file \\in ELF\\_FILES \\\\
δ_{load\\_archive}(linker, file) & \\text{if } file \\in AR\\_FILES \\\\
⊥ & \\text{otherwise}
\\end{cases}
```

State transformation: S_Δ → S_Δ' where O' = O ∪ {parsed_object}
"""
function load_object(linker::DynamicLinker, filename::String)
    # File type detection: classify(file) ∈ {ELF_FILE, AR_FILE, UNKNOWN}
    file_type = detect_file_type_by_magic(filename)
    
    if file_type == ELF_FILE
        return delta_load_elf_object(linker, filename)        # ↔ δ_load_elf
    elseif file_type == AR_FILE
        return delta_load_archive_objects(linker, filename)   # ↔ δ_load_archive
    else
        println("Failed to load object $filename: Unsupported file type")
        return false
    end
end

"""
    load_elf_object(linker::DynamicLinker, filename::String) -> Bool

Load a single ELF object file into the linker.
"""
function load_elf_object(linker::DynamicLinker, filename::String)
    try
        elf_file = parse_elf_file(filename)
        push!(linker.loaded_objects, elf_file)
        
        # Extract symbols from this object
        extract_symbols!(linker, elf_file)
        
        println("Loaded object: $filename")
        return true
    catch e
        println("Failed to load ELF object $filename: $e")
        return false
    end
end

"""
    load_archive_objects(linker::DynamicLinker, filename::String) -> Bool

Load all ELF objects from an archive file into the linker.

Mathematical model for archive extraction:
```math
archive.a = \\{object_1.o, object_2.o, \\ldots, object_n.o\\}
```

```math
load_archive(linker, archive.a) = \\bigwedge_{i=1}^{n} load_elf(linker, object_i.o)
```
"""
function load_archive_objects(linker::DynamicLinker, filename::String)
    if detect_file_type_by_magic(filename) != AR_FILE
        println("Failed to load archive $filename: Not an archive file")
        return false
    end
    
    objects_loaded = 0
    
    try
        open(filename, "r") do file
            # Skip archive magic
            seek(file, 8)
            
            while !eof(file)
                # Read archive member header (60 bytes)
                if position(file) + 60 > filesize(filename)
                    break
                end
                
                header = read(file, 60)
                if length(header) < 60
                    break
                end
                
                # Parse archive member header
                name = strip(String(header[1:16]))
                size_str = strip(String(header[49:58]))
                
                if isempty(size_str)
                    break
                end
                
                member_size = parse(Int, size_str)
                member_start = position(file)
                
                # Check if this member is an object file (ELF)
                if member_size >= 4
                    magic = read(file, 4)
                    seek(file, member_start)  # Reset position
                    
                    if magic == [0x7f, 0x45, 0x4c, 0x46]  # ELF magic
                        # Create temporary file for the ELF object
                        temp_file = tempname() * ".o"
                        try
                            # Extract the ELF object to temp file
                            member_data = read(file, member_size)
                            write(temp_file, member_data)
                            
                            # Add to temporary files list for later cleanup
                            push!(linker.temp_files, temp_file)
                            
                            # Load the extracted ELF object
                            if load_elf_object(linker, temp_file)
                                objects_loaded += 1
                                println("  → Extracted and loaded: $name")
                            else
                                println("  → Failed to load extracted object: $name")
                            end
                        catch e
                            println("  → Error extracting $name: $e")
                            # Clean up this specific temp file on error
                            if isfile(temp_file)
                                rm(temp_file)
                            end
                        end
                    else
                        # Skip non-ELF member
                        seek(file, member_start + member_size)
                    end
                else
                    # Skip too small member
                    seek(file, member_start + member_size)
                end
                
                # Align to even boundary
                if member_size % 2 == 1
                    read(file, 1)
                end
            end
        end
        
        if objects_loaded > 0
            println("Loaded archive: $filename ($objects_loaded objects)")
            return true
        else
            println("Failed to load archive $filename: No valid ELF objects found")
            return false
        end
        
    catch e
        println("Failed to load archive $filename: $e")
        return false
    end
end

"""
    inject_c_runtime_startup!(linker::DynamicLinker, main_address::UInt64) -> UInt64

Inject a minimal C runtime startup function that properly calls main.

Mathematical model for C runtime initialization:
```math
\\text{_start} = align\\_stack \\circ clear\\_frame\\_pointer \\circ call\\_main \\circ exit\\_syscall
```

Assembly implementation:
```assembly
_start:
    and \$-16, %rsp      # Stack alignment (16-byte boundary)
    xor %rbp, %rbp      # Clear frame pointer  
    call main            # Call main function
    mov %rax, %rdi      # Move return value to exit code
    mov \$60, %rax       # sys_exit syscall number
    syscall              # Terminate program
```
"""
function inject_c_runtime_startup!(linker::DynamicLinker, main_address::UInt64)
    # Place startup code at a safe location that doesn't conflict with ELF headers
    # Headers typically end around 0x400000 + 0x200 (512 bytes), so place _start after that
    base_address = 0x400200  # Start after headers (512 bytes should be enough)
    
    # Find a safe location for _start that doesn't conflict with existing regions
    startup_address = base_address
    if !isempty(linker.memory_regions)
        # Find the maximum address and place _start after existing regions if needed
        max_existing = maximum(r.base_address + r.size for r in linker.memory_regions)
        if max_existing > base_address
            startup_address = max_existing + 0x10  # Small gap after existing regions
        end
    end
    
    # Calculate relative call offset (main_address - (startup_address + call_instruction_offset))
    call_instruction_offset = 7  # Position of call instruction within _start
    call_target = startup_address + call_instruction_offset + 5  # Address after the call instruction
    rel_offset_i64 = Int64(main_address) - Int64(call_target)
    
    # Verify the offset fits in Int32
    if abs(rel_offset_i64) > 0x7fffffff
        error("Relative offset too large: main at 0x$(string(main_address, base=16)), _start at 0x$(string(startup_address, base=16))")
    end
    
    rel_offset = Int32(rel_offset_i64)
    
    # x86-64 assembly code for minimal C runtime startup
    startup_code = UInt8[
        # xor %rbp, %rbp  (clear frame pointer)  
        0x48, 0x31, 0xed,
        
        # and $-16, %rsp  (align stack to 16-byte boundary)
        0x48, 0x83, 0xe4, 0xf0,
        
        # call main (relative call)
        0xe8,
        (rel_offset >>  0) & 0xff, (rel_offset >>  8) & 0xff,
        (rel_offset >> 16) & 0xff, (rel_offset >> 24) & 0xff,
        
        # mov %rax, %rdi  (move return value to exit code)
        0x48, 0x89, 0xc7,
        
        # mov $60, %rax  (sys_exit syscall number)
        0x48, 0xc7, 0xc0, 0x3c, 0x00, 0x00, 0x00,
        
        # syscall  (terminate program)
        0x0f, 0x05
    ]
    
    # Create memory region for startup code
    startup_region = MemoryRegion(
        startup_code,           # data
        startup_address,        # base_address  
        length(startup_code),   # size
        0x5                     # permissions: read + execute
    )
    
    # Add to linker's memory regions
    push!(linker.memory_regions, startup_region)
    
    # Add _start symbol to global symbol table
    startup_symbol = Symbol(
        "_start",               # name
        startup_address,        # value
        length(startup_code),   # size
        1,                      # binding (global)
        2,                      # type (function)  
        0,                      # section
        true,                   # defined
        "synthetic"             # source_file
    )
    
    linker.global_symbol_table["_start"] = startup_symbol
    
    return startup_address
end

"""
    cleanup_temp_files!(linker::DynamicLinker)

Clean up all temporary files created during archive extraction.
"""
function cleanup_temp_files!(linker::DynamicLinker)
    for temp_file in linker.temp_files
        if isfile(temp_file)
            try
                rm(temp_file)
            catch e
                println("Warning: Failed to cleanup temp file $temp_file: $e")
            end
        end
    end
    empty!(linker.temp_files)
end

"""
    extract_symbols!(linker::DynamicLinker, elf_file::ElfFile)

Extract symbols from an ELF file and add them to the global symbol table.
"""
function extract_symbols!(linker::DynamicLinker, elf_file::ElfFile)
    for sym in elf_file.symbols
        if sym.name == 0  # Skip unnamed symbols
            continue
        end
        
        symbol_name = get_string_from_table(elf_file.symbol_string_table, sym.name)
        if isempty(symbol_name)
            continue
        end
        
        binding = st_bind(sym.info)
        sym_type = st_type(sym.info)
        
        # Process all symbols for debugging but only add global/weak to global table
        defined = sym.shndx != 0  # SHN_UNDEF = 0
        
        symbol = Symbol(
            symbol_name,
            sym.value,
            sym.size,
            binding,
            sym_type,
            sym.shndx,
            defined,
            elf_file.filename
        )
        
        if binding == STB_GLOBAL || binding == STB_WEAK
            
            # Handle symbol conflicts
            if haskey(linker.global_symbol_table, symbol_name)
                existing = linker.global_symbol_table[symbol_name]
                
                # Defined symbols override undefined symbols
                if defined && !existing.defined
                    linker.global_symbol_table[symbol_name] = symbol
                    println("Symbol '$symbol_name': defined symbol overrides undefined")
                # Global symbols override weak symbols
                elseif binding == STB_GLOBAL && existing.binding == STB_WEAK
                    linker.global_symbol_table[symbol_name] = symbol
                    println("Symbol '$symbol_name': global definition overrides weak")
                elseif binding == STB_WEAK && existing.binding == STB_GLOBAL
                    # Keep existing global symbol
                    println("Symbol '$symbol_name': keeping existing global definition")
                elseif binding == STB_GLOBAL && existing.binding == STB_GLOBAL && defined && existing.defined
                    error("Multiple definitions of global symbol '$symbol_name'")
                end
            else
                linker.global_symbol_table[symbol_name] = symbol
            end
        end
    end
end

"""
    resolve_symbols(linker::DynamicLinker) -> Vector{String}

Mathematical model: δ_resolve: S_Δ → S_Δ' × U
Resolve all symbols in the global symbol table and return unresolved symbol set.

Symbol resolution function:
```math
Σ'(name) = \\begin{cases}
address(def) & \\text{if } \\exists def \\in \\bigcup_{o \\in O} symbols(o): def.name = name \\land defined(def) \\\\
⊥ & \\text{if } binding(name) = STB\\_STRONG \\land \\neg\\exists def
\\end{cases}
```

Returns: U = {s ∈ Σ : ¬defined(s)} (unresolved symbol set)
"""
function resolve_symbols(linker::DynamicLinker)
    # Initialize unresolved symbol set: U = ∅
    unresolved_symbols = String[]                           # ↔ U initialization
    
    # Iterate over global symbol table: ∀(name, symbol) ∈ Σ
    for (symbol_name, symbol) in linker.global_symbol_table
        if !symbol.defined                                  # ↔ ¬defined(symbol)
            # Search for definition in loaded objects: ⋃_{o ∈ O} symbols(o)
            found_definition = nothing
            for obj in linker.loaded_objects                # ↔ object iteration
                for obj_symbol in obj.symbols               # ↔ symbol search
                    obj_symbol_name = get_string_from_table(obj.symbol_string_table, obj_symbol.name)
                    # Check for matching defined symbol: def.name = name ∧ defined(def)
                    if obj_symbol_name == symbol_name && obj_symbol.section != 0  # ↔ definition check
                        found_definition = obj_symbol       # ↔ definition found
                        break
                    end
                end
                found_definition !== nothing && break
            end
            
            if found_definition !== nothing
                # Update symbol with definition: Σ'(name) = address(def)
                updated_symbol = Symbol(
                    symbol_name, found_definition.value, found_definition.size,
                    found_definition.binding, found_definition.type, found_definition.section,
                    true, symbol.source_file                # ↔ defined = true
                )
                linker.global_symbol_table[symbol_name] = updated_symbol  # ↔ Σ' update
            else
                # Strong unresolved symbol: symbol ∈ U
                push!(unresolved_symbols, symbol_name)     # ↔ add to unresolved set
            end
        end
    end
    
    return unresolved_symbols                               # ↔ U result
end

"""
    allocate_memory_regions!(linker::DynamicLinker)

Mathematical model: δ_allocate: S_Δ → S_Δ'
Allocate memory regions for all loaded sections with non-overlap constraint.

Memory allocation constraint:
```math
\\forall m_i, m_j \\in M': i ≠ j \\implies [α_{base}(m_i), α_{base}(m_i) + size(m_i)) \\cap [α_{base}(m_j), α_{base}(m_j) + size(m_j)) = ∅
```

Address computation: α_next' = max_{m ∈ M'} (α_base(m) + size(m))
"""
function allocate_memory_regions!(linker::DynamicLinker)
    # Current address tracking: α_current = α_next
    alpha_current = linker.next_address                     # ↔ α_current initialization
    section_address_map = Dict{Tuple{String, UInt16}, UInt64}()  # Section → address mapping
    
    # Iterate over all loaded objects: ∀o ∈ O
    for elf_file in linker.loaded_objects
        for (section_idx, section) in enumerate(elf_file.sections)
            # Allocatable section filter: section.flags ∧ SHF_ALLOC ≠ 0
            if section.flags & SHF_ALLOC != 0 && section.size > 0
                # Address alignment: align_to_boundary(α_current, section.addralign)
                alpha_aligned = align_address(alpha_current, section.addralign)  # ↔ alignment constraint
                
                # Section address mapping: (filename, index) ↦ α_aligned
                elf_section_index = UInt16(section_idx - 1)  # ↔ 0-based indexing correction
                section_address_map[(elf_file.filename, elf_section_index)] = alpha_aligned
                
                # Create memory region: m = ⟨data, α_base, size, permissions⟩
                region = MemoryRegion(
                    zeros(UInt8, section.size),            # ↔ data allocation
                    alpha_aligned,                         # ↔ α_base(m) = α_aligned
                    section.size,                          # ↔ size(m)
                    get_section_permissions(section.flags) # ↔ permissions mapping
                )
                
                # Load section data if available: data copying from file
                if section.type == SHT_PROGBITS && section.offset > 0
                    open(elf_file.filename, "r") do io
                        seek(io, section.offset)
                        read!(io, region.data)
                    end
                end
                
                push!(linker.memory_regions, region)
                current_address = aligned_addr + section.size
                
                section_name = get_string_from_table(elf_file.string_table, section.name)
                println("Allocated memory region for section '$section_name' (index $elf_section_index) at 0x$(string(aligned_addr, base=16))")
            end
        end
    end
    
    linker.next_address = current_address
    
    # Update symbol addresses to be absolute
    update_symbol_addresses!(linker, section_address_map)
end

"""
    update_symbol_addresses!(linker::DynamicLinker, section_address_map::Dict)

Update symbol addresses to be absolute after memory allocation.
"""
function update_symbol_addresses!(linker::DynamicLinker, section_address_map::Dict{Tuple{String, UInt16}, UInt64})
    for (symbol_name, symbol) in linker.global_symbol_table
        if symbol.defined && symbol.section > 0
            # Find the absolute address of the section
            section_key = (symbol.source_file, symbol.section)
            if haskey(section_address_map, section_key)
                section_base = section_address_map[section_key]
                new_value = section_base + symbol.value
                
                # Create updated symbol
                updated_symbol = Symbol(
                    symbol.name,
                    new_value,
                    symbol.size,
                    symbol.binding,
                    symbol.type,
                    symbol.section,
                    symbol.defined,
                    symbol.source_file
                )
                
                linker.global_symbol_table[symbol_name] = updated_symbol
                println("Updated symbol '$symbol_name' address: 0x$(string(symbol.value, base=16)) -> 0x$(string(new_value, base=16))")
            end
        end
    end
end

"""
    align_address(addr::UInt64, alignment::UInt64) -> UInt64

Align an address to the specified alignment.
"""
function align_address(addr::UInt64, alignment::UInt64)
    if alignment == 0 || alignment == 1
        return addr
    end
    
    mask = alignment - 1
    return (addr + mask) & ~mask
end

"""
    get_section_permissions(flags::UInt64) -> UInt8

Convert section flags to permission bits.
"""
function get_section_permissions(flags::UInt64)
    permissions = 0x0
    
    # Read permission (always granted for allocated sections)
    permissions |= 0x1
    
    # Write permission
    if flags & SHF_WRITE != 0
        permissions |= 0x2
    end
    
    # Execute permission
    if flags & SHF_EXECINSTR != 0
        permissions |= 0x4
    end
    
    return permissions
end

"""
    perform_relocations!(linker::DynamicLinker)

Perform relocations for all loaded objects.
"""
function perform_relocations!(linker::DynamicLinker)
    for elf_file in linker.loaded_objects
        for relocation in elf_file.relocations
            perform_relocation!(linker, elf_file, relocation)
        end
    end
end

"""
    perform_relocation!(linker::DynamicLinker, elf_file::ElfFile, relocation::RelocationEntry)

Perform a single relocation.
"""
function perform_relocation!(linker::DynamicLinker, elf_file::ElfFile, relocation::RelocationEntry)
    sym_index = elf64_r_sym(relocation.info)
    rel_type = elf64_r_type(relocation.info)
    
    # Get symbol
    if sym_index == 0
        symbol_value = 0
        symbol_name = ""
    elseif sym_index <= length(elf_file.symbols)
        # Convert from 0-based ELF indexing to 1-based Julia indexing
        julia_index = sym_index + 1
        if julia_index <= length(elf_file.symbols)
            symbol = elf_file.symbols[julia_index]
            symbol_name = get_string_from_table(elf_file.symbol_string_table, symbol.name)
        else
            error("Invalid symbol index after conversion: $sym_index -> $julia_index")
        end
        
        if !isempty(symbol_name) && haskey(linker.global_symbol_table, symbol_name)
            global_symbol = linker.global_symbol_table[symbol_name]
            if global_symbol.defined
                symbol_value = global_symbol.value
            else
                println("Warning: Undefined symbol: $symbol_name")
                symbol_value = 0
            end
        elseif !isempty(symbol_name)
            # Handle undefined reference
            println("Warning: Undefined reference to symbol: $symbol_name")
            symbol_value = 0  # Use 0 for undefined symbols for now
        else
            symbol_value = symbol.value  # Use symbol value as-is for local symbols
        end
    else
        error("Invalid symbol index: $sym_index")
    end
    
    # For this simplified implementation, assume most relocations are in .text section
    # Find the .text section's memory region
    text_region = nothing
    for region in linker.memory_regions
        # Check if this region likely corresponds to .text (first executable region)
        if region.permissions & 0x4 != 0  # Executable
            text_region = region
            break
        end
    end
    
    if text_region === nothing
        println("Warning: Could not find text region for relocation")
        return
    end
    
    # Perform relocation based on type
    if rel_type == R_X86_64_64
        # Direct 64-bit address
        value = Int64(symbol_value) + relocation.addend
        apply_relocation_to_region!(text_region, relocation.offset, value, 8)
        println("R_X86_64_64 relocation at offset 0x$(string(relocation.offset, base=16)): 0x$(string(value, base=16))")
    elseif rel_type == R_X86_64_PC32
        # PC-relative 32-bit
        target_addr = text_region.base_address + relocation.offset + 4  # +4 for next instruction
        value = Int64(symbol_value) + relocation.addend - Int64(target_addr)
        apply_relocation_to_region!(text_region, relocation.offset, value, 4)
        println("R_X86_64_PC32 relocation at offset 0x$(string(relocation.offset, base=16)): 0x$(string(value, base=16))")
    elseif rel_type == R_X86_64_PLT32
        # PLT 32-bit address (for static linking, treat like PC32)
        # For call instructions, the target address should be the address of the next instruction
        target_addr = text_region.base_address + relocation.offset + 4  # +4 for next instruction
        value = Int64(symbol_value) + relocation.addend - Int64(target_addr)
        apply_relocation_to_region!(text_region, relocation.offset, value, 4)
        println("R_X86_64_PLT32 relocation at offset 0x$(string(relocation.offset, base=16)): 0x$(string(value, base=16))")
    else
        println("Unsupported relocation type: $rel_type")
    end
end

"""
    apply_relocation_to_region!(region::MemoryRegion, offset::UInt64, value::Int64, size::Int)

Apply a relocation to a memory region by patching the binary data.
"""
function apply_relocation_to_region!(region::MemoryRegion, offset::UInt64, value::Int64, size::Int)
    # offset is relative to the start of the region
    pos = Int(offset) + 1  # Julia arrays are 1-indexed
    
    if pos + size - 1 <= length(region.data)
        # Apply the relocation based on size
        if size == 4
            # 32-bit relocation
            val_32 = Int32(value)
            region.data[pos] = UInt8(val_32 & 0xff)
            region.data[pos+1] = UInt8((val_32 >> 8) & 0xff)
            region.data[pos+2] = UInt8((val_32 >> 16) & 0xff)
            region.data[pos+3] = UInt8((val_32 >> 24) & 0xff)
        elseif size == 8
            # 64-bit relocation
            val_64 = UInt64(value)
            for i in 0:7
                region.data[pos+i] = UInt8((val_64 >> (i * 8)) & 0xff)
            end
        end
    else
        println("Warning: Relocation offset 0x$(string(offset, base=16)) exceeds region size")
    end
end

"""
    link_objects(filenames::Vector{String}; base_address::UInt64 = 0x400000, 
                enable_system_libraries::Bool = true,
                library_search_paths::Vector{String} = String[],
                library_names::Vector{String} = String[]) -> DynamicLinker

Link multiple ELF object files together. 
- enable_system_libraries: Attempt to resolve symbols against system libraries
- library_search_paths: Additional library search paths (equivalent to -L option)
- library_names: Specific library names to link against (equivalent to -l option)
"""
function link_objects(filenames::Vector{String}; base_address::UInt64 = UInt64(0x400000),
                     enable_system_libraries::Bool = true,
                     library_search_paths::Vector{String} = String[],
                     library_names::Vector{String} = String[])
    linker = DynamicLinker(base_address)
    
    # Load all objects
    for filename in filenames
        if !load_object(linker, filename)
            error("Failed to load object: $filename")
        end
    end
    
    # Resolve symbols
    unresolved = resolve_symbols(linker)
    
    # Attempt to resolve against libraries
    if enable_system_libraries && !isempty(unresolved)
        all_libraries = LibraryInfo[]
        
        # Always try to link libc automatically (like lld does)
        default_libc = find_default_libc()
        if default_libc !== nothing
            push!(all_libraries, default_libc)
            println("Found default libc: $(default_libc.type) at $(default_libc.path)")
        end
        
        # Find explicitly requested libraries (-l equivalent)
        if !isempty(library_names)
            requested_libs = find_libraries(library_search_paths; library_names=library_names)
            append!(all_libraries, requested_libs)
            
            if !isempty(requested_libs)
                println("Found $(length(requested_libs)) requested libraries:")
                for lib in requested_libs
                    println("  - $(lib.name) ($(lib.type)): $(lib.path)")
                end
            end
        end
        
        if !isempty(all_libraries)
            remaining_unresolved = resolve_unresolved_symbols!(linker, all_libraries)
            unresolved = remaining_unresolved
        else
            println("No libraries found for linking")
        end
    end
    
    if !isempty(unresolved)
        println("Warning: Unresolved symbols:")
        for sym in unresolved
            println("  - $sym")
        end
    end
    
    # Allocate memory regions
    allocate_memory_regions!(linker)
    
    # Perform relocations
    perform_relocations!(linker)
    
    # Clean up temporary files from archive extraction
    cleanup_temp_files!(linker)
    
    println("Linking completed successfully!")
    return linker
end

"""
    link_to_executable(filenames::Vector{String}, output_filename::String; 
                      base_address::UInt64 = 0x400000, entry_symbol::String = "main",
                      enable_system_libraries::Bool = true,
                      library_search_paths::Vector{String} = String[],
                      library_names::Vector{String} = String[]) -> Bool

Link multiple ELF object files together and output an executable ELF file.
- enable_system_libraries: Attempt to resolve symbols against system libraries
- library_search_paths: Additional library search paths (equivalent to -L option)
- library_names: Specific library names to link against (equivalent to -l option)
"""
function link_to_executable(filenames::Vector{String}, output_filename::String; 
                           base_address::UInt64 = UInt64(0x400000), 
                           entry_symbol::String = "main",
                           enable_system_libraries::Bool = true,
                           library_search_paths::Vector{String} = String[],
                           library_names::Vector{String} = String[])
    # Perform normal linking
    linker = link_objects(filenames; base_address=base_address, 
                         enable_system_libraries=enable_system_libraries,
                         library_search_paths=library_search_paths,
                         library_names=library_names)
    
    # Find entry point - prefer _start if available, otherwise use main with C runtime setup
    entry_point = base_address + 0x1000  # Default entry point
    
    # Check if we have _start symbol (proper C runtime)
    if haskey(linker.global_symbol_table, "_start")
        entry_symbol_info = linker.global_symbol_table["_start"]
        if entry_symbol_info.defined
            entry_point = entry_symbol_info.value
            println("Entry point set to '_start' at 0x$(string(entry_point, base=16))")
        else
            println("Warning: _start symbol is not defined")
        end
    elseif haskey(linker.global_symbol_table, entry_symbol)
        # We have main but no _start - need to inject C runtime initialization
        entry_symbol_info = linker.global_symbol_table[entry_symbol]
        if entry_symbol_info.defined
            main_address = entry_symbol_info.value
            # Inject a minimal _start function that calls main properly
            entry_point = inject_c_runtime_startup!(linker, main_address)
            println("Entry point set to synthetic '_start' at 0x$(string(entry_point, base=16))")
            println("  → Will call '$entry_symbol' at 0x$(string(main_address, base=16))")
        else
            println("Warning: Entry symbol '$entry_symbol' is not defined, using default entry point")
        end
    else
        println("Warning: Entry symbol '$entry_symbol' not found, using default entry point")
    end
    
    # Write executable
    try
        write_elf_executable(linker, output_filename, entry_point=UInt64(entry_point))
        return true
    catch e
        println("Error writing executable: $e")
        return false
    finally
        # Ensure cleanup even on errors
        cleanup_temp_files!(linker)
    end
end

"""
    print_symbol_table(linker::DynamicLinker)

Print the global symbol table.
"""
function print_symbol_table(linker::DynamicLinker)
    println("Global Symbol Table:")
    println("Name                  | Value      | Size       | Bind | Type | Defined | Source")
    println("-" ^ 80)
    
    for (name, symbol) in sort(collect(linker.global_symbol_table), by=x->x[1])
        binding_str = symbol.binding == STB_GLOBAL ? "GLOBAL" : 
                     symbol.binding == STB_WEAK ? "WEAK" : "OTHER"
        
        type_str = symbol.type == STT_FUNC ? "FUNC" :
                  symbol.type == STT_OBJECT ? "OBJECT" :
                  symbol.type == STT_NOTYPE ? "NOTYPE" : "OTHER"
        
        defined_str = symbol.defined ? "YES" : "NO"
        
        @printf("%-20s | 0x%08x | 0x%08x | %-6s | %-6s | %-7s | %s\n",
                name[1:min(20, length(name))], symbol.value, symbol.size,
                binding_str, type_str, defined_str, basename(symbol.source_file))
    end
end

"""
    print_memory_layout(linker::DynamicLinker)

Print the memory layout of loaded regions.
"""
function print_memory_layout(linker::DynamicLinker)
    println("Memory Layout:")
    println("Base Address  | Size       | Permissions")
    println("-" ^ 40)
    
    for region in linker.memory_regions
        perm_str = ""
        perm_str *= (region.permissions & 0x1) != 0 ? "R" : "-"
        perm_str *= (region.permissions & 0x2) != 0 ? "W" : "-"
        perm_str *= (region.permissions & 0x4) != 0 ? "X" : "-"
        
        @printf("0x%08x    | 0x%08x | %s\n",
                region.base_address, region.size, perm_str)
    end
end