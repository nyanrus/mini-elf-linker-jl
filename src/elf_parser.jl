# ELF Parser Implementation
# Mathematical model: π: D → R where D = {IO streams, File paths} and R = {ELF structured data, Error states}
# Functions to parse ELF files and extract necessary information following rigorous mathematical specification

"""
    parse_elf_header(io::IO) -> ElfHeader

Mathematical model: π_header: IO → ElfHeader ∪ {⊥}
Parse the ELF header from an IO stream with validation.

Transformation pipeline:
```math
io \\xrightarrow{read\\_magic} magic \\xrightarrow{validate} verified \\xrightarrow{parse\\_fields} header
```

Invariants:
- Pre: magic = (0x7f, 0x45, 0x4c, 0x46) ↔ ELF_MAGIC verification
- Post: valid_elf_header(result) ↔ structural consistency
"""
function parse_elf_header(io::IO)
    # Read ELF magic signature: magic ∈ {0x7f, 'E', 'L', 'F'}
    magic = ntuple(i -> read(io, UInt8), 4)             # ↔ magic extraction
    
    # ELF magic verification: magic = ELF_MAGIC
    if magic != ELF_MAGIC                               # ↔ invariant check
        error("Invalid ELF magic number: $(magic)")    # ↔ ⊥ error state
    end
    
    # Parse ELF identification fields
    class = read(io, UInt8)                            # ↔ architecture class ∈ {1,2}
    data = read(io, UInt8)                             # ↔ endianness ∈ {1,2}
    version = read(io, UInt8)                          # ↔ version number
    osabi = read(io, UInt8)                            # ↔ OS/ABI identification
    abiversion = read(io, UInt8)                       # ↔ ABI version
    pad = ntuple(i -> read(io, UInt8), 7)              # ↔ padding bytes
    
    # Parse remaining header fields: sequential field extraction
    type = read(io, UInt16)                            # ↔ object file type
    machine = read(io, UInt16)                         # ↔ machine architecture
    version2 = read(io, UInt32)                        # ↔ object file version
    entry = read(io, UInt64)                           # ↔ entry point address
    phoff = read(io, UInt64)                           # ↔ program header offset
    shoff = read(io, UInt64)                           # ↔ section header offset
    flags = read(io, UInt32)                           # ↔ processor flags
    ehsize = read(io, UInt16)                          # ↔ ELF header size
    phentsize = read(io, UInt16)                       # ↔ program header entry size
    phnum = read(io, UInt16)                           # ↔ program header count
    shentsize = read(io, UInt16)                       # ↔ section header entry size
    shnum = read(io, UInt16)                           # ↔ section header count
    shstrndx = read(io, UInt16)                        # ↔ section name string table index
    
    # Construct ELF header: field aggregation into structured representation
    return ElfHeader(
        magic, class, data, version, osabi, abiversion, pad,
        type, machine, version2, entry, phoff, shoff, flags,
        ehsize, phentsize, phnum, shentsize, shnum, shstrndx
    )
end

"""
    parse_elf_header(filename::String) -> ElfHeader

Parse the ELF header from a file.
"""
function parse_elf_header(filename::String)
    open(filename, "r") do io
        parse_elf_header(io)
    end
end

"""
    parse_section_headers(io::IO, elf_header::ElfHeader) -> Vector{SectionHeader}

Mathematical model: π_sections: IO × ElfHeader → List(SectionHeader)
Parse all section headers from an ELF file with bounded iteration.

Preconditions:
- header.shoff > 0 ∧ header.shnum ≥ 0 ∧ io_valid(io)

Postconditions:
- |result| = header.shnum ∧ ∀s ∈ result: valid_section(s)

Complexity: O(k) where k = header.shnum (section count)
"""
function parse_section_headers(io::IO, elf_header::ElfHeader)
    # Initialize section collection: sections = ∅
    sections = Vector{SectionHeader}()                      # ↔ result accumulator
    
    # Position to section header table: seek(io, header.shoff)
    seek(io, elf_header.shoff)                             # ↔ file positioning
    
    # Bounded iteration: ∀i ∈ [1, header.shnum]
    for i in 1:elf_header.shnum                            # ↔ section iteration
        # Sequential field extraction: parse_single_section_header
        name = read(io, UInt32)                            # ↔ section name offset
        type = read(io, UInt32)                            # ↔ section type
        flags = read(io, UInt64)                           # ↔ section flags
        addr = read(io, UInt64)                            # ↔ virtual address
        offset = read(io, UInt64)                          # ↔ file offset
        size = read(io, UInt64)                            # ↔ section size
        link = read(io, UInt32)                            # ↔ link information
        info = read(io, UInt32)                            # ↔ auxiliary information
        addralign = read(io, UInt64)                       # ↔ address alignment
        entsize = read(io, UInt64)                         # ↔ entry size
        
        # Section header construction: create structured representation
        section_header = SectionHeader(
            name, type, flags, addr, offset, size,
            link, info, addralign, entsize
        )
        
        push!(sections, section_header)                    # ↔ accumulation: sections = sections ∪ {s}
    end
    
    return sections                                        # ↔ List(SectionHeader) result
end

"""
    parse_section_headers(filename::String, elf_header::ElfHeader) -> Vector{SectionHeader}

Mathematical model: π_sections_file: FilePath × ElfHeader → List(SectionHeader)
Parse section headers from a file using file I/O abstraction.

File I/O monad: IO operation lifted over file handle.
"""
function parse_section_headers(filename::String, elf_header::ElfHeader)
    # File I/O monad: lift parse_section_headers over file handle
    open(filename, "r") do io                              # ↔ file handle acquisition
        parse_section_headers(io, elf_header)              # ↔ π_sections application
    end
end

"""
    read_string_table(io::IO, section::SectionHeader) -> Vector{UInt8}

Read a string table section from the ELF file.
"""
function read_string_table(io::IO, section::SectionHeader)
    seek(io, section.offset)
    return read(io, section.size)
end

"""
    get_string_from_table(string_table::Vector{UInt8}, offset::UInt32) -> String

Extract a null-terminated string from a string table at the given offset.
"""
function get_string_from_table(string_table::Vector{UInt8}, offset::UInt32)
    if offset >= length(string_table)
        return ""
    end
    
    start_idx = firstindex(string_table) + offset
    end_idx = start_idx
    
    # Find null terminator
    while end_idx <= length(string_table) && string_table[end_idx] != 0
        end_idx += 1
    end
    
    if end_idx > start_idx
        return String(string_table[start_idx:end_idx-1])
    else
        return ""
    end
end

"""
    parse_symbol_table(io::IO, section::SectionHeader) -> Vector{SymbolTableEntry}

Parse a symbol table section from the ELF file.
"""
function parse_symbol_table(io::IO, section::SectionHeader)
    symbols = Vector{SymbolTableEntry}()
    
    if section.entsize == 0
        return symbols
    end
    
    num_symbols = div(section.size, section.entsize)
    seek(io, section.offset)
    
    for i in 1:num_symbols
        name = read(io, UInt32)
        info = read(io, UInt8)
        other = read(io, UInt8)
        shndx = read(io, UInt16)
        value = read(io, UInt64)
        size = read(io, UInt64)
        
        push!(symbols, SymbolTableEntry(name, info, other, shndx, value, size))
    end
    
    return symbols
end

"""
    parse_relocations(io::IO, section::SectionHeader, target_section_index::UInt16) -> Vector{RelocationEntry}

Parse a relocation section from the ELF file with target section context.
"""
function parse_relocations(io::IO, section::SectionHeader, target_section_index::UInt16)
    relocations = Vector{RelocationEntry}()
    
    if section.entsize == 0
        return relocations
    end
    
    num_relocations = div(section.size, section.entsize)
    seek(io, section.offset)
    
    for i in 1:num_relocations
        offset = read(io, UInt64)
        info = read(io, UInt64)
        addend = read(io, Int64)
        
        push!(relocations, RelocationEntry(offset, info, addend, target_section_index))
    end
    
    return relocations
end

"""
    find_section_by_name(sections::Vector{SectionHeader}, string_table::Vector{UInt8}, name::String) -> Union{SectionHeader, Nothing}

Find a section by its name.
"""
function find_section_by_name(sections::Vector{SectionHeader}, string_table::Vector{UInt8}, name::String)
    for section in sections
        section_name = get_string_from_table(string_table, section.name)
        if section_name == name
            return section
        end
    end
    return nothing
end

"""
    find_section_by_type(sections::Vector{SectionHeader}, section_type::UInt32) -> Vector{SectionHeader}

Find all sections of a specific type.
"""
function find_section_by_type(sections::Vector{SectionHeader}, section_type::UInt32)
    return filter(section -> section.type == section_type, sections)
end

"""
    ElfFile

A structure to hold parsed ELF file information.
"""
struct ElfFile
    filename::String
    header::ElfHeader
    sections::Vector{SectionHeader}
    string_table::Vector{UInt8}
    symbols::Vector{SymbolTableEntry}
    symbol_string_table::Vector{UInt8}
    relocations::Vector{RelocationEntry}
end

"""
    parse_elf_file(filename::String) -> ElfFile

Parse an entire ELF file and return structured information.
"""
function parse_elf_file(filename::String)
    open(filename, "r") do io
        # Parse header
        header = parse_elf_header(io)
        
        # Parse section headers
        sections = parse_section_headers(io, header)
        
        # Read section header string table
        shstrtab_section = sections[begin + header.shstrndx]
        string_table = read_string_table(io, shstrtab_section)
        
        # Find and parse symbol table
        symbols = SymbolTableEntry[]
        symbol_string_table = UInt8[]
        
        symtab_sections = find_section_by_type(sections, UInt32(SHT_SYMTAB))
        if !isempty(symtab_sections)
            symtab_section = symtab_sections[1]
            symbols = parse_symbol_table(io, symtab_section)
            
            # Read symbol string table
            if symtab_section.link > 0 && symtab_section.link < length(sections)
                strtab_section = sections[begin + symtab_section.link]
                symbol_string_table = read_string_table(io, strtab_section)
            end
        end
        
        # Find and parse relocations - process ALL relocation sections for production readiness
        relocations = RelocationEntry[]
        rela_sections = find_section_by_type(sections, UInt32(SHT_RELA))
        for rela_section in rela_sections
            # Get the section name for debugging
            section_name = get_string_from_table(string_table, rela_section.name)
            
            # Process all relocation sections (not just .rela.text)
            # This is essential for linking complex programs like TinyCC
            target_section_index = UInt16(rela_section.info)  # info field contains target section index
            parsed_relocations = parse_relocations(io, rela_section, target_section_index)
            
            append!(relocations, parsed_relocations)
        end
        
        return ElfFile(
            filename, header, sections, string_table,
            symbols, symbol_string_table, relocations
        )
    end
end