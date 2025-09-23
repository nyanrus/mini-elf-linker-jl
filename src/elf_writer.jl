# ELF Writer Implementation
# Functions to write ELF executable files from linked objects

"""
    write_elf_header(io::IO, header::ElfHeader)

Write an ELF header to an IO stream.
"""
function write_elf_header(io::IO, header::ElfHeader)
    # Write magic
    for b in header.magic
        write(io, b)
    end
    
    # Write ELF identification
    write(io, header.class)
    write(io, header.data)
    write(io, header.version)
    write(io, header.osabi)
    write(io, header.abiversion)
    
    # Write padding
    for b in header.pad
        write(io, b)
    end
    
    # Write rest of header
    write(io, header.type)
    write(io, header.machine)
    write(io, header.version2)
    write(io, header.entry)
    write(io, header.phoff)
    write(io, header.shoff)
    write(io, header.flags)
    write(io, header.ehsize)
    write(io, header.phentsize)
    write(io, header.phnum)
    write(io, header.shentsize)
    write(io, header.shnum)
    write(io, header.shstrndx)
end

"""
    write_program_header(io::IO, ph::ProgramHeader)

Write a program header to an IO stream.
"""
function write_program_header(io::IO, ph::ProgramHeader)
    write(io, ph.type)
    write(io, ph.flags)
    write(io, ph.offset)
    write(io, ph.vaddr)
    write(io, ph.paddr)
    write(io, ph.filesz)
    write(io, ph.memsz)
    write(io, ph.align)
end

"""
    create_program_headers(linker::DynamicLinker) -> Vector{ProgramHeader}

Create program headers for the memory regions in the linker.
"""
function create_program_headers(linker::DynamicLinker)
    program_headers = ProgramHeader[]
    
    # Create LOAD segments for each memory region
    for region in linker.memory_regions
        flags = 0
        if region.permissions & 0x1 != 0  # Read
            flags |= PF_R
        end
        if region.permissions & 0x2 != 0  # Write  
            flags |= PF_W
        end
        if region.permissions & 0x4 != 0  # Execute
            flags |= PF_X
        end
        
        # Calculate file offset (will be updated when writing)
        file_offset = 0  # Will be set during layout
        
        ph = ProgramHeader(
            PT_LOAD,                    # type
            flags,                      # flags
            file_offset,                # offset (to be filled)
            region.base_address,        # vaddr
            region.base_address,        # paddr
            region.size,                # filesz
            region.size,                # memsz
            0x1000                      # align (4KB alignment)
        )
        
        push!(program_headers, ph)
    end
    
    return program_headers
end

"""
    write_elf_executable(linker::DynamicLinker, output_filename::String; entry_point::UInt64 = 0x401000)

Write an executable ELF file from the linker state.
"""
function write_elf_executable(linker::DynamicLinker, output_filename::String; entry_point::UInt64 = UInt64(0x401000))
    open(output_filename, "w") do io
        # Create program headers
        program_headers = create_program_headers(linker)
        
        # Calculate layout
        elf_header_size = 64  # ELF64 header size
        ph_table_size = length(program_headers) * 56  # Program header size is 56 bytes for ELF64
        
        # Calculate data offset (after headers)
        data_offset = elf_header_size + ph_table_size
        
        # Align data to page boundary
        page_size = 0x1000
        data_offset = (data_offset + page_size - 1) & ~(page_size - 1)
        
        # Update program header file offsets
        current_offset = data_offset
        for (i, ph) in enumerate(program_headers)
            program_headers[i] = ProgramHeader(
                ph.type, ph.flags, current_offset, ph.vaddr, ph.paddr,
                ph.filesz, ph.memsz, ph.align
            )
            current_offset += ph.filesz
        end
        
        # Create ELF header for executable
        elf_header = ElfHeader(
            ELF_MAGIC,                  # magic
            ELFCLASS64,                 # class
            ELFDATA2LSB,                # data
            EV_CURRENT,                 # version
            0,                          # osabi (SYSV)
            0,                          # abiversion
            (0, 0, 0, 0, 0, 0, 0),     # pad
            ET_EXEC,                    # type - EXECUTABLE
            EM_X86_64,                  # machine
            UInt32(EV_CURRENT),         # version2
            entry_point,                # entry
            UInt64(elf_header_size),    # phoff
            UInt64(0),                  # shoff (no section headers for now)
            UInt32(0),                  # flags
            UInt16(elf_header_size),    # ehsize
            UInt16(56),                 # phentsize (program header entry size)
            UInt16(length(program_headers)), # phnum
            UInt16(0),                  # shentsize (no sections)
            UInt16(0),                  # shnum (no sections)
            UInt16(0)                   # shstrndx (no string table)
        )
        
        # Write ELF header
        write_elf_header(io, elf_header)
        
        # Write program headers
        for ph in program_headers
            write_program_header(io, ph)
        end
        
        # Pad to data offset
        current_pos = position(io)
        padding_needed = data_offset - current_pos
        for _ in 1:padding_needed
            write(io, UInt8(0))
        end
        
        # Write memory region data
        for (i, region) in enumerate(linker.memory_regions)
            # Ensure we're at the correct offset
            expected_pos = program_headers[i].offset
            current_pos = position(io)
            if current_pos != expected_pos
                seek(io, expected_pos)
            end
            
            # Write the region data
            write(io, region.data)
        end
    end
    
    # Make the file executable
    try
        run(`chmod +x $output_filename`)
    catch e
        println("Warning: Could not make file executable: $e")
    end
    
    println("Executable written to: $output_filename")
end