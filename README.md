# Mini ELF Linker in Julia

This is a study project implementing a basic ELF linker in Julia for educational purposes. The project aims to understand how dynamic linking works by building a simplified version of an ELF linker with comprehensive mathematical documentation.

**Note**: This project is AI-driven and developed for learning purposes. We are unable to accept pull requests at this time.

## 📐 Mathematical Documentation

This linker is documented using **Mathematical-Driven AI Development methodology** with humble, appropriate mathematical notations:

- **[Complete Mathematical Specification](MATHEMATICAL_SPECIFICATION.md)** - Comprehensive mathematical framework
- **[Mathematical-Driven Development Guide](README_DOCUMENTATION.md)** - Documentation structure and methodology

## What is this project?

This is a mathematically-documented implementation of an ELF (Executable and Linkable Format) linker written in Julia. It demonstrates:

**Algorithmic Components** (Mathematical Expression):
- ELF parsing algorithms with mathematical transformations: $\Pi_{parse}: \text{BinaryFile} \to \mathcal{E}_{structured}$
- Symbol resolution using set theory: $\delta_{resolve}: \mathcal{S}_{undefined} \times \mathcal{S}_{global} \to (\mathcal{S}_{resolved}, \mathcal{S}_{unresolved})$
- Memory allocation with spatial mathematics: $\phi_{allocate}: \mathcal{S}_{sections} \to \mathcal{M}_{regions}$
- Relocation processing with address computation: $\rho_{relocate}: \mathcal{R}_{entries} \to \mathcal{M}_{patched}$

**Structural Components** (Direct Julia):
- Command-line interface with LLD/GCC compatibility
- File I/O and system interactions
- Configuration and error handling
- Library support and system integration

**Complete Linking Pipeline**:
```math
\mathcal{L}_{complete} = \omega_{serialize} \circ \rho_{relocate} \circ \phi_{allocate} \circ \delta_{resolve} \circ \pi_{parse}
```

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

## AI Playground

This repository includes an **AI Playground** directory (`ai-playground/`) containing AI-generated test files, experimental scripts, and development iterations. This space allows for:

- AI-assisted development experiments
- Testing new features and approaches
- Learning from previous development iterations
- Safe experimentation without cluttering the main repository

All files in the AI playground (except the README) are gitignored, making it a perfect space for AI development work while keeping the main project structure clean and focused.

Have a nice day!