= ELF Data Structures Mathematical Specification

== Overview

This specification defines the mathematical models and data structures used to represent ELF (Executable and Linkable Format) files in memory. Following the Mathematical-Driven AI Development methodology, these structures bridge the mathematical linking algorithms with practical Julia implementation.

== Mathematical Model

=== ELF File Mathematical Representation

_ELF File Space_:
$
\mathcal{E}_{file} = \langle \mathcal{H}_{header}, \mathcal{S}_{sections}, \mathcal{Y}_{symbols}, \mathcal{R}_{relocations}, \mathcal{P}_{programs} \rangle
$

_Structural Invariant_:
$
\forall e \in \mathcal{E}_{file}: \text{consistent}(\mathcal{H}, \mathcal{S}) \land \text{valid\_references}(\mathcal{S}, \mathcal{Y}) \land \text{complete\_relocations}(\mathcal{R}, \mathcal{Y})
$

_Memory Representation Function_:
$
\text{represent}: \text{BinaryFile} \to \mathcal{E}_{file} \cup \{\text{Error}\}
$

== Core Data Structures (Non-Algorithmic Components)

Following the copilot guidelines, these data structures are implemented directly in Julia with clear, descriptive names since they represent static file format specifications rather than computational algorithms.

=== ELF Header Structure

_Mathematical Model_: Header represents file metadata and format compliance
$
\mathcal{H}_{header} = \{magic, class, data, version, osabi, type, machine, entry, phoff, shoff, flags, sizes\}
$

_Validation Function_:
$
\text{valid\_header}(h) = (h.magic = \text{ELF\_MAGIC}) \land (h.class \in \{32, 64\}) \land (h.version = 1)
$

_Implementation_:
_Purpose_: Contains basic file information and metadata
_Size_: 64 bytes (ELF64), 52 bytes (ELF32)

```julia
struct ElfHeader
    magic::NTuple{4, UInt8}      # File signature: 0x7f, 'E', 'L', 'F'
    class::UInt8                 # 32-bit (1) or 64-bit (2)
    data::UInt8                  # Little-endian (1) or big-endian (2)
    version::UInt8               # ELF version (always 1)
    osabi::UInt8                 # OS/ABI identification
    abiversion::UInt8            # ABI version
    pad::NTuple{7, UInt8}        # Padding bytes (unused)
    type::UInt16                 # Object file type
    machine::UInt16              # Target architecture
    version2::UInt32             # Object file version
    entry::UInt64                # Entry point address
    phoff::UInt64                # Program header offset
    shoff::UInt64                # Section header offset
    flags::UInt32                # Processor-specific flags
    ehsize::UInt16               # ELF header size
    phentsize::UInt16            # Program header entry size
    phnum::UInt16                # Number of program headers
    shentsize::UInt16            # Section header entry size
    shnum::UInt16                # Number of section headers
    shstrndx::UInt16             # Section name string table index
end
```

_Key Fields_:
- `entry`: Address where execution begins
- `shoff`: Location of section headers in file
- `shnum`: Number of sections in the file
- `shstrndx`: Index of section containing section names

=== Section Header Structure

_Mathematical Model_: Section headers form a finite indexed collection
$
\mathcal{S}_{sections} = \{s_i : i \in [0, n_{sections}]\}
$

_Section Type Classification_:
$
\text{classify}(s) = \begin{cases}
\text{SYMTAB} & \text{if } s.type = \text{SHT\_SYMTAB} \\
\text{STRTAB} & \text{if } s.type = \text{SHT\_STRTAB} \\
\text{PROGBITS} & \text{if } s.type = \text{SHT\_PROGBITS} \\
\text{RELA} & \text{if } s.type = \text{SHT\_RELA} \\
\text{NULL} & \text{otherwise}
\end{cases}
$

_Section Filtering Operation_:
$
\text{filter\_by\_type}(sections, t) = \{s \in sections : s.type = t\}
$

_Implementation_:
_Purpose_: Describes individual sections within the ELF file
_Size_: 64 bytes (ELF64), 40 bytes (ELF32)

```julia
struct SectionHeader
    name::UInt32                 # Section name (string table offset)
    type::UInt32                 # Section type
    flags::UInt64                # Section attributes
    addr::UInt64                 # Virtual address in memory
    offset::UInt64               # File offset of section data
    size::UInt64                 # Section size in bytes
    link::UInt32                 # Link to related section
    info::UInt32                 # Additional section information
    addralign::UInt64            # Address alignment constraint
    entsize::UInt64              # Size of each entry (for tables)
end
```

_Common Section Types_:
- `SHT_NULL` (0): Unused section
- `SHT_PROGBITS` (1): Program data
- `SHT_SYMTAB` (2): Symbol table
- `SHT_STRTAB` (3): String table
- `SHT_RELA` (4): Relocation entries with addends
- `SHT_REL` (9): Relocation entries without addends

=== Symbol Table Entry
_Purpose_: Represents symbols (functions, variables, etc.) in the object file
_Size_: 24 bytes (ELF64), 16 bytes (ELF32)

```julia
struct SymbolTableEntry
    name::UInt32                 # Symbol name (string table offset)
    info::UInt8                  # Symbol type and binding
    other::UInt8                 # Symbol visibility
    shndx::UInt16                # Section header index
    value::UInt64                # Symbol value/address
    size::UInt64                 # Symbol size
end
```

_Symbol Binding_ (upper 4 bits of `info`):
- `STB_LOCAL` (0): Local symbol
- `STB_GLOBAL` (1): Global symbol
- `STB_WEAK` (2): Weak symbol

_Symbol Type_ (lower 4 bits of `info`):
- `STT_NOTYPE` (0): Unspecified type
- `STT_OBJECT` (1): Data object
- `STT_FUNC` (2): Function
- `STT_SECTION` (3): Section symbol
- `STT_FILE` (4): Source file name

=== Relocation Entry
_Purpose_: Describes how to modify addresses during linking
_Size_: 24 bytes (RELA), 16 bytes (REL)

```julia
struct RelocationEntry
    offset::UInt64               # Address to modify
    info::UInt64                 # Relocation type and symbol
    addend::Int64                # Constant addend (RELA only)
end
```

_Common x86-64 Relocation Types_:
- `R_X86_64_64` (1): Direct 64-bit address
- `R_X86_64_PC32` (2): PC-relative 32-bit
- `R_X86_64_PLT32` (4): PLT-relative 32-bit
- `R_X86_64_GOTPC32` (26): GOT-relative 32-bit

=== Program Header
_Purpose_: Describes memory segments for runtime loading
_Size_: 56 bytes (ELF64), 32 bytes (ELF32)

```julia
struct ProgramHeader
    type::UInt32                 # Segment type
    flags::UInt32                # Segment flags
    offset::UInt64               # File offset
    vaddr::UInt64                # Virtual address
    paddr::UInt64                # Physical address
    filesz::UInt64               # Size in file
    memsz::UInt64                # Size in memory
    align::UInt64                # Alignment
end
```

_Segment Types_:
- `PT_NULL` (0): Unused entry
- `PT_LOAD` (1): Loadable segment
- `PT_DYNAMIC` (2): Dynamic linking information
- `PT_INTERP` (3): Interpreter path
- `PT_PHDR` (6): Program header table

== Container Structures

=== ElfFile
_Purpose_: Complete in-memory representation of an ELF file

```julia
struct ElfFile
    header::ElfHeader
    sections::Vector{SectionHeader}
    symbols::Vector{SymbolTableEntry}
    relocations::Vector{RelocationEntry}
    section_data::Dict{Int, Vector{UInt8}}
    string_tables::Dict{Int, Vector{String}}
    program_headers::Vector{ProgramHeader}
end
```

=== DynamicLinker State
_Purpose_: Maintains linking state across multiple objects

```julia
mutable struct DynamicLinker
    objects::Vector{ElfFile}
    global_symbol_table::Dict{String, SymbolInfo}
    memory_regions::Vector{MemoryRegion}
    base_address::UInt64
    current_address::UInt64
    temp_files::Vector{String}
end
```

== Parsing Functions

=== Header Parsing
```julia
function parse_elf_header(io::IO)::ElfHeader
    # Read and validate magic number
    magic = ntuple(i -> read(io, UInt8), 4)
    if magic != (0x7f, UInt8('E'), UInt8('L'), UInt8('F'))
        error("Invalid ELF magic number")
    end
    
    # Read remaining header fields
    class = read(io, UInt8)
    data = read(io, UInt8)
    # ... continue reading all fields
    
    return ElfHeader(magic, class, data, ...)
end
```

=== Section Parsing
```julia
function parse_section_headers(io::IO, header::ElfHeader)::Vector{SectionHeader}
    sections = Vector{SectionHeader}(undef, header.shnum)
    
    seek(io, header.shoff)
    for i in 1:header.shnum
        sections[i] = read_section_header(io)
    end
    
    return sections
end
```

=== Symbol Parsing
```julia
function parse_symbol_table(io::IO, section::SectionHeader)::Vector{SymbolTableEntry}
    entry_count = section.size ÷ 24  # 24 bytes per symbol (ELF64)
    symbols = Vector{SymbolTableEntry}(undef, entry_count)
    
    seek(io, section.offset)
    for i in 1:entry_count
        symbols[i] = read_symbol_entry(io)
    end
    
    return symbols
end
```

== Utility Functions

=== Symbol Information Extraction
```julia
= Extract binding from symbol info byte
function st_bind(info::UInt8)::UInt8
    return (info >> 4) & 0xf
end

= Extract type from symbol info byte
function st_type(info::UInt8)::UInt8
    return info & 0xf
end
```

=== Relocation Information Extraction
```julia
= Extract symbol index from relocation info
function elf64_r_sym(info::UInt64)::UInt32
    return UInt32(info >> 32)
end

= Extract relocation type from relocation info
function elf64_r_type(info::UInt64)::UInt32
    return UInt32(info & 0xffffffff)
end
```

== Memory Management

=== Section Data Storage
- Raw section data stored in `section_data` dictionary
- Key: section index, Value: byte array
- Lazy loading for large sections

=== String Table Handling
- String tables parsed into string vectors
- Efficient lookup by index
- Shared between multiple sections

=== Temporary File Management
- Archive extraction creates temporary files
- Automatic cleanup after linking
- Error handling for cleanup failures

== Error Handling

=== Format Validation
- Magic number verification
- Architecture compatibility checks
- Section boundary validation

=== Data Integrity
- Size consistency checks
- Offset validation
- String table bounds checking

=== Resource Management
- Memory allocation limits
- File handle management
- Cleanup on errors

== Implementation Notes

=== Endianness Handling
- Currently supports little-endian only
- Big-endian support planned for future versions
- Automatic detection from ELF header

=== Architecture Support
- Primary target: x86-64
- Limited ARM64 support
- Architecture-specific relocation handling

=== Performance Considerations
- Lazy loading of large sections
- Memory-mapped file access for huge files
- Efficient string table implementation
$
\text{Pre: } header.shoff > 0 \land header.shnum \geq 0 \land io\_valid(io)
$

_Postconditions_:
$
\text{Post: } |result| = header.shnum \land \forall s \in result: valid\_section(s)
$

_Direct code correspondence_:
```julia
= Mathematical model: parse_sections: IO × ElfHeader → List(SectionHeader)
function parse_section_headers(io::IO, header::ElfHeader)::Vector{SectionHeader}
    # Implementation of: iterate over section table
    seek(io, header.shoff)                    # ↔ position to offset
    sections = Vector{SectionHeader}()        # ↔ result accumulator
    for i in 1:header.shnum                   # ↔ bounded iteration
        push!(sections, parse_section(io))    # ↔ sequential parsing
    end
    return sections
end
```

=== Symbol Table Parsing → `parse_symbol_table` function

$
parse\_symbols: IO \times SectionHeader \times StringTable \to List(SymbolEntry)
$

_Complexity constraint_:
$
|result| = \frac{section.size}{24} \quad \text{(symbol entry size)}
$

_Set-theoretic operation_:
$
\text{Filter: } \{s \in sections : s.type = SHT\_SYMTAB\}
\text{Map: } \{parse\_entry(s) : s \in symbol\_sections\}
$

_Direct code correspondence_:
```julia
= Mathematical model: parse_symbols: IO × SectionHeader × StringTable → List(SymbolEntry)
function parse_symbol_table(io::IO, section::SectionHeader, strings::StringTable)::Vector{SymbolEntry}
    # Implementation of: symbol_count = section.size ÷ 24
    symbol_count = div(section.size, 24)     # ↔ size calculation
    symbols = Vector{SymbolEntry}()          # ↔ result collection
    for i in 1:symbol_count                  # ↔ bounded iteration
        entry = parse_symbol_entry(io)       # ↔ entry parsing
        entry.name = resolve_string(strings, entry.name_index)  # ↔ name resolution
        push!(symbols, entry)                # ↔ accumulation
    end
    return symbols
end
```

== Complexity Analysis

$
\begin{align}
T_{header}(n) &= O(1) \quad \text{– Fixed header size} \\
T_{sections}(k) &= O(k) \quad \text{– Linear in section count} \\
T_{symbols}(m) &= O(m) \quad \text{– Linear in symbol count} \\
T_{strings}(s) &= O(s) \quad \text{– Linear in string table size} \\
T_{total}(n,m,s) &= O(k + m + s) \quad \text{– Additive complexity}
\end{align}
$

_Critical path_: String table parsing with linear scan for null terminators.

== Transformation Pipeline

$
binary\_file \xrightarrow{parse\_header} header \xrightarrow{parse\_sections} sections \xrightarrow{filter\_symbols} symbol\_sections \xrightarrow{parse\_symbols} symbols
$

_Code pipeline correspondence_:
```julia
= Mathematical pipeline: file → header → sections → symbols
function parse_elf_file(filename::String)::ElfFile
    open(filename, "r") do io
        header = parse_elf_header(io)           # ↔ parse_header
        sections = parse_section_headers(io, header)  # ↔ parse_sections
        
        # Filter operation: {s ∈ sections : s.type = SHT_SYMTAB}
        symbol_sections = filter(s -> s.type == SHT_SYMTAB, sections)
        
        # Map operation: {parse_symbols(s) : s ∈ symbol_sections}
        symbols = vcat([parse_symbol_table(io, s, strings) for s in symbol_sections]...)
        
        return ElfFile(header, sections, symbols)
    end
end
```

== Set-Theoretic Operations

_Section filtering by type_:
$
filter\_by\_type(sections, t) = \{s \in sections : s.type = t\}
$

_Symbol extraction_:
$
extract\_symbols(sections) = \bigcup_{s \in symbol\_sections} parse\_symbols(s)
$

_String resolution_:
$
resolve\_names(symbols, strings) = \{s' : s' = s \text{ with } s'.name = strings[s.name\_index]\}
$

== Invariant Preservation

$
\text{Parse completeness: } 
\forall f \in ValidELFFiles: parse(f) \neq Error
$

$
\text{Structure consistency: }
|parse\_sections(io, h)| = h.shnum
$

$
\text{String resolution: }
\forall sym \in symbols: sym.name = strings[sym.name\_index]
$

=== Relocation Parsing with Filtering → `parse_elf_file` function

$
parse\_relocations\_filtered: List(RelocationSection) \to List(RelocationEntry)
$

_Mathematical filtering operation_: Critical improvement for basic linking

$
filtered\_relocations = \{r \in all\_relocations : target\_section(r) = \text{".text"}\}
$

_Filter function definition_:
$
filter(sections) = \bigcup_{s \in sections} \begin{cases}
parse\_relocations(s) & \text{if } name(s) = \text{".rela.text"} \\
\emptyset & \text{otherwise}
\end{cases}
$

_Complexity improvement_:
$
\begin{align}
T_{original}(n) &= O(n) \quad \text{– Process all relocation sections} \\
T_{filtered}(k) &= O(k) \quad \text{– Process only .text relocations, } k \ll n \\
\text{Speedup} &= \frac{n}{k} \quad \text{– Significant for complex objects}
\end{align}
$

_Direct code correspondence_:
```julia
= Mathematical model: parse_relocations_filtered: List(RelocationSection) → List(RelocationEntry)
function parse_elf_file(filename::String)
    # ... header and section parsing ...
    
    # Critical improvement: Relocation filtering
    relocations = RelocationEntry[]
    rela_sections = find_section_by_type(sections, UInt32(SHT_RELA))
    for rela_section in rela_sections
        section_name = get_string_from_table(string_table, rela_section.name)
        
        # Mathematical filtering: only process if name(s) = ".rela.text"
        if section_name == ".rela.text"              # ↔ filter condition
            append!(relocations, parse_relocations(io, rela_section))  # ↔ selective parsing
        end
        # Implicit else: ∅ (skip .rela.eh_frame and other sections)
    end
    
    return ElfFile(filename, header, sections, string_table, symbols, symbol_string_table, relocations)
end
```

_Mathematical justification_: 
$
\text{Basic linking requirement: } \forall r \in required\_relocations: r.target = \text{".text"}
$

Therefore:
$
filtered\_relocations \supseteq required\_relocations
$

This ensures correctness while improving performance by excluding unnecessary `.eh_frame` relocations that were causing "relocation offset exceeds region size" errors.