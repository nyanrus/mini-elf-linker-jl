# AI Development Guidelines

## Core Principle: "Math Where Intuitive, Julia Where Practical"

**Key Decision**: For each component, choose the expression method that provides the clearest understanding and fastest development.

### When to Use Mathematical Expression

**Use math for algorithmic components** that benefit from mathematical understanding:
- ELF parsing algorithms and data transformations
- Symbol resolution and linking processes  
- Address calculation and memory layout operations
- Optimization opportunities in critical processing paths

### When to Use Direct Julia Implementation  

**Use Julia directly for structural components**:
- CLI interfaces and argument parsing
- File I/O and system interactions
- Data structures and containers (ELF headers, symbol tables)
- Configuration, setup, error handling, and logging

### Simple Implementation Process

```
Is this component algorithmic/computational? 
├── YES → Document mathematically → Implement with mathematical naming
└── NO → Implement directly in Julia with clear structure
```

## Implementation Examples

### For Algorithmic Components (ELF Processing)

Document the mathematical understanding, then implement:

```math
\text{ELF Symbol Resolution: } \mathcal{S}_{unresolved} \to \mathcal{S}_{resolved}
```

```julia
function resolve_symbol_addresses(𝒮_unresolved_symbols, 𝒯_symbol_table)
    resolved_symbols = Dict{String, UInt64}()
    for symbol_name ∈ keys(𝒮_unresolved_symbols)
        if symbol_name ∈ keys(𝒯_symbol_table)
            resolved_symbols[symbol_name] = 𝒯_symbol_table[symbol_name].address
        end
    end
    return resolved_symbols
end

function apply_relocations(𝑅_relocations, base_address::UInt64)
    return [relocation.offset + base_address for relocation ∈ 𝑅_relocations]
end
```

### For Structural Components (CLI, I/O)

Implement directly with clear naming:

```julia
struct LinkerConfig
    input_files::Vector{String}
    output_file::String
    library_paths::Vector{String}
    entry_point::String
    verbose::Bool
end

function parse_command_line_arguments(args::Vector{String})
    config = LinkerConfig([], "a.out", [], "main", false)
    # Direct argument processing logic
    return config
end

function load_elf_file(filename::String)
    open(filename, "r") do file
        # Direct file reading and parsing
        return read_elf_headers(file)
    end
end
```

## Naming Conventions

**For mathematical/algorithmic components**, use mathematical naming:
- Greek letters: `α_parameter`, `δ_threshold`, `σ_variance`
- Set notation: `𝒮_symbols`, `𝒯_table`, `𝑅_relocations`, `𝒟_data`
- Mathematical operators: `∈` instead of `in`

**For structural components**, use clear descriptive names:
- `LinkerConfig`, `ElfHeader`, `SymbolTable`
- `parse_arguments`, `load_file`, `write_output`
- Standard Julia conventions

## AI Implementation Guidelines

### Focus on Clarity and Effectiveness

1. **Choose the clearer approach** - math for algorithms, Julia for structure
2. **Implement working solutions first** - optimize later when needed
3. **Use self-documenting names** - reduce need for comments
4. **Replace completely when understanding improves** - no legacy preservation

### Quick Decision Framework

For each component, ask:
- Does mathematical notation make this clearer? → Use math specification + mathematical naming
- Is direct Julia implementation clearer? → Use direct implementation + descriptive naming

### Documentation Strategy

**For algorithmic critical components**: Use math to document understanding and discover optimization opportunities

**For non-algorithmic components**: Write Julia directly with clear structure as documentation

---

**Goal**: Enable AI to make fast, effective decisions about expression method while maintaining code clarity and development velocity.
