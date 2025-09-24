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
    create_program_headers(linker::DynamicLinker, elf_header_size::UInt64, ph_table_size::UInt64) -> Vector{ProgramHeader}

Create proper program headers that include ELF headers in the first LOAD segment.

Mathematical model for proper ELF segment layout:
```math
\\begin{align}
header\\_segment &= \\{ELF\\_header, program\\_headers, text\\_sections\\} \\\\
rodata\\_segment &= \\{read\\_only\\_sections\\} \\\\
data\\_segment &= \\{writable\\_sections\\}
\\end{align}
```
"""
function create_program_headers(linker::DynamicLinker, elf_header_size::UInt64, ph_table_size::UInt64)
    if isempty(linker.memory_regions)
        return ProgramHeader[]
    end
    
    # Group memory regions by permissions
    text_regions = MemoryRegion[]      # R+X (executable)
    rodata_regions = MemoryRegion[]    # R (read-only data)
    data_regions = MemoryRegion[]      # R+W (writable data)
    
    for region in linker.memory_regions
        perms = region.permissions
        if (perms & 0x4) != 0  # Execute permission - text segment
            push!(text_regions, region)
        elseif (perms & 0x2) != 0  # Write permission - data segment  
            push!(data_regions, region)
        else  # Read-only - rodata segment
            push!(rodata_regions, region)
        end
    end
    
    program_headers = ProgramHeader[]
    
    # Calculate base address - should be page-aligned
    base_addr = 0x400000  # Standard base address
    headers_size = elf_header_size + ph_table_size + 0x1000  # Add padding
    
    # Create first LOAD segment: ELF headers + text regions
    if !isempty(text_regions)
        min_text_addr = minimum(r.base_address for r in text_regions)
        max_text_addr = maximum(r.base_address + r.size for r in text_regions)
        
        # First segment should start at the lowest address to include _start and all text regions
        # This covers both synthetic _start and main code regions
        first_vaddr = min_text_addr & ~UInt64(0xfff)  # Round down to page boundary (4KB)
        
        # Calculate total size from first address through all text regions
        total_size = max_text_addr - first_vaddr
        
        push!(program_headers, ProgramHeader(
            PT_LOAD,                    # type
            PF_R | PF_X,               # flags (Read + Execute) 
            0,                         # offset (starts at file beginning)
            first_vaddr,               # vaddr
            first_vaddr,               # paddr
            total_size,                # filesz
            total_size,                # memsz
            0x1000                     # align (4KB)
        ))
    end
    
    # Create rodata segment (R) if we have read-only regions
    if !isempty(rodata_regions)
        min_addr = minimum(r.base_address for r in rodata_regions)
        max_addr = maximum(r.base_address + r.size for r in rodata_regions)
        total_size = max_addr - min_addr
        
        push!(program_headers, ProgramHeader(
            PT_LOAD,                    # type
            PF_R,                      # flags (Read only)
            0,                         # offset (to be filled)
            min_addr,                  # vaddr
            min_addr,                  # paddr
            total_size,                # filesz
            total_size,                # memsz
            0x1000                     # align (4KB)
        ))
    end
    
    # Create data segment (R+W) if we have writable regions  
    if !isempty(data_regions)
        min_addr = minimum(r.base_address for r in data_regions)
        max_addr = maximum(r.base_address + r.size for r in data_regions)
        total_size = max_addr - min_addr
        
        push!(program_headers, ProgramHeader(
            PT_LOAD,                    # type
            PF_R | PF_W,               # flags (Read + Write)
            0,                         # offset (to be filled)
            min_addr,                  # vaddr
            min_addr,                  # paddr
            total_size,                # filesz
            total_size,                # memsz
            0x1000                     # align (4KB)
        ))
    end
    
    # Add GNU_STACK program header (required for modern Linux executables)
    push!(program_headers, ProgramHeader(
        PT_GNU_STACK,               # type
        PF_R | PF_W,               # flags (Read + Write, no Execute)
        0,                         # offset (not applicable for GNU_STACK)
        0,                         # vaddr (not applicable for GNU_STACK)
        0,                         # paddr (not applicable for GNU_STACK)  
        0,                         # filesz (not applicable for GNU_STACK)
        0,                         # memsz (not applicable for GNU_STACK)
        0x10                       # align (16-byte alignment)
    ))
    
    return program_headers
end

"""
    write_elf_executable(linker::DynamicLinker, output_filename::String; entry_point::UInt64 = 0x401000)

Write an executable ELF file from the linker state.
"""
function write_elf_executable(linker::DynamicLinker, output_filename::String; entry_point::UInt64 = UInt64(0x401000))
    open(output_filename, "w") do io
        # Calculate layout
        elf_header_size = 64  # ELF64 header size
        # We need to calculate program headers in two passes since we need the count
        temp_headers = create_program_headers(linker, UInt64(elf_header_size), UInt64(0))
        ph_table_size = length(temp_headers) * 56  # Program header size is 56 bytes for ELF64
        
        # Create program headers with correct sizes
        program_headers = create_program_headers(linker, UInt64(elf_header_size), UInt64(ph_table_size))
        
        # Calculate data offset (after headers)
        data_offset = elf_header_size + ph_table_size
        
        # Align data to page boundary
        page_size = 0x1000
        data_offset = (data_offset + page_size - 1) & ~(page_size - 1)
        
        # Update program header file offsets
        current_offset = data_offset
        for (i, ph) in enumerate(program_headers)
            if ph.type == PT_LOAD
                if i == 1  # First LOAD segment starts at offset 0 (includes ELF headers)
                    program_headers[i] = ProgramHeader(
                        ph.type, ph.flags, 0, ph.vaddr, ph.paddr,
                        ph.filesz, ph.memsz, ph.align
                    )
                else  # Subsequent LOAD segments start after data
                    program_headers[i] = ProgramHeader(
                        ph.type, ph.flags, current_offset, ph.vaddr, ph.paddr,
                        ph.filesz, ph.memsz, ph.align
                    )
                    current_offset += ph.filesz
                end
            end
            # Non-LOAD segments (like GNU_STACK) keep their original offsets
        end
        
        # Create ELF header for executable
        elf_header = ElfHeader(
            ELF_MAGIC,                  # magic
            ELFCLASS64,                 # class
            ELFDATA2LSB,                # data
            EV_CURRENT,                 # version
            ELFOSABI_GNU,               # osabi (GNU/Linux)
            0,                          # abiversion
            (0, 0, 0, 0, 0, 0, 0),     # pad
            ET_EXEC,                    # type - EXEC (Static Executable)
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
        
        # Write segment data by grouping memory regions
        for (segment_idx, ph) in enumerate(program_headers)
            # Skip non-LOAD segments
            if ph.type != PT_LOAD
                continue
            end
            
            # Find all memory regions that belong to this segment
            segment_regions = filter(linker.memory_regions) do region
                region.base_address >= ph.vaddr && 
                region.base_address < ph.vaddr + ph.memsz
            end
            
            # Sort regions by address
            sort!(segment_regions, by=r -> r.base_address)
            
            # For segments, calculate the correct file offset based on virtual address mapping
            if ph.type == PT_LOAD && ph.vaddr == 0x400000  # First LOAD segment includes ELF headers
                # For the first LOAD segment, we need to write regions at their correct file offsets
                # But avoid overwriting the ELF header and program headers
                headers_end = elf_header_size + length(program_headers) * 56
                
                for region in segment_regions
                    region_file_offset = region.base_address - ph.vaddr  # Offset within segment
                    
                    # Only write if the region doesn't overlap with headers
                    if region_file_offset >= headers_end
                        seek(io, region_file_offset)
                        write(io, region.data)
                    end
                end
            else
                # Other segments use their specified file offset
                seek(io, ph.offset)
                
                # Write all regions in this segment, padding gaps if needed
                current_addr = ph.vaddr
                for region in segment_regions
                    # Add padding if there's a gap
                    if region.base_address > current_addr
                        gap_size = region.base_address - current_addr
                        for _ in 1:gap_size
                            write(io, UInt8(0))
                        end
                    end
                    
                    # Write the region data
                    write(io, region.data)
                    current_addr = region.base_address + region.size
                end
                
                # Pad to end of segment if needed
                segment_end = ph.vaddr + ph.filesz
                if current_addr < segment_end
                    remaining = segment_end - current_addr
                    for _ in 1:remaining
                        write(io, UInt8(0))
                    end
                end
            end
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