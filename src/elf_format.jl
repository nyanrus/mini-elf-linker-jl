# ELF Format Structures
# Based on the ELF specification for educational purposes

# ELF Header structure
struct ElfHeader
    magic::NTuple{4, UInt8}        # ELF magic number (0x7f, 'E', 'L', 'F')
    class::UInt8                   # File class (32-bit or 64-bit)
    data::UInt8                    # Data encoding (little or big endian)
    version::UInt8                 # ELF version
    osabi::UInt8                   # OS/ABI identification
    abiversion::UInt8              # ABI version
    pad::NTuple{7, UInt8}          # Padding bytes
    type::UInt16                   # Object file type (ET_REL, ET_EXEC, ET_DYN, etc.)
    machine::UInt16                # Machine type (EM_X86_64, etc.)
    version2::UInt32               # Object file version
    entry::UInt64                  # Entry point virtual address
    phoff::UInt64                  # Program header table file offset
    shoff::UInt64                  # Section header table file offset
    flags::UInt32                  # Processor-specific flags
    ehsize::UInt16                 # ELF header size in bytes
    phentsize::UInt16              # Program header table entry size
    phnum::UInt16                  # Program header table entry count
    shentsize::UInt16              # Section header table entry size
    shnum::UInt16                  # Section header table entry count
    shstrndx::UInt16               # Section header string table index
end

# Section Header structure (64-bit)
struct SectionHeader
    name::UInt32                   # Section name (string table index)
    type::UInt32                   # Section type
    flags::UInt64                  # Section flags
    addr::UInt64                   # Section virtual address at execution
    offset::UInt64                 # Section file offset
    size::UInt64                   # Section size in bytes
    link::UInt32                   # Link to another section
    info::UInt32                   # Additional section information
    addralign::UInt64              # Section alignment
    entsize::UInt64                # Entry size if section holds table
end

# Symbol Table Entry structure (64-bit)
struct SymbolTableEntry
    name::UInt32                   # Symbol name (string table index)
    info::UInt8                    # Symbol type and binding
    other::UInt8                   # Symbol visibility
    shndx::UInt16                  # Section index
    value::UInt64                  # Symbol value
    size::UInt64                   # Symbol size
end

# Relocation Entry with addend (64-bit)
struct RelocationEntry
    offset::UInt64                 # Location at which to apply the action
    info::UInt64                   # Relocation type and symbol index
    addend::Int64                  # Addend used to compute value
end

# Program Header structure (64-bit)
struct ProgramHeader
    type::UInt32                   # Segment type
    flags::UInt32                  # Segment flags
    offset::UInt64                 # Segment file offset
    vaddr::UInt64                  # Segment virtual address
    paddr::UInt64                  # Segment physical address
    filesz::UInt64                 # Segment size in file
    memsz::UInt64                  # Segment size in memory
    align::UInt64                  # Segment alignment
end

# ELF constants
const ELF_MAGIC = (0x7f, UInt8('E'), UInt8('L'), UInt8('F'))
const ELFCLASS64 = 2
const ELFDATA2LSB = 1  # Little endian
const EV_CURRENT = 1   # Current version

# Object file types
const ET_NONE = 0      # No file type
const ET_REL = 1       # Relocatable file
const ET_EXEC = 2      # Executable file
const ET_DYN = 3       # Shared object file
const ET_CORE = 4      # Core file

# Machine types
const EM_X86_64 = 62   # AMD x86-64 architecture

# Section types
const SHT_NULL = 0     # Section header table entry unused
const SHT_PROGBITS = 1 # Program data
const SHT_SYMTAB = 2   # Symbol table
const SHT_STRTAB = 3   # String table
const SHT_RELA = 4     # Relocation entries with addends
const SHT_HASH = 5     # Symbol hash table
const SHT_DYNAMIC = 6  # Dynamic linking information
const SHT_NOTE = 7     # Notes
const SHT_NOBITS = 8   # Program space with no data (bss)
const SHT_REL = 9      # Relocation entries, no addends
const SHT_SHLIB = 10   # Reserved
const SHT_DYNSYM = 11  # Dynamic linker symbol table

# Section flags
const SHF_WRITE = 0x1      # Writable
const SHF_ALLOC = 0x2      # Occupies memory during execution
const SHF_EXECINSTR = 0x4  # Executable

# Symbol binding
const STB_LOCAL = 0    # Local scope
const STB_GLOBAL = 1   # Global scope
const STB_WEAK = 2     # Weak global scope

# Symbol types
const STT_NOTYPE = 0   # Symbol type is unspecified
const STT_OBJECT = 1   # Symbol is a data object
const STT_FUNC = 2     # Symbol is a code object
const STT_SECTION = 3  # Symbol associated with a section
const STT_FILE = 4     # Symbol's name is file name

# Relocation types for x86-64
const R_X86_64_NONE = 0     # No relocation
const R_X86_64_64 = 1       # Direct 64 bit
const R_X86_64_PC32 = 2     # PC relative 32 bit signed
const R_X86_64_GOT32 = 3    # 32 bit GOT entry
const R_X86_64_PLT32 = 4    # 32 bit PLT address
const R_X86_64_COPY = 5     # Copy symbol at runtime
const R_X86_64_GLOB_DAT = 6 # Create GOT entry
const R_X86_64_JUMP_SLOT = 7 # Create PLT entry

# Helper functions for symbol info
st_bind(info::UInt8) = (info >> 4) & 0xf
st_type(info::UInt8) = info & 0xf
st_info(bind::UInt8, type::UInt8) = (bind << 4) | (type & 0xf)

# Helper functions for relocation info
elf64_r_sym(info::UInt64) = info >> 32
elf64_r_type(info::UInt64) = info & 0xffffffff
elf64_r_info(sym::UInt32, type::UInt32) = (UInt64(sym) << 32) | UInt64(type)