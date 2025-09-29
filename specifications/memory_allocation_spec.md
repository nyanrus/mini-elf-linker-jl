# Memory Allocation Mathematical Specification

## Overview

This specification defines the mathematical models for memory allocation and layout in the MiniElfLinker. Following the Mathematical-Driven AI Development methodology, memory allocation implements algorithmic processes using mathematical notation for spatial algorithms and direct Julia implementation for configuration and data structures.

## Mathematical Model

### Memory Space Framework

**Virtual Memory Address Space**:
```math
\mathcal{A} = [0, 2^{64} - 1] \subset \mathbb{N}
```

**Allocated Region Set**:
```math
\mathcal{M}_{regions} = \{r_i : r_i = [base_i, base_i + size_i), i \in [1, n]\}
```

**Non-Overlap Constraint**:
```math
\forall i, j \in [1, n], i \neq j: r_i \cap r_j = \emptyset
```

**Memory Region Representation**:
```math
r = \langle base, size, data, permissions, alignment \rangle
```
where:
- $base \in \mathcal{A}$: starting virtual address
- $size \in \mathbb{N}_{64}$: region size in bytes
- $data \in \{0, 1\}^{size}$: binary content
- $permissions \in \{READ, WRITE, EXEC\}^*$: access permissions
- $alignment \in \{2^k : k \in \mathbb{N}\}$: address alignment constraint

### Allocation Algorithm

**Primary Allocation Function**:
```math
\phi_{allocate}: \mathcal{S}_{sections} \times \mathcal{A}_{base} \to \mathcal{M}_{regions} \cup \{\text{Error}\}
```

**Sequential Allocation Strategy**:
```math
\begin{align}
addr_0 &= base\_address \\
addr_{i+1} &= \text{align}(addr_i + size_i, alignment_{i+1})
\end{align}
```

**Alignment Function**:
```math
\text{align}(addr, a) = \begin{cases}
addr & \text{if } addr \bmod a = 0 \\
addr + (a - (addr \bmod a)) & \text{otherwise}
\end{cases}
```

**Space Utilization Measure**:
```math
\eta_{utilization} = \frac{\sum_{i=1}^n size_i}{\max_i(base_i + size_i) - base\_address}
```

## Implementation Correspondence

### Memory Region Structure (Non-Algorithmic)

Following copilot guidelines, memory region data structures use direct Julia implementation:

```julia
"""
MemoryRegion represents an allocated virtual memory region.
Non-algorithmic: data structure for memory layout representation.
"""
mutable struct MemoryRegion
    data::Vector{UInt8}
    base_address::UInt64
    size::UInt64
    permissions::UInt8
    alignment::UInt64
    source_section::String
    
    function MemoryRegion(data::Vector{UInt8}, base_address::UInt64, 
                         permissions::UInt8 = PERM_READ_WRITE)
        size = length(data)
        alignment = determine_alignment(size)
        new(data, base_address, size, permissions, alignment, "")
    end
end

# Permission constants (non-algorithmic)
const PERM_READ = 0x4
const PERM_WRITE = 0x2
const PERM_EXEC = 0x1
const PERM_READ_WRITE = PERM_READ | PERM_WRITE
const PERM_READ_EXEC = PERM_READ | PERM_EXEC
```

### Section Allocation Algorithm

**Mathematical Model**: $\phi_{allocate\_section}: \text{Section} \times \mathcal{A}_{current} \to \mathcal{M}_{region}$

**Section Processing Pipeline**:
```math
section \xrightarrow{\text{size\_calculation}} required\_size \xrightarrow{\text{alignment}} aligned\_address \xrightarrow{\text{allocation}} memory\_region
```

**Implementation**:
```julia
"""
Mathematical model: φ_allocate_section: Section × 𝒜_current → ℳ_region
Allocate memory region for ELF section with alignment constraints.
"""
function φ_allocate_section!(linker::DynamicLinker, section::SectionHeader, 
                            section_data::Vector{UInt8})::MemoryRegion
    # Size computation: required_size = max(section.size, section.addralign)
    required_size = max(section.size, section.addralign)
    
    # Alignment constraint: α_current ≡ 0 (mod addralign)
    if section.addralign > 0
        aligned_address = φ_align_address(linker.current_address, section.addralign)
    else
        aligned_address = linker.current_address
    end
    
    # Permission mapping: map section flags to memory permissions
    permissions = φ_map_permissions(section.flags)
    
    # Region creation: create memory region with computed parameters
    region = MemoryRegion(section_data, aligned_address, permissions)
    region.source_section = get_section_name(section)
    
    # State update: advance current address pointer
    linker.current_address = aligned_address + required_size
    
    # Non-overlap verification: ensure ∀r ∈ existing: new_region ∩ r = ∅
    if φ_verify_no_overlap(linker.memory_regions, region)
        push!(linker.memory_regions, region)
        return region
    else
        throw(ArgumentError("Memory region overlap detected"))
    end
end
```

### Address Alignment Algorithm

**Mathematical Model**: $\phi_{align}: \mathbb{N}_{64} \times \mathbb{N}_{64} \to \mathbb{N}_{64}$

**Alignment Computation**:
```math
\phi_{align}(addr, alignment) = \begin{cases}
addr & \text{if } addr \equiv 0 \pmod{alignment} \\
addr + (alignment - (addr \bmod alignment)) & \text{otherwise}
\end{cases}
```

**Bit-Level Optimization**:
```math
\phi_{align\_fast}(addr, 2^k) = (addr + 2^k - 1) \land \neg(2^k - 1)
```

**Implementation**:
```julia
"""
Mathematical model: φ_align: ℕ₆₄ × ℕ₆₄ → ℕ₆₄
Address alignment with efficient computation for power-of-2 alignments.
"""
function φ_align_address(address::UInt64, alignment::UInt64)::UInt64
    if alignment == 0
        return address
    end
    
    # Check if alignment is power of 2: alignment = 2^k
    if (alignment & (alignment - 1)) == 0
        # Bit-level optimization: φ_align_fast(addr, 2^k)
        return (address + alignment - 1) & ~(alignment - 1)
    else
        # General case: φ_align(addr, alignment)
        remainder = address % alignment
        return remainder == 0 ? address : address + (alignment - remainder)
    end
end
```

### Permission Mapping Algorithm

**Mathematical Model**: $\phi_{permissions}: \text{SectionFlags} \to \text{MemoryPermissions}$

**Flag Interpretation**:
```math
\phi_{permissions}(flags) = \begin{cases}
\text{READ\_EXEC} & \text{if } (flags \land \text{SHF\_EXECINSTR}) \neq 0 \\
\text{READ\_WRITE} & \text{if } (flags \land \text{SHF\_WRITE}) \neq 0 \\
\text{READ} & \text{if } (flags \land \text{SHF\_ALLOC}) \neq 0 \\
\text{NONE} & \text{otherwise}
\end{cases}
```

**Implementation**:
```julia
"""
Mathematical model: φ_permissions: SectionFlags → MemoryPermissions
Map ELF section flags to memory protection flags.
"""
function φ_map_permissions(section_flags::UInt64)::UInt8
    permissions = 0x0
    
    # Mathematical flag interpretation: bitwise analysis
    if (section_flags & SHF_ALLOC) != 0
        permissions |= PERM_READ           # ↔ allocatable sections are readable
    end
    
    if (section_flags & SHF_WRITE) != 0
        permissions |= PERM_WRITE          # ↔ writable sections get write permission
    end
    
    if (section_flags & SHF_EXECINSTR) != 0
        permissions |= PERM_EXEC           # ↔ executable sections get exec permission
    end
    
    return permissions == 0x0 ? PERM_READ : permissions  # ↔ default to read-only
end
```

### Overlap Detection Algorithm

**Mathematical Model**: $\phi_{overlap}: \mathcal{M}_{existing} \times \mathcal{M}_{new} \to \mathbb{B}$

**Interval Intersection Test**:
```math
\text{intersects}(r_1, r_2) = \neg(r_1.end \leq r_2.start \lor r_2.end \leq r_1.start)
```

**Comprehensive Overlap Check**:
```math
\phi_{overlap}(regions, new\_region) = \exists r \in regions: \text{intersects}(r, new\_region)
```

**Implementation**:
```julia
"""
Mathematical model: φ_overlap: ℳ_existing × ℳ_new → 𝔹
Detect memory region overlaps using interval intersection mathematics.
"""
function φ_verify_no_overlap(existing_regions::Vector{MemoryRegion}, 
                            new_region::MemoryRegion)::Bool
    new_start = new_region.base_address
    new_end = new_start + new_region.size
    
    # Mathematical intersection test: ∀r ∈ existing: ¬intersects(r, new_region)
    for region ∈ existing_regions
        region_start = region.base_address
        region_end = region_start + region.size
        
        # Interval intersection: ¬(r₁.end ≤ r₂.start ∨ r₂.end ≤ r₁.start)
        if !(region_end <= new_start || new_end <= region_start)
            @error "Memory overlap detected: [$region_start, $region_end) ∩ [$new_start, $new_end) ≠ ∅"
            return false
        end
    end
    
    return true  # ↔ no overlaps found
end
```

## Memory Layout Strategy

### Base Address Configuration

**Address Space Layout**:
```math
\begin{align}
\alpha_{base} &= 0x400000 \quad \text{(standard executable base)} \\
\alpha_{text} &= \alpha_{base} + 0x1000 \quad \text{(code section)} \\
\alpha_{data} &= \text{align}(\alpha_{text} + size_{text}, 0x1000) \quad \text{(data section)} \\
\alpha_{bss} &= \text{align}(\alpha_{data} + size_{data}, 0x1000) \quad \text{(BSS section)}
\end{align}
```

**Layout Function**:
```math
\phi_{layout}: \mathcal{S}_{sections} \to \mathcal{M}_{layout}
```

**Implementation**:
```julia
"""
Mathematical model: φ_layout: 𝒮_sections → ℳ_layout
Compute optimal memory layout for all sections.
"""
function φ_compute_memory_layout!(linker::DynamicLinker, sections::Vector{SectionHeader})
    # Initialize base addresses: α_base = 0x400000
    linker.base_address = 0x400000
    linker.current_address = linker.base_address + 0x1000  # Skip ELF header space
    
    # Section ordering: executable → read-only → read-write
    ordered_sections = φ_order_sections_by_permissions(sections)
    
    for section ∈ ordered_sections
        if (section.flags & SHF_ALLOC) != 0  # Only allocate loadable sections
            section_data = load_section_data(linker, section)
            
            # Apply allocation algorithm: φ_allocate_section
            region = φ_allocate_section!(linker, section, section_data)
            
            @debug "Allocated section $(section.name): [$(region.base_address), $(region.base_address + region.size))"
        end
    end
    
    return linker.memory_regions
end
```

## Complexity Analysis

### Time Complexity

```math
\begin{align}
T_{\text{alignment}}(1) &= O(1) \quad \text{– Constant time alignment computation} \\
T_{\text{overlap\_check}}(n) &= O(n) \quad \text{– Linear search through existing regions} \\
T_{\text{allocation}}(n) &= O(n) \quad \text{– Per-section allocation} \\
T_{\text{total}}(m) &= O(m \cdot n) \quad \text{– } m \text{ sections, } n \text{ avg. regions}
\end{align}
```

### Space Complexity

```math
\begin{align}
S_{\text{regions}}(m) &= O(m) \quad \text{– One region per allocatable section} \\
S_{\text{data}}(d) &= O(d) \quad \text{– Total data size} \\
S_{\text{overhead}}(m) &= O(m) \quad \text{– Region metadata}
\end{align}
```

### Optimization Opportunities

**Current Sequential Allocation**:
```math
T_{\text{current}} = O(n^2) \text{ for overlap checking}
```

**Optimized Spatial Data Structure**:
```math
T_{\text{interval\_tree}} = O(n \log n) \text{ for insertion and overlap detection}
```

**Memory Pre-allocation Strategy**:
```math
\text{total\_size} = \sum_{s \in sections} \text{align}(s.size, s.addralign)
```

## Integration Points

### Symbol Resolution Interface

```math
\phi_{\text{resolve\_address}}: \text{SymbolName} \times \mathcal{M}_{regions} \to \mathcal{A} \cup \{\perp\}
```

### Relocation Processing Interface

```math
\phi_{\text{find\_region}}: \mathcal{A} \times \mathcal{M}_{regions} \to \mathcal{M}_{region} \cup \{\perp\}
```

### ELF Writer Interface

```math
\phi_{\text{serialize\_layout}}: \mathcal{M}_{regions} \to \text{ProgramHeaders} \times \text{FileLayout}
```

## Error Handling and Validation

### Memory Validation Function

```math
\phi_{\text{validate}}: \mathcal{M}_{regions} \to \mathbb{B}
```

**Validation Criteria**:
```math
\begin{align}
\text{valid\_alignment} &= \forall r \in regions: r.base \bmod r.alignment = 0 \\
\text{no\_overlaps} &= \forall i, j: i \neq j \implies r_i \cap r_j = \emptyset \\
\text{within\_bounds} &= \forall r: r.base + r.size \leq 2^{64}
\end{align}
```

**Implementation**:
```julia
"""
Mathematical model: φ_validate: ℳ_regions → 𝔹
Validate memory layout consistency and constraints.
"""
function φ_validate_memory_layout(regions::Vector{MemoryRegion})::Bool
    # Check alignment: ∀r: r.base mod r.alignment = 0
    for region ∈ regions
        if region.alignment > 0 && (region.base_address % region.alignment) != 0
            @error "Alignment violation: $(region.base_address) not aligned to $(region.alignment)"
            return false
        end
    end
    
    # Check overlaps: ∀i,j: i ≠ j ⟹ rᵢ ∩ rⱼ = ∅
    for i ∈ 1:length(regions)
        for j ∈ (i+1):length(regions)
            if !φ_verify_no_overlap([regions[i]], regions[j])
                return false
            end
        end
    end
    
    # Check bounds: ∀r: r.base + r.size ≤ 2⁶⁴
    for region ∈ regions
        if region.base_address + region.size < region.base_address  # Overflow check
            @error "Address space overflow in region"
            return false
        end
    end
    
    return true
end
```

## Advanced Memory Management

### Virtual Memory Mapping

**Page-Aligned Allocation**:
```math
\text{page\_align}(addr) = \text{align}(addr, 4096)
```

**Memory Protection Regions**:
```math
\mathcal{P}_{regions} = \{(r, prot) : r \in \mathcal{M}_{regions}, prot \in \text{Permissions}\}
```

### Memory Compaction

**Fragmentation Measure**:
```math
\delta_{fragmentation} = 1 - \frac{\sum_{i=1}^n size_i}{\max_i(base_i + size_i) - \min_i(base_i)}
```

**Compaction Algorithm**:
```math
\phi_{compact}: \mathcal{M}_{regions} \to \mathcal{M}_{regions}' \text{ with } \delta'_{fragmentation} < \delta_{fragmentation}
```

This mathematical specification provides a comprehensive framework for understanding and implementing memory allocation algorithms in the MiniElfLinker while following the humble, appropriate mathematical notation guidelines.