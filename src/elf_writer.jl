# ELF Writer Implementation
# Mathematical model: ω: D → R where D = Linked objects × Memory layouts × Entry points
# Functions to write ELF executable files from linked objects following rigorous mathematical specification

"""
    write_elf_header(io::IO, header::ElfHeader)

Mathematical model: ω_header_write: IO × ElfHeader → IO
Write an ELF header to an IO stream with sequential field serialization.

Serialization mapping: header_fields ↦ binary_representation
Each field f ∈ header mapped to write(io, f) operation.
"""
function write_elf_header(io::IO, header::ElfHeader)
    # Sequential field serialization: ∀f ∈ header_fields: write(io, f)
    
    # ELF magic signature: magic = (0x7f, 'E', 'L', 'F')
    for b in header.magic                                   # ↔ magic serialization
        write(io, b)
    end
    
    # ELF identification fields: sequential byte writing
    write(io, header.class)                                # ↔ architecture class
    write(io, header.data)                                 # ↔ endianness specification
    write(io, header.version)                              # ↔ version number
    write(io, header.osabi)                                # ↔ OS/ABI identification
    write(io, header.abiversion)                           # ↔ ABI version
    
    # Padding bytes: maintain header structure alignment
    for b in header.pad                                    # ↔ padding serialization
        write(io, b)
    end
    
    # Core header fields: structured data serialization
    write(io, header.type)                                 # ↔ object file type
    write(io, header.machine)                              # ↔ machine architecture
    write(io, header.version2)                             # ↔ object file version
    write(io, header.entry)                                # ↔ α_entry entry point
    write(io, header.phoff)                                # ↔ program header offset
    write(io, header.shoff)                                # ↔ section header offset
    write(io, header.flags)                                # ↔ processor flags
    write(io, header.ehsize)                               # ↔ ELF header size
    write(io, header.phentsize)                            # ↔ program header entry size
    write(io, header.phnum)                                # ↔ program header count
    write(io, header.shentsize)                            # ↔ section header entry size
    write(io, header.shnum)                                # ↔ section header count
    write(io, header.shstrndx)                             # ↔ string table index
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
    
    # Add PT_PHDR program header FIRST (required for PIE executables)
    # This describes the program header table itself and MUST come before LOAD segments
    push!(program_headers, ProgramHeader(
        PT_PHDR,                    # type
        PF_R,                      # flags (Read only)
        UInt64(elf_header_size),   # offset (right after ELF header)
        base_addr + UInt64(elf_header_size), # vaddr
        base_addr + UInt64(elf_header_size), # paddr
        UInt64(ph_table_size),     # filesz (size of program header table)
        UInt64(ph_table_size),     # memsz
        0x8                        # align (8-byte alignment)
    ))
    
    # First LOAD segment: ELF headers + Program headers (Read-only, NO execute!)
    # This LOAD segment must cover both ELF header and program header table
    headers_end = elf_header_size + ph_table_size
    push!(program_headers, ProgramHeader(
        PT_LOAD,                    # type
        PF_R,                      # flags (Read only - headers should not be executable!)
        0,                         # offset (starts at file beginning)
        base_addr,                 # vaddr (0x400000)
        base_addr,                 # paddr
        UInt64(max(0x1000, headers_end)), # filesz (at least 4KB to cover headers)
        UInt64(max(0x1000, headers_end)), # memsz
        0x1000                     # align (4KB)
    ))
    
    # Second LOAD segment: Executable code regions (Read + Execute)
    if !isempty(text_regions)
        min_text_addr = minimum(r.base_address for r in text_regions)
        max_text_addr = maximum(r.base_address + r.size for r in text_regions)
        
        # Calculate file offset for text segment - must match write_elf_executable calculation
        # data_offset = elf_header_size + ph_table_size, then page-aligned
        data_offset_calc = elf_header_size + ph_table_size
        page_size = 0x1000
        text_file_offset = (data_offset_calc + page_size - 1) & ~(page_size - 1)
        total_size = max_text_addr - min_text_addr
        
        push!(program_headers, ProgramHeader(
            PT_LOAD,                    # type
            PF_R | PF_X,               # flags (Read + Execute) 
            text_file_offset,          # offset (after headers)
            min_text_addr,             # vaddr (where text is loaded)
            min_text_addr,             # paddr
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
    
    # Add PT_INTERP program header for dynamic linking (if dynamic symbols present)
    if !isempty(linker.dynamic_section.entries)
        # Standard Linux x86-64 dynamic linker path
        interp_path = "/lib64/ld-linux-x86-64.so.2"
        interp_size = UInt64(length(interp_path) + 1)  # +1 for null terminator
        
        # Find a suitable location for the interpreter string (after headers)
        interp_offset = elf_header_size + ph_table_size + 0x40  # Some padding
        interp_vaddr = base_addr + interp_offset
        
        push!(program_headers, ProgramHeader(
            PT_INTERP,                  # type
            PF_R,                      # flags (Read only)
            interp_offset,             # offset in file
            interp_vaddr,              # virtual address
            interp_vaddr,              # physical address  
            interp_size,               # size in file
            interp_size,               # size in memory
            0x1                        # align (byte alignment)
        ))
    end
    
    # Add PT_DYNAMIC program header for dynamic section
    if !isempty(linker.dynamic_section.entries)
        # Find the dynamic section memory region
        dynamic_region = nothing
        for region in linker.memory_regions
            # Look for region that looks like dynamic section (read-only, proper size)
            if region.permissions == 0x4 && length(region.data) == length(linker.dynamic_section.entries) * 16
                dynamic_region = region
                break
            end
        end
        
        if dynamic_region !== nothing
            # Calculate dynamic section file offset based on virtual address mapping
            # The dynamic section offset will be calculated later in write_elf_executable
            # For now, use placeholder offset that will be corrected later
            dynamic_offset = UInt64(0)  # Placeholder - will be calculated in write phase
            
            push!(program_headers, ProgramHeader(
                PT_DYNAMIC,                # type
                PF_R | PF_W,              # flags (Read + Write for runtime updates)
                dynamic_offset,            # offset in file (to be calculated later)
                dynamic_region.base_address, # virtual address
                dynamic_region.base_address, # physical address
                dynamic_region.size,       # size in file
                dynamic_region.size,       # size in memory
                0x8                        # align (8-byte alignment for 64-bit)
            ))
        end
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
        first_load = true
        for (i, ph) in enumerate(program_headers)
            if ph.type == PT_LOAD
                if first_load && ph.vaddr == 0x400000  # First LOAD segment starts at offset 0 (includes ELF headers)
                    program_headers[i] = ProgramHeader(
                        ph.type, ph.flags, 0, ph.vaddr, ph.paddr,
                        ph.filesz, ph.memsz, ph.align
                    )
                    first_load = false
                else  # Subsequent LOAD segments start after data
                    program_headers[i] = ProgramHeader(
                        ph.type, ph.flags, current_offset, ph.vaddr, ph.paddr,
                        ph.filesz, ph.memsz, ph.align
                    )
                    current_offset += ph.filesz
                end
            elseif ph.type == PT_DYNAMIC
                # Calculate dynamic segment offset within its containing LOAD segment
                # Find which LOAD segment contains this virtual address
                containing_load = nothing
                for load_ph in program_headers
                    if load_ph.type == PT_LOAD && 
                       ph.vaddr >= load_ph.vaddr && 
                       ph.vaddr < (load_ph.vaddr + load_ph.memsz)
                        containing_load = load_ph
                        break
                    end
                end
                
                if containing_load !== nothing
                    # Calculate offset within the LOAD segment
                    offset_in_segment = ph.vaddr - containing_load.vaddr
                    dynamic_file_offset = containing_load.offset + offset_in_segment
                    
                    program_headers[i] = ProgramHeader(
                        ph.type, ph.flags, dynamic_file_offset, ph.vaddr, ph.paddr,
                        ph.filesz, ph.memsz, ph.align
                    )
                end
            end
            # Other segments (GNU_STACK, PHDR, INTERP) keep their original offsets
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
            if !isempty(linker.dynamic_section.entries)
                ET_DYN                      # type - DYN (Position-Independent Executable) when dynamic section exists
            else
                ET_EXEC                     # type - EXEC (Static Executable) for purely static executables
            end,
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
        
        # Write interpreter string if PT_INTERP exists
        interp_ph = findfirst(ph -> ph.type == PT_INTERP, program_headers)
        if interp_ph !== nothing
            ph = program_headers[interp_ph]
            seek(io, ph.offset)
            write(io, "/lib64/ld-linux-x86-64.so.2\0")  # Standard Linux x86-64 dynamic linker
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
                # But avoid overwriting the ELF header, program headers, and interpreter string
                headers_end = elf_header_size + length(program_headers) * 56
                
                # Find INTERP segment to avoid overwriting it
                interp_start = UInt64(0)
                interp_end = UInt64(0)
                interp_ph = findfirst(ph -> ph.type == PT_INTERP, program_headers)
                if interp_ph !== nothing
                    interp_seg = program_headers[interp_ph]
                    interp_start = interp_seg.offset
                    interp_end = interp_seg.offset + interp_seg.filesz
                end
                
                for region in segment_regions
                    region_file_offset = region.base_address - ph.vaddr  # Offset within segment
                    region_file_end = region_file_offset + region.size
                    
                    # Only write if the region doesn't overlap with headers or interpreter
                    overlaps_headers = region_file_offset < headers_end
                    overlaps_interp = (interp_start > 0 && 
                                     region_file_offset < interp_end && 
                                     region_file_end > interp_start)
                    
                    if !overlaps_headers && !overlaps_interp
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