# Command Line Interface Specification

## Overview

The MiniElfLinker provides a command-line interface compatible with common Unix linkers like `ld`. This specification defines the supported options, argument parsing, and program behavior.

## Basic Usage

```bash
# Link object files into executable
mini-elf-linker file1.o file2.o -o program

# Link with libraries
mini-elf-linker main.o -lc -o program

# Specify library search paths
mini-elf-linker main.o -L/usr/local/lib -lmylib -o program

# Set base address
mini-elf-linker main.o --Ttext=0x400000 -o program
```

## Supported Options

### Output Control
- `-o <file>`, `--output <file>`: Specify output filename
- `-o<file>`: Alternative compact form

### Library Handling
- `-l<name>`: Link with library `lib<name>.a` or `lib<name>.so`
- `-L<path>`: Add directory to library search path
- `--library-path=<path>`: Alternative form for `-L`

### Memory Layout
- `--Ttext=<address>`: Set text segment base address
- `--Ttext-segment=<address>`: Alternative form
- `-e <symbol>`, `--entry=<symbol>`: Set entry point symbol

### Linking Mode
- `-static`: Create statically linked executable
- `-shared`: Create shared library (planned)

### Information Options
- `-h`, `--help`: Show help message
- `--version`: Show version information

## Argument Processing

### LinkerOptions Structure
```julia
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
end
```

### Default Values
```julia
function LinkerOptions()
    return LinkerOptions(
        String[],           # input_files
        "a.out",            # output_file
        String[],           # library_names
        String[],           # library_search_paths
        0x400000,           # base_address
        "main",             # entry_symbol
        false,              # help
        false,              # version
        false               # static_link
    )
end
```

### Argument Parser
```julia
function parse_arguments(args::Vector{String})::LinkerOptions
    options = LinkerOptions()
    i = 1
    
    while i <= length(args)
        arg = args[i]
        
        if arg in ["--help", "-h"]
            options.help = true
            
        elseif arg == "--version"
            options.version = true
            
        elseif arg in ["-o", "--output"]
            if i + 1 > length(args)
                error("Option $arg requires an argument")
            end
            options.output_file = args[i + 1]
            i += 1
            
        elseif startswith(arg, "-o")
            options.output_file = arg[3:end]
            
        elseif arg == "-L"
            if i + 1 > length(args)
                error("Option -L requires an argument")
            end
            push!(options.library_search_paths, args[i + 1])
            i += 1
            
        elseif startswith(arg, "-L")
            push!(options.library_search_paths, arg[3:end])
            
        elseif startswith(arg, "-l")
            push!(options.library_names, arg[3:end])
            
        elseif arg in ["-e", "--entry"]
            if i + 1 > length(args)
                error("Option $arg requires an argument")
            end
            options.entry_symbol = args[i + 1]
            i += 1
            
        elseif startswith(arg, "--Ttext=")
            addr_str = arg[9:end]
            options.base_address = parse_address(addr_str)
            
        elseif startswith(arg, "--Ttext-segment=")
            addr_str = arg[17:end]
            options.base_address = parse_address(addr_str)
            
        elseif arg == "-static"
            options.static_link = true
            
        elseif !startswith(arg, "-")
            # Input file
            push!(options.input_files, arg)
            
        else
            println("Warning: Unknown option '$arg' ignored")
        end
        
        i += 1
    end
    
    return options
end
```

## Address Parsing

Supports multiple address formats:
- Hexadecimal: `0x400000`, `0X400000`
- Decimal: `4194304`
- Octal: `0o17777777` (Julia format)

```julia
function parse_address(addr_str::String)::UInt64
    if startswith(addr_str, "0x") || startswith(addr_str, "0X")
        return parse(UInt64, addr_str[3:end], base=16)
    elseif startswith(addr_str, "0o")
        return parse(UInt64, addr_str[3:end], base=8)
    else
        return parse(UInt64, addr_str)
    end
end
```

## Help System

### Help Message
```
Usage: mini-elf-linker [OPTIONS] file1.o file2.o ...

Options:
  -o <file>              Write output to <file> (default: a.out)
  -l<name>               Link with library lib<name>.a
  -L<path>               Add <path> to library search paths
  --Ttext=<address>      Set base address for text segment
  -e <symbol>            Set entry point symbol (default: main)
  -static                Create statically linked executable
  -h, --help             Show this help message
  --version              Show version information

Examples:
  mini-elf-linker main.o utils.o -o myprogram
  mini-elf-linker main.o -lc -L/usr/local/lib -o myprogram
  mini-elf-linker main.o --Ttext=0x10000000 -o myprogram
```

### Version Information
```
MiniElfLinker v0.1.0
Educational ELF linker implementation in Julia
Target: x86_64-linux-gnu
```

## Error Messages

### Missing Arguments
```
Error: Option '-o' requires an argument
Error: Option '-L' requires an argument  
Error: Option '-e' requires an argument
```

### Invalid Input
```
Error: Invalid address format: '0xGGG'
Error: File not found: 'nonexistent.o'
Error: Cannot write to output file: '/root/output'
```

### Parsing Errors
```
Error: Failed to parse 'corrupted.o': Invalid ELF magic number
Error: Unsupported ELF architecture in 'arm_file.o'
```

## Program Flow

### Main Function
```julia
function main(args=ARGS)
    try
        options = parse_arguments(args)
        
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
            return 1
        end
        
        return execute_linker(options)
        
    catch e
        println("Error: $e")
        return 1
    end
end
```

### Linker Execution
```julia
function execute_linker(options::LinkerOptions)::Int
    try
        # Create linker with specified base address
        linker = DynamicLinker(base_address=options.base_address)
        
        # Load input objects
        for filename in options.input_files
            load_object(linker, filename)
        end
        
        # Link objects with libraries
        link_objects(linker, 
            library_search_paths=options.library_search_paths,
            library_names=options.library_names)
        
        # Generate executable
        link_to_executable(
            options.input_files, 
            options.output_file,
            base_address=options.base_address,
            entry_symbol=options.entry_symbol,
            library_search_paths=options.library_search_paths,
            library_names=options.library_names
        )
        
        return 0
        
    catch e
        println("Linking failed: $e")
        return 1
    end
end
```

## Environment Variables

### Library Search
- `LD_LIBRARY_PATH`: Additional library search directories
- `LIBRARY_PATH`: Compile-time library search paths

### Configuration
- `MINI_ELF_DEBUG`: Enable debug output (values: 0, 1)
- `MINI_ELF_TEMP_DIR`: Temporary directory for extracted archives

## Exit Codes

- `0`: Success
- `1`: General error (parsing, linking, file I/O)
- `2`: Invalid command line arguments
- `3`: File not found or permission denied

## Compatibility Notes

### GNU ld Compatibility
- Basic option syntax matches `ld`
- Subset of most common options
- Different error message format

### LLD Compatibility
- Similar modern option handling
- Compatible address format parsing
- Shared basic workflow

### Limitations
- No linker script support
- Limited relocation types
- No plugin system
- No LTO (Link Time Optimization)

## Future Extensions

### Planned Options
- `--dynamic-linker=<path>`: Set dynamic linker path
- `--rpath=<path>`: Set runtime library search path
- `--soname=<name>`: Set shared library name
- `-pie`: Create position-independent executable

### Advanced Features
- Linker script parsing
- Section manipulation options
- Symbol versioning support
- Garbage collection of unused sections

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