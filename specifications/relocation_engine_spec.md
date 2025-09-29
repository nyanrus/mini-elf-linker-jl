# Relocation Engine Mathematical Specification

## Overview

This specification defines the mathematical model for ELF relocation processing in the MiniElfLinker. Following the Mathematical-Driven AI Development methodology, relocation algorithms are expressed mathematically with direct code correspondence, enabling precise understanding and optimization analysis.

## Mathematical Model

### Relocation Mathematical Framework

**Universe of Relocations**: The complete set of possible relocations in x86-64 architecture
```math
\mathcal{R}_{universe} = \{R\_X86\_64\_i : i \in [0, 37]\}
```

**Implemented Relocation Subset**: Currently supported relocations
```math
\mathcal{R}_{implemented} \subseteq \mathcal{R}_{universe}
```

**Relocation Entry Representation**:
```math
r \in \mathcal{R}_{entry} = \{offset, info, addend\}
```
where:
- $offset \in \mathbb{N}_{64}$: target memory address
- $info \in \mathbb{N}_{64}$: packed symbol index and relocation type
- $addend \in \mathbb{Z}_{64}$: signed constant value

### Relocation Processing Function

**Primary Relocation Function**:
```math
\Phi_{relocate}: \mathcal{R}_{entry} \times \mathcal{L}_{state} \to \mathcal{L}_{state}' \cup \{\text{Error}\}
```

**Type Extraction Functions**:
```math
\begin{align}
\text{type}(r) &= r.info \bmod 2^{32} \\
\text{symbol\_index}(r) &= \lfloor r.info / 2^{32} \rfloor
\end{align}
```

**Handler Dispatch Function**:
```math
\text{dispatch}(r) = \begin{cases}
\Phi_{64}(r) & \text{if } \text{type}(r) = R\_X86\_64\_64 \\
\Phi_{PC32}(r) & \text{if } \text{type}(r) = R\_X86\_64\_PC32 \\
\Phi_{PLT32}(r) & \text{if } \text{type}(r) = R\_X86\_64\_PLT32 \\
\vdots \\
\text{Error} & \text{if } \text{type}(r) \notin \mathcal{R}_{implemented}
\end{cases}
```

## Specific Relocation Algorithms

### Direct 64-bit Address Relocation

**Mathematical Model**: $\Phi_{64}: \mathcal{R}_{entry} \to \mathcal{M}_{patch}$

**Address Computation**:
```math
\text{target\_value} = \text{symbol\_address} + r.addend
```

**Memory Patch Operation**:
```math
\mathcal{M}[r.offset : r.offset + 8] \leftarrow \text{little\_endian}(\text{target\_value})
```

**Implementation Correspondence**:
```julia
"""
Mathematical model: Φ₆₄: ℛ_entry → ℳ_patch
Direct 64-bit address relocation with symbol resolution.
"""
struct Direct64Handler <: RelocationHandler end

function apply_relocation!(handler::Direct64Handler, relocation::RelocationEntry, linker_state)
    # Extract symbol information: symbol_index(r) = ⌊r.info / 2³²⌋
    symbol_index = elf64_r_sym(relocation.info)
    
    # Resolve symbol address: resolve symbol in global symbol table
    symbol_address = resolve_symbol_address(linker_state, symbol_index)
    
    # Mathematical computation: target_value = symbol_address + r.addend  
    target_value = symbol_address + relocation.addend
    
    # Apply memory patch: ℳ[r.offset : r.offset + 8] ← little_endian(target_value)
    patch_memory_64bit!(linker_state, relocation.offset, target_value)
    
    return true
end
```

### PC-Relative 32-bit Relocation

**Mathematical Model**: $\Phi_{PC32}: \mathcal{R}_{entry} \to \mathcal{M}_{patch}$

**Relative Address Computation**:
```math
\begin{align}
\text{pc\_address} &= r.offset + 4 \\
\text{displacement} &= (\text{symbol\_address} + r.addend) - \text{pc\_address} \\
\text{target\_value} &= \text{sign\_extend\_32}(\text{displacement})
\end{align}
```

**Overflow Check**:
```math
\text{valid} = \text{displacement} \in [-2^{31}, 2^{31} - 1]
```

**Implementation Correspondence**:
```julia
"""
Mathematical model: Φ_PC32: ℛ_entry → ℳ_patch
PC-relative 32-bit relocation with overflow checking.
"""
struct PC32Handler <: RelocationHandler end

function apply_relocation!(handler::PC32Handler, relocation::RelocationEntry, linker_state)
    symbol_index = elf64_r_sym(relocation.info)
    symbol_address = resolve_symbol_address(linker_state, symbol_index)
    
    # Mathematical computation: pc_address = r.offset + 4
    pc_address = relocation.offset + 4
    
    # Displacement calculation: displacement = (symbol_address + r.addend) - pc_address
    displacement = Int64(symbol_address + relocation.addend) - Int64(pc_address)
    
    # Overflow validation: displacement ∈ [-2³¹, 2³¹ - 1]
    if displacement < -2^31 || displacement >= 2^31
        throw(UnsupportedRelocationError("PC32 displacement overflow: $displacement"))
    end
    
    # Apply 32-bit patch: target_value = sign_extend_32(displacement)
    target_value = Int32(displacement)
    patch_memory_32bit!(linker_state, relocation.offset, target_value)
    
    return true
end
```

### PLT32 Relocation (Procedure Linkage Table)

**Mathematical Model**: $\Phi_{PLT32}: \mathcal{R}_{entry} \to \mathcal{PLT} \to \mathcal{M}_{patch}$

**PLT Entry Creation**:
```math
\text{plt\_entry} = \text{create\_plt\_entry}(\text{symbol\_name}, \text{got\_offset})
```

**Relative Jump Computation**:
```math
\begin{align}
\text{plt\_address} &= \text{base\_plt} + \text{plt\_offset} \\
\text{pc\_address} &= r.offset + 4 \\
\text{displacement} &= \text{plt\_address} - \text{pc\_address}
\end{align}
```

**Implementation Correspondence**:
```julia
"""
Mathematical model: Φ_PLT32: ℛ_entry → 𝒫ℒ𝒯 → ℳ_patch
PLT32 relocation through procedure linkage table creation.
"""
struct PLT32Handler <: RelocationHandler end

function apply_relocation!(handler::PLT32Handler, relocation::RelocationEntry, linker_state)
    symbol_index = elf64_r_sym(relocation.info)
    symbol_name = get_symbol_name(linker_state, symbol_index)
    
    # PLT entry creation: create_plt_entry(symbol_name, got_offset)
    plt_entry = ensure_plt_entry!(linker_state, symbol_name)
    
    # Mathematical computation: plt_address = base_plt + plt_offset
    plt_address = linker_state.plt.base_address + plt_entry.offset
    pc_address = relocation.offset + 4
    
    # Displacement calculation: displacement = plt_address - pc_address  
    displacement = Int64(plt_address) - Int64(pc_address)
    
    # Overflow check for 32-bit displacement
    if displacement < -2^31 || displacement >= 2^31
        throw(UnsupportedRelocationError("PLT32 displacement overflow: $displacement"))
    end
    
    patch_memory_32bit!(linker_state, relocation.offset, Int32(displacement))
    return true
end
```

## Global Offset Table (GOT) Support

### GOT Mathematical Framework

**GOT Entry Space**:
```math
\mathcal{GOT} = \{got\_entry_i : i \in [0, n_{symbols}]\}
```

**GOT Address Resolution**:
```math
\text{got\_address}(symbol) = \text{base\_got} + \text{got\_offset}(symbol)
```

**GOT32 Relocation Algorithm**:
```math
\Phi_{GOT32}: \mathcal{R}_{entry} \to \mathcal{GOT} \to \mathcal{M}_{patch}
```

**Implementation Correspondence**:
```julia
"""
Mathematical model: Φ_GOT32: ℛ_entry → 𝒢ℴ𝒯 → ℳ_patch
GOT32 relocation through global offset table.
"""
struct GOT32Handler <: RelocationHandler end

function apply_relocation!(handler::GOT32Handler, relocation::RelocationEntry, linker_state)
    symbol_index = elf64_r_sym(relocation.info)
    symbol_name = get_symbol_name(linker_state, symbol_index)
    
    # GOT entry creation: ensure symbol has GOT entry
    got_entry = ensure_got_entry!(linker_state, symbol_name)
    
    # Mathematical computation: got_address(symbol) = base_got + got_offset(symbol)
    got_address = linker_state.got.base_address + got_entry.offset
    
    # Apply 32-bit patch with GOT address
    patch_memory_32bit!(linker_state, relocation.offset, UInt32(got_address))
    return true
end
```

## Dispatcher Architecture

### Relocation Type Registry

**Handler Registry**:
```math
\mathcal{H} = \{(type, handler) : type \in \mathcal{R}_{implemented}, handler \in \text{HandlerImplementations}\}
```

**Dispatch Function**:
```math
\text{dispatch}(r) = \mathcal{H}[\text{type}(r)] \text{ if } \text{type}(r) \in \text{keys}(\mathcal{H})
```

**Error Handling**:
```math
\text{unsupported}(r) = \text{type}(r) \notin \text{keys}(\mathcal{H})
```

**Implementation Correspondence**:
```julia
"""
Mathematical model: Dispatcher = {handler_i}_{i=0}^{37}
Complete relocation processing engine with handler registry.
"""
struct RelocationDispatcher
    handlers::Dict{UInt32, RelocationHandler}
    
    function RelocationDispatcher()
        # Build handler registry: ℋ = {(type, handler)}
        handlers = Dict{UInt32, RelocationHandler}()
        
        # Register implemented relocations only
        handlers[R_X86_64_64] = Direct64Handler()      # ↔ Φ₆₄
        handlers[R_X86_64_PC32] = PC32Handler()        # ↔ Φ_PC32  
        handlers[R_X86_64_PLT32] = PLT32Handler()      # ↔ Φ_PLT32
        handlers[R_X86_64_GOT32] = GOT32Handler()      # ↔ Φ_GOT32
        # ... additional handlers
        
        return new(handlers)
    end
end

"""
Mathematical model: apply: (Relocation, LinkerState) → LinkerState'
Main relocation processing dispatch function.
"""
function apply_relocation!(dispatcher::RelocationDispatcher, relocation::RelocationEntry, linker_state)
    relocation_type = elf64_r_type(relocation.info)
    
    # Dispatch function: handler = ℋ[type(r)]
    if haskey(dispatcher.handlers, relocation_type)
        handler = dispatcher.handlers[relocation_type]
        return apply_relocation!(handler, relocation, linker_state)
    else
        # Error case: type(r) ∉ keys(ℋ)
        throw(UnsupportedRelocationError("Unsupported relocation type: $relocation_type"))
    end
end
```

## Error Handling and Recovery

### Error Categories

**Relocation Error Space**:
```math
\mathcal{E}_{relocation} = \mathcal{E}_{unsupported} \cup \mathcal{E}_{overflow} \cup \mathcal{E}_{symbol} \cup \mathcal{E}_{memory}
```

**Error Recovery Function**:
```math
\text{recover}(error) = \begin{cases}
\text{skip} & \text{if } error \in \mathcal{E}_{recoverable} \\
\text{abort} & \text{if } error \in \mathcal{E}_{fatal}
\end{cases}
```

**Implementation Correspondence**:
```julia
"""
Mathematical model: Error handling with recovery strategies.
"""
struct UnsupportedRelocationError <: Exception
    message::String
    relocation_type::UInt32
    context::String
end

function safe_apply_relocation!(dispatcher::RelocationDispatcher, relocation::RelocationEntry, linker_state)
    try
        return apply_relocation!(dispatcher, relocation, linker_state)
    catch e::UnsupportedRelocationError
        # Mathematical error recovery: skip ∈ ℰ_recoverable
        @warn "Unsupported relocation skipped: $(e.message)"
        return false
    catch e::BoundsError
        # Fatal error: abort ∈ ℰ_fatal
        @error "Memory bounds error in relocation: $e"
        rethrow(e)
    end
end
```

## Memory Management

### Memory Patch Operations

**Memory State Representation**:
```math
\mathcal{M} = \{addr \to value : addr \in \text{AllocatedMemory}\}
```

**Patch Functions**:
```math
\begin{align}
\text{patch\_32}(addr, value) &: \mathcal{M} \to \mathcal{M}' \\
\text{patch\_64}(addr, value) &: \mathcal{M} \to \mathcal{M}'
\end{align}
```

**Endianness Conversion**:
```math
\text{little\_endian}(value) = \sum_{i=0}^{n-1} \text{byte}_i \cdot 256^i
```

**Implementation Correspondence**:
```julia
"""
Mathematical model: Memory patch operations with endianness handling.
"""
function patch_memory_32bit!(linker_state, offset::UInt64, value::Union{Int32, UInt32})
    # Locate target memory region: find region containing offset
    region = find_memory_region(linker_state, offset)
    
    if region === nothing
        throw(BoundsError("Invalid memory access at offset $offset"))
    end
    
    # Calculate local offset: relative_offset = offset - region.base
    relative_offset = offset - region.base_address + 1  # Julia 1-based indexing
    
    # Mathematical patch operation: ℳ[addr] ← little_endian(value)
    value_bytes = reinterpret(UInt8, [UInt32(value)])
    region.data[relative_offset:relative_offset+3] = value_bytes
    
    return true
end

function patch_memory_64bit!(linker_state, offset::UInt64, value::UInt64)
    region = find_memory_region(linker_state, offset)
    relative_offset = offset - region.base_address + 1
    
    # 64-bit little-endian conversion: value → bytes[1:8]
    value_bytes = reinterpret(UInt8, [value])
    region.data[relative_offset:relative_offset+7] = value_bytes
    
    return true
end
```

## Complexity Analysis

### Time Complexity

```math
\begin{align}
T_{dispatch}(1) &= O(1) \quad \text{– Hash table lookup} \\
T_{relocation}(r) &= O(1) \quad \text{– Per relocation processing} \\
T_{total}(n) &= O(n) \quad \text{– Linear in relocation count}
\end{align}
```

### Space Complexity

```math
\begin{align}
S_{handlers} &= O(|\mathcal{R}_{implemented}|) \quad \text{– Handler registry} \\
S_{got} &= O(n_{external\_symbols}) \quad \text{– GOT entries} \\
S_{plt} &= O(n_{function\_calls}) \quad \text{– PLT entries}
\end{align}
```

## Optimization Opportunities

### Batch Processing

**Current**: Sequential relocation processing
```math
T_{current} = \sum_{i=1}^{n} T_{relocation}(r_i)
```

**Optimized**: Batch relocations by type
```math
T_{batched} = \sum_{type \in \mathcal{R}_{types}} T_{batch}(|\{r : \text{type}(r) = type\}|)
```

### Memory Layout Optimization

**Spatial Locality**: Group relocations by memory region
```math
\text{region\_groups} = \{r \in \mathcal{R} : \text{region}(r.offset) = region_i\}
```

### Jump Table Optimization

**Dynamic Dispatch**: Replace hash table with jump table for critical path
```math
T_{jump\_table} = O(1) \text{ worst-case vs } O(1) \text{ average-case hash}
```

## Integration Points

### Symbol Resolution Interface

```math
\text{resolve\_symbol}: \text{SymbolIndex} \times \mathcal{L}_{state} \to \text{SymbolAddress} \cup \{\perp\}
```

### Memory Management Interface  

```math
\text{find\_region}: \text{Address} \times \mathcal{L}_{state} \to \text{MemoryRegion} \cup \{\perp\}
```

### PLT/GOT Management Interface

```math
\begin{align}
\text{ensure\_plt}: \text{SymbolName} \times \mathcal{L}_{state} &\to \text{PLTEntry} \\
\text{ensure\_got}: \text{SymbolName} \times \mathcal{L}_{state} &\to \text{GOTEntry}
\end{align}
```