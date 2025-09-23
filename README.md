# Mini ELF Linker in Julia

A proof-of-concept dynamic ELF linker implemented in Julia for educational purposes. This project provides a simple yet comprehensive implementation of an ELF (Executable and Linkable Format) file parser and dynamic linker, making it ideal for studying linker concepts and ELF file structure.

## Features

- **ELF File Parsing**: Complete parsing of ELF headers, section headers, symbol tables, and relocation entries
- **Symbol Resolution**: Global symbol table management with support for weak and strong symbols
- **Memory Management**: Virtual memory allocation for loaded sections
- **Relocation Handling**: Basic relocation processing for x86-64 architecture
- **Educational Focus**: Clean, well-documented code optimized for understanding rather than performance

## Architecture Overview

The linker consists of three main components:

1. **ELF Format Definitions** (`elf_format.jl`): Structures and constants defining the ELF file format
2. **ELF Parser** (`elf_parser.jl`): Functions to read and parse ELF files
3. **Dynamic Linker** (`dynamic_linker.jl`): Core linking functionality including symbol resolution and relocation

## Installation

```julia
# Clone the repository
git clone https://github.com/nyanrus/mini-elf-linker-jl.git
cd mini-elf-linker-jl

# Start Julia in the project directory
julia --project=.

# Import the package
using MiniElfLinker
```

## Quick Start

### Basic ELF File Parsing

```julia
using MiniElfLinker

# Parse an ELF file header
header = parse_elf_header("examples/test_program.o")
println("Entry point: 0x$(string(header.entry, base=16))")

# Parse the complete ELF file
elf_file = parse_elf_file("examples/test_program.o")
println("Sections: $(length(elf_file.sections))")
println("Symbols: $(length(elf_file.symbols))")
```

### Dynamic Linking

```julia
# Create a dynamic linker
linker = DynamicLinker(0x400000)

# Load object files
load_object(linker, "file1.o")
load_object(linker, "file2.o")

# Perform linking
linked_result = link_objects(["file1.o", "file2.o"])

# Examine results
print_symbol_table(linked_result)
print_memory_layout(linked_result)
```

## ELF File Structure

The ELF format consists of several key components that this linker handles:

### ELF Header
- File identification and metadata
- Entry point address
- Section and program header table offsets

### Section Headers
- Describe file sections (.text, .data, .bss, etc.)
- Section types, flags, and memory layout information

### Symbol Table
- Global and local symbol definitions
- Symbol types (function, object, etc.) and binding (global, weak, local)

### Relocations
- Instructions for fixing up addresses during linking
- Support for various relocation types (absolute, PC-relative, etc.)

## Supported Features

### Symbol Types
- `STT_NOTYPE`: Unspecified type
- `STT_OBJECT`: Data objects
- `STT_FUNC`: Functions
- `STT_SECTION`: Section symbols
- `STT_FILE`: File symbols

### Symbol Binding
- `STB_LOCAL`: Local scope
- `STB_GLOBAL`: Global scope  
- `STB_WEAK`: Weak global scope

### Relocation Types (x86-64)
- `R_X86_64_64`: Direct 64-bit address
- `R_X86_64_PC32`: PC-relative 32-bit
- `R_X86_64_GOT32`: GOT entry reference
- `R_X86_64_PLT32`: PLT entry reference

### Section Types
- `SHT_PROGBITS`: Program data
- `SHT_SYMTAB`: Symbol table
- `SHT_STRTAB`: String table
- `SHT_RELA`: Relocation entries with addends
- `SHT_NOBITS`: BSS sections

## Examples

The `examples/` directory contains several demonstration programs:

- `basic_usage.jl`: Fundamental parsing and linking operations
- `test_program.c`: Simple C program for generating test ELF objects

### Running Examples

```bash
# Compile test objects
cd examples
gcc -c test_program.c -o test_program.o

# Run examples
julia basic_usage.jl
```

## Educational Value

This implementation is designed to be educational and includes:

- **Clear Documentation**: Every function and structure is documented
- **Readable Code**: Prioritizes clarity over optimization
- **Complete Coverage**: Handles all major ELF components
- **Error Handling**: Informative error messages for debugging
- **Debugging Output**: Verbose logging of linking operations

## Limitations

As a proof-of-concept, this linker has several intentional limitations:

- **x86-64 Only**: Primary focus on 64-bit x86 architecture
- **Basic Relocations**: Limited relocation type support
- **No Optimization**: Code clarity prioritized over performance
- **Simplified Memory Model**: Basic virtual memory simulation
- **Limited Error Recovery**: Fails fast on errors for clarity

## References and Study Materials

This implementation draws inspiration from several excellent resources:

- **ELF Specification**: System V ABI ELF specification
- **GNU ld**: GNU linker implementation study
- **LLVM lld**: LLVM linker architecture
- **Linkers and Loaders**: John Levine's comprehensive book
- **Linux Programming Interface**: Chapter on shared libraries

### Recommended Reading

1. "Linkers and Loaders" by John R. Levine
2. System V ABI ELF specification
3. Intel 64 and IA-32 Architectures Software Developer's Manual
4. GNU binutils documentation
5. LLVM linker documentation

## Contributing

This is an educational project. Contributions that improve clarity, add documentation, or extend educational value are welcome. Please prioritize code readability and educational merit over performance optimizations.

## API Reference

### Core Types

- `ElfHeader`: ELF file header structure
- `SectionHeader`: Section header entry
- `SymbolTableEntry`: Symbol table entry
- `RelocationEntry`: Relocation entry with addend
- `DynamicLinker`: Main linker state

### Main Functions

- `parse_elf_header(filename)`: Parse ELF header from file
- `parse_elf_file(filename)`: Parse complete ELF file
- `DynamicLinker(base_address)`: Create new linker instance
- `load_object(linker, filename)`: Load object file
- `link_objects(filenames)`: Link multiple object files
- `resolve_symbols(linker)`: Resolve symbol references
- `print_symbol_table(linker)`: Display symbol table
- `print_memory_layout(linker)`: Display memory layout

## License

This project is provided for educational purposes. See LICENSE file for details.