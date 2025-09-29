# Library Support for glibc and musl libc
# Mathematical model: λ: P × N → L where P = search paths, N = library names, L = library info
# Provides functionality to detect and link against system libraries following rigorous mathematical specification

"""
    LibraryType

Mathematical model: LibraryType ∈ {GLIBC, MUSL, STATIC, SHARED, UNKNOWN}
Enum representing different library classification types in the library universe.

Library type classification:
```math
classify: LibraryPath → LibraryType
```
"""
@enum LibraryType GLIBC MUSL STATIC SHARED UNKNOWN

"""
    LibraryInfo

Mathematical model: LibraryInfo ∈ L where L = {LibraryInfo}
Information structure representing a detected library with complete metadata.

Library information tuple:
```math
LibraryInfo = ⟨type, path, name, version, symbols⟩
```

Fields:
- type ∈ LibraryType: library classification
- path ∈ String: absolute file system path
- name ∈ String: canonical library name (e.g., "c" for libc)
- version ∈ String: version identifier
- symbols ∈ Set{String}: available symbol set Σ_lib
"""
struct LibraryInfo
    type::LibraryType
    path::String
    name::String      # Library name (e.g., "c" for libc, "math" for libmath)
    version::String
    symbols::Set{String}  # Available symbols in this library
end

"""
    detect_library_type(library_path::String) -> LibraryType

Mathematical model: classify: LibraryPath → LibraryType
Detect the type of library at the given path using magic byte analysis.

Classification function:
```math
classify(path) = \\begin{cases}
STATIC & \\text{if } magic(path) = AR\\_MAGIC \\\\
GLIBC & \\text{if } magic(path) = ELF\\_MAGIC \\land is\\_libc(path) \\land detect\\_libc\\_type(path) = GLIBC \\\\
MUSL & \\text{if } magic(path) = ELF\\_MAGIC \\land is\\_libc(path) \\land detect\\_libc\\_type(path) = MUSL \\\\
SHARED & \\text{if } magic(path) = ELF\\_MAGIC \\land \\neg is\\_libc(path) \\\\
UNKNOWN & \\text{otherwise}
\\end{cases}
```
"""
function detect_library_type(library_path::String)
    # File existence check: path ∈ filesystem
    if !isfile(library_path)                               # ↔ ¬exists(path)
        return UNKNOWN                                     # ↔ classification failure
    end
    
    # Magic byte classification: magic(path) → file_type
    file_type = detect_file_type_by_magic(library_path)    # ↔ magic analysis
    
    if file_type == AR_FILE                                # ↔ AR_MAGIC match
        return STATIC                                      # ↔ static library classification
    elseif file_type == ELF_FILE                          # ↔ ELF_MAGIC match
        # ELF header analysis: parse ELF structure
        elf_header = parse_native_elf_header(library_path) # ↔ ELF structure extraction
        if elf_header !== nothing
            if elf_header.type == ET_DYN                   # ↔ shared object check
                # libc detection: filename pattern matching
                filename = basename(library_path)
                if occursin(r"libc\.so", filename)         # ↔ is_libc(path) = true
                    return detect_libc_type(library_path)  # ↔ GLIBC/MUSL classification
                else
                    return SHARED                          # ↔ general shared library
                end
            elseif elf_header.type == ET_REL               # ↔ relocatable object
                return SHARED  # Treat relocatable objects as shared for now
            end
        end
        return SHARED
    elseif file_type == LINKER_SCRIPT
        # Parse linker script to find actual library
        return parse_linker_script_type(library_path)
    end
    
    return UNKNOWN
end

"""
    parse_linker_script_type(library_path::String) -> LibraryType

Parse a linker script to determine the type of the actual library it references.
"""
function parse_linker_script_type(library_path::String)
    try
        content = read(library_path, String)
        # Find referenced files in the linker script
        for line in split(content, '\n')
            for m in eachmatch(r"/[^\s)]+\.(?:so\.?[0-9]*|a)", line)
                if isfile(m.match)
                    # Recursively check the referenced file
                    return detect_library_type(m.match)
                end
            end
        end
    catch e
        println("Warning: Failed to parse linker script $library_path: $e")
    end
    return UNKNOWN
end

"""
    detect_libc_type(library_path::String) -> LibraryType

Detect the type of libc library at the given path.
"""
function detect_libc_type(library_path::String)
    if !isfile(library_path)
        return UNKNOWN
    end
    
    try
        # Use a safer approach - run strings command if available
        # This is more reliable for binary files
        result = read(`strings $library_path`, String)
        
        # Check for glibc identification strings
        if occursin("GLIBC", result) || occursin("GNU C Library", result)
            return GLIBC
        end
        
        # Check for musl identification strings  
        if occursin("musl", result) || occursin("MUSL", result)
            return MUSL
        end
        
    catch e
        # Fall back to manual binary reading if strings command fails
        try
            open(library_path, "r") do io
                # Read binary data in chunks
                total_read = 0
                max_read = 65536  # 64KB should be enough
                
                while total_read < max_read && !eof(io)
                    chunk_size = min(4096, max_read - total_read)
                    data = read(io, chunk_size)
                    total_read += length(data)
                    
                    # Extract printable strings from binary data
                    current_string = UInt8[]
                    
                    for byte in data
                        if byte >= 0x20 && byte <= 0x7e  # Printable ASCII
                            push!(current_string, byte)
                        elseif length(current_string) >= 4  # Minimum string length
                            found_string = String(current_string)
                            if occursin("GLIBC", found_string) || occursin("GNU", found_string)
                                return GLIBC
                            end
                            if occursin("musl", found_string) || occursin("MUSL", found_string)
                                return MUSL
                            end
                            current_string = UInt8[]
                        else
                            current_string = UInt8[]
                        end
                    end
                end
            end
        catch inner_e
            println("Warning: Failed to read library file $library_path: $inner_e")
        end
    end
    
    return UNKNOWN
end

"""
    find_system_libraries() -> Vector{LibraryInfo}

Find and detect system C libraries (glibc, musl).
"""
function find_system_libraries()
    libraries = LibraryInfo[]
    
    # Common library search paths
    search_paths = [
        "/lib/x86_64-linux-gnu",
        "/usr/lib/x86_64-linux-gnu", 
        "/lib64",
        "/usr/lib64",
        "/lib",
        "/usr/lib",
        "/usr/local/lib"
    ]
    
    # Common library names
    library_patterns = [
        "libc.so.6",
        "libc.so",
        "libc.a"
    ]
    
    for search_path in search_paths
        if isdir(search_path)
            for pattern in library_patterns
                full_path = joinpath(search_path, pattern)
                if isfile(full_path)
                    lib_type = detect_libc_type(full_path)
                    if lib_type != UNKNOWN
                        # Extract basic library symbols (simplified)
                        symbols = extract_library_symbols(full_path)
                        version = extract_library_version(full_path)
                        
                        lib_info = LibraryInfo(lib_type, full_path, "c", version, symbols)
                        push!(libraries, lib_info)
                        println("Detected $(lib_type) library at: $full_path")
                    end
                end
            end
        end
    end
    
    return libraries
end

"""
    get_default_library_search_paths() -> Vector{String}

Get the default library search paths similar to lld/ld.
"""
function get_default_library_search_paths()
    return [
        "/usr/local/lib/x86_64-linux-gnu",
        "/lib/x86_64-linux-gnu",
        "/usr/lib/x86_64-linux-gnu", 
        "/usr/lib/x86_64-linux-gnu64",
        "/usr/local/lib64",
        "/lib64",
        "/usr/lib64",
        "/usr/local/lib",
        "/lib",
        "/usr/lib",
        "/usr/x86_64-linux-gnu/lib64",
        "/usr/x86_64-linux-gnu/lib"
    ]
end

"""
    extract_library_name_from_path(library_path::String) -> String

Extract the library name from a library path (e.g., "c" from "/usr/lib/libc.so.6").
"""
function extract_library_name_from_path(library_path::String)
    filename = basename(library_path)
    
    # Remove lib prefix and extensions
    name = filename
    if startswith(name, "lib")
        name = name[4:end]  # Remove "lib" prefix
    end
    
    # Remove .so, .so.version, .a extensions
    name = replace(name, r"\.so(\.\d+)*$" => "")
    name = replace(name, r"\.a$" => "")
    
    return name
end

"""
    find_libraries_in_paths(search_paths::Vector{String}; library_names::Vector{String} = String[]) -> Vector{LibraryInfo}

Find libraries in the specified search paths. If library_names is provided, only search for those specific libraries.
If library_names is empty, finds all libraries in the search paths.
"""
function find_libraries_in_paths(search_paths::Vector{String}; library_names::Vector{String} = String[])
    libraries = LibraryInfo[]
    
    for search_path in search_paths
        if !isdir(search_path)
            continue
        end
        
        try
            for file in readdir(search_path)
                full_path = joinpath(search_path, file)
                
                if !isfile(full_path)
                    continue
                end
                
                # Check if it matches library patterns
                if !matches_library_pattern(file)
                    continue
                end
                
                # If specific library names are requested, check if this matches
                if !isempty(library_names)
                    lib_name = extract_library_name_from_path(full_path)
                    if !(lib_name in library_names)
                        continue
                    end
                end
                
                # Detect library type
                lib_type = detect_library_type(full_path)
                if lib_type == UNKNOWN
                    continue
                end
                
                # Extract library information
                lib_name = extract_library_name_from_path(full_path)
                version = extract_library_version(full_path)
                symbols = extract_library_symbols(full_path)
                
                lib_info = LibraryInfo(lib_type, full_path, lib_name, version, symbols)
                push!(libraries, lib_info)
            end
        catch e
            println("Warning: Failed to read directory $search_path: $e")
        end
    end
    
    return libraries
end

"""
    matches_library_pattern(filename::String) -> Bool

Check if a filename matches library naming patterns.
"""
function matches_library_pattern(filename::String)
    # Static libraries (.a files)
    if endswith(filename, ".a")
        return startswith(filename, "lib")
    end
    
    # Shared libraries (.so files)
    if occursin(r"\.so(\.\d+)*$", filename)
        return startswith(filename, "lib")
    end
    
    return false
end

"""
    find_crt_objects() -> Dict{String, String}

Find C runtime objects (crt1.o, crti.o, crtn.o) required for program startup.
"""
function find_crt_objects()
    crt_objects = Dict{String, String}()
    
    # Common CRT object search paths
    search_paths = [
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib64", 
        "/lib64",
        "/usr/lib",
        "/lib"
    ]
    
    # CRT objects we need to find
    crt_names = ["crt1.o", "crti.o", "crtn.o"]
    
    for search_path in search_paths
        if !isdir(search_path)
            continue
        end
        
        for crt_name in crt_names
            if haskey(crt_objects, crt_name)
                continue  # Already found
            end
            
            crt_path = joinpath(search_path, crt_name)
            if isfile(crt_path)
                crt_objects[crt_name] = crt_path
            end
        end
    end
    
    return crt_objects
end

"""
    find_default_libc() -> Union{LibraryInfo, Nothing}

Find the default libc that should be automatically linked (like lld does).
Only libc is linked automatically, other libraries must be explicitly requested.
"""
function find_default_libc()
    # Search for libc.so in standard locations
    search_paths = get_default_library_search_paths()
    
    for search_path in search_paths
        if !isdir(search_path)
            continue
        end
        
        # Look for libc.so.6 or libc.so
        for libc_name in ["libc.so.6", "libc.so"]
            libc_path = joinpath(search_path, libc_name)
            if isfile(libc_path)
                lib_type = detect_libc_type(libc_path)
                if lib_type != UNKNOWN
                    version = extract_library_version(libc_path)
                    symbols = extract_library_symbols(libc_path)
                    return LibraryInfo(lib_type, libc_path, "c", version, symbols)
                end
            end
        end
    end
    
    return nothing
end

"""
    find_libraries(search_paths::Vector{String} = String[]; library_names::Vector{String} = String[]) -> Vector{LibraryInfo}

Find specific libraries using lld-style search. 
- search_paths: Additional search paths (equivalent to -L option)
- library_names: Specific library names to search for (equivalent to -l option)

This only finds libraries explicitly requested via library_names.
For automatic libc linking, use find_default_libc().
"""
function find_libraries(search_paths::Vector{String} = String[]; library_names::Vector{String} = String[])
    # Return empty if no specific libraries requested (lld-compatible behavior)
    if isempty(library_names)
        return LibraryInfo[]
    end
    
    # Combine custom search paths with default ones
    all_search_paths = String[]
    
    # Add custom search paths first (higher priority)
    append!(all_search_paths, search_paths)
    
    # Add default system search paths
    append!(all_search_paths, get_default_library_search_paths())
    
    # Remove duplicates while preserving order
    unique_paths = String[]
    seen = Set{String}()
    for path in all_search_paths
        if !(path in seen)
            push!(unique_paths, path)
            push!(seen, path)
        end
    end
    
    return find_libraries_in_paths(unique_paths; library_names=library_names)
end

"""
    extract_library_symbols(library_path::String) -> Set{String}

Extract available symbols from a library using native binary parsing.
"""
function extract_library_symbols(library_path::String)
    symbols = Set{String}()
    
    if !isfile(library_path)
        return symbols
    end
    
    file_type = detect_file_type_by_magic(library_path)
    
    if file_type == ELF_FILE
        # Native ELF parsing
        symbols = extract_elf_symbols_native(library_path)
    elseif file_type == AR_FILE
        # Native archive parsing
        symbols = extract_archive_symbols_native(library_path)
    elseif file_type == LINKER_SCRIPT
        # Parse linker script and extract symbols from referenced files
        symbols = extract_linker_script_symbols(library_path)
    else
        println("Warning: Unknown file type for $library_path")
    end
    
    return symbols
end

"""
    extract_linker_script_symbols(library_path::String) -> Set{String}

Extract symbols from libraries referenced in a linker script.
"""
function extract_linker_script_symbols(library_path::String)
    symbols = Set{String}()
    
    try
        content = read(library_path, String)
        # Find referenced files in the linker script
        for line in split(content, '\n')
            for m in eachmatch(r"/[^\s)]+\.(?:so\.?[0-9]*|a)", line)
                if isfile(m.match)
                    # Recursively extract symbols from referenced file
                    referenced_symbols = extract_library_symbols(m.match)
                    union!(symbols, referenced_symbols)
                end
            end
        end
    catch e
        println("Warning: Failed to parse linker script $library_path: $e")
    end
    
    return symbols
end

"""
    extract_library_version(library_path::String) -> String

Extract version information from a library.
"""
function extract_library_version(library_path::String)
    # Try to extract version from filename or library contents
    filename = basename(library_path)
    
    # Extract version from filename (e.g., libc.so.6)
    if occursin(r"\.so\.(\d+)", filename)
        m = match(r"\.so\.(\d+(?:\.\d+)*)", filename)
        if m !== nothing
            return m.captures[1]
        end
    end
    
    return "unknown"
end

"""
    resolve_symbol_against_libraries(symbol_name::String, libraries::Vector{LibraryInfo}) -> Union{LibraryInfo, Nothing}

Find which library provides a given symbol.
"""
function resolve_symbol_against_libraries(symbol_name::String, libraries::Vector{LibraryInfo})
    for library in libraries
        if symbol_name in library.symbols
            return library
        end
    end
    return nothing
end

"""
    resolve_unresolved_symbols!(linker::DynamicLinker, libraries::Vector{LibraryInfo}) -> Vector{String}

Attempt to resolve unresolved symbols against system libraries.
Returns remaining unresolved symbols.
"""
function resolve_unresolved_symbols!(linker::DynamicLinker, libraries::Vector{LibraryInfo})
    remaining_unresolved = String[]
    
    for (symbol_name, symbol) in linker.global_symbol_table
        if !symbol.defined
            # Try to resolve against system libraries
            providing_library = resolve_symbol_against_libraries(symbol_name, libraries)
            
            if providing_library !== nothing
                # Create a resolved symbol entry for system library symbol
                resolved_symbol = Symbol(
                    symbol_name,
                    UInt64(0x0),  # Runtime address resolved via PLT/GOT
                    UInt64(0),
                    symbol.binding,
                    symbol.type,
                    UInt16(0),  # External symbol
                    true,  # Mark as defined
                    "$(providing_library.type):$(providing_library.path)"
                )
                
                linker.global_symbol_table[symbol_name] = resolved_symbol
                println("Resolved '$symbol_name' against $(providing_library.type) library")
            else
                push!(remaining_unresolved, symbol_name)
            end
        end
    end
    
    return remaining_unresolved
end