# Native Parsing Mathematical Specification

## Mathematical Model

```math
\text{Domain: } \mathcal{D} = \{\text{Binary files}, \text{Magic bytes}, \text{File paths}\}
\text{Range: } \mathcal{R} = \{\text{File types}, \text{Symbol sets}, \text{Archive contents}\}
\text{Mapping: } detect\_and\_parse: \mathcal{D} \to \mathcal{R}
```

## Operations

```math
\text{Primary operations: } \{detect\_file\_type, extract\_elf\_symbols, extract\_archive\_symbols\}
\text{Invariants: } \{magic\_byte\_consistency, symbol\_completeness, native\_parsing\_correctness\}
\text{Complexity bounds: } O(n + m) \text{ where } n,m = \text{file size, symbol count}
```

## Critical Bug Fix: Constant Naming

### Issue: Type Definition Errors

**Mathematical inconsistency**:
```math
NATIVE\_ELF\_CLASS\_64 \neq NATIVE\_NATIVE\_ELF\_CLASS\_64
```

**Error manifestation**:
```math
parse\_native\_elf\_header(file) \to UndefVarError(\text{"NATIVE\_ELF\_CLASS\_64"})
```

**Fix applied**:
```math
\text{Before: } NATIVE\_NATIVE\_ELF\_CLASS\_64 = 0x02 \quad \text{(typo)}
```
```math
\text{After: } NATIVE\_ELF\_CLASS\_64 = 0x02 \quad \text{(correct)}
```

**Direct code correspondence**:
```julia
# Mathematical model: Constant definition correction
# Before (incorrect):
const NATIVE_ELF_CLASS_32 = 0x01
const NATIVE_NATIVE_ELF_CLASS_64 = 0x02  # ← TYPO: double "NATIVE"

# After (correct):
const NATIVE_ELF_CLASS_32 = 0x01
const NATIVE_ELF_CLASS_64 = 0x02         # ← FIXED: single "NATIVE"
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