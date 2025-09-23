# Dynamic Linker Mathematical Specification

## Mathematical Model

```math
\text{Domain: } \mathcal{D} = \{\text{ELF objects}, \text{Symbol tables}, \text{Memory layouts}\}
\text{Range: } \mathcal{R} = \{\text{Linked executables}, \text{Resolved symbols}, \text{Memory mappings}\}
\text{Mapping: } link: \mathcal{D} \to \mathcal{R}
```

## Operations

```math
\text{Primary operations: } \{resolve\_symbols, load\_objects, apply\_relocations, allocate\_memory\}
\text{Invariants: } \{symbol\_uniqueness, memory\_non\_overlap, address\_valid\}
\text{Complexity bounds: } O(n \cdot m + r) \text{ where } n,m,r = \text{symbols, objects, relocations}
```

## Implementation Correspondence

### Symbol Resolution → `resolve_symbols` function

```math
resolve: DynamicLinker \to DynamicLinker \cup \{Error\}
```

**Mathematical operation**: Symbol table lookup and binding resolution

```math
lookup\_symbol(name, tables) = \begin{cases}
address & \text{if } name \in global\_symbols \\
weak\_default & \text{if } name \in weak\_symbols \\
error & \text{if } name \text{ unresolved and strong}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: resolve: DynamicLinker → DynamicLinker ∪ {Error}
function resolve_symbols(linker::DynamicLinker)::DynamicLinker
    # Implementation of: symbol table lookup with binding priority
    for symbol in get_undefined_symbols(linker)     # ↔ undefined symbol iteration
        definition = lookup_global(symbol.name)     # ↔ global table lookup
        if definition !== nothing
            symbol.address = definition.address     # ↔ address assignment
            symbol.resolved = true                  # ↔ state update
        elseif symbol.binding == STB_WEAK
            symbol.address = 0                      # ↔ weak default handling
            symbol.resolved = true
        else
            error("Unresolved strong symbol: $(symbol.name)")  # ↔ error condition
        end
    end
    return linker
end
```

### Memory Allocation → `allocate_section` function

```math
allocate: DynamicLinker \times Section \times Size \to MemoryRegion
```

**Mathematical constraint**: Non-overlapping memory allocation

```math
\forall m_1, m_2 \in memory\_regions: 
[m_1.base, m_1.base + m_1.size) \cap [m_2.base, m_2.base + m_2.size) = \emptyset
```

**Direct code correspondence**:
```julia
# Mathematical model: allocate: DynamicLinker × Section × Size → MemoryRegion
function allocate_section(linker::DynamicLinker, section::SectionHeader, size::Int)::MemoryRegion
    # Implementation of: find_next_available_address with alignment
    current_address = linker.next_address           # ↔ address tracking
    aligned_address = align_to_page(current_address)  # ↔ alignment constraint
    
    # Verify non-overlap: ∀m ∈ memory_regions: disjoint(new_region, m)
    verify_no_overlap(aligned_address, size, linker.memory_regions)
    
    region = MemoryRegion(Vector{UInt8}(undef, size), aligned_address, size, section.flags)
    push!(linker.memory_regions, region)           # ↔ region registration
    linker.next_address = aligned_address + size   # ↔ address advancement
    return region
end
```

### Relocation Application → `apply_relocations` function

```math
apply\_relocations: DynamicLinker \times List(RelocationEntry) \to DynamicLinker
```

**Mathematical operations**: Address computation and patch application

```math
relocate(entry) = \begin{cases}
target\_addr + symbol\_addr & \text{if R\_X86\_64\_64} \\
symbol\_addr - current\_addr & \text{if R\_X86\_64\_PC32} \\
symbol\_addr + addend & \text{if R\_X86\_64\_RELA}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: apply_relocations: DynamicLinker × List(RelocationEntry) → DynamicLinker
function apply_relocations(linker::DynamicLinker, relocations::Vector{RelocationEntry})::DynamicLinker
    for reloc in relocations                       # ↔ relocation iteration
        symbol = resolve_symbol_reference(reloc.symbol_index)  # ↔ symbol lookup
        target_address = reloc.offset + section_base_address   # ↔ target calculation
        
        # Mathematical case analysis for relocation types
        relocated_value = if reloc.type == R_X86_64_64
            symbol.address + reloc.addend           # ↔ absolute addressing
        elseif reloc.type == R_X86_64_PC32
            symbol.address - target_address         # ↔ relative addressing  
        else
            error("Unsupported relocation type")
        end
        
        patch_memory(target_address, relocated_value)  # ↔ memory patching
    end
    return linker
end
```

## Complexity Analysis

```math
\begin{align}
T_{symbol\_resolution}(n,m) &= O(n \cdot m) \quad \text{– Symbol lookup in object tables} \\
T_{memory\_allocation}(k) &= O(k \log k) \quad \text{– Sorted region management} \\
T_{relocation}(r) &= O(r) \quad \text{– Linear relocation processing} \\
T_{total\_linking}(n,m,r) &= O(n \cdot m + r + k \log k) \quad \text{– Combined operations}
\end{align}
```

**Critical path**: Symbol resolution with O(n·m) complexity for cross-object lookups.

## Transformation Pipeline

```math
objects \xrightarrow{load} linker\_state \xrightarrow{resolve} resolved\_symbols \xrightarrow{relocate} executable\_image
```

**Code pipeline correspondence**:
```julia
# Mathematical pipeline: objects → linker_state → resolved_symbols → executable
function link_to_executable(object_files::Vector{String}, output_name::String)::Bool
    linker = DynamicLinker()                       # ↔ state initialization
    
    # Load phase: objects → linker_state  
    for file in object_files
        elf = parse_elf_file(file)                 # ↔ object parsing
        load_object(linker, elf)                   # ↔ state accumulation
    end
    
    # Resolve phase: linker_state → resolved_symbols
    resolve_symbols(linker)                        # ↔ symbol resolution
    
    # Relocate phase: resolved_symbols → executable
    apply_all_relocations(linker)                  # ↔ address patching
    
    # Generate phase: executable → file
    write_elf_executable(linker, output_name)      # ↔ binary generation
end
```

## Set-Theoretic Operations

**Symbol collection**:
```math
global\_symbols = \bigcup_{obj \in objects} symbols(obj)
```

**Undefined symbol filtering**:
```math
undefined = \{s \in global\_symbols : \neg defined(s)\}
```

**Memory region union**:
```math
total\_memory = \bigcup_{region \in memory\_regions} [region.base, region.base + region.size)
```

## Invariant Preservation

```math
\text{Symbol uniqueness: }
\forall s_1, s_2 \in global\_symbols: s_1.name = s_2.name \implies s_1.address = s_2.address
```

```math
\text{Memory safety: }
\forall m_1, m_2 \in memory\_regions: m_1 \neq m_2 \implies disjoint(m_1, m_2)
```

```math
\text{Relocation correctness: }
\forall r \in relocations: applied(r) \implies valid\_target\_address(r)
```

## Optimization Trigger Points

- **Inner loops**: Symbol resolution with O(n·m) nested iteration
- **Memory allocation**: Region sorting and search optimization opportunities
- **Bottleneck operations**: Cross-object symbol lookup with hash table potential
- **Invariant preservation**: Memory overlap checking with spatial data structures