module MiniElfLinker

export ElfHeader, SectionHeader, SymbolTableEntry, RelocationEntry, ElfFile, ProgramHeader
export parse_elf_header, parse_section_headers, parse_symbol_table, parse_elf_file
export DynamicLinker, link_objects, link_to_executable, resolve_symbols, load_object, print_symbol_table, print_memory_layout
export write_elf_executable

include("elf_format.jl")
include("elf_parser.jl")
include("dynamic_linker.jl")
include("elf_writer.jl")

end # module MiniElfLinker