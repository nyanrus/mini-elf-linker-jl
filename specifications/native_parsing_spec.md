# Native Binary Parsing Specification

## Overview

The native parsing module provides direct binary file analysis without depending on external tools like `nm`, `objdump`, or `readelf`. This enables the linker to work in environments where these tools aren't available and provides better error handling and performance.

## File Type Detection

### Magic Number Recognition
File types are identified by reading the first few bytes (magic numbers):

```julia
# File type detection by magic bytes
function detect_file_type_by_magic(filepath::String)::String
    try
        open(filepath, "r") do file
            # Read first 16 bytes for magic number detection
            magic_bytes = read(file, 16)
            
            if length(magic_bytes) < 4
                return "unknown"
            end
            
            # ELF files
            if magic_bytes[1:4] == [0x7f, UInt8('E'), UInt8('L'), UInt8('F')]
                return detect_elf_type(magic_bytes)
            end
            
            # AR archives (static libraries)
            if String(magic_bytes[1:8]) == "!<arch>\n"
                return "AR archive"
            end
            
            # PE files (Windows)  
            if magic_bytes[1:2] == [0x4d, 0x5a]  # "MZ"
                return "PE executable"
            end
            
            return "unknown"
        end
    catch e
        @debug "Error detecting file type for $filepath: $e"
        return "unknown"
    end
end
```

### ELF Subtype Detection
```julia
function detect_elf_type(magic_bytes::Vector{UInt8})::String
    if length(magic_bytes) < 16
        return "ELF (truncated)"
    end
    
    # ELF class (32/64-bit)
    class = magic_bytes[5]
    architecture = class == NATIVE_ELF_CLASS_32 ? "32-bit" : "64-bit"
    
    # ELF type (starting at offset 16)
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

## Native ELF Constants

### ELF Header Constants
```julia
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
```

### Symbol Table Constants
```julia
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

## Symbol Extraction

### ELF Symbol Extraction
Direct parsing of ELF files to extract symbol information:

```julia
struct NativeSymbol
    name::String
    value::UInt64
    size::UInt64
    type::UInt8
    binding::UInt8
    section::UInt16
    defined::Bool
end

function extract_elf_symbols_native(filepath::String)::Vector{NativeSymbol}
    symbols = NativeSymbol[]
    
    try
        open(filepath, "r") do file
            # Parse ELF header
            header = parse_native_elf_header(file)
            
            # Find symbol table and string table sections
            sections = parse_native_section_headers(file, header)
            symtab_section = find_section_by_type(sections, NATIVE_SHT_SYMTAB)
            strtab_section = find_section_by_type(sections, NATIVE_SHT_STRTAB)
            
            if symtab_section !== nothing && strtab_section !== nothing
                # Load string table
                strings = load_string_table(file, strtab_section)
                
                # Parse symbol table
                symbols = parse_symbol_table(file, symtab_section, strings)
            end
        end
    catch e
        @debug "Error extracting symbols from $filepath: $e"
    end
    
    return symbols
end
```

### Native ELF Header Parsing
```julia
function parse_native_elf_header(file::IO)
    # Verify ELF magic
    magic = read(file, 4)
    if magic != [0x7f, UInt8('E'), UInt8('L'), UInt8('F')]
        throw(ArgumentError("Invalid ELF magic number"))
    end
    
    # Read ELF identification
    class = read(file, UInt8)
    data = read(file, UInt8)
    version = read(file, UInt8)
    osabi = read(file, UInt8)
    abiversion = read(file, UInt8)
    pad = read(file, 7)  # Padding
    
    # Read remaining header fields (depends on class)
    if class == NATIVE_ELF_CLASS_64
        type = read_uint16_le(file)
        machine = read_uint16_le(file)
        version2 = read_uint32_le(file)
        entry = read_uint64_le(file)
        phoff = read_uint64_le(file)
        shoff = read_uint64_le(file)
        flags = read_uint32_le(file)
        ehsize = read_uint16_le(file)
        phentsize = read_uint16_le(file)
        phnum = read_uint16_le(file)
        shentsize = read_uint16_le(file)
        shnum = read_uint16_le(file)
        shstrndx = read_uint16_le(file)
        
        return (class=class, shoff=shoff, shnum=shnum, shstrndx=shstrndx)
    else
        throw(ArgumentError("32-bit ELF not yet supported"))
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