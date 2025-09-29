= Dynamic Linker Mathematical Specification

== Mathematical Model

$
\text{Domain: } \mathcal{D} = \{\text{ELF objects} \times \text{Symbol tables} \times \text{Memory layouts} \times \text{Relocation entries}\}
\text{Range: } \mathcal{R} = \{\text{Linked executables} \times \text{Resolved symbols} \times \text{Memory mappings}\}
\text{Mapping: } \Delta: \mathcal{D} \to \mathcal{R}
$

_Dynamic Linker State Space_:
$
\mathcal{S}_{\Delta} = \langle \mathcal{O}, \Sigma, \mathcal{M}, \mathcal{R}, \alpha_{base}, \alpha_{next} \rangle
$

where:
- $\mathcal{O} = \{o_i\}_{i=1}^n$ is the set of loaded ELF objects
- $\Sigma: \text{String} \to \text{Symbol}$ is the global symbol table mapping
- $\mathcal{M} = \{m_j\}_{j=1}^k$ is the set of allocated memory regions
- $\mathcal{R} = \{r_l\}_{l=1}^p$ is the set of relocation entries
- $\alpha_{base}, \alpha_{next} \in \mathbb{N}_{64}$ are address space boundaries

== Operations

$
\text{Primary operations: } \{\delta_{resolve}, \delta_{load}, \delta_{relocate}, \delta_{allocate}\}
$

_Operation Signatures_:
$
\begin{align}
\delta_{load} &: \text{ElfFile} \times \mathcal{S}_{\Delta} \to \mathcal{S}_{\Delta}' \\
\delta_{resolve} &: \mathcal{S}_{\Delta} \to \mathcal{S}_{\Delta}' \times \mathcal{U} \\
\delta_{allocate} &: \mathcal{S}_{\Delta} \to \mathcal{S}_{\Delta}' \\
\delta_{relocate} &: \mathcal{S}_{\Delta} \to \mathcal{S}_{\Delta}'
\end{align}
$

where $\mathcal{U}$ is the set of unresolved symbols.

_Invariants_:
$
\begin{align}
\text{Symbol uniqueness: } &\forall s_1, s_2 \in \Sigma: s_1.name = s_2.name \implies s_1.address = s_2.address \\
\text{Memory safety: } &\forall m_i, m_j \in \mathcal{M}: i \neq j \implies disjoint(m_i, m_j) \\
\text{Address validity: } &\forall a \in addresses: \alpha_{base} \leq a < \alpha_{next}
\end{align}
$

_Complexity bounds_: $O(|\mathcal{O}| \cdot |\Sigma| + |\mathcal{R}|)$

== Implementation Correspondence

=== Symbol Resolution → `resolve_symbols` function

$
\delta_{resolve}: \mathcal{S}_{\Delta} \to \mathcal{S}_{\Delta}' \times \mathcal{U}
$

_Mathematical operation_: Global symbol table construction with binding resolution

$
\Sigma'(name) = \begin{cases}
\text{address}(def) & \text{if } \exists def \in \bigcup_{o \in \mathcal{O}} symbols(o): def.name = name \land defined(def) \\
0 & \text{if } binding(name) = STB\_WEAK \land \neg\exists def \\
\bot & \text{if } binding(name) = STB\_STRONG \land \neg\exists def
\end{cases}
$

_Symbol binding precedence ordering_:
$
STB\_GLOBAL \succ STB\_WEAK \succ STB\_LOCAL
$

_Direct code correspondence_:
```julia
= Mathematical model: δ_resolve: S_Δ → S_Δ' × U
function resolve_symbols(linker::DynamicLinker)::Vector{String}
    # Implementation of: Σ'(name) construction with binding precedence
    unresolved_symbols = String[]                           # ↔ U initialization
    
    for (symbol_name, symbol) in linker.global_symbol_table  # ↔ Σ iteration
        if !symbol.defined                                  # ↔ ¬defined(symbol)
            # Search in loaded objects: ⋃_{o ∈ O} symbols(o)
            found_definition = nothing
            for obj in linker.loaded_objects                # ↔ object iteration
                for obj_symbol in obj.symbols               # ↔ symbol search
                    obj_symbol_name = get_string_from_table(obj.symbol_string_table, obj_symbol.name)
                    if obj_symbol_name == symbol_name && obj_symbol.section != 0  # ↔ defined check
                        found_definition = obj_symbol       # ↔ definition found
                        break
                    end
                end
                found_definition !== nothing && break
            end
            
            if found_definition !== nothing
                # Update symbol with definition: Σ'(name) = address(def)
                updated_symbol = Symbol(
                    symbol_name, found_definition.value, found_definition.size,
                    found_definition.binding, found_definition.type, found_definition.section,
                    true, symbol.source_file                # ↔ defined = true
                )
                linker.global_symbol_table[symbol_name] = updated_symbol
            elseif symbol.binding == STB_WEAK               # ↔ weak binding check
                # Weak symbol default: Σ'(name) = 0
                weak_symbol = Symbol(symbol_name, 0, 0, STB_WEAK, symbol.type, 0, true, "weak_default")
                linker.global_symbol_table[symbol_name] = weak_symbol
            else
                # Strong unresolved: symbol ∈ U
                push!(unresolved_symbols, symbol_name)     # ↔ add to unresolved set
            end
        end
    end
    
    return unresolved_symbols                               # ↔ U result
end
```

=== Memory Allocation → `allocate_section` function

$
allocate: DynamicLinker \times Section \times Size \to MemoryRegion
$

_Mathematical constraint_: Non-overlapping memory allocation

$
\forall m_1, m_2 \in memory\_regions: 
[m_1.base, m_1.base + m_1.size) \cap [m_2.base, m_2.base + m_2.size) = \emptyset
$

_Direct code correspondence_:
```julia
= Mathematical model: allocate: DynamicLinker × Section × Size → MemoryRegion
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

=== Relocation Application → `perform_relocation!` function

$
perform\_relocation: DynamicLinker \times ElfFile \times RelocationEntry \to DynamicLinker
$

_Mathematical operations_: Symbol index correction and address computation

$
symbol\_lookup(index_{elf}) = \begin{cases}
symbols[index_{elf} + 1] & \text{if } index_{elf} > 0 \\
null\_symbol & \text{if } index_{elf} = 0
\end{cases}
$

_Critical Index Correction_: ELF uses 0-based indexing, Julia uses 1-based indexing

$
index_{julia} = index_{elf} + 1
$

_Relocation value computation_:
$
relocate(entry) = \begin{cases}
symbol\_addr + addend & \text{if R\_X86\_64\_64} \\
symbol\_addr + addend - (target\_addr + 4) & \text{if R\_X86\_64\_PC32} \\
symbol\_addr + addend - (target\_addr + 4) & \text{if R\_X86\_64\_PLT32}
\end{cases}
$

_Direct code correspondence_:
```julia
= Mathematical model: perform_relocation: DynamicLinker × ElfFile × RelocationEntry → DynamicLinker
function perform_relocation!(linker::DynamicLinker, elf_file::ElfFile, relocation::RelocationEntry)
    sym_index = elf64_r_sym(relocation.info)      # ↔ extract symbol index
    
    # Critical fix: Convert from 0-based ELF indexing to 1-based Julia indexing
    julia_index = sym_index + 1                   # ↔ index correction
    symbol = elf_file.symbols[julia_index]        # ↔ correct symbol lookup
    
    # Symbol resolution with global table lookup
    symbol_name = get_string_from_table(elf_file.symbol_string_table, symbol.name)
    if haskey(linker.global_symbol_table, symbol_name)
        symbol_value = linker.global_symbol_table[symbol_name].value  # ↔ address resolution
    end
    
    # PC-relative relocation calculation with correct target address
    if rel_type == R_X86_64_PLT32 || rel_type == R_X86_64_PC32
        target_addr = text_region.base_address + relocation.offset + 4  # ↔ next instruction address
        value = Int64(symbol_value) + relocation.addend - Int64(target_addr)  # ↔ relative offset
        apply_relocation_to_region!(text_region, relocation.offset, value, 4)
    end
end
```

== Complexity Analysis

$
\begin{align}
T_{symbol\_resolution}(n,m) &= O(n \cdot m) \quad \text{– Symbol lookup in object tables} \\
T_{memory\_allocation}(k) &= O(k \log k) \quad \text{– Sorted region management} \\
T_{relocation}(r) &= O(r) \quad \text{– Linear relocation processing} \\
T_{total\_linking}(n,m,r) &= O(n \cdot m + r + k \log k) \quad \text{– Combined operations}
\end{align}
$

_Critical path_: Symbol resolution with O(n·m) complexity for cross-object lookups.

== Transformation Pipeline

$
objects \xrightarrow{load} linker\_state \xrightarrow{resolve} resolved\_symbols \xrightarrow{relocate} executable\_image
$

_Code pipeline correspondence_:
```julia
= Mathematical pipeline: objects → linker_state → resolved_symbols → executable
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

== Set-Theoretic Operations

_Symbol collection_:
$
global\_symbols = \bigcup_{obj \in objects} symbols(obj)
$

_Undefined symbol filtering_:
$
undefined = \{s \in global\_symbols : \neg defined(s)\}
$

_Memory region union_:
$
total\_memory = \bigcup_{region \in memory\_regions} [region.base, region.base + region.size)
$

== Invariant Preservation

$
\text{Symbol uniqueness: }
\forall s_1, s_2 \in global\_symbols: s_1.name = s_2.name \implies s_1.address = s_2.address
$

$
\text{Memory safety: }
\forall m_1, m_2 \in memory\_regions: m_1 \neq m_2 \implies disjoint(m_1, m_2)
$

$
\text{Relocation correctness: }
\forall r \in relocations: applied(r) \implies valid\_target\_address(r)
$

== Optimization Trigger Points

- _Inner loops_: Symbol resolution with O(n·m) nested iteration
- _Memory allocation_: Region sorting and search optimization opportunities
- _Bottleneck operations_: Cross-object symbol lookup with hash table potential
- _Invariant preservation_: Memory overlap checking with spatial data structures