# Command Line Interface Specification

## Overview

The CLI interface handles command-line argument parsing and program execution coordination. As a non-algorithmic component focused on configuration and user interaction, this specification uses direct Julia documentation following the Mathematical-Driven AI Development methodology.

## Interface Design (Julia Direct Documentation)

### LinkerOptions Configuration Structure
```julia
"""
LinkerOptions contains all configuration parameters extracted from command-line arguments.
This is a non-algorithmic data structure for storing user preferences and program settings.

Fields:
- input_files: Object files to link together
- output_file: Target executable name (default: "a.out")
- library_names: Libraries to link against (from -l flags)
- library_search_paths: Additional library search directories (from -L flags)  
- base_address: Memory base address for text segment
- entry_symbol: Symbol name for program entry point
- help: Show help message flag
- version: Show version information flag
- static_link: Create statically linked executable
"""
mutable struct LinkerOptions
    input_files::Vector{String}
    output_file::String
    library_names::Vector{String}
    library_search_paths::Vector{String}
    base_address::UInt64
    entry_symbol::String
    help::Bool
    version::Bool
    static_link::Bool
    
    function LinkerOptions()
        new(
            String[],           # input_files
            "a.out",            # output_file (default)
            String[],           # library_names
            String[],           # library_search_paths
            0x400000,           # base_address (standard x86-64 default)
            "main",             # entry_symbol (C convention)
            false,              # help
            false,              # version
            false               # static_link
        )
    end
end
```

### Argument Processing Implementation
```julia
"""
parse_arguments processes command-line arguments into LinkerOptions.
Non-algorithmic: straightforward option parsing without complex algorithms.

This implementation follows Unix linker conventions for compatibility with ld and lld.
"""
function parse_arguments(args::Vector{String})::LinkerOptions
    options = LinkerOptions()
    i = 1
    
    while i ≤ length(args)
        arg = args[i]
        
        # Help and version flags
        if arg ∈ ["--help", "-h"]
            options.help = true
            
        elseif arg == "--version"
            options.version = true
            
        # Output file specification
        elseif arg ∈ ["-o", "--output"]
            if i + 1 > length(args)
                throw(ArgumentError("Option $arg requires an argument"))
            end
            options.output_file = args[i + 1]
            i += 1
            
        elseif startswith(arg, "-o")
            # Compact form: -ofilename
            options.output_file = arg[3:end]
            
        # Library search paths
        elseif arg == "-L"
            if i + 1 > length(args)
                throw(ArgumentError("Option -L requires a directory path"))
            end
            push!(options.library_search_paths, args[i + 1])
            i += 1
            
        elseif startswith(arg, "-L")
            # Compact form: -L/path/to/libs
            push!(options.library_search_paths, arg[3:end])
            
        # Library names
        elseif startswith(arg, "-l")
            if length(arg) ≤ 2
                throw(ArgumentError("Option -l requires a library name"))
            end
            # Extract library name: -lmath → "math"
            library_name = arg[3:end]
            push!(options.library_names, library_name)
            
        # Entry point specification
        elseif arg ∈ ["-e", "--entry"]
            if i + 1 > length(args)
                throw(ArgumentError("Option $arg requires a symbol name"))
            end
            options.entry_symbol = args[i + 1]
            i += 1
            
        # Base address specification
        elseif startswith(arg, "--Ttext=")
            addr_str = arg[9:end]
            options.base_address = parse_address_string(addr_str)
            
        elseif startswith(arg, "--Ttext-segment=")
            addr_str = arg[17:end]
            options.base_address = parse_address_string(addr_str)
            
        # Linking mode
        elseif arg == "-static"
            options.static_link = true
            
        elseif arg == "-shared"
            @warn "Shared library creation not yet implemented"
            
        # Input files (non-option arguments)
        elseif !startswith(arg, "-")
            push!(options.input_files, arg)
            
        else
            @warn "Unknown option '$arg' ignored"
        end
        
        i += 1
    end
    
    return options
end
```

### Address Parsing Utilities
```julia
"""
parse_address_string converts various address formats to UInt64.
Non-algorithmic utility function for handling different numeric formats.

Supported formats:
- Hexadecimal: 0x400000, 0X400000
- Decimal: 4194304
- Octal: 0o17777777 (Julia syntax)
"""
function parse_address_string(addr_str::String)::UInt64
    try
        if startswith(addr_str, "0x") || startswith(addr_str, "0X")
            return parse(UInt64, addr_str[3:end], base=16)
        elseif startswith(addr_str, "0o")
            return parse(UInt64, addr_str[3:end], base=8)
        else
            return parse(UInt64, addr_str, base=10)
        end
    catch e
        throw(ArgumentError("Invalid address format: '$addr_str'"))
    end
end
```

## Program Flow Control (Julia Direct Documentation)

### Main Entry Point
```julia
"""
main function coordinates the complete program execution flow.
Non-algorithmic: program structure and control flow management.
"""
function main(args::Vector{String} = ARGS)::Int
    try
        # Parse command-line arguments
        options = parse_arguments(args)
        
        # Handle information requests
        if options.help
            show_help_message()
            return 0
        end
        
        if options.version
            show_version_information()
            return 0
        end
        
        # Validate input
        if isempty(options.input_files)
            println(stderr, "Error: No input files specified")
            println(stderr, "Use --help for usage information")
            return 1
        end
        
        # Execute linking process
        return execute_linker_with_options(options)
        
    catch e
        println(stderr, "Error: $e")
        return 1
    end
end
```

### Linker Execution Coordinator
```julia
"""
execute_linker_with_options coordinates the linking process using parsed options.
Non-algorithmic: orchestrates the mathematical linking algorithms with user configuration.
"""
function execute_linker_with_options(options::LinkerOptions)::Int
    try
        println("MiniElfLinker: Linking $(length(options.input_files)) object file(s)")
        
        # Execute the mathematical linking pipeline
        linker = execute_linking_pipeline(
            options.input_files,
            options.output_file;
            base_address = options.base_address,
            entry_symbol = options.entry_symbol,
            library_search_paths = options.library_search_paths,
            library_names = options.library_names,
            static_link = options.static_link
        )
        
        println("Successfully created executable: $(options.output_file)")
        return 0
        
    catch e
        println(stderr, "Linking failed: $e")
        return 1
    end
end
```

## Help and Information Display (Julia Direct Documentation)

### Help System
```julia
"""
show_help_message displays comprehensive usage information.
Non-algorithmic: user interface and documentation display.
"""
function show_help_message()
    println("""
MiniElfLinker - Educational ELF Linker Implementation

USAGE:
    mini-elf-linker [OPTIONS] file1.o file2.o ...

OPTIONS:
    -o <file>, --output <file>    Write output to <file> (default: a.out)
    -l<name>                      Link with library lib<name>.a or lib<name>.so
    -L<path>                      Add <path> to library search paths
    --Ttext=<address>             Set base address for text segment
    --Ttext-segment=<address>     Alternative form of --Ttext
    -e <symbol>, --entry <symbol> Set entry point symbol (default: main)
    -static                       Create statically linked executable
    -h, --help                    Show this help message
    --version                     Show version information

ADDRESS FORMATS:
    Hexadecimal: 0x400000, 0X400000
    Decimal:     4194304
    Octal:       0o17777777

EXAMPLES:
    # Basic linking
    mini-elf-linker main.o utils.o -o myprogram
    
    # Link with system libraries
    mini-elf-linker main.o -lc -lm -o myprogram
    
    # Custom library paths and base address
    mini-elf-linker main.o -L/usr/local/lib -lmylib --Ttext=0x10000000 -o myprogram
    
    # Static linking with custom entry point
    mini-elf-linker start.o main.o -static -e _start -o myprogram

LIBRARY SEARCH ORDER:
    1. Paths specified with -L options (in order)
    2. Standard system library directories:
       /lib, /lib64, /usr/lib, /usr/lib64, /usr/local/lib
    3. Architecture-specific directories (e.g., /usr/lib/x86_64-linux-gnu)

EXIT CODES:
    0 - Success
    1 - General error (parsing, linking, file I/O)
    2 - Invalid command line arguments  
    3 - File not found or permission denied
""")
end
```

### Version Information
```julia
"""
show_version_information displays program version and build details.
Non-algorithmic: static information display.
"""
function show_version_information()
    println("""
MiniElfLinker v0.1.0
Educational ELF linker implementation in Julia

Build Information:
  Target:       x86_64-linux-gnu
  Julia:        $(VERSION)
  Architecture: $(Sys.ARCH)
  Platform:     $(Sys.KERNEL)

Features:
  ✅ ELF object file linking
  ✅ Symbol resolution
  ✅ Basic relocations (R_X86_64_64, R_X86_64_PC32)
  ✅ System library integration
  ✅ Static executable generation
  ⚠️  Dynamic linking (partial)
  ❌ Shared library creation
  ❌ LTO support

For more information: https://github.com/nyanrus/mini-elf-linker-jl
""")
end
```

## Error Handling and Validation (Julia Direct Documentation)

### Input Validation
```julia
"""
validate_input_files checks that all specified input files exist and are readable.
Non-algorithmic: file system interaction and validation.
"""
function validate_input_files(input_files::Vector{String})
    for filename ∈ input_files
        if !isfile(filename)
            throw(ArgumentError("Input file not found: $filename"))
        end
        
        if !isreadable(filename)
            throw(ArgumentError("Input file not readable: $filename"))
        end
        
        # Basic file type validation
        file_type = detect_file_type_by_magic(filename)
        if file_type == "unknown"
            @warn "Unknown file type for $filename, will attempt to process"
        end
    end
end
```

### Option Validation
```julia
"""
validate_linker_options performs semantic validation on parsed options.
Non-algorithmic: configuration validation and consistency checking.
"""
function validate_linker_options(options::LinkerOptions)
    # Validate output file can be created
    output_dir = dirname(options.output_file)
    if !isempty(output_dir) && !isdir(output_dir)
        throw(ArgumentError("Output directory does not exist: $output_dir"))
    end
    
    # Validate base address alignment
    if options.base_address % 0x1000 != 0
        @warn "Base address $(options.base_address) is not page-aligned"
    end
    
    # Validate library search paths
    for path ∈ options.library_search_paths
        if !isdir(path)
            @warn "Library search path does not exist: $path"
        end
    end
    
    # Validate input files exist
    validate_input_files(options.input_files)
end
```

## Integration with Mathematical Components

### Interface to Algorithmic Linker
```julia
"""
execute_linking_pipeline bridges CLI configuration to mathematical linking algorithms.
This function adapts non-algorithmic CLI parameters to the algorithmic core processes.
"""
function execute_linking_pipeline(input_files::Vector{String}, 
                                 output_file::String;
                                 base_address::UInt64 = 0x400000,
                                 entry_symbol::String = "main",
                                 library_search_paths::Vector{String} = String[],
                                 library_names::Vector{String} = String[],
                                 static_link::Bool = false)
    
    # Create linker with mathematical algorithms
    linker = DynamicLinker(base_address=base_address)
    
    # Configure library paths (non-algorithmic configuration)
    linker.library_search_paths = vcat(library_search_paths, get_default_library_search_paths())
    linker.library_names = library_names
    
    # Execute mathematical linking pipeline: ℒ = ω ∘ ρ ∘ φ ∘ δ ∘ π
    for filename ∈ input_files
        load_object(linker, filename)  # π_parse component
    end
    
    # Apply mathematical algorithms (see core_processes.md)
    δ_resolve_symbols(linker)          # Symbol resolution algorithm
    φ_allocate_memory_regions!(linker) # Memory allocation algorithm  
    ρ_perform_relocations!(linker)     # Relocation algorithm
    ω_serialize_executable(linker, output_file) # Serialization
    
    return linker
end
```

### Library Path Processing → Library search path handling

```math
library\_paths: \{L\_flag \in args : L\_flag = "-L" \lor startswith(L\_flag, "-L")\} \to Vector(String)
```

**Path extraction logic**:
```math
extract\_library\_path(L\_flag) = \begin{cases}
args[next(L\_flag)] & \text{if } L\_flag = "-L" \\
substring(L\_flag, 3) & \text{if } startswith(L\_flag, "-L") \land |L\_flag| > 2
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: Library path extraction and validation
elseif arg == "-L"
    if i + 1 <= length(args)
        push!(options.library_search_paths, args[i + 1])  # ↔ Path list extension
        i += 1                                             # ↔ Parameter consumption
    else
        error("Option $arg requires an argument")          # ↔ Validation error
    end
elseif startswith(arg, "-L")
    # Handle -L/path format
    push!(options.library_search_paths, arg[3:end])       # ↔ Embedded path extraction
```

### Library Name Processing → Library linking directives

```math
library\_names: \{l\_flag \in args : l\_flag = "-l" \lor startswith(l\_flag, "-l")\} \to Vector(String)
```

**Library name mapping**:
```math
library\_resolution(name) = \begin{cases}
"lib" + name + ".so" & \text{if shared linking} \\
"lib" + name + ".a" & \text{if static linking} \\
search\_all\_variants(name) & \text{if mixed linking}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: Library name processing with deferred resolution
elseif arg == "-l"
    if i + 1 <= length(args)
        push!(options.library_names, args[i + 1])     # ↔ Name storage
        i += 1
    else
        error("Option $arg requires an argument")
    end
elseif startswith(arg, "-l")
    # Handle -lmath format  
    push!(options.library_names, arg[3:end])          # ↔ Embedded name extraction
```

### Address Parsing → Base address specification

```math
parse\_address: HexString \to UInt64 \cup \{Error\}
```

**Address validation**:
```math
valid\_address(addr) = addr \in [0x400000, 0x7FFFFFFF] \land aligned(addr, 0x1000)
```

**Direct code correspondence**:
```julia
# Mathematical model: Address parsing with validation
elseif arg == "--Ttext" || arg == "--Ttext-segment"
    if i + 1 <= length(args)
        options.base_address = parse(UInt64, args[i + 1], base=16)  # ↔ Hex parsing
        i += 1
    else
        error("Option $arg requires an argument")
    end
elseif startswith(arg, "--Ttext=")
    options.base_address = parse(UInt64, split(arg, "=", 2)[2], base=16)  # ↔ Embedded hex parsing
```

### Help System → `show_help` function

```math
show\_help: \{\} \to IO\_Output
```

**Information organization**:
```math
help\_content = \{usage, options, examples, compatibility\_notes\}
```

**Direct code correspondence**:
```julia
# Mathematical model: Structured help output generation
function show_help()
    println("""
Mini ELF Linker - LLD Compatible Interface

USAGE:
    mini-elf-linker [OPTIONS] <input-files>...

OPTIONS:
    -o, --output <file>         Write output to <file>
    -L <dir>                    Add directory to library search path
    -l <lib>                    Link against library <lib>
    # ... (structured option documentation)
    """)                                              # ↔ Formatted output generation
end
```

### Version Information → `show_version` function

```math
version\_info: \{\} \to \{version\_string, build\_info, compatibility\_level\}
```

**Direct code correspondence**:
```julia
# Mathematical model: Version information compilation
function show_version()
    println("Mini ELF Linker v0.1.0")               # ↔ Version string output
    println("Julia implementation of ELF linking")   # ↔ Description
    println("Compatible with LLD/GNU ld interface")  # ↔ Compatibility statement
end
```

### Linker Execution → `execute_linker` function

```math
execute\_linker: LinkerOptions \to Boolean
```

**Execution pipeline**:
```math
options \xrightarrow{validate} validated\_options \xrightarrow{link} result \xrightarrow{output} success\_status
```

**Direct code correspondence**:
```julia
# Mathematical model: execute_linker: LinkerOptions → Boolean
function execute_linker(options::LinkerOptions)::Bool
    try
        # Validation phase
        if options.help
            show_help()                               # ↔ Help action
            return true
        elseif options.version
            show_version()                            # ↔ Version action
            return true
        end
        
        # Input validation
        if isempty(options.input_files)
            error("No input files specified")        # ↔ Validation error
        end
        
        # Execution phase: options → linking → result
        if options.output_file !== nothing
            return link_to_executable(                # ↔ Executable generation
                options.input_files,
                options.output_file,
                base_address = options.base_address,
                entry_symbol = options.entry_symbol,
                enable_system_libraries = options.enable_system_libraries
            )
        else
            # Default output name generation
            output_name = generate_default_output_name(options.input_files[1])
            return link_to_executable(options.input_files, output_name)
        end
        
    catch e
        if options.verbose
            println("Linker error: $e")              # ↔ Error reporting
        end
        return false                                  # ↔ Failure status
    end
end
```

### Main Entry Point → `main` function

```math
main: Vector(String) \to ExitCode
```

**Program flow control**:
```math
main(args) = \begin{cases}
0 & \text{if } execute\_linker(parse\_arguments(args)) = true \\
1 & \text{otherwise}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: main: Vector(String) → ExitCode
function main(args::Vector{String} = ARGS)
    try
        options = parse_arguments(args)               # ↔ Argument parsing phase
        success = execute_linker(options)             # ↔ Execution phase
        exit(success ? 0 : 1)                        # ↔ Exit code mapping
    catch e
        println(stderr, "Error: $e")                 # ↔ Error output
        exit(1)                                      # ↔ Error exit code
    end
end
```

## Complexity Analysis

```math
\begin{align}
T_{parse}(n) &= O(n) \quad \text{– Linear argument processing} \\
T_{validate}(m) &= O(m) \quad \text{where } m = \text{option count} \\
T_{execute}(f) &= O(linking(f)) \quad \text{where } f = \text{input files} \\
S_{options}(n) &= O(n) \quad \text{– Storage proportional to arguments}
\end{align}
```

## LLD Compatibility Matrix

```math
\text{Compatibility mapping: } lld\_option \mapsto mini\_elf\_option
```

| LLD Option | Mini ELF Linker | Status | Mathematical Equivalence |
|------------|-----------------|---------|-------------------------|
| `-o output` | `-o output` | ✅ Full | $output_{lld} = output_{mini}$ |
| `-L path` | `-L path` | ✅ Full | $paths_{lld} = paths_{mini}$ |
| `-l lib` | `-l lib` | ✅ Full | $libs_{lld} = libs_{mini}$ |
| `--entry sym` | `--entry sym` | ✅ Full | $entry_{lld} = entry_{mini}$ |
| `-shared` | `-shared` | ⚠️ Partial | $shared_{lld} \approx shared_{mini}$ |
| `-static` | `-static` | ✅ Full | $static_{lld} = static_{mini}$ |
| `--verbose` | `--verbose` | ✅ Full | $verbose_{lld} = verbose_{mini}$ |

## Error Handling and Robustness

```math
\text{Error recovery: } \forall arg \in args: \exists action \in \{process, warn, error\}
```

**Error classification**:
```math
error\_type(condition) = \begin{cases}
FATAL & \text{if } missing\_required\_parameter(condition) \\
WARNING & \text{if } unknown\_flag(condition) \\
IGNORE & \text{if } redundant\_option(condition)
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: Robust error handling with classification
elseif startswith(arg, "-")
    # Unknown flag - warn but continue
    if options.verbose
        println("Warning: Unknown flag '$arg' ignored")  # ↔ Warning classification
    end
    # Continue processing (graceful degradation)
```

## Optimization Trigger Points

- **Argument parsing**: Single-pass linear algorithm with early termination for help/version
- **Memory allocation**: Pre-allocate vectors based on typical argument patterns
- **String processing**: Minimize string allocations during parsing
- **Validation**: Defer expensive validation until execution phase