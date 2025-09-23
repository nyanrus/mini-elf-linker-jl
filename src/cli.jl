# Command-Line Interface for Mini ELF Linker
# Provides lld-compatible command-line argument parsing and execution

"""
Mathematical Model for CLI:
```math
text{CLI}: mathcal{A} to mathcal{L}
```
where mathcal{A} = {command-line arguments} and mathcal{L} = {linker operations}

This module implements the mapping:
```math
begin{align}
text{parse_args}: mathcal{A} &to mathcal{P} \\
text{execute_linker}: mathcal{P} &to mathcal{L}
end{align}
```
where mathcal{P} = {parsed parameters}
"""

"""
    LinkerOptions

Structure representing parsed command-line options.

Mathematical representation:
```math
mathcal{P} = {
    text{input_files}: mathbb{F}*, 
    text{output_file}: mathbb{F} cup {emptyset},
    text{library_paths}: mathbb{P}*,
    text{library_names}: mathbb{L}*,
    text{options}: mathbb{O}
}
```
where mathbb{F} = files, mathbb{P} = paths, mathbb{L} = library names, mathbb{O} = boolean options
"""
mutable struct LinkerOptions
    input_files::Vector{String}
    output_file::Union{String, Nothing}
    library_search_paths::Vector{String}
    library_names::Vector{String}
    base_address::UInt64
    entry_symbol::String
    enable_system_libraries::Bool
    verbose::Bool
    help::Bool
    version::Bool
    shared::Bool
    static::Bool
    
    LinkerOptions() = new(
        String[],           # input_files
        nothing,            # output_file  
        String[],           # library_search_paths
        String[],           # library_names
        0x400000,          # base_address
        "main",            # entry_symbol
        true,              # enable_system_libraries
        false,             # verbose
        false,             # help
        false,             # version
        false,             # shared
        false              # static
    )
end

"""
    parse_arguments(args::Vector{String}) -> LinkerOptions

Parse command-line arguments into LinkerOptions structure.

Mathematical transformation:
```math
text{parse_arguments}: text{args} mapsto begin{cases}
    text{input_files} &leftarrow {f in text{args} : neg text{is_flag}(f)} \\
    text{library_names} &leftarrow {l : text{"-l"} cdot l in text{args}} \\
    text{library_paths} &leftarrow {p : text{"-L"} cdot p in text{args}} \\
    text{output_file} &leftarrow {o : text{"-o"} cdot o in text{args}}
end{cases}
```
"""
function parse_arguments(args::Vector{String})::LinkerOptions
    options = LinkerOptions()
    i = 1
    
    while i <= length(args)
        arg = args[i]
        
        if arg == "--help" || arg == "-h"
            options.help = true
        elseif arg == "--version"
            options.version = true
        elseif arg == "-v" || arg == "--verbose"
            options.verbose = true
        elseif arg == "-shared"
            options.shared = true
        elseif arg == "-static"
            options.static = true
            options.enable_system_libraries = false
        elseif arg == "-o" || arg == "--output"
            if i + 1 <= length(args)
                options.output_file = args[i + 1]
                i += 1
            else
                error("Option $arg requires an argument")
            end
        elseif startswith(arg, "-o")
            # Handle -ofile format
            options.output_file = arg[3:end]
        elseif arg == "-L"
            if i + 1 <= length(args)
                push!(options.library_search_paths, args[i + 1])
                i += 1
            else
                error("Option $arg requires an argument")
            end
        elseif startswith(arg, "-L")
            # Handle -L/path format
            push!(options.library_search_paths, arg[3:end])
        elseif arg == "-l"
            if i + 1 <= length(args)
                push!(options.library_names, args[i + 1])
                i += 1
            else
                error("Option $arg requires an argument")
            end
        elseif startswith(arg, "-l")
            # Handle -lmath format
            push!(options.library_names, arg[3:end])
        elseif arg == "--entry" || arg == "-e"
            if i + 1 <= length(args)
                options.entry_symbol = args[i + 1]
                i += 1
            else
                error("Option $arg requires an argument")
            end
        elseif startswith(arg, "--entry=")
            options.entry_symbol = split(arg, "=", 2)[2]
        elseif arg == "--Ttext" || arg == "--Ttext-segment"
            if i + 1 <= length(args)
                options.base_address = parse(UInt64, args[i + 1], base=16)
                i += 1
            else
                error("Option $arg requires an argument")
            end
        elseif startswith(arg, "--Ttext=")
            options.base_address = parse(UInt64, split(arg, "=", 2)[2], base=16)
        elseif arg == "--no-system-libs"
            options.enable_system_libraries = false
        elseif startswith(arg, "-")
            # Unknown flag - warn but continue
            if options.verbose
                println("Warning: Unknown flag '$arg' ignored")
            end
        else
            # Input file
            push!(options.input_files, arg)
        end
        
        i += 1
    end
    
    return options
end

"""
    show_help()

Display help message with LLD-compatible options.
"""
function show_help()
    println("""
Mini ELF Linker - LLD Compatible Interface

USAGE:
    mini-elf-linker [OPTIONS] <input-files>...

OPTIONS:
    -o, --output <file>         Write output to <file>
    -L <dir>                    Add directory to library search path
    -l <lib>                    Link against library <lib>
    -e, --entry <symbol>        Set entry point symbol (default: main)
    --Ttext <addr>              Set text segment base address (hex)
    -shared                     Create shared library
    -static                     Force static linking, disable system libraries
    --no-system-libs            Disable automatic system library linking
    -v, --verbose               Verbose output
    -h, --help                  Show this help message
    --version                   Show version information

EXAMPLES:
    mini-elf-linker file.o                           # Link single object
    mini-elf-linker -o program file.o                # Specify output name
    mini-elf-linker -lm -lpthread file.o             # Link with math and pthread
    mini-elf-linker -L/opt/lib -lmath file.o         # Custom library path
    mini-elf-linker --entry start file.o             # Custom entry point
    mini-elf-linker --Ttext 0x800000 file.o          # Custom base address

LLD COMPATIBILITY:
    This linker provides a subset of LLD functionality, focusing on basic
    object file linking and executable generation. Mathematical model:
    
    CLI_args → parse_arguments() → LinkerOptions → execute_linker() → ELF_output
""")
end

"""
    show_version()

Display version information.
"""
function show_version()
    println("Mini ELF Linker v0.1.0")
    println("LLD-compatible interface for educational ELF linking")
    println("Built with Julia $(VERSION)")
end

"""
    execute_linker(options::LinkerOptions) -> Int

Execute the linker with parsed options.

Mathematical execution model:
```math
text{execute_linker}: mathcal{P} to mathbb{Z}
```
where the return code follows POSIX convention: 0 = success, non-zero = failure.

Implementation follows the transformation:
```math
begin{cases}
text{if } |text{input_files}| = 0 & to text{error}(1) \\
text{if } text{output_file} = emptyset & to text{link_objects}(text{files}) \\
text{if } text{output_file} neq emptyset & to text{link_to_executable}(text{files}, text{output})
end{cases}
```
"""
function execute_linker(options::LinkerOptions)::Int
    try
        if options.help
            show_help()
            return 0
        end
        
        if options.version
            show_version()
            return 0
        end
        
        if isempty(options.input_files)
            println("Error: No input files specified")
            println("Use --help for usage information")
            return 1
        end
        
        if options.verbose
            println("📋 Linker Configuration:")
            println("   Input files: $(options.input_files)")
            println("   Output file: $(options.output_file)")
            println("   Library paths: $(options.library_search_paths)")
            println("   Library names: $(options.library_names)")
            println("   Base address: 0x$(string(options.base_address, base=16))")
            println("   Entry symbol: $(options.entry_symbol)")
            println("   System libraries: $(options.enable_system_libraries)")
            println()
        end
        
        # Execute linking based on whether output file is specified
        if options.output_file === nothing
            # Just link objects without generating executable
            if options.verbose
                println("🔗 Linking objects (no executable generation)...")
            end
            
            linker = link_objects(
                options.input_files;
                base_address = options.base_address,
                enable_system_libraries = options.enable_system_libraries,
                library_search_paths = options.library_search_paths,
                library_names = options.library_names
            )
            
            if options.verbose
                println("✅ Linking completed successfully")
                print_symbol_table(linker)
            end
            
        else
            # Generate executable
            if options.verbose
                println("🔗 Linking and generating executable '$(options.output_file)'...")
            end
            
            success = link_to_executable(
                options.input_files,
                options.output_file;
                base_address = options.base_address,
                entry_symbol = options.entry_symbol,
                enable_system_libraries = options.enable_system_libraries,
                library_search_paths = options.library_search_paths,
                library_names = options.library_names
            )
            
            if success
                if options.verbose
                    println("✅ Executable '$(options.output_file)' generated successfully")
                end
            else
                println("❌ Failed to generate executable")
                return 1
            end
        end
        
        return 0
        
    catch e
        println("Error: $e")
        if options.verbose
            println("Stack trace:")
            for (exc, bt) in Base.catch_stack()
                showerror(stdout, exc, bt)
                println()
            end
        end
        return 1
    end
end

"""
    main(args::Vector{String} = ARGS) -> Int

Main entry point for command-line interface.

Mathematical composition:
```math
text{main} = text{execute_linker} circ text{parse_arguments}
```
"""
function main(args::Vector{String} = ARGS)::Int
    try
        options = parse_arguments(args)
        return execute_linker(options)
    catch e
        println("Error parsing arguments: $e")
        println("Use --help for usage information")
        return 1
    end
end