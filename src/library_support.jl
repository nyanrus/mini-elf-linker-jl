# Library Support for glibc and musl libc
# Provides functionality to detect and link against system libraries

"""
    LibraryType

Enum representing different library types.
"""
@enum LibraryType GLIBC MUSL STATIC SHARED UNKNOWN

"""
    LibraryInfo

Information about a detected library.
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

Detect the type of library at the given path.
"""
function detect_library_type(library_path::String)
    if !isfile(library_path)
        return UNKNOWN
    end
    
    filename = basename(library_path)
    
    # Check for static libraries
    if endswith(filename, ".a")
        return STATIC
    end
    
    # Check for shared libraries
    if occursin(r"\.so(\.\d+)*$", filename)
        # For .so files, try to determine if it's glibc or musl
        if occursin(r"libc\.so", filename)
            return detect_libc_type(library_path)
        else
            return SHARED
        end
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
    find_libraries(search_paths::Vector{String} = String[]; library_names::Vector{String} = String[]) -> Vector{LibraryInfo}

Find libraries using lld-style search. 
- search_paths: Additional search paths (equivalent to -L option)
- library_names: Specific library names to search for (equivalent to -l option)

If search_paths is empty, uses default system search paths.
If library_names is empty, finds all available libraries.
"""
function find_libraries(search_paths::Vector{String} = String[]; library_names::Vector{String} = String[])
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

Extract available symbols from a library (simplified implementation).
"""
function extract_library_symbols(library_path::String)
    # Extract library name to determine symbol set
    lib_name = extract_library_name_from_path(library_path)
    
    # Return appropriate symbols based on library type
    if lib_name == "c"
        # libc symbols
        return Set{String}([
            "printf", "sprintf", "fprintf", "snprintf",
            "malloc", "free", "calloc", "realloc",
            "strlen", "strcpy", "strcmp", "strcat",
            "memcpy", "memset", "memcmp", "memmove",
            "exit", "_exit", "abort",
            "open", "close", "read", "write",
            "getpid", "getuid", "getgid"
        ])
    elseif lib_name == "m" || lib_name == "math"
        # libmath symbols
        return Set{String}([
            "sin", "cos", "tan", "asin", "acos", "atan", "atan2",
            "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
            "exp", "exp2", "log", "log2", "log10",
            "pow", "sqrt", "cbrt", "fabs", "ceil", "floor", "round",
            "fmod", "remainder", "frexp", "ldexp", "modf"
        ])
    elseif lib_name == "pthread"
        # pthread symbols
        return Set{String}([
            "pthread_create", "pthread_join", "pthread_detach", "pthread_exit",
            "pthread_mutex_init", "pthread_mutex_destroy", "pthread_mutex_lock", 
            "pthread_mutex_unlock", "pthread_mutex_trylock",
            "pthread_cond_init", "pthread_cond_destroy", "pthread_cond_wait",
            "pthread_cond_signal", "pthread_cond_broadcast"
        ])
    elseif lib_name == "dl"
        # libdl symbols
        return Set{String}([
            "dlopen", "dlclose", "dlsym", "dlerror"
        ])
    else
        # For unknown libraries, try to extract symbols using nm if available
        # For now, return empty set as a placeholder
        return Set{String}()
    end
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
                # Create a resolved symbol entry
                # For system library symbols, we use a placeholder address
                # In a real linker, this would involve PLT/GOT setup
                resolved_symbol = Symbol(
                    symbol_name,
                    UInt64(0x0),  # Placeholder - would be resolved at runtime via PLT
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