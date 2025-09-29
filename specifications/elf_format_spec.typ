= ELF Binary Format Specification

== Overview

This specification defines how MiniElfLinker interprets and processes the ELF (Executable and Linkable Format) binary format. ELF is the standard binary format for executables, object files, and shared libraries on Unix-like systems.

== ELF File Structure

=== File Layout
```
ELF File = ELF Header + Program Headers + Sections + Section Headers
```

=== Basic Components
1. _ELF Header_: File metadata and pointers to other components
2. _Program Headers_: Runtime loading information (executables)
3. _Section Headers_: Development-time section information
4. _Sections_: Actual code, data, and metadata

== ELF Header Format

=== Header Constants
```julia
= ELF Magic Number
const ELF_MAGIC = (0x7f, UInt8('E'), UInt8('L'), UInt8('F'))

= ELF Class (Architecture)
const ELFCLASS32 = 1    # 32-bit objects
const ELFCLASS64 = 2    # 64-bit objects

= Data Encoding  
const ELFDATA2LSB = 1   # Little-endian
const ELFDATA2MSB = 2   # Big-endian

= Object File Types
const ET_NONE = 0       # No file type
const ET_REL = 1        # Relocatable file  
const ET_EXEC = 2       # Executable file
const ET_DYN = 3        # Shared object file
const ET_CORE = 4       # Core file

= Machine Types
const EM_X86_64 = 62    # AMD x86-64
const EM_AARCH64 = 183  # ARM 64-bit
```

=== Header Validation
```julia
function validate_elf_header(header::ElfHeader)::Bool
    # Check magic number
    if header.magic != ELF_MAGIC
        return false
    end
    
    # Verify class (32/64-bit)
    if !(header.class in [ELFCLASS32, ELFCLASS64])
        return false
    end
    
    # Check endianness
    if !(header.data in [ELFDATA2LSB, ELFDATA2MSB])
        return false
    end
    
    # Validate version
    if header.version != 1
        return false
    end
    
    # Check supported architecture
    if !(header.machine in [EM_X86_64, EM_AARCH64])
        @warn "Unsupported architecture: $(header.machine)"
    end
    
    return true
end
```

== Section Types

=== Standard Section Types
```julia
const SHT_NULL = 0          # Inactive section
const SHT_PROGBITS = 1      # Program data
const SHT_SYMTAB = 2        # Symbol table
const SHT_STRTAB = 3        # String table
const SHT_RELA = 4          # Relocation entries with addends
const SHT_HASH = 5          # Symbol hash table
const SHT_DYNAMIC = 6       # Dynamic linking information
const SHT_NOTE = 7          # Notes section
const SHT_NOBITS = 8        # Program space with no data (BSS)
const SHT_REL = 9           # Relocation entries, no addends
```

=== Section Flags
```julia
const SHF_WRITE = 0x1       # Writable section
const SHF_ALLOC = 0x2       # Occupies memory during execution
const SHF_EXECINSTR = 0x4   # Executable instructions
const SHF_MERGE = 0x10      # Might be merged
const SHF_STRINGS = 0x20    # Contains null-terminated strings
```

=== Section Processing
```julia
function process_section(header::SectionHeader, data::Vector{UInt8})
    if header.type == SHT_SYMTAB
        return parse_symbol_table(data, header)
    elseif header.type == SHT_STRTAB
        return parse_string_table(data)
    elseif header.type == SHT_RELA
        return parse_relocation_table(data, header)
    elseif header.type == SHT_PROGBITS
        return data  # Raw program data
    else
        return nothing  # Skip unknown sections
    end
end
```

== Symbol Table Format

=== Symbol Binding Types
```julia
const STB_LOCAL = 0     # Local scope
const STB_GLOBAL = 1    # Global scope
const STB_WEAK = 2      # Weak reference
```

=== Symbol Types
```julia
const STT_NOTYPE = 0    # Symbol type not specified
const STT_OBJECT = 1    # Data object
const STT_FUNC = 2      # Code object
const STT_SECTION = 3   # Associated with a section
const STT_FILE = 4      # File name
const STT_COMMON = 5    # Common data object
```

=== Symbol Information Extraction
```julia
= Extract binding from symbol info field
function st_bind(info::UInt8)::UInt8
    return (info >> 4) & 0xf
end

= Extract type from symbol info field  
function st_type(info::UInt8)::UInt8
    return info & 0xf
end

= Create symbol info from binding and type
function st_info(bind::UInt8, type::UInt8)::UInt8
    return (bind << 4) | (type & 0xf)
end
```

=== Symbol Resolution
```julia
function resolve_symbol_value(symbol::SymbolTableEntry, sections::Vector{SectionHeader})::UInt64
    if symbol.shndx == SHN_UNDEF
        return 0  # Undefined symbol
    elseif symbol.shndx == SHN_ABS
        return symbol.value  # Absolute value
    elseif symbol.shndx < length(sections)
        section = sections[symbol.shndx + 1]  # Julia 1-based indexing
        return section.addr + symbol.value
    else
        error("Invalid section index: $(symbol.shndx)")
    end
end
```

== Relocation Processing

=== x86-64 Relocation Types
```julia
const R_X86_64_NONE = 0         # No relocation
const R_X86_64_64 = 1           # Direct 64-bit address
const R_X86_64_PC32 = 2         # PC-relative 32-bit signed
const R_X86_64_GOT32 = 3        # 32-bit GOT entry
const R_X86_64_PLT32 = 4        # 32-bit PLT address
const R_X86_64_COPY = 5         # Copy symbol at runtime
const R_X86_64_GLOB_DAT = 6     # Create GOT entry
const R_X86_64_JUMP_SLOT = 7    # Create PLT entry
```

=== Relocation Information Extraction
```julia
= Extract symbol table index from relocation info
function elf64_r_sym(info::UInt64)::UInt32
    return UInt32(info >> 32)
end

= Extract relocation type from relocation info
function elf64_r_type(info::UInt64)::UInt32
    return UInt32(info & 0xffffffff)
end

= Create relocation info from symbol index and type
function elf64_r_info(sym::UInt32, type::UInt32)::UInt64
    return (UInt64(sym) << 32) | UInt64(type)
end
```

=== Relocation Application
```julia
function apply_relocation(rel::RelocationEntry, symbol_value::UInt64, 
                         section_data::Vector{UInt8}, section_address::UInt64)
    # Calculate target location
    target_offset = Int(rel.offset - section_address)
    
    # Get relocation type
    rel_type = elf64_r_type(rel.info)
    
    if rel_type == R_X86_64_64
        # Direct 64-bit address
        target_value = symbol_value + rel.addend
        write_uint64_le(section_data, target_offset, target_value)
        
    elseif rel_type == R_X86_64_PC32
        # PC-relative 32-bit
        pc_address = section_address + rel.offset
        target_value = Int32(symbol_value + rel.addend - pc_address)
        write_uint32_le(section_data, target_offset, UInt32(target_value))
        
    else
        error("Unsupported relocation type: $rel_type")
    end
end
```

== String Table Handling

=== String Storage Format
- Null-terminated strings stored consecutively
- Index 0 always contains empty string
- String references use byte offsets into table

```julia
function parse_string_table(data::Vector{UInt8})::Vector{String}
    strings = String[]
    current_string = UInt8[]
    
    for byte in data
        if byte == 0
            if !isempty(current_string)
                push!(strings, String(current_string))
                empty!(current_string)
            end
        else
            push!(current_string, byte)
        end
    end
    
    return strings
end

function get_string(string_table::Vector{UInt8}, offset::UInt32)::String
    if offset >= length(string_table)
        return ""
    end
    
    # Find null terminator
    end_pos = offset + 1
    while end_pos <= length(string_table) && string_table[end_pos] != 0
        end_pos += 1
    end
    
    return String(string_table[offset+1:end_pos-1])
end
```

== Binary I/O Utilities

=== Little-Endian Reading
```julia
function read_uint16_le(io::IO)::UInt16
    bytes = read(io, 2)
    return UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
end

function read_uint32_le(io::IO)::UInt32
    bytes = read(io, 4)
    return UInt32(bytes[1]) | (UInt32(bytes[2]) << 8) |
           (UInt32(bytes[3]) << 16) | (UInt32(bytes[4]) << 24)
end

function read_uint64_le(io::IO)::UInt64
    low = UInt64(read_uint32_le(io))
    high = UInt64(read_uint32_le(io))
    return low | (high << 32)
end
```

=== Little-Endian Writing
```julia
function write_uint16_le(data::Vector{UInt8}, offset::Int, value::UInt16)
    data[offset + 1] = UInt8(value & 0xff)
    data[offset + 2] = UInt8((value >> 8) & 0xff)
end

function write_uint32_le(data::Vector{UInt8}, offset::Int, value::UInt32)
    data[offset + 1] = UInt8(value & 0xff)
    data[offset + 2] = UInt8((value >> 8) & 0xff)
    data[offset + 3] = UInt8((value >> 16) & 0xff)
    data[offset + 4] = UInt8((value >> 24) & 0xff)
end

function write_uint64_le(data::Vector{UInt8}, offset::Int, value::UInt64)
    write_uint32_le(data, offset, UInt32(value & 0xffffffff))
    write_uint32_le(data, offset + 4, UInt32(value >> 32))
end
```

== Format Validation

=== File Integrity Checks
```julia
function validate_elf_file(header::ElfHeader, sections::Vector{SectionHeader})::Bool
    # Check section header count
    if length(sections) != header.shnum
        @error "Section count mismatch"
        return false
    end
    
    # Validate section string table index
    if header.shstrndx >= header.shnum
        @error "Invalid string table index"
        return false
    end
    
    # Check section alignments
    for section in sections
        if section.addralign != 0 && (section.addr % section.addralign) != 0
            @warn "Section alignment violation"
        end
    end
    
    return true
end
```

=== Size Consistency Checks
```julia
function validate_section_sizes(sections::Vector{SectionHeader}, file_size::Int)::Bool
    for section in sections
        if section.offset + section.size > file_size
            @error "Section extends beyond file: $(section.name)"
            return false
        end
        
        if section.type == SHT_SYMTAB && (section.size % 24) != 0
            @error "Invalid symbol table size"
            return false
        end
    end
    
    return true
end
```

== Architecture-Specific Details

=== x86-64 Specifics
- 64-bit addresses and pointers
- Little-endian byte order
- 16-byte stack alignment requirement
- Red zone: 128 bytes below stack pointer

=== ARM64 Considerations (Future)
- 64-bit addresses with different relocation types
- Can be little or big-endian
- Different calling conventions
- ADRP/ADD instruction pairs for addressing

== Error Recovery

=== Partial File Handling
- Continue processing when encountering unknown sections
- Skip corrupted symbol entries
- Provide warnings for non-critical format violations
- Attempt best-effort parsing of malformed files

=== Error Reporting
```julia
struct ElfParseError
    message::String
    offset::UInt64
    context::String
end

function report_elf_error(error::ElfParseError)
    @error "ELF parsing failed at offset $(error.offset): $(error.message)" context=error.context
end
```

== Optimization Trigger Points

- _Inner loops_: Symbol table iteration with O(n) complexity bounds
- _Memory allocation_: Section data loading with size validation  
- _Bottleneck operations_: String table parsing with linear scan
- _Invariant preservation_: Magic number validation on every parse