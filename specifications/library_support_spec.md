# Library Support Specification

## Overview

The MiniElfLinker supports linking with system libraries to resolve external symbols. This includes automatic detection of system C libraries, library search path management, and symbol resolution from static archives and shared libraries.

## Library Types

### Supported Library Types
```julia
@enum LibraryType begin
    GLIBC      # GNU C Library (most common)
    MUSL       # musl C Library (Alpine Linux, embedded)
    STATIC     # Static archive (.a files)
    SHARED     # Shared object (.so files)  
    UNKNOWN    # Unrecognized library type
end
```

### Library Information Structure
```julia
struct LibraryInfo
    name::String              # Library name (e.g., "libc")
    path::String              # Full file path
    type::LibraryType         # Library classification
    symbols::Vector{String}   # Available symbols (if extracted)
    arch::String              # Target architecture
end
```

## Library Discovery

### Default Search Paths
Standard locations where libraries are typically found:

```julia
function get_default_library_search_paths()::Vector{String}
    return [
        "/lib",
        "/lib64", 
        "/usr/lib",
        "/usr/lib64",
        "/usr/local/lib",
        "/usr/lib/x86_64-linux-gnu",  # Debian/Ubuntu multiarch
        "/lib/x86_64-linux-gnu"
    ]
end
```

### Library Search Algorithm
```julia
function find_libraries(search_paths::Vector{String}, 
                       library_names::Vector{String} = String[])::Vector{LibraryInfo}
    libraries = LibraryInfo[]
    
    # Combine custom and default search paths
    all_paths = vcat(search_paths, get_default_library_search_paths())
    
    for path in all_paths
        if !isdir(path)
            continue
        end
        
        # Scan directory for library files
        for filename in readdir(path)
            full_path = joinpath(path, filename)
            
            # Check if it's a library file
            if is_library_file(filename)
                lib_info = analyze_library_file(full_path)
                
                # Filter by requested names if specified
                if isempty(library_names) || lib_info.name in library_names
                    push!(libraries, lib_info)
                end
            end
        end
    end
    
    return unique_libraries(libraries)
end
```

### Library File Recognition
```julia
function is_library_file(filename::String)::Bool
    # Static libraries (.a files)
    if endswith(filename, ".a") && startswith(filename, "lib")
        return true
    end
    
    # Shared libraries (.so files)
    if contains(filename, ".so") && startswith(filename, "lib")
        return true
    end
    
    return false
end
```

## Library Analysis

### File Type Detection
```julia
function detect_library_type(filepath::String)::LibraryType
    try
        # Try to detect by file magic
        file_type = detect_file_type_by_magic(filepath)
        
        if file_type == "ELF shared library"
            return detect_libc_type(filepath)
        elseif file_type == "AR archive"
            return STATIC
        else
            return UNKNOWN
        end
    catch
        return UNKNOWN
    end
end
```

### C Library Detection
```julia
function detect_libc_type(library_path::String)::LibraryType
    try
        # Extract symbols to check for library-specific functions
        symbols = extract_elf_symbols_native(library_path)
        symbol_names = [sym.name for sym in symbols]
        
        # Check for glibc-specific symbols
        glibc_markers = ["__glibc_version", "__libc_start_main", "gnu_get_libc_version"]
        if any(marker -> marker in symbol_names, glibc_markers)
            return GLIBC
        end
        
        # Check for musl-specific symbols  
        musl_markers = ["__dls3", "__init_tp", "__libc"]
        if any(marker -> marker in symbol_names, musl_markers)
            return MUSL
        end
        
        # Generic shared library
        return SHARED
        
    catch e
        @debug "Failed to detect libc type: $e"
        return UNKNOWN
    end
end
```

## Symbol Resolution

### System Library Integration
```julia
function resolve_unresolved_symbols!(linker::DynamicLinker)::Vector{String}
    unresolved = String[]
    
    # Find system libraries
    system_libs = find_system_libraries()
    
    for (symbol_name, symbol_info) in linker.global_symbol_table
        if !symbol_info.defined
            # Try to find symbol in system libraries
            found = false
            
            for lib in system_libs
                if has_symbol(lib, symbol_name)
                    # Mark symbol as resolved
                    symbol_info.defined = true
                    symbol_info.value = 0  # Will be resolved at runtime
                    symbol_info.source = lib.path
                    found = true
                    break
                end
            end
            
            if !found
                push!(unresolved, symbol_name)
            end
        end
    end
    
    return unresolved
end
```

### Symbol Extraction from Libraries
```julia
function extract_library_symbols(library_path::String)::Vector{String}
    if endswith(library_path, ".a")
        # Static archive
        return extract_archive_symbols_native(library_path)
    else
        # ELF shared library
        symbols = extract_elf_symbols_native(library_path) 
        return [sym.name for sym in symbols if sym.binding == STB_GLOBAL]
    end
end
```

## Standard C Library Support

### Finding Default C Library
```julia
function find_default_libc()::Union{LibraryInfo, Nothing}
    search_paths = get_default_library_search_paths()
    
    # Common libc names
    libc_names = ["libc.so.6", "libc.so", "libc.a"]
    
    for path in search_paths
        for name in libc_names
            full_path = joinpath(path, name)
            if isfile(full_path)
                return LibraryInfo(
                    name="libc",
                    path=full_path,
                    type=detect_library_type(full_path),
                    symbols=String[],  # Lazy loading
                    arch="x86_64"
                )
            end
        end
    end
    
    return nothing
end
```

### C Runtime Objects
```julia
function find_crt_objects()::Dict{String, String}
    crt_objects = Dict{String, String}()
    search_paths = [
        "/usr/lib/x86_64-linux-gnu",
        "/usr/lib64",  
        "/lib64"
    ]
    
    crt_files = ["crt1.o", "crti.o", "crtn.o"]
    
    for path in search_paths
        for crt_file in crt_files
            full_path = joinpath(path, crt_file)
            if isfile(full_path)
                crt_objects[crt_file] = full_path
            end
        end
    end
    
    return crt_objects
end
```

## Archive Processing

### Static Library Symbol Extraction
Static libraries (.a files) are archives containing multiple object files. We need to extract symbols from all contained objects.

```julia
function extract_archive_symbols_native(archive_path::String)::Vector{String}
    symbols = String[]
    temp_dir = mktempdir()
    
    try
        # Extract archive contents
        run(`ar x $archive_path`, dir=temp_dir)
        
        # Process each extracted object file
        for filename in readdir(temp_dir)
            if endswith(filename, ".o")
                object_path = joinpath(temp_dir, filename)
                object_symbols = extract_elf_symbols_native(object_path)
                append!(symbols, [sym.name for sym in object_symbols])
            end
        end
    finally
        # Cleanup temporary directory
        rm(temp_dir, recursive=true, force=true)
    end
    
    return unique(symbols)
end
```

## Library Search Optimization

### Library Caching
```julia
mutable struct LibraryCache
    libraries::Dict{String, Vector{LibraryInfo}}
    symbols::Dict{String, Vector{String}}
    last_update::Float64
end

const GLOBAL_LIBRARY_CACHE = LibraryCache(Dict(), Dict(), 0.0)

function get_cached_libraries(search_paths::Vector{String})::Vector{LibraryInfo}
    cache_key = join(sort(search_paths), ":")
    current_time = time()
    
    # Cache validity: 5 minutes
    if haskey(GLOBAL_LIBRARY_CACHE.libraries, cache_key) &&
       (current_time - GLOBAL_LIBRARY_CACHE.last_update) < 300
        return GLOBAL_LIBRARY_CACHE.libraries[cache_key]
    end
    
    # Refresh cache
    libraries = find_libraries(search_paths)
    GLOBAL_LIBRARY_CACHE.libraries[cache_key] = libraries
    GLOBAL_LIBRARY_CACHE.last_update = current_time
    
    return libraries
end
```

### Parallel Library Scanning
```julia
using Base.Threads

function find_libraries_parallel(search_paths::Vector{String})::Vector{LibraryInfo}
    # Split paths across available threads
    path_chunks = collect(Iterators.partition(search_paths, 
                         ceil(Int, length(search_paths) / nthreads())))
    
    # Process chunks in parallel
    results = Vector{Vector{LibraryInfo}}(undef, length(path_chunks))
    
    @threads for i in 1:length(path_chunks)
        results[i] = find_libraries(collect(path_chunks[i]))
    end
    
    # Combine results
    return vcat(results...)
end
```

## Error Handling

### Library Loading Errors
```julia
struct LibraryError <: Exception
    message::String
    path::String
    cause::Union{Exception, Nothing}
end

function safe_library_analysis(library_path::String)::Union{LibraryInfo, LibraryError}
    try
        return analyze_library_file(library_path)
    catch e
        return LibraryError("Failed to analyze library", library_path, e)
    end
end
```

### Symbol Resolution Failures
```julia
function report_unresolved_symbols(symbols::Vector{String})
    if !isempty(symbols)
        @warn "Unresolved symbols found:" symbols
        for sym in symbols
            @info "  - $sym: Consider linking with appropriate library (-l<name>)"
        end
    end
end
```

## Configuration Options

### Environment Variables
- `LD_LIBRARY_PATH`: Runtime library search paths
- `LIBRARY_PATH`: Compile-time library search paths  
- `LD_PRELOAD`: Libraries to preload

### Search Path Precedence
1. Paths specified with `-L` option
2. `LIBRARY_PATH` environment variable
3. Default system paths
4. `LD_LIBRARY_PATH` (runtime only)

## Performance Considerations

### Symbol Lookup Optimization
- Cache symbol tables for frequently used libraries
- Use hash sets for O(1) symbol membership testing
- Lazy symbol extraction (extract only when needed)

### File System Optimization
- Cache directory listings to avoid repeated `readdir()` calls
- Use `stat()` to check file modifications for cache invalidation
- Parallel directory scanning for large library collections

## Integration Examples

### Basic Library Linking
```julia
# Find and link with C library
libraries = find_libraries(["/usr/lib"], ["c"])
resolve_symbols_with_libraries(linker, libraries)
```

### Custom Library Search
```julia  
# Add custom search paths and libraries
custom_paths = ["/opt/mylib/lib", "/home/user/libs"]
custom_libs = ["mymath", "myutil"]
libraries = find_libraries(custom_paths, custom_libs)
```

### System Integration
```julia
# Full system library integration
function link_with_system_libraries!(linker::DynamicLinker)
    # Find system C library
    libc = find_default_libc()
    if libc !== nothing
        integrate_library(linker, libc)
    end
    
    # Find CRT objects
    crt_objects = find_crt_objects()
    for (name, path) in crt_objects
        load_crt_object(linker, path)
    end
end
```

### Library Type Detection → `detect_library_type` function

```math
detect\_type: String \to LibraryType
```

**Mathematical classification**:
```math
classify(library\_path) = \begin{cases}
STATIC & \text{if } filename \text{ ends with } ".a" \\
GLIBC & \text{if } "libc.so" \in filename \land detect\_libc\_type(path) = GLIBC \\
MUSL & \text{if } "libc.so" \in filename \land detect\_libc\_type(path) = MUSL \\
SHARED & \text{if } filename \text{ matches } "\.so(\.\d+)*$" \\
UNKNOWN & \text{otherwise}
\end{cases}
```

### Extended Library Discovery → `find_libraries` function

```math
find\_libraries: \mathcal{P} \times \mathcal{N} \to \mathcal{L}
```

**Set-theoretic operation**: Multi-path traversal with filtering

```math
library\_search = \bigcup_{path \in unified\_paths} \{f \in files(path) : matches\_library\_pattern(f) \land name\_filter(f)\}
```

**Direct code correspondence**:
```julia
# Mathematical model: find_libraries: P × N → L
function find_libraries(search_paths::Vector{String} = String[]; library_names::Vector{String} = String[])
    # Implementation of: custom_paths ∪ default_paths with precedence preservation
    all_search_paths = vcat(search_paths, get_default_library_search_paths())
    unique_paths = unique(all_search_paths)                    # ↔ duplicate removal
    
    return find_libraries_in_paths(unique_paths; library_names=library_names)  # ↔ filtered discovery
end
```

### Library Pattern Matching → `matches_library_pattern` function

```math
matches\_pattern: String \to Boolean
```

**Pattern recognition**:
```math
matches(filename) = \begin{cases}
true & \text{if } filename \text{ starts with } "lib" \land filename \text{ ends with } ".a" \\
true & \text{if } filename \text{ starts with } "lib" \land filename \text{ matches } "\.so(\.\d+)*$" \\
false & \text{otherwise}
\end{cases}
```

### Symbol Extraction → `extract_library_symbols` function

```math
extract\_symbols: String \to \mathcal{S}
```

**Library-specific symbol mapping**:
```math
symbol\_set(library\_name) = \begin{cases}
\{printf, malloc, strlen, ...\} & \text{if } library\_name = "c" \\
\{sin, cos, exp, sqrt, ...\} & \text{if } library\_name = "m" \\
\{pthread\_create, pthread\_join, ...\} & \text{if } library\_name = "pthread" \\
\{dlopen, dlclose, dlsym, ...\} & \text{if } library\_name = "dl" \\
\emptyset & \text{otherwise}
\end{cases}
```

### Backward Compatibility → `find_system_libraries` function

```math
find\_system\_libraries: \{\} \to List(LibraryInfo)
```

**Specialized libc discovery**:
```math
system\_libraries = \{lib \in find\_libraries(\{\}, \{"c"\}) : lib.type \in \{GLIBC, MUSL\}\}
```

## Complexity Analysis

```math
\begin{align}
T_{library\_detection}(f) &= O(f) \quad \text{– File pattern matching and type detection} \\
T_{path\_discovery}(p,f) &= O(p \cdot f) \quad \text{– Multi-path directory traversal} \\
T_{symbol\_resolution}(s,l) &= O(s \cdot l) \quad \text{– Symbol lookup across libraries} \\
T_{total\_search}(p,f,s,l) &= O(p \cdot f + s \cdot l) \quad \text{– Combined search and resolution}
\end{align}
```

**Critical path**: Library discovery with O(p·f) path traversal operations.

## Transformation Pipeline

**Library discovery pipeline**:
```math
search\_paths \xrightarrow{filter} valid\_paths \xrightarrow{scan} all\_files \xrightarrow{match} library\_files \xrightarrow{classify} typed\_libraries
```

**Symbol resolution pipeline**:
```math
unresolved\_symbols \xrightarrow{lookup} candidate\_libraries \xrightarrow{match} providing\_library \xrightarrow{resolve} resolved\_symbols
```

## Set-Theoretic Operations

**Library path union with precedence**:
```math
all\_search\_paths = custom\_paths \cup default\_paths \text{ (preserving order)}
```

**Symbol availability across libraries**:
```math
available\_symbols = \bigcup_{lib \in discovered\_libraries} lib.symbols
```

**Library filtering by name**:
```math
filtered\_libraries = \{lib \in all\_libraries : lib.name \in requested\_names\}
```

**Resolution status partitioning**:
```math
resolved\_symbols = \{s \in symbols : s.resolved = true\}
unresolved\_symbols = \{s \in symbols : s.resolved = false\}
```

## Invariant Preservation

```math
\text{Library type consistency: }
\forall lib: classify(lib) \in \{GLIBC, MUSL, STATIC, SHARED, UNKNOWN\}
```

```math
\text{Search path precedence: }
\forall p_1, p_2: p_1 \text{ before } p_2 \text{ in input} \implies p_1 \text{ searched before } p_2
```

```math
\text{Symbol availability: }
\forall lib: lib.type \neq UNKNOWN \implies lib.symbols \neq \emptyset \lor lib.name \in known\_libraries
```

```math
\text{Pattern matching correctness: }
\forall file: matches\_library\_pattern(file) \iff (file \text{ starts with } "lib" \land file \text{ ends with } (".a" \lor ".so*"))
```

## Optimization Trigger Points

- **Inner loops**: Multi-path directory traversal with potential parallel scanning
- **Memory allocation**: Library list pre-allocation based on typical system library counts  
- **Bottleneck operations**: File pattern matching with compiled regex optimization
- **Search optimization**: Path deduplication and caching of directory contents
- **Symbol lookup**: Hash-based symbol set membership testing