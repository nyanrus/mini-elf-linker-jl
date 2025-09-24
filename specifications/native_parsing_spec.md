# Native Binary Parsing Specification

## Overview

The native parsing module provides direct binary file analysis without depending on external tools like `nm`, `objdump`, or `readelf`. Following the Mathematical-Driven AI Development methodology, this specification uses Julia directly for non-algorithmic components (constants, data structures, file I/O) and mathematical notation for algorithmic components (parsing algorithms, symbol extraction).

## Non-Algorithmic Components (Julia Direct Documentation)

### Binary Format Constants
```julia
"""
Native ELF constants for direct binary parsing.
Non-algorithmic: static constant definitions for ELF format specification.
"""

# ELF class identification
const NATIVE_ELF_CLASS_32 = 0x01
const NATIVE_ELF_CLASS_64 = 0x02

# Data encoding
const NATIVE_ELF_DATA_LSB = 0x01  # Little-endian
const NATIVE_ELF_DATA_MSB = 0x02  # Big-endian

# ELF file types
const NATIVE_ET_NONE = 0          # No file type
const NATIVE_ET_REL = 1           # Relocatable file
const NATIVE_ET_EXEC = 2          # Executable file
const NATIVE_ET_DYN = 3           # Shared object file
const NATIVE_ET_CORE = 4          # Core file

# Machine types
const NATIVE_EM_X86_64 = 62       # AMD x86-64
const NATIVE_EM_AARCH64 = 183     # ARM 64-bit

# Symbol binding
const NATIVE_STB_LOCAL = 0
const NATIVE_STB_GLOBAL = 1
const NATIVE_STB_WEAK = 2

# Symbol type
const NATIVE_STT_NOTYPE = 0
const NATIVE_STT_OBJECT = 1
const NATIVE_STT_FUNC = 2
const NATIVE_STT_SECTION = 3
const NATIVE_STT_FILE = 4

# Section header types
const NATIVE_SHT_NULL = 0
const NATIVE_SHT_PROGBITS = 1
const NATIVE_SHT_SYMTAB = 2
const NATIVE_SHT_STRTAB = 3
const NATIVE_SHT_RELA = 4
```

### Symbol Information Structure
```julia
"""
NativeSymbol represents a symbol extracted from ELF files.
Non-algorithmic: data structure for symbol information storage.
"""
struct NativeSymbol
    name::String
    value::UInt64
    size::UInt64
    type::UInt8
    binding::UInt8
    section::UInt16
    defined::Bool
    
    function NativeSymbol(name::String, value::UInt64, size::UInt64, 
                         type::UInt8, binding::UInt8, section::UInt16)
        # Symbol is defined if it's not in the undefined section (SHN_UNDEF = 0)
        defined = section != 0
        new(name, value, size, type, binding, section, defined)
    end
end
```

### Binary I/O Utilities
```julia
"""
Binary reading utilities for little-endian format processing.
Non-algorithmic: basic I/O operations without complex algorithms.
"""
function read_uint16_le(file::IO)::UInt16
    bytes = read(file, 2)
    return UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
end

function read_uint32_le(file::IO)::UInt32
    bytes = read(file, 4)
    return UInt32(bytes[1]) | 
           (UInt32(bytes[2]) << 8) |
           (UInt32(bytes[3]) << 16) | 
           (UInt32(bytes[4]) << 24)
end

function read_uint64_le(file::IO)::UInt64
    low = UInt64(read_uint32_le(file))
    high = UInt64(read_uint32_le(file))
    return low | (high << 32)
end
```

### File Type Detection (Non-Algorithmic)
```julia
"""
detect_file_type_by_magic identifies file types using magic number signatures.
Non-algorithmic: pattern matching against known magic numbers.
"""
function detect_file_type_by_magic(filepath::String)::String
    try
        open(filepath, "r") do file
            magic_bytes = read(file, 16)
            
            if length(magic_bytes) < 4
                return "unknown"
            end
            
            # ELF files: 0x7f + "ELF"
            if magic_bytes[1:4] == [0x7f, UInt8('E'), UInt8('L'), UInt8('F')]
                return detect_elf_subtype(magic_bytes)
            end
            
            # AR archives: "!<arch>\n"
            if String(magic_bytes[1:8]) == "!<arch>\n"
                return "AR archive"
            end
            
            # PE files: "MZ"
            if magic_bytes[1:2] == [0x4d, 0x5a]
                return "PE executable"
            end
            
            return "unknown"
        end
    catch e
        @debug "Error detecting file type for $filepath: $e"
        return "unknown"
    end
end

function detect_elf_subtype(magic_bytes::Vector{UInt8})::String
    if length(magic_bytes) < 16
        return "ELF (truncated)"
    end
    
    class = magic_bytes[5]
    architecture = class == NATIVE_ELF_CLASS_32 ? "32-bit" : "64-bit"
    
    if length(magic_bytes) >= 18
        elf_type = UInt16(magic_bytes[17]) | (UInt16(magic_bytes[18]) << 8)
        
        type_description = if elf_type == NATIVE_ET_REL
            "object file"
        elseif elf_type == NATIVE_ET_EXEC  
            "executable"
        elseif elf_type == NATIVE_ET_DYN
            "shared library"
        else
            "unknown type"
        end
        
        return "ELF $architecture $type_description"
    end
    
    return "ELF $architecture"
end
```

## Algorithmic Components (Mathematical Analysis)

### ELF Parsing Algorithm

**Mathematical Model**: ELF parsing transforms binary byte sequences into structured representations through sequential field extraction.

```math
\text{Let } \mathcal{B} = \{b_1, b_2, \ldots, b_n\} \text{ be the binary file as byte sequence}
```

```math
\text{Let } \mathcal{S} = \{\text{structured ELF components}\} \text{ be the target representation}
```

**Parsing Function**:
```math
\Pi_{parse}: \mathcal{B} \to \mathcal{S} \cup \{\text{Error}\}
```

**Sequential Extraction Operations**:
```math
\begin{align}
\Pi_{header} &: \mathcal{B}[0:64] \to \text{ElfHeader} \\
\Pi_{sections} &: \mathcal{B}[h.shoff:h.shoff + h.shnum \times h.shentsize] \to \text{SectionHeaders} \\
\Pi_{symbols} &: \mathcal{B}[s.offset:s.offset + s.size] \to \text{SymbolEntries}
\end{align}
```

**Parsing Pipeline Composition**:
```math
\Pi_{complete} = \Pi_{symbols} \circ \Pi_{sections} \circ \Pi_{header}
```

**Complexity Analysis**:
```math
T_{parse}(n, s, m) = O(n) + O(s) + O(m) = O(n + s + m)
```
where $n$ = file size, $s$ = number of sections, $m$ = number of symbols.

**Implementation with Mathematical Correspondence**:
```julia
"""
Mathematical model: Π_parse: ℬ → 𝒮 ∪ {Error}
Parse ELF files through sequential field extraction algorithm.
"""
function Π_extract_elf_symbols_native(filepath::String)::Vector{NativeSymbol}
    symbols = NativeSymbol[]
    
    try
        open(filepath, "r") do file
            # Apply header parsing: Π_header(ℬ[0:64]) → ElfHeader
            header = Π_parse_native_elf_header(file)
            
            # Apply section parsing: Π_sections(ℬ[shoff:...]) → SectionHeaders  
            sections = Π_parse_native_section_headers(file, header)
            
            # Find symbol and string table sections
            symtab_section = find_section_by_type(sections, NATIVE_SHT_SYMTAB)
            strtab_section = find_section_by_type(sections, NATIVE_SHT_STRTAB)
            
            if symtab_section !== nothing && strtab_section !== nothing
                # Load string table for symbol name resolution
                strings = Π_load_string_table(file, strtab_section)
                
                # Apply symbol extraction: Π_symbols(ℬ[symtab:...]) → SymbolEntries
                symbols = Π_parse_symbol_table(file, symtab_section, strings)
            end
        end
    catch e
        @debug "Error in ELF parsing algorithm for $filepath: $e"
    end
    
    return symbols
end
```

### Symbol Extraction Algorithm

**Mathematical Model**: Symbol extraction transforms binary symbol table entries into structured symbol information.

```math
\text{Let } \mathcal{T}_{symtab} = \{t_1, t_2, \ldots, t_k\} \text{ be symbol table entries}
```

```math
\text{Let } \mathcal{T}_{strtab} = \{c_1, c_2, \ldots, c_l\} \text{ be string table characters}
```

**Symbol Transformation Function**:
```math
\Sigma_{extract}: \mathcal{T}_{symtab} \times \mathcal{T}_{strtab} \to \mathcal{S}_{symbols}
```

**Name Resolution Operation**:
```math
\text{resolve\_name}(offset, \mathcal{T}_{strtab}) = \text{extract\_string}(\mathcal{T}_{strtab}[offset:null\_terminator])
```

**Symbol Entry Transformation**:
```math
\Sigma_{transform}(entry) = \begin{cases}
\text{NativeSymbol}(\text{resolve\_name}(entry.name), entry.value, \ldots) & \text{if valid entry} \\
\text{skip} & \text{if invalid or null entry}
\end{cases}
```

**Complexity Analysis**:
```math
T_{extraction}(k, l) = O(k \times \log l) \text{ for string lookups}
```

**Optimization Potential**:
```math
T_{optimized}(k, l) = O(k + l) \text{ with pre-processed string index}
```

**Implementation**:
```julia
"""
Mathematical model: Σ_extract: 𝒯_symtab × 𝒯_strtab → 𝒮_symbols
Transform binary symbol table entries into structured symbol information.
"""
function Π_parse_symbol_table(file::IO, symtab_section, strings::Vector{UInt8})::Vector{NativeSymbol}
    symbols = NativeSymbol[]
    symbol_count = symtab_section.size ÷ 24  # 24 bytes per symbol in ELF64
    
    seek(file, symtab_section.offset)
    
    # Apply extraction algorithm: ∀i ∈ [1, symbol_count]
    for i ∈ 1:symbol_count
        # Read symbol entry fields
        name_offset = read_uint32_le(file)
        info = read(file, UInt8)
        other = read(file, UInt8)  
        shndx = read_uint16_le(file)
        value = read_uint64_le(file)
        size = read_uint64_le(file)
        
        # Apply field extraction transformations
        binding = (info >> 4) & 0xf  # Extract binding: binding = ⌊info/16⌋ ∧ 0xF
        sym_type = info & 0xf        # Extract type: type = info ∧ 0xF
        
        # Apply name resolution: resolve_name(offset, 𝒯_strtab)
        name = get_string_at_offset(strings, name_offset)
        
        # Apply transformation function: Σ_transform(entry) → NativeSymbol
        if !isempty(name) || value != 0  # Skip null entries
            symbol = NativeSymbol(name, value, size, sym_type, binding, shndx)
            push!(symbols, symbol)
        end
    end
    
    return symbols
end
```

### Archive Processing Algorithm

**Mathematical Model**: Archive processing extracts and processes multiple object files contained within static library archives.

```math
\text{Let } \mathcal{A} = \{\text{archive file}\} \text{ be the input archive}
```

```math
\text{Let } \mathcal{O} = \{o_1, o_2, \ldots, o_m\} \text{ be extracted object files}
```

```math
\text{Let } \mathcal{S}_i = \{\text{symbols in } o_i\} \text{ be symbol sets}
```

**Archive Extraction Function**:
```math
\mathcal{E}_{extract}: \mathcal{A} \to \mathcal{O}
```

**Symbol Union Operation**:
```math
\mathcal{S}_{total} = \bigcup_{i=1}^{m} \mathcal{S}_i
```

**Complete Processing Function**:
```math
\Omega_{process}: \mathcal{A} \to \mathcal{S}_{total}
```

**Complexity Analysis**:
```math
T_{archive}(m, s) = O(m \times s) \text{ where } m = \text{objects}, s = \text{avg symbols per object}
```

**Implementation**:
```julia
"""
Mathematical model: Ω_process: 𝒜 → 𝒮_total
Process static library archives through extraction and symbol union operations.
"""
function Ω_extract_archive_symbols_native(archive_path::String)::Vector{String}
    𝒮_total = String[]  # Total symbol set: ⋃ᵢ 𝒮ᵢ
    temp_dir = mktempdir()
    
    try
        # Apply extraction function: ℰ_extract(𝒜) → 𝒪
        cd(temp_dir) do
            run(`ar x $archive_path`)
        end
        
        # Process each extracted object: ∀oᵢ ∈ 𝒪
        for filename ∈ readdir(temp_dir)
            if endswith(filename, ".o")
                object_path = joinpath(temp_dir, filename)
                
                try
                    # Extract symbols from object: oᵢ → 𝒮ᵢ
                    object_symbols = Π_extract_elf_symbols_native(object_path)
                    
                    # Apply union operation: 𝒮_total ← 𝒮_total ∪ 𝒮ᵢ
                    for sym ∈ object_symbols
                        if sym.binding == NATIVE_STB_GLOBAL && sym.defined
                            push!(𝒮_total, sym.name)
                        end
                    end
                catch e
                    @debug "Failed to process object $filename: $e"
                end
            end
        end
    finally
        # Cleanup temporary extraction
        rm(temp_dir, recursive=true, force=true)
    end
    
    # Return unique symbol set: ensure no duplicates in 𝒮_total
    return unique(𝒮_total)
end
```

## Error Handling and Recovery (Non-Algorithmic)

### Robust File Processing
```julia
"""
safe_symbol_extraction provides error-resilient symbol extraction.
Non-algorithmic: error handling and recovery mechanisms.
"""
function safe_symbol_extraction(filepath::String)::Vector{NativeSymbol}
    try
        return Π_extract_elf_symbols_native(filepath)
    catch BoundsError
        @warn "File appears truncated: $filepath"
        return NativeSymbol[]
    catch ArgumentError as e
        @warn "Invalid file format: $filepath - $e"
        return NativeSymbol[]
    catch e
        @error "Unexpected error processing $filepath: $e"
        return NativeSymbol[]
    end
end
```

### Format Validation
```julia
"""
validate_elf_structure performs consistency checks on parsed ELF components.
Non-algorithmic: structural validation and integrity checking.
"""
function validate_elf_structure(header, sections)::Bool
    # Check section count consistency
    if length(sections) != header.shnum
        @warn "Section count mismatch: expected $(header.shnum), got $(length(sections))"
        return false
    end
    
    # Validate section header string table index
    if header.shstrndx >= header.shnum
        @warn "Invalid section header string table index: $(header.shstrndx)"
        return false
    end
    
    return true
end
```

## Integration with Mathematical Linker Core

### Native Parsing Bridge
```julia
"""
integrate_native_symbols! integrates natively parsed symbols into the mathematical linker.
Bridges algorithmic parsing results to the mathematical linking pipeline.
"""
function integrate_native_symbols!(linker::DynamicLinker, object_path::String)
    # Apply parsing algorithm: Π_extract
    native_symbols = Π_extract_elf_symbols_native(object_path)
    
    # Integrate with mathematical symbol resolution (see core_processes.md)
    for sym ∈ native_symbols
        if sym.binding == NATIVE_STB_GLOBAL
            symbol_info = SymbolInfo(
                name=sym.name,
                value=sym.value,
                defined=sym.defined,
                binding=sym.binding,
                type=sym.type,
                source=object_path
            )
            
            # Add to global symbol space for δ_resolve algorithm
            linker.global_symbol_table[sym.name] = symbol_info
        end
    end
end
```

## Archive Processing

### Static Library Symbol Extraction
```julia
function extract_archive_symbols_native(archive_path::String)::Vector{String}
    symbols = String[]
    
    try
        # Create temporary directory for extraction
        temp_dir = mktempdir()
        
        try
            # Use `ar` command to extract archive
            cd(temp_dir) do
                run(`ar x $archive_path`)
            end
            
            # Process each extracted object file
            for filename in readdir(temp_dir)
                if endswith(filename, ".o")
                    object_path = joinpath(temp_dir, filename)
                    
                    try
                        object_symbols = extract_elf_symbols_native(object_path)
                        for sym in object_symbols
                            if sym.binding == NATIVE_STB_GLOBAL && sym.defined
                                push!(symbols, sym.name)
                            end
                        end
                    catch e
                        @debug "Failed to process $filename: $e"
                    end
                end
            end
        finally
            # Cleanup temporary directory
            rm(temp_dir, recursive=true, force=true)
        end
    catch e
        @error "Failed to extract archive $archive_path: $e"
    end
    
    return unique(symbols)
end
```

## Section Processing

### Section Header Parsing
```julia
function parse_native_section_headers(file::IO, header)::Vector{Any}
    sections = []
    
    # Seek to section header table
    seek(file, header.shoff)
    
    # Read each section header
    for i in 1:header.shnum
        section = (
            name = read_uint32_le(file),
            type = read_uint32_le(file),
            flags = read_uint64_le(file),
            addr = read_uint64_le(file),
            offset = read_uint64_le(file),
            size = read_uint64_le(file),
            link = read_uint32_le(file),
            info = read_uint32_le(file),
            addralign = read_uint64_le(file),
            entsize = read_uint64_le(file)
        )
        push!(sections, section)
    end
    
    return sections
end
```

### String Table Loading
```julia
function load_string_table(file::IO, strtab_section)::Vector{UInt8}
    seek(file, strtab_section.offset)
    return read(file, strtab_section.size)
end

function get_string_at_offset(strtab::Vector{UInt8}, offset::UInt32)::String
    if offset >= length(strtab)
        return ""
    end
    
    # Find null terminator
    end_pos = offset + 1
    while end_pos <= length(strtab) && strtab[end_pos] != 0
        end_pos += 1
    end
    
    return String(strtab[offset+1:end_pos-1])
end
```

### Symbol Table Parsing
```julia
function parse_symbol_table(file::IO, symtab_section, strings::Vector{UInt8})::Vector{NativeSymbol}
    symbols = NativeSymbol[]
    symbol_count = symtab_section.size ÷ 24  # 24 bytes per symbol in ELF64
    
    seek(file, symtab_section.offset)
    
    for i in 1:symbol_count
        # Read symbol entry
        name_offset = read_uint32_le(file)
        info = read(file, UInt8)
        other = read(file, UInt8)  
        shndx = read_uint16_le(file)
        value = read_uint64_le(file)
        size = read_uint64_le(file)
        
        # Extract binding and type
        binding = (info >> 4) & 0xf
        sym_type = info & 0xf
        
        # Get symbol name
        name = get_string_at_offset(strings, name_offset)
        
        # Determine if symbol is defined
        defined = shndx != 0  # SHN_UNDEF
        
        symbol = NativeSymbol(
            name, value, size, sym_type, binding, shndx, defined
        )
        push!(symbols, symbol)
    end
    
    return symbols
end
```

## Binary Utilities

### Little-Endian Reading Functions
```julia
function read_uint16_le(file::IO)::UInt16
    bytes = read(file, 2)
    return UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
end

function read_uint32_le(file::IO)::UInt32
    bytes = read(file, 4)
    return UInt32(bytes[1]) | 
           (UInt32(bytes[2]) << 8) |
           (UInt32(bytes[3]) << 16) | 
           (UInt32(bytes[4]) << 24)
end

function read_uint64_le(file::IO)::UInt64
    low = UInt64(read_uint32_le(file))
    high = UInt64(read_uint32_le(file))
    return low | (high << 32)
end
```

## Error Handling and Recovery

### Robust File Processing
```julia
function safe_symbol_extraction(filepath::String)::Vector{NativeSymbol}
    try
        return extract_elf_symbols_native(filepath)
    catch BoundsError
        @warn "File appears truncated: $filepath"
        return NativeSymbol[]
    catch ArgumentError as e
        @warn "Invalid file format: $filepath - $e"
        return NativeSymbol[]
    catch e
        @error "Unexpected error processing $filepath: $e"
        return NativeSymbol[]
    end
end
```

### Validation and Sanity Checks
```julia
function validate_elf_structure(header, sections)::Bool
    # Check section count matches header
    if length(sections) != header.shnum
        @warn "Section count mismatch"
        return false
    end
    
    # Validate section header string table index
    if header.shstrndx >= header.shnum
        @warn "Invalid section header string table index"
        return false
    end
    
    return true
end
```

## Performance Optimizations

### Lazy Symbol Loading
Only extract symbols when specifically needed:

```julia
mutable struct LazySymbolExtractor
    filepath::String
    symbols::Union{Vector{NativeSymbol}, Nothing}
    
    LazySymbolExtractor(path) = new(path, nothing)
end

function get_symbols(extractor::LazySymbolExtractor)::Vector{NativeSymbol}
    if extractor.symbols === nothing
        extractor.symbols = extract_elf_symbols_native(extractor.filepath)
    end
    return extractor.symbols
end
```

### Caching for Repeated Access
```julia
const SYMBOL_CACHE = Dict{String, Vector{NativeSymbol}}()

function get_symbols_cached(filepath::String)::Vector{NativeSymbol}
    if !haskey(SYMBOL_CACHE, filepath)
        SYMBOL_CACHE[filepath] = extract_elf_symbols_native(filepath)
    end
    return SYMBOL_CACHE[filepath]
end
```

## Integration with Linker

### Symbol Resolution Integration
```julia
function integrate_native_symbols!(linker::DynamicLinker, object_path::String)
    native_symbols = extract_elf_symbols_native(object_path)
    
    for sym in native_symbols
        if sym.binding == NATIVE_STB_GLOBAL
            # Add to global symbol table
            symbol_info = SymbolInfo(
                name=sym.name,
                value=sym.value,
                defined=sym.defined,
                binding=sym.binding,
                type=sym.type,
                source=object_path
            )
            
            linker.global_symbol_table[sym.name] = symbol_info
        end
    end
end
```
```

## Implementation Correspondence

### File Type Detection → `detect_file_type_by_magic` function

```math
detect\_file\_type: FilePath \to FileType \cup \{Error\}
```

**Magic byte classification**:
```math
classify(bytes) = \begin{cases}
ELF\_FILE & \text{if } bytes[1:4] = [0x7f, 0x45, 0x4c, 0x46] \\
AR\_FILE & \text{if } bytes[1:8] = \text{"!<arch>\textbackslash n"} \\
LINKER\_SCRIPT & \text{if } \text{"GROUP"} \in content \\
UNKNOWN\_FILE & \text{otherwise}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: detect_file_type: FilePath → FileType ∪ {Error}
function detect_file_type_by_magic(file_path::String)
    open(file_path, "r") do file
        magic_bytes = read(file, 8)
        
        # Mathematical classification by magic bytes
        if length(magic_bytes) >= 4 && magic_bytes[1:4] == NATIVE_ELF_MAGIC
            return ELF_FILE                       # ↔ ELF file identification
        elseif length(magic_bytes) >= 8 && magic_bytes == NATIVE_AR_MAGIC  
            return AR_FILE                        # ↔ Archive file identification
        else
            # Additional heuristic classification
            return classify_by_content(file)      # ↔ Content-based detection
        end
    end
end
```

### Native ELF Symbol Extraction → `extract_elf_symbols_native` function

```math
extract\_symbols: ELFFile \to Set(SymbolName)
```

**Symbol filtering criteria**:
```math
valid\_symbol(sym) = \begin{cases}
true & \text{if } binding(sym) \in \{STB\_GLOBAL, STB\_WEAK\} \\
     & \land shndx(sym) \neq 0 \\
     & \land name(sym) \neq \emptyset \\
     & \land \neg startswith(name(sym), "\_") \\
false & \text{otherwise}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: extract_symbols: ELFFile → Set(SymbolName)
function extract_elf_symbols_native(file_path::String)
    symbols = Set{String}()
    
    header = parse_native_elf_header(file_path)
    if header === nothing
        return symbols
    end
    
    # Process symbol tables using corrected constants
    is_64bit = (header.class == NATIVE_ELF_CLASS_64)  # ↔ Fixed constant usage
    
    for (i, section) in enumerate(section_headers)
        if section.type == NATIVE_SHT_SYMTAB || section.type == NATIVE_SHT_DYNSYM
            # Symbol extraction with filtering
            symbols_found = parse_symbol_table(file, section, strtab_section, little_endian, is_64bit)
            union!(symbols, symbols_found)       # ↔ Set union operation
        end
    end
    
    return symbols
end
```

### Symbol Table Parsing → `parse_symbol_table` function

```math
parse\_symbol\_table: File \times Section \times StringTable \times Boolean \times Boolean \to Set(String)
```

**Symbol validation logic**:
```math
\forall symbol \in symbol\_table: 
\begin{cases}
symbol \in result & \text{if } valid\_symbol(symbol) \\
symbol \notin result & \text{otherwise}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: parse_symbol_table with validation
function parse_symbol_table(file, symtab_section, strtab_section, little_endian, is_64bit)
    symbols = Set{String}()
    
    for i in 1:num_symbols
        # Symbol field extraction
        name_offset = read_offset(file, little_endian)
        info = read(file, UInt8)
        shndx = read_section_index(file, little_endian)
        
        # Extract binding and type information
        binding = info >> 4                       # ↔ Bit manipulation
        symbol_type = info & 0xf
        
        # Mathematical validation conditions
        if (binding == NATIVE_STB_GLOBAL || binding == NATIVE_STB_WEAK) && 
           shndx != 0 && !isempty(symbol_name) && !startswith(symbol_name, "_")
            push!(symbols, symbol_name)          # ↔ Filtered addition
        end
    end
    
    return symbols
end
```

## Archive Processing → `extract_archive_symbols_native` function

```math
extract\_archive\_symbols: ArchiveFile \to Set(SymbolName)
```

**Archive member processing**:
```math
archive\_symbols = \bigcup_{member \in archive} \begin{cases}
extract\_elf\_symbols(member) & \text{if } is\_elf(member) \\
\emptyset & \text{otherwise}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: extract_archive_symbols: ArchiveFile → Set(SymbolName)
function extract_archive_symbols_native(file_path::String)
    symbols = Set{String}()
    
    open(file_path, "r") do file
        seek(file, 8)  # Skip archive magic
        
        while !eof(file)
            # Parse archive member header
            header = read(file, 60)
            member_size = parse_size(header)
            
            # Check if member is ELF object
            if is_elf_object(file)
                # Extract to temporary file and process
                temp_file = create_temp_elf_object(file, member_size)
                member_symbols = extract_elf_symbols_native(temp_file)
                union!(symbols, member_symbols)   # ↔ Symbol aggregation
                cleanup(temp_file)
            end
            
            # Advance to next member
            seek_to_next_member(file, member_size)
        end
    end
    
    return symbols
end
```

## Complexity Analysis

```math
\begin{align}
T_{file\_detection}(n) &= O(1) \quad \text{– Constant magic byte check} \\
T_{elf\_parsing}(m) &= O(m) \quad \text{– Linear in file size} \\
T_{symbol\_extraction}(s) &= O(s) \quad \text{– Linear in symbol count} \\
T_{archive\_processing}(k,s) &= O(k \cdot s) \quad \text{– Members × symbols per member}
\end{align}
```

## Transformation Pipeline

```math
file\_path \xrightarrow{detect\_type} file\_type \xrightarrow{parse\_header} elf\_header \xrightarrow{extract\_symbols} symbol\_set
```

**Code pipeline correspondence**:
```julia
# Mathematical pipeline: file_path → file_type → elf_header → symbol_set
function extract_symbols_pipeline(file_path::String)::Set{String}
    # Stage 1: file_path → file_type
    file_type = detect_file_type_by_magic(file_path)      # ↔ type detection
    
    # Stage 2: file_type → elf_header → symbol_set  
    if file_type == ELF_FILE
        return extract_elf_symbols_native(file_path)      # ↔ ELF processing
    elseif file_type == AR_FILE
        return extract_archive_symbols_native(file_path) # ↔ Archive processing
    else
        return Set{String}()                              # ↔ Empty set for unsupported
    end
end
```

## Error Recovery and Robustness

```math
\text{Error handling: } \forall file \in files: \exists result \in \{symbols, \emptyset, error\}
```

```math
\text{Graceful degradation: } parse\_error(file) \implies return(\emptyset) \land continue
```

**Direct code correspondence**:
```julia
# Mathematical model: Robust parsing with error recovery
function extract_elf_symbols_native(file_path::String)
    try
        # Normal extraction logic
        return perform_symbol_extraction(file_path)
    catch e
        println("Warning: Failed to extract symbols from $file_path: $e")
        return Set{String}()                              # ↔ Graceful failure
    end
end
```

## Optimization Trigger Points

- **Magic byte detection**: Fast file type classification without full parsing
- **Symbol filtering**: Early filtering reduces memory allocation
- **Archive processing**: Temporary file optimization for member extraction
- **Error recovery**: Continue processing even when individual files fail