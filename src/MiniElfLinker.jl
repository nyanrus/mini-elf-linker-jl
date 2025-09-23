module MiniElfLinker

export ElfHeader, SectionHeader, SymbolTableEntry, RelocationEntry, ElfFile
export parse_elf_header, parse_section_headers, parse_symbol_table, parse_elf_file
export DynamicLinker, link_objects, resolve_symbols, load_object, print_symbol_table, print_memory_layout

include("elf_format.jl")
include("elf_parser.jl")
include("dynamic_linker.jl")

end # module MiniElfLinker