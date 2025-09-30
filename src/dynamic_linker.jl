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

Mathematical model: S_Δ = ⟨O, Σ, M, α_base, α_next, T, GOT, PLT, RelocationEngine, DynSection⟩
Main dynamic linker state representing the complete linking context.

State space components:
- loaded_objects ∈ Vector{ElfFile}: O = {o_i}_{i=1}^n loaded ELF objects
- global_symbol_table ∈ Dict{String, Symbol}: Σ: String → Symbol mapping
- memory_regions ∈ Vector{MemoryRegion}: M = {m_j}_{j=1}^k memory allocations
- base_address ∈ ℕ₆₄: α_base virtual memory base
- next_address ∈ ℕ₆₄: α_next next available address
- temp_files ∈ Vector{String}: T temporary file cleanup set
- got ∈ GlobalOffsetTable: Enhanced GOT for dynamic symbols
- plt ∈ ProcedureLinkageTable: Enhanced PLT for lazy resolution  
- relocation_dispatcher ∈ RelocationDispatcher: Complete relocation engine
- dynamic_section ∈ DynamicSection: Dynamic linking metadata (.dynamic section)
"""
mutable struct DynamicLinker
    loaded_objects::Vector{ElfFile}                    # ↔ O = {o_i}
    global_symbol_table::Dict{String, Symbol}          # ↔ Σ: String → Symbol  
    memory_regions::Vector{MemoryRegion}               # ↔ M = {m_j}
    base_address::UInt64                               # ↔ α_base ∈ ℕ₆₄
    next_address::UInt64                               # ↔ α_next ∈ ℕ₆₄
    temp_files::Vector{String}                         # ↔ T cleanup set
    
    # Section mapping for relocation resolution
    section_address_map::Dict{Tuple{String, UInt16}, UInt64}  # (filename, section_index) -> virtual_address
    
    got::GlobalOffsetTable                             # ↔ Enhanced GOT structure
    plt::ProcedureLinkageTable                        # ↔ Enhanced PLT structure  
    relocation_dispatcher::RelocationDispatcher       # ↔ Complete relocation engine
    dynamic_section::DynamicSection                   # ↔ Dynamic linking metadata
end

"""
    DynamicLinker(base_address::UInt64 = UInt64(0x400000)) -> DynamicLinker

Mathematical model: S_Δ initialization
Create a new dynamic linker instance with enhanced structures for production-ready linking.

Base address α_base defaults to 0x400000 (standard Linux executable base).
For PIE executables, use lower addresses compatible with 0x0 base.
"""
function DynamicLinker(alpha_base::UInt64 = UInt64(0x400000); pie_mode::Bool = false)
    # For PIE executables, use base address 0x0 to match LLD behavior
    if pie_mode
        alpha_base = UInt64(0x0)   # Start at 0x0 for PIE executables like LLD
        got_offset = 0x3000   # GOT at 12KB (similar to LLD layout)
        plt_offset = 0x3100   # PLT at 12KB + 256 bytes  
    else
        got_offset = 0x100000  # GOT at base + 1MB for traditional executables
        plt_offset = 0x110000  # PLT at base + 1MB + 64KB
    end
    
    # Initialize enhanced GOT and PLT structures
    got = GlobalOffsetTable(alpha_base + got_offset)  
    plt = ProcedureLinkageTable(alpha_base + plt_offset)
    relocation_dispatcher = RelocationDispatcher()
    dynamic_section = DynamicSection()
    
    # Initialize linker state: S_Δ = ⟨O, Σ, M, α_base, α_next, T, SectionMap, GOT, PLT, RelocationEngine, DynSection⟩
    return DynamicLinker(
        ElfFile[],                    # ↔ O = ∅ (empty object set)
        Dict{String, Symbol}(),       # ↔ Σ = ∅ (empty symbol table)
        MemoryRegion[],              # ↔ M = ∅ (empty memory regions)
        alpha_base,                   # ↔ α_base virtual memory base
        alpha_base,                   # ↔ α_next = α_base initially
        String[],                     # ↔ T = ∅ (empty temp files)
        Dict{Tuple{String, UInt16}, UInt64}(),  # ↔ Section address mapping
        got,                          # ↔ Enhanced GOT structure
        plt,                          # ↔ Enhanced PLT structure
        relocation_dispatcher,        # ↔ Complete relocation engine
        dynamic_section               # ↔ Dynamic section metadata
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
        return load_elf_object(linker, filename)        # ↔ δ_load_elf
    elseif file_type == AR_FILE
        return load_archive_objects(linker, filename)   # ↔ δ_load_archive
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
    # Find executable text regions to place _start within them
    text_regions = filter(r -> (r.permissions & 0x1) != 0, linker.memory_regions)  # Executable regions
    
    if !isempty(text_regions)
        # PRODUCTION FIX: Place _start at a separate location to avoid overlaps
        # Instead of moving existing code, place _start at the beginning of the text segment
        min_text_addr = minimum(r.base_address for r in text_regions)
        startup_address = min_text_addr - 0x40  # Place 64 bytes before existing code
        
        println("🔧 PRODUCTION FIX: Placing _start at 0x$(string(startup_address, base=16)), main stays at 0x$(string(main_address, base=16))")
        
        # Don't move existing regions - keep them as they are
    else
        # Fallback: place at standard text start
        startup_address = 0x400000 + 0x1000
    end
    
    # Use the original main_address - no need to update from symbol table
    
    # PRODUCTION FIX: Simple approach - use the virtual address distance as calculated
    # The key insight is that the ELF writer should maintain the same relative distances
    # between regions as they have in virtual memory, just with different base offsets
    
    # Calculate relative call offset (main_address - (startup_address + call_instruction_offset))
    call_instruction_offset = 7  # Position of call instruction within _start
    call_target = startup_address + call_instruction_offset + 5  # Address after the call instruction
    
    println("🔍 Call calculation: _start at 0x$(string(startup_address, base=16)), main at 0x$(string(main_address, base=16))")
    println("   Call target: 0x$(string(call_target, base=16))")
    
    rel_offset_i64 = Int64(main_address) - Int64(call_target)
    println("   Calculated offset: $(rel_offset_i64) (0x$(string(rel_offset_i64, base=16)))")
    
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
    
    # Add to linker's memory regions at the beginning (so it gets proper placement)
    pushfirst!(linker.memory_regions, startup_region)
    
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
                    if obj_symbol_name == symbol_name && obj_symbol.shndx != 0  # ↔ definition check
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
                    st_bind(found_definition.info), st_type(found_definition.info), found_definition.shndx,
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
    # Calculate space needed for ELF headers and program headers
    # ELF header: 64 bytes
    # Program headers: estimated 5 segments × 56 bytes = 280 bytes  
    # Round up for safety: 64 + 280 = 344 → round to 512 bytes (0x200)
    headers_size = UInt64(0x200)
    
    # Current address tracking: α_current = α_base + headers_size (start after headers)
    alpha_current = linker.base_address + headers_size
    
    # Update linker's next_address to skip headers
    linker.next_address = alpha_current
    
    # Iterate over all loaded objects: ∀o ∈ O
    for elf_file in linker.loaded_objects
        for (section_idx, section) in enumerate(elf_file.sections)
            # Allocatable section filter: section.flags ∧ SHF_ALLOC ≠ 0
            if section.flags & SHF_ALLOC != 0 && section.size > 0
                # Address alignment: align_to_boundary(α_current, section.addralign)
                alpha_aligned = align_address(alpha_current, section.addralign)  # ↔ alignment constraint
                
                # Section address mapping: (filename, index) ↦ α_aligned
                elf_section_index = UInt16(section_idx - 1)  # ↔ 0-based indexing correction
                linker.section_address_map[(elf_file.filename, elf_section_index)] = alpha_aligned
                
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
                alpha_current = alpha_aligned + section.size
                
                section_name = get_string_from_table(elf_file.string_table, section.name)
                println("Allocated memory region for section '$section_name' (index $elf_section_index) at 0x$(string(alpha_aligned, base=16))")
            end
        end
    end
    
    linker.next_address = alpha_current
    
    # Allocate GOT memory region if present
    if !isempty(linker.got.entries)
        # Assign actual base address to GOT
        got_base = align_address(alpha_current, UInt64(8))  # 8-byte align
        linker.got.base_address = got_base
        got_size = UInt64(length(linker.got.entries) * 8)  # 8 bytes per entry
        alpha_current = got_base + got_size
        
        # GOT entries will be resolved at runtime by dynamic linker
        got_region = MemoryRegion(
            zeros(UInt8, got_size),     # Zero-initialized GOT entries
            got_base,
            got_size,
            0x6  # R+W permissions (GOT is writable for runtime resolution)
        )
        push!(linker.memory_regions, got_region)
        println("Allocated GOT memory region at 0x$(string(got_base, base=16)) ($(got_size) bytes)")
    end
    
    # Allocate PLT memory region if present
    if !isempty(linker.plt.entries)
        # Assign actual base address to PLT
        plt_base = align_address(alpha_current, UInt64(16))  # 16-byte align
        linker.plt.base_address = plt_base
        plt_size = UInt64(length(linker.plt.entries) * linker.plt.entry_size)
        alpha_current = plt_base + plt_size
        
        # Create PLT code by concatenating all entries
        plt_code = UInt8[]
        for entry_code in linker.plt.entries
            append!(plt_code, entry_code)
        end
        
        # Ensure we have the correct size
        while length(plt_code) < plt_size
            push!(plt_code, 0x90)  # NOP padding
        end
        
        plt_region = MemoryRegion(
            plt_code,
            plt_base,
            plt_size,
            0x5  # R+X permissions (PLT is executable)
        )
        push!(linker.memory_regions, plt_region)
        println("Allocated PLT memory region at 0x$(string(plt_base, base=16)) ($(plt_size) bytes)")
    end
    
    # Allocate dynamic section memory region if present
    if !isempty(linker.dynamic_section.entries)
        # Dynamic section contains DynamicEntry structs (16 bytes each on 64-bit)
        dynamic_base = align_address(alpha_current, UInt64(8))  # 8-byte align
        dynamic_size = UInt64(length(linker.dynamic_section.entries) * 16)  # 16 bytes per entry
        alpha_current = dynamic_base + dynamic_size
        
        # Serialize dynamic entries to binary format using direct byte writing
        dynamic_data = Vector{UInt8}()
        sizehint!(dynamic_data, length(linker.dynamic_section.entries) * 16)
        
        for entry in linker.dynamic_section.entries
            # Write tag as 8-byte little-endian
            for i in 0:7
                push!(dynamic_data, UInt8((entry.tag >> (8*i)) & 0xff))
            end
            # Write value as 8-byte little-endian
            for i in 0:7
                push!(dynamic_data, UInt8((entry.value >> (8*i)) & 0xff))
            end
        end
        
        dynamic_region = MemoryRegion(
            dynamic_data,
            dynamic_base,
            dynamic_size,
            0x4  # R-- permissions (dynamic section is read-only)
        )
        push!(linker.memory_regions, dynamic_region)
        println("Allocated dynamic section at 0x$(string(dynamic_base, base=16)) ($(dynamic_size) bytes)")
        
        # Also allocate dynamic string table if present
        if !isempty(linker.dynamic_section.string_table)
            dynstr_base = align_address(alpha_current, UInt64(1))  # byte align
            dynstr_size = UInt64(length(linker.dynamic_section.string_table))
            alpha_current = dynstr_base + dynstr_size
            
            dynstr_region = MemoryRegion(
                copy(linker.dynamic_section.string_table),
                dynstr_base,
                dynstr_size,
                0x4  # R-- permissions (string table is read-only)
            )
            push!(linker.memory_regions, dynstr_region)
            println("Allocated dynamic string table at 0x$(string(dynstr_base, base=16)) ($(dynstr_size) bytes)")
            
            # Update DT_STRTAB entry with actual address
            for i in 1:length(linker.dynamic_section.entries)
                if linker.dynamic_section.entries[i].tag == DT_STRTAB
                    linker.dynamic_section.entries[i] = DynamicEntry(DT_STRTAB, dynstr_base)
                    # Also update the serialized data
                    offset = (i - 1) * 16 + 8  # Skip to value field
                    for j in 1:8
                        dynamic_region.data[offset + j] = UInt8((dynstr_base >> ((j - 1) * 8)) & 0xff)
                    end
                    break
                end
            end
        end
    end
    
    # Update PLTGOT entry with actual GOT base address (similar to DT_STRTAB update)
    if !isempty(linker.got.entries) && !isempty(linker.dynamic_section.entries)
        # Find the dynamic section memory region  
        dynamic_region = nothing
        for region in linker.memory_regions
            if region.permissions == 0x4 && length(region.data) == length(linker.dynamic_section.entries) * 16
                dynamic_region = region
                break
            end
        end
        
        if dynamic_region !== nothing
            # Update DT_PLTGOT entry with actual GOT base address
            for i in 1:length(linker.dynamic_section.entries)
                if linker.dynamic_section.entries[i].tag == DT_PLTGOT
                    linker.dynamic_section.entries[i] = DynamicEntry(DT_PLTGOT, linker.got.base_address)
                    # Also update the serialized data
                    offset = (i - 1) * 16 + 8  # Skip to value field
                    for j in 1:8
                        dynamic_region.data[offset + j] = UInt8((linker.got.base_address >> ((j - 1) * 8)) & 0xff)
                    end
                    break
                end
            end
        end
    end
    
    # Update final next_address
    linker.next_address = alpha_current
    
    # Update symbol addresses to be absolute
    update_symbol_addresses!(linker, linker.section_address_map)
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

Mathematical model: ∀r ∈ Relocations: apply_relocation(r, linker_state)
Perform relocations for all loaded objects using enhanced relocation engine.
"""
function perform_relocations!(linker::DynamicLinker)
    for elf_file in linker.loaded_objects
        for relocation in elf_file.relocations
            # Skip relocations for debug sections or other non-allocatable sections
            # Check if the target section is allocatable by looking in our section address map
            section_key = (elf_file.filename, relocation.target_section_index)
            
            if !haskey(linker.section_address_map, section_key)
                # Target section was not allocated (probably debug section) - skip relocation
                continue
            end
            
            # Convert section-relative offset to virtual address
            virtual_offset = get_relocation_virtual_address(linker, elf_file, relocation)
            
            # Create a virtual relocation with the correct virtual address
            virtual_relocation = RelocationEntry(
                virtual_offset,
                relocation.info,
                relocation.addend,
                relocation.target_section_index
            )
            
            if !apply_relocation!(linker.relocation_dispatcher, virtual_relocation, linker)
                error("Failed to apply relocation of type $(elf64_r_type(relocation.info))")
            end
        end
    end
end

"""
    get_relocation_virtual_address(linker::DynamicLinker, elf_file::ElfFile, relocation::RelocationEntry) -> UInt64

Convert a section-relative relocation offset to a virtual address.
"""
function get_relocation_virtual_address(linker::DynamicLinker, elf_file::ElfFile, relocation::RelocationEntry)
    # Find the virtual address of the target section
    section_key = (elf_file.filename, relocation.target_section_index)
    
    if haskey(linker.section_address_map, section_key)
        section_base_address = linker.section_address_map[section_key]
        return section_base_address + relocation.offset
    else
        # Fallback for sections not in the map (might be absolute address)
        @warn "Could not find section mapping for relocation in $(elf_file.filename), section $(relocation.target_section_index)"
        return relocation.offset
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
    # Detect if we'll need dynamic linking (PIE mode)
    pie_mode = enable_system_libraries || !isempty(library_names)
    
    # Create linker with appropriate mode
    linker = if pie_mode
        DynamicLinker(pie_mode=true)  # Use PIE-compatible addresses
    else
        DynamicLinker(base_address)   # Use specified base address
    end
    
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
    
    # Setup dynamic linking infrastructure (GOT/PLT) for external symbols
    dynamic_symbols = setup_dynamic_linking!(linker)
    
    # Setup dynamic section with required library information
    # Always create dynamic section when linking with system libraries or when library names specified
    if !isempty(dynamic_symbols) || !isempty(library_names) || enable_system_libraries
        println("Setting up dynamic section with $(length(dynamic_symbols)) dynamic symbols and $(length(library_names)) library names")
        setup_dynamic_section!(linker, library_names)
    end
    
    # Allocate memory regions (now includes GOT/PLT/Dynamic section if created)
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
            
            # Get updated main address after injection
            updated_main_address = linker.global_symbol_table[entry_symbol].value
            
            println("Entry point set to synthetic '_start' at 0x$(string(entry_point, base=16))")
            println("  → Will call '$entry_symbol' at 0x$(string(updated_main_address, base=16))")
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

"""
    create_got!(linker::DynamicLinker, symbols::Vector{String}) -> Nothing

Mathematical model: GOT creation for dynamic symbols
Creates Global Offset Table for runtime symbol resolution.

GOT structure:
```math
GOT = {(s_i, addr_i)}_{i=1}^n \\text{ where } s_i \\in \\text{dynamic_symbols}
```
"""
function create_got!(linker::DynamicLinker, dynamic_symbols::Vector{String})
    if isempty(dynamic_symbols)
        return  # No dynamic symbols, no GOT needed
    end
    
    # Add symbols to the existing enhanced GOT structure
    for (i, symbol) in enumerate(dynamic_symbols)
        # Add entry to GOT (entries are indices, base address set later)
        push!(linker.got.entries, 0x0)  # Will be resolved at runtime
        linker.got.symbol_indices[symbol] = length(linker.got.entries)
    end
    
    println("Prepared GOT with $(length(dynamic_symbols)) entries ($(length(linker.got.entries) * 8) bytes)")
end

"""
    create_plt!(linker::DynamicLinker, dynamic_symbols::Vector{String}) -> Nothing

Mathematical model: PLT creation for lazy symbol resolution
Creates Procedure Linkage Table for dynamic symbol resolution.

PLT structure per entry (x86-64):
```asm
jmp *GOT[n]     # 6 bytes
push \$index     # 5 bytes  
jmp PLT[0]      # 5 bytes (16 bytes total per entry)
```
"""
function create_plt!(linker::DynamicLinker, dynamic_symbols::Vector{String})
    if isempty(dynamic_symbols)
        return  # No dynamic symbols, no PLT needed
    end
    
    # Add symbols to the existing enhanced PLT structure
    for (i, symbol) in enumerate(dynamic_symbols)
        # Create PLT entry for this symbol
        got_index = get(linker.got.symbol_indices, symbol, 0)
        if got_index == 0
            @warn "Symbol $symbol not found in GOT, skipping PLT entry"
            continue
        end
        
        got_offset = UInt32(got_index * 8)  # Each GOT entry is 8 bytes  
        reloc_index = UInt32(i - 1)  # 0-based relocation index
        
        # Create PLT entry with proper x86-64 code
        plt_entry = create_plt_entry(got_offset, reloc_index)
        push!(linker.plt.entries, plt_entry.code)
        linker.plt.symbol_indices[symbol] = length(linker.plt.entries)
    end
    
    println("Prepared PLT with $(length(dynamic_symbols)) entries ($(length(linker.plt.entries) * 16) bytes)")
end

"""
    setup_dynamic_linking!(linker::DynamicLinker) -> Vector{String}

Mathematical model: Dynamic linking infrastructure setup
Identifies dynamic symbols and creates GOT/PLT infrastructure.

Returns: List of symbols requiring dynamic resolution
"""
function setup_dynamic_linking!(linker::DynamicLinker)
    # Find symbols that need dynamic resolution (external/undefined symbols)
    dynamic_symbols = String[]
    
    for (symbol_name, symbol) in linker.global_symbol_table
        # Symbols resolved against system libraries need dynamic resolution
        if symbol.defined && startswith(symbol.source_file, "GLIBC:") || 
           startswith(symbol.source_file, "MUSL:")
            push!(dynamic_symbols, symbol_name)
        end
    end
    
    if !isempty(dynamic_symbols)
        println("Setting up dynamic linking for $(length(dynamic_symbols)) symbols: $(dynamic_symbols)")
        create_got!(linker, dynamic_symbols)
        create_plt!(linker, dynamic_symbols)
    end
    
    return dynamic_symbols
end

"""
    setup_dynamic_section!(linker::DynamicLinker, required_libraries::Vector{String})

Mathematical model: generate_dynamic_metadata: LinkerState → DynamicSection
Generate .dynamic section entries for runtime linking information.
"""
function setup_dynamic_section!(linker::DynamicLinker, required_libraries::Vector{String} = String[])
    # Add required library dependencies
    for lib in required_libraries
        add_needed_library!(linker.dynamic_section, lib)
    end
    
    # Add standard C library if not explicitly specified and system libraries are enabled
    if !any(lib -> contains(lib, "libc"), required_libraries)
        add_needed_library!(linker.dynamic_section, "libc.so.6")
    end
    
    # Finalize the dynamic section with all required entries
    finalize_dynamic_section!(linker.dynamic_section, linker)
    
    println("Generated dynamic section with $(length(linker.dynamic_section.entries)) entries")
end