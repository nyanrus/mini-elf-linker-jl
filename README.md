# Mini ELF Linker in Julia

This is a study project implementing a basic ELF linker in Julia for educational purposes. The project aims to understand how dynamic linking works by building a simplified version of an ELF linker.

**Note**: This project is AI-driven and developed for learning purposes. We are unable to accept pull requests at this time.

## What is this project?

This is a simple implementation of an ELF (Executable and Linkable Format) linker written in Julia. It can:

- Parse ELF object files
- Link multiple object files together
- Generate executable ELF files
- Resolve symbols between different object files
- Work with system libraries like glibc

The project consists of several components:
- ELF file format parsing
- Symbol table management
- Dynamic linking functionality
- Basic relocation handling
- Command-line interface compatible with LLD/GCC syntax

## How to build this project

1. Clone the repository:
```bash
git clone https://github.com/nyanrus/mini-elf-linker-jl.git
cd mini-elf-linker-jl
```

2. Install Julia dependencies:
```bash
julia --project=.
```

3. In the Julia REPL:
```julia
using Pkg
Pkg.instantiate()
using MiniElfLinker
```

4. Run tests to verify everything works:
```bash
julia --project=. test/runtests.jl
```

## Command-line parameters

The linker provides a command-line interface with the following options:

```
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
```

You can also use the linker programmatically in Julia:

```julia
using MiniElfLinker

# Link object files to create an executable
link_to_executable(["main.o"], "my_program")

# Link multiple objects with custom settings
link_to_executable(["file1.o", "file2.o"], "program", 
                   base_address=0x400000, 
                   entry_symbol="main")
```

Have a nice day!