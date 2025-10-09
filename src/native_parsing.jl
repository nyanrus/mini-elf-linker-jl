# Native ELF and Archive parsing for library support
# This replaces external tool dependencies (nm, objdump) with direct binary parsing
# Uses unified ELF constants and structures from elf_format.jl
#
# Implementation Note: This module provides endianness-aware parsing (supporting both
# little-endian and big-endian) while reusing canonical ELF data structures. It complements
# elf_parser.jl which assumes little-endian format for performance.

"""
    Archive magic constant for native parsing
"""
const AR_MAGIC = b"!<arch>\n"  # Archive magic

# Helper constants for cleaner code - map to canonical ELF format constants
const ELF_MAGIC_BYTES = UInt8[0x7f, 0x45, 0x4c, 0x46]  # "\x7fELF" as bytes for comparison

"""
    FileType

Enum for different file types detected by magic bytes.
"""
@enum FileType ELF_FILE AR_FILE LINKER_SCRIPT UNKNOWN_FILE

"""
    detect_file_type_by_magic(file_path::String) -> FileType

Detect file type using magic bytes instead of filename extension.
"""
function detect_file_type_by_magic(file_path::String)
    if !isfile(file_path)
        return UNKNOWN_FILE
    end
    
    try
        open(file_path, "r") do file
            # Read first 8 bytes to check magic
            magic_bytes = read(file, 8)
            
            if length(magic_bytes) >= 4 && magic_bytes[1:4] == ELF_MAGIC_BYTES
                return ELF_FILE
            elseif length(magic_bytes) >= 8 && magic_bytes == AR_MAGIC
                return AR_FILE
            else
                # Check if it's a linker script (text file)
                seekstart(file)
                try
                    # Try to read a larger portion to check for linker script
                    content = read(file, min(512, filesize(file_path)))
                    content_str = String(content)
                    if occursin("GROUP", content_str) || occursin("OUTPUT_FORMAT", content_str) || 
                       occursin("GNU ld script", content_str)
                        return LINKER_SCRIPT
                    end
                catch
                    # If can't read as string, it's binary but unknown
                end
                return UNKNOWN_FILE  # Add explicit return
            end
        end
    catch e
        println("Warning: Failed to read magic bytes from $file_path: $e")
        return UNKNOWN_FILE  # Add explicit return
    end
end

"""
    parse_native_elf_header(file_path::String) -> Union{ElfHeader, Nothing}

Parse ELF header from file using native binary reading.
Returns canonical ElfHeader structure from elf_format.jl.
"""
function parse_native_elf_header(file_path::String)
    if detect_file_type_by_magic(file_path) != ELF_FILE
        return nothing
    end
    
    try
        open(file_path, "r") do file
            # Read and validate magic
            magic = ntuple(i -> read(file, UInt8), 4)
            
            class = read(file, UInt8)
            data = read(file, UInt8)
            version = read(file, UInt8)
            osabi = read(file, UInt8)
            abiversion = read(file, UInt8)
            
            # Skip padding
            pad = ntuple(i -> read(file, UInt8), 7)
            
            # Read rest of header based on endianness
            little_endian = (data == ELFDATA2LSB)
            
            if little_endian
                type = ltoh(read(file, UInt16))
                machine = ltoh(read(file, UInt16))
                version2 = ltoh(read(file, UInt32))
                
                if class == ELFCLASS64
                    entry = ltoh(read(file, UInt64))
                    phoff = ltoh(read(file, UInt64))
                    shoff = ltoh(read(file, UInt64))
                else
                    entry = UInt64(ltoh(read(file, UInt32)))
                    phoff = UInt64(ltoh(read(file, UInt32)))
                    shoff = UInt64(ltoh(read(file, UInt32)))
                end
                
                flags = ltoh(read(file, UInt32))
                ehsize = ltoh(read(file, UInt16))
                phentsize = ltoh(read(file, UInt16))
                phnum = ltoh(read(file, UInt16))
                shentsize = ltoh(read(file, UInt16))
                shnum = ltoh(read(file, UInt16))
                shstrndx = ltoh(read(file, UInt16))
            else
                type = ntoh(read(file, UInt16))
                machine = ntoh(read(file, UInt16))
                version2 = ntoh(read(file, UInt32))
                
                if class == ELFCLASS64
                    entry = ntoh(read(file, UInt64))
                    phoff = ntoh(read(file, UInt64))
                    shoff = ntoh(read(file, UInt64))
                else
                    entry = UInt64(ntoh(read(file, UInt32)))
                    phoff = UInt64(ntoh(read(file, UInt32)))
                    shoff = UInt64(ntoh(read(file, UInt32)))
                end
                
                flags = ntoh(read(file, UInt32))
                ehsize = ntoh(read(file, UInt16))
                phentsize = ntoh(read(file, UInt16))
                phnum = ntoh(read(file, UInt16))
                shentsize = ntoh(read(file, UInt16))
                shnum = ntoh(read(file, UInt16))
                shstrndx = ntoh(read(file, UInt16))
            end
            
            return ElfHeader(magic, class, data, version, osabi, abiversion, pad,
                           type, machine, version2, entry, phoff, shoff, flags,
                           ehsize, phentsize, phnum, shentsize, shnum, shstrndx)
        end
    catch e
        println("Warning: Failed to parse ELF header from $file_path: $e")
        return nothing
    end
end

"""
    read_section_header_64(file::IO, little_endian::Bool) -> SectionHeader

Helper function to read a 64-bit section header with endianness handling.
"""
function read_section_header_64(file::IO, little_endian::Bool)
    # Use appropriate byte order conversion based on endianness
    convert_fn = little_endian ? ltoh : ntoh
    
    name = convert_fn(read(file, UInt32))
    type = convert_fn(read(file, UInt32))
    flags = convert_fn(read(file, UInt64))
    addr = convert_fn(read(file, UInt64))
    offset = convert_fn(read(file, UInt64))
    size = convert_fn(read(file, UInt64))
    link = convert_fn(read(file, UInt32))
    info = convert_fn(read(file, UInt32))
    addralign = convert_fn(read(file, UInt64))
    entsize = convert_fn(read(file, UInt64))
    
    return SectionHeader(name, type, flags, addr, offset, size, link, info, addralign, entsize)
end

"""
    extract_elf_symbols_native(file_path::String) -> Set{String}

Extract symbols from ELF file using native parsing (no external tools).
"""
function extract_elf_symbols_native(file_path::String)
    symbols = Set{String}()
    
    header = parse_native_elf_header(file_path)
    if header === nothing
        return symbols
    end
    
    try
        open(file_path, "r") do file
            little_endian = (header.data == ELFDATA2LSB)
            is_64bit = (header.class == ELFCLASS64)
            
            # Read section headers
            if header.shoff == 0 || header.shnum == 0
                return symbols  # No sections
            end
            
            seek(file, header.shoff)
            section_headers = []
            
            for i in 1:header.shnum
                if is_64bit
                    push!(section_headers, read_section_header_64(file, little_endian))
                else
                    # 32-bit ELF handling would go here
                    # For now, focus on 64-bit
                    break
                end
            end
            
            # Find symbol tables and string tables
            for (i, section) in enumerate(section_headers)
                if section.type == SHT_SYMTAB || section.type == SHT_DYNSYM
                    # Found symbol table, get corresponding string table
                    strtab_section = nothing
                    
                    # First try the link field
                    if section.link > 0 && section.link <= length(section_headers)
                        candidate = section_headers[section.link]
                        # Check if it's actually a string table and not pointing to itself
                        if candidate.type == SHT_STRTAB && section.link != i
                            strtab_section = candidate
                        end
                    end
                    
                    # If link field doesn't work (common with dynamic symbols), find the largest string table
                    if strtab_section === nothing && section.type == SHT_DYNSYM
                        largest_strtab = nothing
                        largest_size = 0
                        for candidate in section_headers
                            if candidate.type == SHT_STRTAB && candidate.size > largest_size
                                largest_strtab = candidate
                                largest_size = candidate.size
                            end
                        end
                        strtab_section = largest_strtab
                    end
                    
                    if strtab_section !== nothing
                        # Read symbols
                        symbols_found = parse_symbol_table(file, section, strtab_section, little_endian, is_64bit)
                        union!(symbols, symbols_found)
                    end
                end
            end
        end
    catch e
        println("Warning: Failed to extract symbols from $file_path: $e")
    end
    
    return symbols
end

"""
    read_symbol_entry_64(file::IO, little_endian::Bool) -> SymbolTableEntry

Helper function to read a 64-bit symbol table entry with endianness handling.
"""
function read_symbol_entry_64(file::IO, little_endian::Bool)
    convert_fn = little_endian ? ltoh : ntoh
    
    name = convert_fn(read(file, UInt32))
    info = read(file, UInt8)
    other = read(file, UInt8)
    shndx = convert_fn(read(file, UInt16))
    value = convert_fn(read(file, UInt64))
    size = convert_fn(read(file, UInt64))
    
    return SymbolTableEntry(name, info, other, shndx, value, size)
end

"""
    parse_symbol_table(file, symtab_section, strtab_section, little_endian, is_64bit) -> Set{String}

Parse symbol table section and extract symbol names.
"""
function parse_symbol_table(file, symtab_section, strtab_section, little_endian, is_64bit)
    symbols = Set{String}()
    
    if symtab_section.size == 0 || symtab_section.entsize == 0
        return symbols
    end
    
    # Read string table
    seek(file, strtab_section.offset)
    string_table = read(file, strtab_section.size)
    
    # Read symbol table
    seek(file, symtab_section.offset)
    num_symbols = div(symtab_section.size, symtab_section.entsize)
    
    for i in 1:num_symbols
        if is_64bit
            symbol_entry = read_symbol_entry_64(file, little_endian)
            
            # Extract symbol name from string table
            if symbol_entry.name > 0 && symbol_entry.name < length(string_table)
                # Find null terminator
                name_end = findfirst(x -> x == 0, string_table[symbol_entry.name+1:end])
                if name_end !== nothing && name_end > 1
                    try
                        # Extract the byte range for the symbol name
                        symbol_bytes = string_table[symbol_entry.name+1:symbol_entry.name+name_end-1]
                        
                        # Validate that all bytes are valid ASCII/UTF-8 
                        if all(b -> 0x20 <= b <= 0x7E || b == 0x09, symbol_bytes)  # Printable ASCII + tab
                            symbol_name = String(copy(symbol_bytes))
                            
                            # Filter symbols (only global/weak defined symbols)
                            binding = symbol_entry.info >> 4
                            symbol_type = symbol_entry.info & 0xf
                            
                            # Include printf and other libc symbols - remove the underscore filter
                            if (binding == STB_GLOBAL || binding == STB_WEAK) && 
                               symbol_entry.shndx != 0 && !isempty(symbol_name) && length(symbol_name) > 0
                                push!(symbols, symbol_name)
                            end
                        end
                    catch e
                        # Skip symbols that can't be converted to valid strings
                        continue
                    end
                end
            end
        else
            # 32-bit symbol parsing would go here
            # Skip for now, focus on 64-bit
            break
        end
    end
    
    return symbols
end

"""
    extract_archive_symbols_native(file_path::String) -> Set{String}

Extract symbols from archive (.a) file using native parsing.
"""
function extract_archive_symbols_native(file_path::String)
    symbols = Set{String}()
    
    if detect_file_type_by_magic(file_path) != AR_FILE
        return symbols
    end
    
    try
        open(file_path, "r") do file
            # Skip archive magic
            seek(file, 8)
            
            while !eof(file)
                # Read archive member header (60 bytes)
                if position(file) + 60 > filesize(file_path)
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
                    
                    if magic == ELF_MAGIC_BYTES
                        # Create temporary file for the ELF object
                        temp_file = tempname() * ".o"
                        try
                            # Extract the ELF object to temp file
                            member_data = read(file, member_size)
                            write(temp_file, member_data)
                            
                            # Parse symbols from the extracted ELF object
                            member_symbols = extract_elf_symbols_native(temp_file)
                            union!(symbols, member_symbols)
                        finally
                            # Clean up temp file
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
    catch e
        println("Warning: Failed to extract symbols from archive $file_path: $e")
    end
    
    return symbols
end