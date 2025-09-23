# Native ELF and Archive parsing for library support
# This replaces external tool dependencies (nm, objdump) with direct binary parsing

"""
    ELF Magic bytes and constants for native parsing
"""
const NATIVE_ELF_MAGIC = UInt8[0x7f, 0x45, 0x4c, 0x46]  # "\x7fELF"
const NATIVE_AR_MAGIC = b"!<arch>\n"  # Archive magic

const NATIVE_ELF_CLASS_32 = 0x01
const NATIVE_NATIVE_ELF_CLASS_64 = 0x02
const NATIVE_ELF_DATA_LSB = 0x01  # Little endian
const NATIVE_ELF_DATA_MSB = 0x02  # Big endian

const NATIVE_ET_NONE = 0x0000    # No file type
const NATIVE_ET_REL = 0x0001     # Relocatable file
const NATIVE_ET_EXEC = 0x0002    # Executable file  
const NATIVE_ET_DYN = 0x0003     # Shared object file
const NATIVE_ET_CORE = 0x0004    # Core file

const NATIVE_SHT_NULL = 0x00000000
const NATIVE_SHT_PROGBITS = 0x00000001
const NATIVE_SHT_SYMTAB = 0x00000002
const NATIVE_SHT_STRTAB = 0x00000003
const NATIVE_SHT_DYNSYM = 0x0000000b

const NATIVE_STB_LOCAL = 0
const NATIVE_STB_GLOBAL = 1
const NATIVE_STB_WEAK = 2

const NATIVE_STT_NOTYPE = 0
const NATIVE_STT_OBJECT = 1
const NATIVE_STT_FUNC = 2

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
            
            if length(magic_bytes) >= 4 && magic_bytes[1:4] == NATIVE_ELF_MAGIC
                return ELF_FILE
            elseif length(magic_bytes) >= 8 && magic_bytes == NATIVE_AR_MAGIC
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
    NativeElfHeader

Struct representing ELF header for native parsing.
"""
struct NativeElfHeader
    class::UInt8          # 32 or 64 bit
    data::UInt8           # Endianness
    version::UInt8        # ELF version
    osabi::UInt8          # OS/ABI
    abiversion::UInt8     # ABI version
    type::UInt16          # Object file type
    machine::UInt16       # Target architecture
    entry::UInt64         # Entry point address
    phoff::UInt64         # Program header offset
    shoff::UInt64         # Section header offset
    flags::UInt32         # Processor flags
    ehsize::UInt16        # ELF header size
    phentsize::UInt16     # Program header entry size
    phnum::UInt16         # Number of program headers
    shentsize::UInt16     # Section header entry size
    shnum::UInt16         # Number of section headers
    shstrndx::UInt16      # Section header string table index
end

"""
    NativeSectionHeader64

Struct representing 64-bit ELF section header for native parsing.
"""
struct NativeSectionHeader64
    name::UInt32          # Section name offset
    type::UInt32          # Section type
    flags::UInt64         # Section flags
    addr::UInt64          # Section virtual address
    offset::UInt64        # Section file offset
    size::UInt64          # Section size
    link::UInt32          # Link to other section
    info::UInt32          # Additional section information
    addralign::UInt64     # Section alignment
    entsize::UInt64       # Entry size if section has table
end

"""
    NativeSymbol64

Struct representing 64-bit ELF symbol table entry for native parsing.
"""
struct NativeSymbol64
    name::UInt32          # Symbol name offset
    info::UInt8           # Symbol type and binding
    other::UInt8          # Symbol visibility
    shndx::UInt16         # Section index
    value::UInt64         # Symbol value
    size::UInt64          # Symbol size
end

"""
    parse_native_elf_header(file_path::String) -> Union{NativeElfHeader, Nothing}

Parse ELF header from file using native binary reading.
"""
function parse_native_elf_header(file_path::String)
    if detect_file_type_by_magic(file_path) != ELF_FILE
        return nothing
    end
    
    try
        open(file_path, "r") do file
            # Skip magic (already verified)
            seek(file, 4)
            
            class = read(file, UInt8)
            data = read(file, UInt8)
            version = read(file, UInt8)
            osabi = read(file, UInt8)
            abiversion = read(file, UInt8)
            
            # Skip padding
            seek(file, 16)
            
            # Read rest of header based on endianness
            little_endian = (data == NATIVE_ELF_DATA_LSB)
            
            if little_endian
                type = ltoh(read(file, UInt16))
                machine = ltoh(read(file, UInt16))
                version32 = ltoh(read(file, UInt32))
                
                if class == NATIVE_ELF_CLASS_64
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
                version32 = ntoh(read(file, UInt32))
                
                if class == NATIVE_ELF_CLASS_64
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
            
            return NativeElfHeader(class, data, version, osabi, abiversion, type, machine,
                           entry, phoff, shoff, flags, ehsize, phentsize, phnum,
                           shentsize, shnum, shstrndx)
        end
    catch e
        println("Warning: Failed to parse ELF header from $file_path: $e")
        return nothing
    end
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
            little_endian = (header.data == ELF_DATA_LSB)
            is_64bit = (header.class == NATIVE_ELF_CLASS_64)
            
            # Read section headers
            if header.shoff == 0 || header.shnum == 0
                return symbols  # No sections
            end
            
            seek(file, header.shoff)
            section_headers = []
            
            for i in 1:header.shnum
                if is_64bit
                    if little_endian
                        name = ltoh(read(file, UInt32))
                        type = ltoh(read(file, UInt32))
                        flags = ltoh(read(file, UInt64))
                        addr = ltoh(read(file, UInt64))
                        offset = ltoh(read(file, UInt64))
                        size = ltoh(read(file, UInt64))
                        link = ltoh(read(file, UInt32))
                        info = ltoh(read(file, UInt32))
                        addralign = ltoh(read(file, UInt64))
                        entsize = ltoh(read(file, UInt64))
                    else
                        name = ntoh(read(file, UInt32))
                        type = ntoh(read(file, UInt32))
                        flags = ntoh(read(file, UInt64))
                        addr = ntoh(read(file, UInt64))
                        offset = ntoh(read(file, UInt64))
                        size = ntoh(read(file, UInt64))
                        link = ntoh(read(file, UInt32))
                        info = ntoh(read(file, UInt32))
                        addralign = ntoh(read(file, UInt64))
                        entsize = ntoh(read(file, UInt64))
                    end
                    
                    push!(section_headers, NativeSectionHeader64(name, type, flags, addr, offset, size, link, info, addralign, entsize))
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
                    if section.link > 0 && section.link <= length(section_headers)
                        strtab_section = section_headers[section.link]
                        
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
            if little_endian
                name_offset = ltoh(read(file, UInt32))
                info = read(file, UInt8)
                other = read(file, UInt8)
                shndx = ltoh(read(file, UInt16))
                value = ltoh(read(file, UInt64))
                size = ltoh(read(file, UInt64))
            else
                name_offset = ntoh(read(file, UInt32))
                info = read(file, UInt8)
                other = read(file, UInt8)
                shndx = ntoh(read(file, UInt16))
                value = ntoh(read(file, UInt64))
                size = ntoh(read(file, UInt64))
            end
            
            # Extract symbol name from string table
            if name_offset > 0 && name_offset < length(string_table)
                # Find null terminator
                name_end = findfirst(x -> x == 0, string_table[name_offset+1:end])
                if name_end !== nothing
                    symbol_name = String(string_table[name_offset+1:name_offset+name_end-1])
                    
                    # Filter symbols (only global/weak defined symbols)
                    binding = info >> 4
                    symbol_type = info & 0xf
                    
                    if (binding == STB_GLOBAL || binding == STB_WEAK) && 
                       shndx != 0 && !isempty(symbol_name) && !startswith(symbol_name, "_")
                        push!(symbols, symbol_name)
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
                    
                    if magic == ELF_MAGIC
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