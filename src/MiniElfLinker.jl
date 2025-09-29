module MiniElfLinker

export ElfHeader, SectionHeader, SymbolTableEntry, RelocationEntry, ElfFile, ProgramHeader
export parse_elf_header, parse_section_headers, parse_symbol_table, parse_elf_file
export DynamicLinker, link_objects, link_to_executable, resolve_symbols, load_object, print_symbol_table, print_memory_layout
export write_elf_executable
export LibraryType, GLIBC, MUSL, STATIC, SHARED, UNKNOWN, LibraryInfo, find_system_libraries, find_libraries, find_default_libc, find_crt_objects, get_default_library_search_paths, resolve_unresolved_symbols!, detect_libc_type, detect_library_type, detect_file_type_by_magic, extract_elf_symbols_native, extract_archive_symbols_native
export LinkerOptions, parse_arguments, show_help, show_version, execute_linker, main
# Enhanced production-ready components
export GlobalOffsetTable, ProcedureLinkageTable, PLTEntry, create_plt_entry, create_plt_resolver_entry
export RelocationDispatcher, RelocationHandler, apply_relocation!, UnsupportedRelocationError
export DynamicSection, DynamicEntry, add_needed_library!, finalize_dynamic_section!

include("elf_format.jl")
include("elf_parser.jl")
include("native_parsing.jl")
include("relocation_engine.jl")
include("dynamic_linker.jl")
include("elf_writer.jl")
include("library_support.jl")
include("cli.jl")

end # module MiniElfLinker