# ELF Format Structures
# Based on the ELF specification for educational purposes

using Printf

# ELF Header structure
struct ElfHeader
    magic::NTuple{4, UInt8}        # ELF magic number (0x7f, 'E', 'L', 'F')
    class::UInt8                   # File class (32-bit or 64-bit)
    data::UInt8                    # Data encoding (little or big endian)
    version::UInt8                 # ELF version
    osabi::UInt8                   # OS/ABI identification
    abiversion::UInt8              # ABI version
    pad::NTuple{7, UInt8}          # Padding bytes
    type::UInt16                   # Object file type (ET_REL, ET_EXEC, ET_DYN, etc.)
    machine::UInt16                # Machine type (EM_X86_64, etc.)
    version2::UInt32               # Object file version
    entry::UInt64                  # Entry point virtual address
    phoff::UInt64                  # Program header table file offset
    shoff::UInt64                  # Section header table file offset
    flags::UInt32                  # Processor-specific flags
    ehsize::UInt16                 # ELF header size in bytes
    phentsize::UInt16              # Program header table entry size
    phnum::UInt16                  # Program header table entry count
    shentsize::UInt16              # Section header table entry size
    shnum::UInt16                  # Section header table entry count
    shstrndx::UInt16               # Section header string table index
end

# Section Header structure (64-bit)
struct SectionHeader
    name::UInt32                   # Section name (string table index)
    type::UInt32                   # Section type
    flags::UInt64                  # Section flags
    addr::UInt64                   # Section virtual address at execution
    offset::UInt64                 # Section file offset
    size::UInt64                   # Section size in bytes
    link::UInt32                   # Link to another section
    info::UInt32                   # Additional section information
    addralign::UInt64              # Section alignment
    entsize::UInt64                # Entry size if section holds table
end

# Symbol Table Entry structure (64-bit)
struct SymbolTableEntry
    name::UInt32                   # Symbol name (string table index)
    info::UInt8                    # Symbol type and binding
    other::UInt8                   # Symbol visibility
    shndx::UInt16                  # Section index
    value::UInt64                  # Symbol value
    size::UInt64                   # Symbol size
end

# Relocation Entry with addend (64-bit)
struct RelocationEntry
    offset::UInt64                 # Location at which to apply the action
    info::UInt64                   # Relocation type and symbol index
    addend::Int64                  # Addend used to compute value
end

# Program Header structure (64-bit)
struct ProgramHeader
    type::UInt32                   # Segment type
    flags::UInt32                  # Segment flags
    offset::UInt64                 # Segment file offset
    vaddr::UInt64                  # Segment virtual address
    paddr::UInt64                  # Segment physical address
    filesz::UInt64                 # Segment size in file
    memsz::UInt64                  # Segment size in memory
    align::UInt64                  # Segment alignment
end

# ELF constants
const ELF_MAGIC = (0x7f, UInt8('E'), UInt8('L'), UInt8('F'))
const ELFCLASS64 = 2
const ELFDATA2LSB = 1  # Little endian
const EV_CURRENT = 1   # Current version

# OS/ABI types
const ELFOSABI_SYSV = 0    # UNIX System V ABI
const ELFOSABI_GNU = 3     # GNU/Linux ABI

# Object file types
const ET_NONE = 0      # No file type
const ET_REL = 1       # Relocatable file
const ET_EXEC = 2      # Executable file
const ET_DYN = 3       # Shared object file
const ET_CORE = 4      # Core file

# Machine types
const EM_X86_64 = 62   # AMD x86-64 architecture

# Section types
const SHT_NULL = 0     # Section header table entry unused
const SHT_PROGBITS = 1 # Program data
const SHT_SYMTAB = 2   # Symbol table
const SHT_STRTAB = 3   # String table
const SHT_RELA = 4     # Relocation entries with addends
const SHT_HASH = 5     # Symbol hash table
const SHT_DYNAMIC = 6  # Dynamic linking information
const SHT_NOTE = 7     # Notes
const SHT_NOBITS = 8   # Program space with no data (bss)
const SHT_REL = 9      # Relocation entries, no addends
const SHT_SHLIB = 10   # Reserved
const SHT_DYNSYM = 11  # Dynamic linker symbol table

# Section flags
const SHF_WRITE = 0x1      # Writable
const SHF_ALLOC = 0x2      # Occupies memory during execution
const SHF_EXECINSTR = 0x4  # Executable

# Symbol binding
const STB_LOCAL = 0    # Local scope
const STB_GLOBAL = 1   # Global scope
const STB_WEAK = 2     # Weak global scope

# Symbol types
const STT_NOTYPE = 0   # Symbol type is unspecified
const STT_OBJECT = 1   # Symbol is a data object
const STT_FUNC = 2     # Symbol is a code object
const STT_SECTION = 3  # Symbol associated with a section
const STT_FILE = 4     # Symbol's name is file name

# Program header types
const PT_NULL = 0           # Unused entry
const PT_LOAD = 1           # Loadable segment
const PT_DYNAMIC = 2        # Dynamic linking information
const PT_INTERP = 3         # Interpreter information
const PT_NOTE = 4           # Note information
const PT_SHLIB = 5          # Reserved
const PT_PHDR = 6           # Program header table
const PT_TLS = 7            # Thread-local storage
const PT_GNU_STACK = 0x6474e551  # GNU stack permissions

# Program header flags
const PF_X = 0x1            # Execute
const PF_W = 0x2            # Write
const PF_R = 0x4            # Read

# Complete x86-64 Relocation Types (ELF Specification Compliant)
# Mathematical model: ℛ = {R_X86_64_i}_{i=0}^{37} where each defines address computation
const R_X86_64_NONE = 0      # No relocation
const R_X86_64_64 = 1        # Direct 64 bit: S + A  
const R_X86_64_PC32 = 2      # PC relative 32 bit signed: S + A - P
const R_X86_64_GOT32 = 3     # 32 bit GOT entry: G + A
const R_X86_64_PLT32 = 4     # 32 bit PLT address: L + A - P  
const R_X86_64_COPY = 5      # Copy symbol at runtime: none
const R_X86_64_GLOB_DAT = 6  # Create GOT entry: S
const R_X86_64_JUMP_SLOT = 7 # Create PLT entry: S
const R_X86_64_RELATIVE = 8  # Adjust by program base: B + A
const R_X86_64_GOTPCREL = 9  # 32 bit signed PC relative offset to GOT: G + GOT + A - P
const R_X86_64_32 = 10       # Direct 32 bit zero extended: S + A  
const R_X86_64_32S = 11      # Direct 32 bit sign extended: S + A
const R_X86_64_16 = 12       # Direct 16 bit zero extended: S + A
const R_X86_64_PC16 = 13     # 16 bit sign extended PC relative: S + A - P
const R_X86_64_8 = 14        # Direct 8 bit sign extended: S + A
const R_X86_64_PC8 = 15      # 8 bit sign extended PC relative: S + A - P
const R_X86_64_DTPMOD64 = 16 # ID of module containing symbol
const R_X86_64_DTPOFF64 = 17 # Offset in module's TLS block  
const R_X86_64_TPOFF64 = 18  # Offset in initial TLS block
const R_X86_64_TLSGD = 19    # 32 bit signed PC relative offset to GD GOT entry
const R_X86_64_TLSLD = 20    # 32 bit signed PC relative offset to LD GOT entry
const R_X86_64_DTPOFF32 = 21 # Offset in TLS block: S + A
const R_X86_64_GOTTPOFF = 22 # 32 bit signed PC relative offset to IE GOT entry  
const R_X86_64_TPOFF32 = 23  # Offset in initial TLS block: S + A
const R_X86_64_PC64 = 24     # PC relative 64 bit: S + A - P
const R_X86_64_GOTOFF64 = 25 # 64 bit offset to GOT: S + A - GOT
const R_X86_64_GOTPC32 = 26  # 32 bit signed PC relative offset to GOT: GOT + A - P
const R_X86_64_GOT64 = 27    # 64-bit GOT entry offset: G + A
const R_X86_64_GOTPCREL64 = 28 # 64-bit PC relative offset to GOT entry: G + GOT + A - P
const R_X86_64_GOTPC64 = 29  # 64-bit PC relative offset to GOT: GOT + A - P
const R_X86_64_GOTPLT64 = 30 # 64-bit GOT relative offset to PLT entry: G + A
const R_X86_64_PLTOFF64 = 31 # 64-bit PLT relative offset: L + A - PLT
const R_X86_64_SIZE32 = 32   # Size of symbol plus 32-bit addend: Z + A
const R_X86_64_SIZE64 = 33   # Size of symbol plus 64-bit addend: Z + A  
const R_X86_64_GOTPC32_TLSDESC = 34 # GOT offset for TLS descriptor: G + A
const R_X86_64_TLSDESC_CALL = 35    # TLS descriptor call
const R_X86_64_TLSDESC = 36  # TLS descriptor: S
const R_X86_64_IRELATIVE = 37 # Indirect relative: B + A

# Dynamic Section Entry Types (DT_* constants)
# Mathematical model: DynamicEntry = (tag, value) where tag ∈ DT_*
const DT_NULL = 0          # End of dynamic array
const DT_NEEDED = 1        # Name of needed library  
const DT_PLTRELSZ = 2      # Size in bytes of PLT relocations
const DT_PLTGOT = 3        # Address of PLT/GOT
const DT_HASH = 4          # Address of symbol hash table
const DT_STRTAB = 5        # Address of string table
const DT_SYMTAB = 6        # Address of symbol table
const DT_RELA = 7          # Address of Rela relocations
const DT_RELASZ = 8        # Total size of Rela relocations
const DT_RELAENT = 9       # Size of one Rela relocation
const DT_STRSZ = 10        # Size of string table
const DT_SYMENT = 11       # Size of one symbol table entry
const DT_INIT = 12         # Address of init function
const DT_FINI = 13         # Address of fini function
const DT_SONAME = 14       # Name of shared object
const DT_RPATH = 15        # Library search path (deprecated)
const DT_SYMBOLIC = 16     # Symbolic resolution flag
const DT_REL = 17          # Address of Rel relocations
const DT_RELSZ = 18        # Total size of Rel relocations
const DT_RELENT = 19       # Size of one Rel relocation
const DT_PLTREL = 20       # Type of relocation in PLT
const DT_DEBUG = 21        # Debug information
const DT_TEXTREL = 22      # Text relocations flag
const DT_JMPREL = 23       # Address of PLT relocations
const DT_BIND_NOW = 24     # Process relocations at program start
const DT_INIT_ARRAY = 25   # Array with addresses of init functions
const DT_FINI_ARRAY = 26   # Array with addresses of fini functions
const DT_INIT_ARRAYSZ = 27 # Size in bytes of DT_INIT_ARRAY
const DT_FINI_ARRAYSZ = 28 # Size in bytes of DT_FINI_ARRAY
const DT_RUNPATH = 29      # Library search path
const DT_FLAGS = 30        # Flags for object being loaded
const DT_ENCODING = 32     # Start of encoded range
const DT_PREINIT_ARRAY = 32     # Array with addresses of preinit functions
const DT_PREINIT_ARRAYSZ = 33   # Size in bytes of DT_PREINIT_ARRAY
const DT_MAXPOSTAGS = 34   # End of range using d_val

# GNU extensions
const DT_GNU_HASH = 0x6ffffef5      # GNU-style hash table
const DT_VERSYM = 0x6ffffff0        # Version symbol table
const DT_RELACOUNT = 0x6ffffff9     # Count of RELATIVE relocations
const DT_RELCOUNT = 0x6ffffffa      # Count of RELATIVE relocations
const DT_FLAGS_1 = 0x6ffffffb       # Extended flags
const DT_VERDEF = 0x6ffffffc        # Version definition table
const DT_VERDEFNUM = 0x6ffffffd     # Number of version definitions
const DT_VERNEED = 0x6ffffffe       # Version dependency table
const DT_VERNEEDNUM = 0x6fffffff    # Number of version dependencies

# Dynamic Section Entry structure (64-bit)
struct DynamicEntry
    tag::UInt64        # Entry type (DT_*)
    value::UInt64      # Value or address
end

"""
    DynamicSection

Mathematical model: 𝒟 = {(tag_i, value_i)}_{i=0}^{n-1} ∪ {(DT_NULL, 0)}  
Represents the .dynamic section containing runtime linking information.
"""
mutable struct DynamicSection
    entries::Vector{DynamicEntry}           # Dynamic entries
    string_table::Vector{UInt8}             # Dynamic string table (.dynstr)
    string_offsets::Dict{String, UInt32}    # String → offset mapping
    
    function DynamicSection()
        new(DynamicEntry[], UInt8[], Dict{String, UInt32}())
    end
end

"""
    add_needed_library!(dynamic::DynamicSection, library_name::String)

Mathematical model: add_dependency: (𝒟, library) → 𝒟'
Add a DT_NEEDED entry for a required library.
"""
function add_needed_library!(dynamic::DynamicSection, library_name::String)
    # Add string to dynamic string table
    offset = add_dynamic_string!(dynamic, library_name)
    
    # Add DT_NEEDED entry
    entry = DynamicEntry(DT_NEEDED, UInt64(offset))
    push!(dynamic.entries, entry)
end

"""
    add_dynamic_string!(dynamic::DynamicSection, str::String) → UInt32

Add string to dynamic string table and return offset.
"""
function add_dynamic_string!(dynamic::DynamicSection, str::String)
    if haskey(dynamic.string_offsets, str)
        return dynamic.string_offsets[str]
    end
    
    # Add string at current end of table
    offset = UInt32(length(dynamic.string_table))
    
    # Append string bytes plus null terminator
    append!(dynamic.string_table, Vector{UInt8}(str))
    push!(dynamic.string_table, 0x00)  # null terminator
    
    dynamic.string_offsets[str] = offset
    return offset
end

"""
    finalize_dynamic_section!(dynamic::DynamicSection, linker) 

Mathematical model: finalize: 𝒟 → 𝒟_complete
Complete the dynamic section by adding all required entries and NULL terminator.
"""
function finalize_dynamic_section!(dynamic::DynamicSection, linker)
    # Add essential dynamic entries based on linker state
    
    # String table
    if !isempty(dynamic.string_table)
        push!(dynamic.entries, DynamicEntry(DT_STRTAB, 0x0))  # Address filled later
        push!(dynamic.entries, DynamicEntry(DT_STRSZ, UInt64(length(dynamic.string_table))))
    end
    
    # Symbol table - will be implemented when we add dynamic symbol support
    # push!(dynamic.entries, DynamicEntry(DT_SYMTAB, get_dynsym_address(linker)))
    # push!(dynamic.entries, DynamicEntry(DT_SYMENT, UInt64(sizeof(SymbolTableEntry))))
    
    # Relocations - will be implemented with enhanced relocation output
    # if !isempty(linker.relocations)
    #     push!(dynamic.entries, DynamicEntry(DT_RELA, get_rela_address(linker)))
    #     push!(dynamic.entries, DynamicEntry(DT_RELASZ, get_rela_size(linker)))
    #     push!(dynamic.entries, DynamicEntry(DT_RELAENT, UInt64(sizeof(RelocationEntry))))
    # end
    
    # PLT relocations
    if !isempty(linker.plt.entries)
        push!(dynamic.entries, DynamicEntry(DT_PLTGOT, linker.got.base_address))
        # PLT relocation details will be filled when PLT relocations are implemented
        # push!(dynamic.entries, DynamicEntry(DT_PLTRELSZ, get_plt_reloc_size(linker)))
        # push!(dynamic.entries, DynamicEntry(DT_PLTREL, UInt64(DT_RELA)))
        # push!(dynamic.entries, DynamicEntry(DT_JMPREL, get_plt_reloc_address(linker)))
    end
    
    # Terminator - must be last
    push!(dynamic.entries, DynamicEntry(DT_NULL, 0))
end

# Helper functions for symbol info
st_bind(info::UInt8) = (info >> 4) & 0xf
st_type(info::UInt8) = info & 0xf
st_info(bind::UInt8, type::UInt8) = (bind << 4) | (type & 0xf)

# Helper functions for relocation info
elf64_r_sym(info::UInt64) = info >> 32
elf64_r_type(info::UInt64) = info & 0xffffffff
elf64_r_info(sym::UInt32, type::UInt32) = (UInt64(sym) << 32) | UInt64(type)

# Enhanced Dynamic Linking Structures
# Mathematical model: GOT = {GOT[i]}_{i=0}^{n-1} where GOT[i] ∈ ℕ₆₄

"""
    GlobalOffsetTable (GOT)

Mathematical model: 𝒢 = {g_i}_{i=0}^{n-1} where g_i ∈ ℕ₆₄
Manages runtime symbol address resolution for dynamic linking.
"""
mutable struct GlobalOffsetTable
    entries::Vector{UInt64}        # GOT entries: symbol addresses or PLT resolver
    symbol_indices::Dict{String, Int} # Symbol name → GOT index mapping
    base_address::UInt64           # GOT virtual memory address
    
    function GlobalOffsetTable(base_address::UInt64 = 0x0)
        # GOT[0] is reserved for dynamic linker information
        new([0x0], Dict{String, Int}(), base_address)
    end
end

"""
    ProcedureLinkageTable (PLT)

Mathematical model: 𝒫 = {p_i}_{i=0}^{n-1} where p_i = {jmp_code, push_code, resolver_code}
Enables lazy binding for dynamic function calls.
"""
mutable struct ProcedureLinkageTable  
    entries::Vector{Vector{UInt8}}     # PLT entry machine code (16 bytes each)
    symbol_indices::Dict{String, Int}  # Symbol name → PLT index mapping  
    base_address::UInt64              # PLT virtual memory address
    entry_size::UInt32                # Size per PLT entry (typically 16)
    
    function ProcedureLinkageTable(base_address::UInt64 = 0x0)
        # PLT[0] is the resolver entry that calls dynamic linker
        resolver_entry = create_plt_resolver_entry()
        new([resolver_entry], Dict{String, Int}(), base_address, 16)
    end
end

"""
    PLTEntry

Mathematical model: PLT[i] = (jmp_instruction, push_instruction, jmp_resolver)
Represents a single PLT entry with x86-64 machine code.
"""
struct PLTEntry
    code::Vector{UInt8}      # 16 bytes of x86-64 PLT stub code
    got_offset::UInt32       # Offset into GOT for this symbol
    reloc_index::UInt32      # Index for relocation processing
end

"""
    create_plt_resolver_entry() → Vector{UInt8}

Mathematical model: PLT[0] = resolver_code
Creates the PLT[0] resolver entry that interfaces with dynamic linker.
"""
function create_plt_resolver_entry()
    # x86-64 PLT resolver stub (16 bytes)
    # This will be called by other PLT entries to resolve symbols
    code = UInt8[
        # push GOT[1] (link_map)
        0xff, 0x35, 0x00, 0x00, 0x00, 0x00,  # 6 bytes: push offset to GOT[1]
        # jmp *GOT[2] (dl_runtime_resolve)  
        0xff, 0x25, 0x00, 0x00, 0x00, 0x00,  # 6 bytes: jmp to GOT[2]
        # padding
        0x90, 0x90, 0x90, 0x90               # 4 bytes: nop padding
    ]
    return code
end

"""
    create_plt_entry(got_offset::UInt32, reloc_index::UInt32) → PLTEntry

Mathematical model: PLT[i] = f(GOT_offset_i, reloc_index_i) 
Creates a PLT entry for symbol with given GOT offset and relocation index.
"""
function create_plt_entry(got_offset::UInt32, reloc_index::UInt32)
    # Standard x86-64 PLT entry (16 bytes)
    code = UInt8[]
    
    # jmp *got_offset(%rip) - 6 bytes  
    append!(code, [0xff, 0x25])  # jmp *offset(%rip)
    append!(code, reinterpret(UInt8, [got_offset]))  # 4-byte offset
    
    # push reloc_index - 5 bytes
    push!(code, 0x68)  # push imm32
    append!(code, reinterpret(UInt8, [reloc_index]))  # 4-byte index
    
    # jmp PLT[0] - 5 bytes  
    push!(code, 0xe9)  # jmp rel32
    append!(code, [0x00, 0x00, 0x00, 0x00])  # will be patched with relative offset
    
    return PLTEntry(code, got_offset, reloc_index)
end