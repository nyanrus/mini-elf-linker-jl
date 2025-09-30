# Production-Level Library Support for Complex Projects
# Enhanced library detection and linking for real-world projects like ZSTD

"""
Mathematical Framework for Production Library Support:
```math
ProductionLibrary = {
    detection: Σ_{paths} × Σ_{names} → LibrarySet,
    resolution: UnresolvedSymbols × LibrarySet → ResolvedSymbols,
    linking: ObjectFiles × LibrarySet → ExecutableFile
}
```
"""

"""
    ProductionLibraryInfo

Enhanced library information structure for production-level linking.
"""
struct ProductionLibraryInfo
    type::LibraryType
    path::String
    name::String
    version::String
    symbols::Set{String}
    dependencies::Vector{String}  # Library dependencies
    architecture::String          # Target architecture  
    is_compatible::Bool           # Compatibility with target
    priority::Int                 # Search priority
end

"""
    detect_system_libraries_enhanced() -> Vector{ProductionLibraryInfo}

Enhanced system library detection for production environments.
Detects libraries needed for complex projects like ZSTD.
"""
function detect_system_libraries_enhanced()
    println("🔍 Enhanced system library detection...")
    
    libraries = ProductionLibraryInfo[]
    
    # Essential libraries for complex projects
    essential_libraries = [
        "c",        # C standard library
        "m",        # Math library
        "pthread",  # POSIX threads
        "dl",       # Dynamic linking
        "rt",       # Real-time extensions
        "gcc_s",    # GCC runtime
        "stdc++",   # C++ standard library (for mixed projects)
    ]
    
    # Search paths with priority
    search_paths = [
        ("/lib/x86_64-linux-gnu", 10),
        ("/usr/lib/x86_64-linux-gnu", 9),
        ("/lib64", 8),
        ("/usr/lib64", 7),
        ("/usr/local/lib", 6),
        ("/lib", 5),
        ("/usr/lib", 4),
    ]
    
    for (search_path, priority) in search_paths
        if !isdir(search_path)
            continue
        end
        
        for lib_name in essential_libraries
            # Look for shared libraries first
            for extension in [".so", ".so.6", ".so.1", ".so.2"]
                lib_file = "lib$(lib_name)$(extension)"
                full_path = joinpath(search_path, lib_file)
                
                if isfile(full_path)
                    lib_info = analyze_library_file(full_path, lib_name, priority)
                    if lib_info !== nothing
                        push!(libraries, lib_info)
                        println("   ✅ Found $(lib_name) at: $full_path")
                        break  # Found this library, move to next
                    end
                end
            end
            
            # Also look for static libraries as fallback
            static_file = "lib$(lib_name).a"
            static_path = joinpath(search_path, static_file)
            if isfile(static_path)
                lib_info = analyze_library_file(static_path, lib_name, priority - 1)
                if lib_info !== nothing
                    push!(libraries, lib_info)
                    println("   ✅ Found static $(lib_name) at: $static_path")
                end
            end
        end
    end
    
    return libraries
end

"""
    analyze_library_file(file_path::String, lib_name::String, priority::Int) -> Union{ProductionLibraryInfo, Nothing}

Analyze a library file and extract comprehensive information.
"""
function analyze_library_file(file_path::String, lib_name::String, priority::Int)
    try
        # Detect file type
        lib_type = detect_library_type(file_path)
        if lib_type == UNKNOWN
            return nothing
        end
        
        # Extract symbols (simplified for now, can be enhanced)
        symbols = extract_library_symbols_enhanced(file_path)
        
        # Extract version information
        version = extract_library_version_enhanced(file_path)
        
        # Detect dependencies (for shared libraries)
        dependencies = extract_library_dependencies(file_path)
        
        # Check architecture compatibility
        architecture = detect_library_architecture(file_path)
        is_compatible = check_architecture_compatibility(architecture)
        
        return ProductionLibraryInfo(
            lib_type, file_path, lib_name, version, symbols,
            dependencies, architecture, is_compatible, priority
        )
        
    catch e
        # Non-critical error - library analysis failed
        return nothing
    end
end

"""
    extract_library_symbols_enhanced(file_path::String) -> Set{String}

Enhanced symbol extraction from library files.
"""
function extract_library_symbols_enhanced(file_path::String)
    symbols = Set{String}()
    
    try
        if endswith(file_path, ".so") || contains(file_path, ".so.")
            # Use nm or objdump for shared libraries
            if success(`which nm`)
                result = read(`nm -D $file_path`, String)
                for line in split(result, '\n')
                    # Parse nm output: address type symbol
                    parts = split(strip(line))
                    if length(parts) >= 3 && parts[2] == "T"  # Text (code) symbols
                        push!(symbols, parts[3])
                    end
                end
            end
        elseif endswith(file_path, ".a")
            # Use ar for static libraries
            if success(`which ar`)
                result = read(`ar -t $file_path`, String)
                for line in split(result, '\n')
                    line = strip(line)
                    if !isempty(line) && endswith(line, ".o")
                        # Could extract symbols from each object file
                        # For now, just note that the archive exists
                        push!(symbols, "archive_$(basename(line, ".o"))")
                    end
                end
            end
        end
    catch e
        # Symbol extraction failed - not critical
    end
    
    # Add common symbols based on library name
    if isempty(symbols)
        symbols = get_common_symbols_for_library(basename(file_path))
    end
    
    return symbols
end

"""
    get_common_symbols_for_library(lib_name::String) -> Set{String}

Get commonly expected symbols for well-known libraries.
"""
function get_common_symbols_for_library(lib_name::String)
    common_symbols = Dict{String, Vector{String}}(
        "libc.so" => ["printf", "malloc", "free", "strlen", "strcpy", "exit", "main"],
        "libc.so.6" => ["printf", "malloc", "free", "strlen", "strcpy", "exit", "main"],
        "libm.so" => ["sin", "cos", "sqrt", "pow", "log", "exp"],
        "libm.so.6" => ["sin", "cos", "sqrt", "pow", "log", "exp"],
        "libpthread.so" => ["pthread_create", "pthread_join", "pthread_mutex_init", "pthread_mutex_lock"],
        "libpthread.so.0" => ["pthread_create", "pthread_join", "pthread_mutex_init", "pthread_mutex_lock"],
        "libdl.so" => ["dlopen", "dlclose", "dlsym", "dlerror"],
        "libdl.so.2" => ["dlopen", "dlclose", "dlsym", "dlerror"]
    )
    
    base_name = basename(lib_name)
    return Set{String}(get(common_symbols, base_name, String[]))
end

"""
    extract_library_version_enhanced(file_path::String) -> String

Enhanced version extraction from library files.
"""
function extract_library_version_enhanced(file_path::String)
    # Try to extract version from filename
    filename = basename(file_path)
    
    # Pattern: lib<name>.so.<version>
    version_match = match(r"\.so\.(\d+(?:\.\d+)*)", filename)
    if version_match !== nothing
        return version_match.captures[1]
    end
    
    # Try using ldd or other tools for version info
    try
        if success(`which ldd`) && (endswith(file_path, ".so") || contains(file_path, ".so."))
            result = read(`ldd $file_path`, String)
            # Parse ldd output for version information
            for line in split(result, '\n')
                if contains(line, "libc.so.6")
                    # Extract GLIBC version
                    glibc_match = match(r"GLIBC_(\d+\.\d+)", line)
                    if glibc_match !== nothing
                        return "glibc-$(glibc_match.captures[1])"
                    end
                end
            end
        end
    catch e
        # Version detection failed - not critical
    end
    
    return "unknown"
end

"""
    extract_library_dependencies(file_path::String) -> Vector{String}

Extract library dependencies for shared libraries.
"""
function extract_library_dependencies(file_path::String)
    dependencies = String[]
    
    try
        if success(`which ldd`) && (endswith(file_path, ".so") || contains(file_path, ".so."))
            result = read(`ldd $file_path`, String)
            for line in split(result, '\n')
                line = strip(line)
                if contains(line, " => ")
                    # Parse: libname.so => /path/to/lib (address)
                    parts = split(line, " => ")
                    if length(parts) >= 2
                        dep_name = strip(parts[1])
                        if startswith(dep_name, "lib") && !contains(dep_name, "ld-linux")
                            push!(dependencies, dep_name)
                        end
                    end
                end
            end
        end
    catch e
        # Dependency extraction failed - not critical
    end
    
    return dependencies
end

"""
    detect_library_architecture(file_path::String) -> String

Detect the architecture of a library file.
"""
function detect_library_architecture(file_path::String)
    try
        if success(`which file`)
            result = read(`file $file_path`, String)
            if contains(result, "x86-64") || contains(result, "x86_64")
                return "x86_64"
            elseif contains(result, "i386") || contains(result, "i686")
                return "i386"
            elseif contains(result, "ARM") || contains(result, "aarch64")
                return "arm64"
            end
        end
    catch e
        # Architecture detection failed
    end
    
    return "unknown"
end

"""
    check_architecture_compatibility(arch::String) -> Bool

Check if the library architecture is compatible with the current system.
"""
function check_architecture_compatibility(arch::String)
    # For simplicity, assume x86_64 system
    # In production, this would check against actual system architecture
    return arch in ["x86_64", "unknown"]
end

"""
    resolve_library_dependencies(libraries::Vector{ProductionLibraryInfo}) -> Vector{ProductionLibraryInfo}

Resolve and order libraries based on dependencies.
"""
function resolve_library_dependencies(libraries::Vector{ProductionLibraryInfo})
    println("🔗 Resolving library dependencies...")
    
    # Sort by priority (higher priority first)
    sorted_libs = sort(libraries, by=lib -> lib.priority, rev=true)
    
    # Filter compatible libraries
    compatible_libs = filter(lib -> lib.is_compatible, sorted_libs)
    
    # Remove duplicates (keep highest priority version)
    unique_libs = ProductionLibraryInfo[]
    seen_names = Set{String}()
    
    for lib in compatible_libs
        if !(lib.name in seen_names)
            push!(unique_libs, lib)
            push!(seen_names, lib.name)
            println("   ✅ Selected $(lib.name): $(lib.path)")
        end
    end
    
    return unique_libs
end

"""
    find_production_libraries(library_names::Vector{String}, search_paths::Vector{String} = String[]) -> Vector{ProductionLibraryInfo}

Find libraries needed for production linking with enhanced detection.
"""
function find_production_libraries(library_names::Vector{String}, search_paths::Vector{String} = String[])
    println("🔍 Finding production libraries: $(join(library_names, ", "))")
    
    # Get system libraries
    system_libs = detect_system_libraries_enhanced()
    
    # Filter requested libraries
    requested_libs = ProductionLibraryInfo[]
    
    for lib_name in library_names
        found = false
        for sys_lib in system_libs
            if sys_lib.name == lib_name
                push!(requested_libs, sys_lib)
                found = true
                break
            end
        end
        
        if !found
            println("   ⚠️  Library '$lib_name' not found in system")
        end
    end
    
    # Resolve dependencies and return ordered list
    return resolve_library_dependencies(requested_libs)
end

"""
    validate_production_libraries(libraries::Vector{ProductionLibraryInfo}) -> Bool

Validate that all required libraries are available and compatible.
"""
function validate_production_libraries(libraries::Vector{ProductionLibraryInfo})
    println("✅ Validating production libraries...")
    
    all_valid = true
    
    for lib in libraries
        if !isfile(lib.path)
            println("   ❌ Library file missing: $(lib.path)")
            all_valid = false
            continue
        end
        
        if !lib.is_compatible
            println("   ❌ Library incompatible: $(lib.name) ($(lib.architecture))")
            all_valid = false
            continue
        end
        
        println("   ✅ $(lib.name) v$(lib.version) - OK")
    end
    
    return all_valid
end