# CLI Mathematical Specification

## Mathematical Model

```math
\text{Domain: } \mathcal{D} = \{\text{Command-line arguments}, \text{Option strings}, \text{File paths}\}
\text{Range: } \mathcal{R} = \{\text{LinkerOptions}, \text{Program actions}, \text{Error states}\}
\text{Mapping: } cli: \mathcal{D} \to \mathcal{R}
```

## Operations

```math
\text{Primary operations: } \{parse\_arguments, execute\_linker, show\_help, show\_version\}
\text{Invariants: } \{option\_consistency, file\_path\_validity, parameter\_completeness\}
\text{Complexity bounds: } O(n) \text{ where } n = \text{argument count}
```

## Command-Line Parsing Mathematical Model

### Argument Classification

```math
classify(arg) = \begin{cases}
HELP\_FLAG & \text{if } arg \in \{"-h", "--help"\} \\
VERSION\_FLAG & \text{if } arg = "--version" \\
OUTPUT\_FLAG & \text{if } arg \in \{"-o", "--output"\} \lor startswith(arg, "-o") \\
LIBRARY\_PATH & \text{if } arg = "-L" \lor startswith(arg, "-L") \\
LIBRARY\_NAME & \text{if } arg = "-l" \lor startswith(arg, "-l") \\
ENTRY\_POINT & \text{if } arg \in \{"-e", "--entry"\} \\
BASE\_ADDRESS & \text{if } arg \in \{"--Ttext", "--Ttext-segment"\} \\
LINKAGE\_MODE & \text{if } arg \in \{"-shared", "-static"\} \\
INPUT\_FILE & \text{if } \neg startswith(arg, "-") \\
UNKNOWN\_FLAG & \text{otherwise}
\end{cases}
```

### Parameter Extraction

```math
extract\_parameter(flag, args, index) = \begin{cases}
args[index + 1] & \text{if } flag \text{ requires argument} \land index + 1 \leq |args| \\
substring(flag, offset) & \text{if } flag \text{ contains embedded value} \\
Error & \text{if } flag \text{ requires argument} \land index + 1 > |args| \\
\emptyset & \text{otherwise}
\end{cases}
```

## Implementation Correspondence

### Argument Parsing → `parse_arguments` function

```math
parse\_arguments: Vector(String) \to LinkerOptions \cup \{Error\}
```

**Transformation pipeline**:
```math
args \xrightarrow{classify} classified\_args \xrightarrow{extract} parameters \xrightarrow{validate} LinkerOptions
```

**Direct code correspondence**:
```julia
# Mathematical model: parse_arguments: Vector(String) → LinkerOptions ∪ {Error}
function parse_arguments(args::Vector{String})::LinkerOptions
    options = LinkerOptions()                      # ↔ Initialize empty options
    i = 1
    
    while i <= length(args)                        # ↔ Linear traversal O(n)
        arg = args[i]
        
        # Mathematical classification and processing
        if arg == "--help" || arg == "-h"
            options.help = true                    # ↔ Help flag activation
        elseif arg == "--version"
            options.version = true                 # ↔ Version flag activation
        elseif arg == "-o" || arg == "--output"
            # Parameter extraction with validation
            if i + 1 <= length(args)
                options.output_file = args[i + 1]  # ↔ Output file assignment
                i += 1                             # ↔ Advance past parameter
            else
                error("Option $arg requires an argument")  # ↔ Error state
            end
        elseif startswith(arg, "-o")
            # Embedded parameter extraction
            options.output_file = arg[3:end]       # ↔ String slicing
        # ... (additional classifications)
        else
            # Input file classification
            push!(options.input_files, arg)       # ↔ File list accumulation
        end
        
        i += 1                                     # ↔ Iterator advancement
    end
    
    return options
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