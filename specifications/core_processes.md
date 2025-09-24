# Core Linker Processes Specification

## Overview

This specification defines the core processes that transform multiple object files into a single executable. The MiniElfLinker implements these processes using a clear pipeline architecture.

## Process Pipeline

### 1. Object File Loading
**Purpose**: Load and validate ELF object files
**Input**: List of file paths
**Output**: Parsed ELF objects with symbol tables

```julia
function load_objects(filenames)
    objects = []
    for filename in filenames
        elf_object = parse_elf_file(filename)
        push!(objects, elf_object)
    end
    return objects
end
```

**Responsibilities**:
- File existence validation
- ELF format verification
- Section header parsing
- Symbol table extraction

### 2. Symbol Resolution
**Purpose**: Resolve all undefined symbols by finding their definitions
**Input**: Parsed objects + library search paths
**Output**: Complete symbol table with resolved addresses

```julia
function resolve_symbols(linker::DynamicLinker)
    unresolved = String[]
    for (name, symbol) in linker.global_symbol_table
        if !symbol.defined
            # Search for definition in loaded objects or libraries
            definition = find_symbol_definition(name, linker)
            if definition !== nothing
                symbol.value = definition.value
                symbol.defined = true
            else
                push!(unresolved, name)
            end
        end
    end
    return unresolved
end
```

**Responsibilities**:
- Symbol definition lookup
- Address assignment
- Undefined symbol tracking
- Library symbol resolution

### 3. Memory Layout Allocation
**Purpose**: Assign memory addresses to all sections
**Input**: Resolved symbols and sections
**Output**: Memory layout with assigned addresses

```julia
function allocate_memory_regions!(linker)
    current_address = linker.base_address
    
    for object in linker.objects
        for section in object.sections
            if section.type != SHT_NULL
                section.allocated_address = current_address
                current_address += section.size
            end
        end
    end
end
```

**Responsibilities**:
- Address space management
- Section alignment
- Memory region calculation
- Address assignment

### 4. Relocation Application
**Purpose**: Update addresses in object code based on final memory layout
**Input**: Memory layout + relocation entries
**Output**: Relocated object code

```julia
function perform_relocations!(linker)
    for object in linker.objects
        for relocation in object.relocations
            target_address = calculate_target_address(relocation, linker)
            apply_relocation(relocation, target_address, object.data)
        end
    end
end
```

**Responsibilities**:
- Relocation type handling
- Address calculation
- Binary patching
- Reference updating

### 5. Executable Generation
**Purpose**: Serialize linked code into final executable
**Input**: Relocated objects + memory layout
**Output**: ELF executable file

```julia
function write_executable(linker, output_filename)
    executable_data = serialize_sections(linker)
    program_headers = create_program_headers(linker)
    elf_header = create_elf_header(linker, program_headers)
    
    write_elf_file(output_filename, elf_header, program_headers, executable_data)
end
```

**Responsibilities**:
- ELF header creation
- Program header generation
- Section serialization
- File writing

## Error Handling

Each process includes comprehensive error handling:

### Load Errors
- File not found
- Invalid ELF format
- Unsupported architecture

### Resolution Errors  
- Undefined symbols
- Circular dependencies
- Library not found

### Memory Errors
- Address conflicts
- Insufficient space
- Invalid alignment

### Relocation Errors
- Unknown relocation types
- Invalid targets
- Overflow conditions

## Configuration Options

### Base Address
- Default: `0x400000` (typical for executables)
- Configurable via `--Ttext` option
- Must be page-aligned

### Entry Point
- Default: `_start` symbol
- Fallback: `main` with runtime setup
- Configurable via `--entry` option

### Library Handling
- System library integration
- Custom search paths
- Static vs dynamic linking

## Performance Characteristics

### Time Complexity
- Object loading: O(total file size)
- Symbol resolution: O(symbols × libraries)
- Memory allocation: O(sections)
- Relocation: O(relocations)
- Serialization: O(final executable size)

### Space Complexity
- Symbol table: O(unique symbols)
- Memory layout: O(sections)
- Temporary data: O(largest object file)

## Implementation Status

- ✅ Object file loading
- ✅ Basic symbol resolution
- ✅ Memory layout allocation
- ✅ Simple relocations (R_X86_64_64, R_X86_64_PC32)
- ✅ Executable generation
- ⚠️ Advanced relocations (partial)
- ⚠️ Dynamic linking (basic)
- ❌ Shared library creation

```math
\mathcal{L}_{state} = \langle \mathcal{O}, \Sigma, \mathcal{M}, \alpha_{base}, \alpha_{next}, \mathcal{T} \rangle
```

where:
- $\mathcal{O} = \{o_i\}_{i=1}^n$ is the set of loaded ELF objects
- $\Sigma: \text{String} \to \text{Symbol}$ is the global symbol table
- $\mathcal{M} = \{m_j\}_{j=1}^k$ is the set of memory regions
- $\alpha_{base}, \alpha_{next} \in \mathbb{N}_{64}$ are base and next addresses
- $\mathcal{T}$ is the set of temporary files for cleanup

**Direct code correspondence**:
```julia
# Mathematical model: L_state = ⟨O, Σ, M, α_base, α_next, T⟩
mutable struct DynamicLinker
    loaded_objects::Vector{ElfFile}           # ↔ O = {o_i}
    global_symbol_table::Dict{String, Symbol} # ↔ Σ: String → Symbol  
    memory_regions::Vector{MemoryRegion}      # ↔ M = {m_j}
    base_address::UInt64                      # ↔ α_base ∈ ℕ₆₄
    next_address::UInt64                      # ↔ α_next ∈ ℕ₆₄
    temp_files::Vector{String}                # ↔ T cleanup set
end
```

### Symbol Resolution Function → `resolve_symbols` function

```math
\phi_{resolve}: \mathcal{L}_{state} \times \mathcal{P} \to \mathcal{L}_{state}' \cup \{\bot\}
```

**Mathematical operation**: Global symbol table construction with library resolution

```math
\Sigma'(name) = \begin{cases}
definition.address & \text{if } name \in \bigcup_{o \in \mathcal{O}} symbols(o) \\
library\_lookup(name, \mathcal{P}) & \text{if } name \notin local\_symbols \\
\text{weak\_default} & \text{if } binding(name) = STB\_WEAK \\
\bot & \text{if } binding(name) = STB\_STRONG \land name \text{ unresolved}
\end{cases}
```

**Direct code correspondence**:
```julia
# Mathematical model: φ_resolve: L_state × P → L_state' ∪ {⊥}
function resolve_symbols(linker::DynamicLinker)::Vector{String}
    # Implementation of: Σ'(name) construction with library lookup
    unresolved_symbols = String[]
    
    for (name, symbol) in linker.global_symbol_table    # ↔ symbol iteration
        if !symbol.defined                              # ↔ undefined check
            # Library lookup: name ∈ ⋃_{lib ∈ libraries} symbols(lib)
            if symbol.binding == STB_GLOBAL             # ↔ strong binding
                push!(unresolved_symbols, name)         # ↔ unresolved accumulation
            elseif symbol.binding == STB_WEAK           # ↔ weak binding  
                # Weak default: assign default value
                symbol = Symbol(name, 0, 0, STB_WEAK, symbol.type, 0, true, "default")
                linker.global_symbol_table[name] = symbol  # ↔ weak_default assignment
            end
        end
    end
    
    return unresolved_symbols                           # ↔ unresolved set
end
```

### Memory Allocation Function → `allocate_memory_regions!` function

```math
\phi_{allocate}: \mathcal{L}_{state} \to \mathcal{L}_{state}
```

**Mathematical constraint**: Non-overlapping memory allocation with alignment

```math
\forall m_i, m_j \in \mathcal{M}: i \neq j \implies [\alpha_{base}(m_i), \alpha_{base}(m_i) + size(m_i)) \cap [\alpha_{base}(m_j), \alpha_{base}(m_j) + size(m_j)) = \emptyset
```

**Address computation**:
```math
\alpha_{next}' = \max_{m \in \mathcal{M}} (\alpha_{base}(m) + size(m))
```

**Direct code correspondence**:
```julia
# Mathematical model: φ_allocate: L_state → L_state
function allocate_memory_regions!(linker::DynamicLinker)
    # Implementation of: non-overlapping memory region assignment
    current_address = linker.base_address                   # ↔ α_base initialization
    
    for obj in linker.loaded_objects                        # ↔ object iteration
        for section in obj.sections                         # ↔ section iteration
            if (section.flags & SHF_ALLOC) != 0            # ↔ allocatable filter
                # Alignment constraint: align_to_page for memory consistency
                aligned_address = align_to_page(current_address)    # ↔ alignment operation
                
                # Create memory region: m = ⟨data, α_base, size, permissions⟩
                region = MemoryRegion(
                    Vector{UInt8}(undef, section.size),    # ↔ data allocation
                    aligned_address,                       # ↔ α_base(m)
                    section.size,                         # ↔ size(m)
                    section.flags                         # ↔ permissions
                )
                
                push!(linker.memory_regions, region)      # ↔ M' = M ∪ {m}
                current_address = aligned_address + section.size  # ↔ α_next advancement
            end
        end
    end
    
    linker.next_address = current_address                  # ↔ α_next' assignment
end
```

### Complete Linking Pipeline → `link_to_executable` function

```math
\phi_{complete}: \text{FilePath}^n \times \text{FilePath} \to \{0, 1\}
```

**Mathematical pipeline**: Complete ELF processing workflow

```math
\begin{align}
\{f_1, f_2, \ldots, f_n\} &\xrightarrow{\phi_{parse}^n} \{o_1, o_2, \ldots, o_n\} \\
&\xrightarrow{\phi_{load}} \mathcal{L}_{state} \\
&\xrightarrow{\phi_{resolve}} \mathcal{L}_{state}' \\
&\xrightarrow{\phi_{allocate}} \mathcal{L}_{state}'' \\
&\xrightarrow{\phi_{relocate}} \mathcal{L}_{state}''' \\
&\xrightarrow{\phi_{serialize}} \text{ExecutableBinary}
\end{align}
```

**Direct code correspondence**:
```julia
# Mathematical model: φ_complete: FilePath^n × FilePath → {0,1}
function link_to_executable(object_files::Vector{String}, output_name::String)::Bool
    # Implementation of: complete linking pipeline composition
    try
        linker = DynamicLinker()                          # ↔ L_state initialization
        
        # Parse phase: {f_i} → {o_i} via φ_parse^n
        for file in object_files                          # ↔ file iteration
            elf_obj = parse_elf_file(file)                # ↔ φ_parse(f_i)
            load_object(linker, elf_obj)                  # ↔ φ_load: o_i → L_state
        end
        
        # Resolve phase: L_state → L_state' via φ_resolve
        unresolved = resolve_symbols(linker)              # ↔ symbol resolution
        
        # Library resolution: P × unresolved → resolved
        if !isempty(unresolved)                          # ↔ unresolved check
            resolve_unresolved_symbols!(linker, unresolved)  # ↔ library lookup
        end
        
        # Allocate phase: L_state' → L_state'' via φ_allocate
        allocate_memory_regions!(linker)                 # ↔ memory allocation
        
        # Relocate phase: L_state'' → L_state''' via φ_relocate
        perform_relocations!(linker)                      # ↔ address patching
        
        # Serialize phase: L_state''' → ExecutableBinary via φ_serialize
        entry_point = find_entry_point(linker)           # ↔ entry point resolution
        return write_elf_executable(linker, output_name, entry_point)  # ↔ binary generation
        
    catch e
        return false                                      # ↔ error state
    end
end
```

### Export Interface → Public API definition

```math
public\_interface = \{f : f \in module\_functions \land exported(f)\}
```

**Set-theoretic operation**: Function export filtering

```math
exported\_functions = \{parse\_elf\_file, link\_to\_executable, write\_elf\_executable, \ldots\}
```

**Direct code correspondence**:
```julia
# Mathematical model: public_interface = {f : f ∈ module_functions ∧ exported(f)}

# Core parsing interface: parse_elf_file: String → ElfFile
# Implementation corresponds to: file_path ↦ structured_representation
export parse_elf_file

# High-level linking interface: link_to_executable: List(String) × String → Boolean  
# Implementation corresponds to: (object_files, output) ↦ success_status
export link_to_executable

# Low-level writing interface: write_elf_executable: DynamicLinker × String × Address → Boolean
# Implementation corresponds to: (linker_state, file, entry) ↦ serialization_result
export write_elf_executable

# Utility interfaces for debugging and analysis
export print_symbol_table       # ↔ symbol table display
export print_memory_layout      # ↔ memory layout visualization
```

## Complexity Analysis

```math
\begin{align}
T_{\phi_{parse}}(n,s) &= O(n \cdot s) \quad \text{– Parse n files of average size s} \\
T_{\phi_{resolve}}(s,l) &= O(s \cdot l) \quad \text{– Resolve s symbols across l libraries} \\
T_{\phi_{allocate}}(r) &= O(r) \quad \text{– Allocate r memory regions} \\
T_{\phi_{relocate}}(e) &= O(e) \quad \text{– Apply e relocation entries} \\
T_{\phi_{serialize}}(m) &= O(m) \quad \text{– Serialize m bytes to file} \\
T_{\mathcal{L}}(n,s,l,r,e,m) &= O(n \cdot s + s \cdot l + r + e + m) \quad \text{– Total pipeline}
\end{align}
```

**Critical path**: Symbol resolution with O(s·l) complexity dominates for large codebases.

**Space complexity**:
```math
S_{\mathcal{L}}(n,s,r) = O(n \cdot s + r \cdot p) \quad \text{where } p = \text{average memory region size}
```

## Mathematical Properties and Invariants

### Commutativity Properties

**Object loading commutativity**:
```math
\forall o_1, o_2 \in \mathcal{O}: \phi_{load}(o_1) \circ \phi_{load}(o_2) = \phi_{load}(o_2) \circ \phi_{load}(o_1)
```
*Proof*: Object loading only adds to global symbol table and object list without modification.

**Symbol resolution idempotency**:
```math
\phi_{resolve} \circ \phi_{resolve} = \phi_{resolve}
```
*Proof*: Once symbols are resolved, subsequent resolution has no effect.

### Correctness Invariants

**Memory consistency**:
```math
\forall m_i, m_j \in \mathcal{M}: i \neq j \implies memory\_regions\_disjoint(m_i, m_j)
```

**Symbol uniqueness**:
```math
\forall s_1, s_2 \in \Sigma: s_1.name = s_2.name \implies s_1.address = s_2.address
```

**Format compliance**:
```math
\forall e \in \text{generated executables}: valid\_elf\_format(e) = \text{true}
```

### Error Propagation Laws

**Pipeline failure propagation**:
```math
\phi_{k} = \bot \implies \mathcal{L} = \bot \quad \text{for any stage } k
```

**Graceful degradation for weak symbols**:
```math
weak\_symbol\_unresolved(s) \not\Rightarrow \mathcal{L} = \bot
```

## Transformation Pipeline

```math
\mathcal{F}_{input} \xrightarrow{\phi_{parse}} \mathcal{O} \xrightarrow{\phi_{load}} \mathcal{L}_{state} \xrightarrow{\phi_{resolve}} \mathcal{L}_{resolved} \xrightarrow{\phi_{allocate}} \mathcal{L}_{allocated} \xrightarrow{\phi_{relocate}} \mathcal{L}_{relocated} \xrightarrow{\phi_{serialize}} \mathcal{B}_{output}
```

where:
- $\mathcal{F}_{input} = \{f_1, f_2, \ldots, f_n\}$ are input object files
- $\mathcal{O} = \{o_1, o_2, \ldots, o_n\}$ are parsed ELF objects
- $\mathcal{L}_{state}$ is linker state with loaded objects
- $\mathcal{L}_{resolved}$ is state with resolved symbols
- $\mathcal{L}_{allocated}$ is state with allocated memory regions
- $\mathcal{L}_{relocated}$ is state with applied relocations
- $\mathcal{B}_{output}$ is the final executable binary

**Code pipeline correspondence**:
```julia
# Mathematical pipeline: F_input → O → L_state → L_resolved → L_allocated → L_relocated → B_output

# Stage 1: F_input → O via φ_parse
function parse_all_objects(filenames::Vector{String})::Vector{ElfFile}
    return [parse_elf_file(f) for f in filenames]           # ↔ {φ_parse(f_i)}
end

# Stage 2: O → L_state via φ_load  
function load_all_objects(objects::Vector{ElfFile})::DynamicLinker
    linker = DynamicLinker()                                 # ↔ L_state initialization
    for obj in objects                                       # ↔ object iteration
        load_object(linker, obj)                             # ↔ φ_load(o_i)
    end
    return linker                                            # ↔ L_state result
end

# Stage 3: L_state → L_resolved via φ_resolve
function resolve_all_symbols!(linker::DynamicLinker)        # ↔ φ_resolve application
    unresolved = resolve_symbols(linker)                     # ↔ symbol resolution
    resolve_unresolved_symbols!(linker, unresolved)         # ↔ library resolution
    return linker                                            # ↔ L_resolved
end

# Stages 4-6: Complete remaining pipeline
function complete_linking_pipeline(linker::DynamicLinker, output::String)::Bool
    allocate_memory_regions!(linker)                        # ↔ L_allocated
    perform_relocations!(linker)                             # ↔ L_relocated  
    return write_elf_executable(linker, output)              # ↔ B_output
end
```

## Set-Theoretic Operations

**Global symbol table construction**:
```math
\Sigma_{global} = \bigcup_{o \in \mathcal{O}} \{s \in symbols(o) : binding(s) \neq STB\_LOCAL\}
```

**Undefined symbol collection**:
```math
\mathcal{U} = \{s \in \Sigma_{global} : \neg defined(s)\}
```

**Memory address space union**:
```math
\mathcal{A}_{virtual} = \bigcup_{m \in \mathcal{M}} [\alpha_{base}(m), \alpha_{base}(m) + size(m))
```

**Library symbol availability**:
```math
\Sigma_{libraries} = \bigcup_{lib \in \mathcal{P}} symbols(lib)
```

**Resolved symbol intersection**:
```math
\Sigma_{resolved} = \mathcal{U} \cap \Sigma_{libraries}
```

## Advanced Mathematical Framework

### Category Theory Formulation

**Linker as a Functor**:
```math
\mathcal{L}: \mathbf{ElfObj} \to \mathbf{Exec}
```

where $\mathbf{ElfObj}$ is the category of ELF objects with morphisms as symbol references, and $\mathbf{Exec}$ is the category of executable binaries.

**Natural Transformations**:
```math
\eta: \text{Id}_{\mathbf{ElfObj}} \Rightarrow \mathcal{L} \circ \mathcal{P}
```

where $\mathcal{P}$ is the parsing functor and $\eta$ represents the natural way to embed objects into the linking process.

### Homomorphism Properties

**Symbol table homomorphism**:
```math
\Sigma(o_1 \oplus o_2) = \Sigma(o_1) \oplus \Sigma(o_2)
```

where $\oplus$ is the object combination operation and preserves symbol table structure.

**Memory layout distributivity**:
```math
\mathcal{M}(o_1 \oplus o_2) = \mathcal{M}(o_1) \oplus \mathcal{M}(o_2)
```

### Algebraic Laws

**Associativity of object loading**:
```math
(o_1 \oplus o_2) \oplus o_3 = o_1 \oplus (o_2 \oplus o_3)
```

**Identity element**:
```math
\exists e \in \mathbf{ElfObj}: \forall o \in \mathbf{ElfObj}, e \oplus o = o \oplus e = o
```

**Inverse for error recovery**:
```math
\forall o \in \mathbf{ElfObj}: \exists o^{-1}: o \oplus o^{-1} = e
```

## Optimization Trigger Points

### Critical Mathematical Bottlenecks

1. **Symbol Resolution Optimization**:
   ```math
   T_{naive}(s,l) = O(s \cdot l) \quad \text{vs} \quad T_{optimized}(s,l) = O(s \log l + l \log l)
   ```
   - **Trigger**: Hash table implementation for O(1) symbol lookup
   - **Mathematical improvement**: Replace linear search with hash-based lookup

2. **Memory Region Allocation**:
   ```math
   T_{allocation}(r) = O(r^2) \quad \text{vs} \quad T_{spatial}(r) = O(r \log r)
   ```
   - **Trigger**: Spatial data structures for overlap detection
   - **Mathematical improvement**: Use interval trees or segment trees

3. **Relocation Application**:
   ```math
   T_{relocations}(e) = O(e \cdot s) \quad \text{vs} \quad T_{batch}(e) = O(e + s \log s)
   ```
   - **Trigger**: Batch processing of relocations by target region
   - **Mathematical improvement**: Group relocations by memory region

4. **Binary Serialization**:
   ```math
   T_{serial}(m) = O(m) \quad \text{– Already optimal but can be parallelized}
   ```
   - **Trigger**: Parallel I/O for large binaries
   - **Mathematical improvement**: Concurrent region writing

### Invariant Preservation Optimization

**Mathematical invariant checking**:
```math
\text{Cost}_{invariant} = O(\text{check frequency} \times \text{invariant complexity})
```

**Optimization strategies**:
- **Lazy validation**: Only check invariants when state changes
- **Incremental checking**: Update invariant proofs rather than recomputing
- **Statistical sampling**: Probabilistic invariant validation for performance

## Function Composition Properties

### Composition Algebra

**Pipeline composition**:
```math
\mathcal{L} = \phi_n \circ \phi_{n-1} \circ \cdots \circ \phi_1
```

**Associativity preservation**:
```math
(\phi_3 \circ \phi_2) \circ \phi_1 = \phi_3 \circ (\phi_2 \circ \phi_1)
```

**Partial application**:
```math
\mathcal{L}_{partial} = \phi_k \circ \cdots \circ \phi_1 \quad \text{for } k < n
```

**Error short-circuiting**:
```math
\phi_i = \bot \implies \mathcal{L} = \bot \quad \text{for any } i \in [1,n]
```

### Monadic Error Handling

**Linker monad**:
```math
\mathcal{M}_{\mathcal{L}} = \text{Result}[\mathcal{L}_{state}, \text{Error}]
```

**Bind operation**:
```math
\phi_i \gg= \phi_{i+1} = \begin{cases}
\phi_{i+1}(result) & \text{if } \phi_i = \text{Success}(result) \\
\text{Error}(e) & \text{if } \phi_i = \text{Error}(e)
\end{cases}
```

**Monadic composition**:
```math
\mathcal{L}_{monadic} = \phi_1 \gg= \phi_2 \gg= \cdots \gg= \phi_n
```