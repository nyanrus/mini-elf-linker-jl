# ELF Parser Implementation
# Functions to parse ELF files and extract necessary information

"""
    parse_elf_header(io::IO) -> ElfHeader

Parse the ELF header from an IO stream.
"""
function parse_elf_header(io::IO)
    # Read the ELF header (64 bytes for 64-bit ELF)
    magic = ntuple(i -> read(io, UInt8), 4)
    
    # Verify ELF magic
    if magic != ELF_MAGIC
        error("Invalid ELF magic number: $(magic)")
    end
    
    class = read(io, UInt8)
    data = read(io, UInt8)
    version = read(io, UInt8)
    osabi = read(io, UInt8)
    abiversion = read(io, UInt8)
    pad = ntuple(i -> read(io, UInt8), 7)
    
    # Read the rest of the header
    type = read(io, UInt16)
    machine = read(io, UInt16)
    version2 = read(io, UInt32)
    entry = read(io, UInt64)
    phoff = read(io, UInt64)
    shoff = read(io, UInt64)
    flags = read(io, UInt32)
    ehsize = read(io, UInt16)
    phentsize = read(io, UInt16)
    phnum = read(io, UInt16)
    shentsize = read(io, UInt16)
    shnum = read(io, UInt16)
    shstrndx = read(io, UInt16)
    
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

Parse all section headers from an ELF file.
"""
function parse_section_headers(io::IO, elf_header::ElfHeader)
    sections = Vector{SectionHeader}()
    
    # Seek to section header table
    seek(io, elf_header.shoff)
    
    for i in 1:elf_header.shnum
        name = read(io, UInt32)
        type = read(io, UInt32)
        flags = read(io, UInt64)
        addr = read(io, UInt64)
        offset = read(io, UInt64)
        size = read(io, UInt64)
        link = read(io, UInt32)
        info = read(io, UInt32)
        addralign = read(io, UInt64)
        entsize = read(io, UInt64)
        
        push!(sections, SectionHeader(
            name, type, flags, addr, offset, size,
            link, info, addralign, entsize
        ))
    end
    
    return sections
end

"""
    parse_section_headers(filename::String, elf_header::ElfHeader) -> Vector{SectionHeader}

Parse section headers from a file.
"""
function parse_section_headers(filename::String, elf_header::ElfHeader)
    open(filename, "r") do io
        parse_section_headers(io, elf_header)
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
    
    start_idx = offset + 1  # Julia 1-based indexing
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
    parse_relocations(io::IO, section::SectionHeader) -> Vector{RelocationEntry}

Parse a relocation section from the ELF file.
"""
function parse_relocations(io::IO, section::SectionHeader)
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
        
        push!(relocations, RelocationEntry(offset, info, addend))
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
        shstrtab_section = sections[header.shstrndx + 1]  # +1 for Julia indexing
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
                strtab_section = sections[symtab_section.link + 1]  # +1 for Julia 1-based indexing
                symbol_string_table = read_string_table(io, strtab_section)
            end
        end
        
        # Find and parse relocations - only include .text relocations for now
        relocations = RelocationEntry[]
        rela_sections = find_section_by_type(sections, UInt32(SHT_RELA))
        for rela_section in rela_sections
            # Get the section name to filter out non-text relocations
            section_name = get_string_from_table(string_table, rela_section.name)
            
            # Only process .rela.text sections for basic linking
            if section_name == ".rela.text"
                append!(relocations, parse_relocations(io, rela_section))
            end
        end
        
        return ElfFile(
            filename, header, sections, string_table,
            symbols, symbol_string_table, relocations
        )
    end
end