# Library Support Mathematical Specification

## Mathematical Model

```math
\text{Domain: } \mathcal{D} = \{\text{Search paths}, \text{Library names}, \text{Symbol names}, \text{Library types}\}
\text{Range: } \mathcal{R} = \{\text{Library info}, \text{Symbol mappings}, \text{Resolution results}\}
\text{Mapping: } find\_and\_resolve: \mathcal{D} \to \mathcal{R}
```

## Operations

```math
\text{Primary operations: } \{detect\_library\_type, find\_libraries, resolve\_symbols, extract\_symbols\}
\text{Library types: } \{GLIBC, MUSL, STATIC, SHARED, UNKNOWN\}
\text{Invariants: } \{library\_valid, symbol\_available, path\_accessible, search\_order\_preserved\}
\text{Complexity bounds: } O(p \cdot f + s \cdot l) \text{ where } p,f,s,l = \text{paths, files, symbols, libraries}
```

## Library Search Mathematical Model

```math
find\_libraries: \mathcal{P} \times \mathcal{N} \to \mathcal{L}
```

where:
- $\mathcal{P} = \{search\_paths\}$ is the set of library search paths
- $\mathcal{N} = \{library\_names\}$ is the set of requested library names  
- $\mathcal{L} = \{LibraryInfo\}$ is the set of discovered libraries

**Search path union with precedence**:
```math
search\_paths = custom\_paths \cup default\_paths
```

**Library discovery operation**:
```math
discovered\_libraries = \bigcup_{path \in search\_paths} \{lib \in scan(path) : matches\_pattern(lib) \land satisfies\_filter(lib)\}
```

**Filter predicate**:
```math
satisfies\_filter(lib) = \begin{cases}
true & \text{if } library\_names = \emptyset \\
lib.name \in library\_names & \text{otherwise}
\end{cases}
```

## Implementation Correspondence

### Library Type Detection → `detect_library_type` function

```math
detect\_type: String \to LibraryType
```

**Mathematical classification**:
```math
classify(library\_path) = \begin{cases}
STATIC & \text{if } filename \text{ ends with } ".a" \\
GLIBC & \text{if } "libc.so" \in filename \land detect\_libc\_type(path) = GLIBC \\
MUSL & \text{if } "libc.so" \in filename \land detect\_libc\_type(path) = MUSL \\
SHARED & \text{if } filename \text{ matches } "\.so(\.\d+)*$" \\
UNKNOWN & \text{otherwise}
\end{cases}
```

### Extended Library Discovery → `find_libraries` function

```math
find\_libraries: \mathcal{P} \times \mathcal{N} \to \mathcal{L}
```

**Set-theoretic operation**: Multi-path traversal with filtering

```math
library\_search = \bigcup_{path \in unified\_paths} \{f \in files(path) : matches\_library\_pattern(f) \land name\_filter(f)\}
```

**Direct code correspondence**:
```julia
# Mathematical model: find_libraries: P × N → L
function find_libraries(search_paths::Vector{String} = String[]; library_names::Vector{String} = String[])
    # Implementation of: custom_paths ∪ default_paths with precedence preservation
    all_search_paths = vcat(search_paths, get_default_library_search_paths())
    unique_paths = unique(all_search_paths)                    # ↔ duplicate removal
    
    return find_libraries_in_paths(unique_paths; library_names=library_names)  # ↔ filtered discovery
end
```

### Library Pattern Matching → `matches_library_pattern` function

```math
matches\_pattern: String \to Boolean
```

**Pattern recognition**:
```math
matches(filename) = \begin{cases}
true & \text{if } filename \text{ starts with } "lib" \land filename \text{ ends with } ".a" \\
true & \text{if } filename \text{ starts with } "lib" \land filename \text{ matches } "\.so(\.\d+)*$" \\
false & \text{otherwise}
\end{cases}
```

### Symbol Extraction → `extract_library_symbols` function

```math
extract\_symbols: String \to \mathcal{S}
```

**Library-specific symbol mapping**:
```math
symbol\_set(library\_name) = \begin{cases}
\{printf, malloc, strlen, ...\} & \text{if } library\_name = "c" \\
\{sin, cos, exp, sqrt, ...\} & \text{if } library\_name = "m" \\
\{pthread\_create, pthread\_join, ...\} & \text{if } library\_name = "pthread" \\
\{dlopen, dlclose, dlsym, ...\} & \text{if } library\_name = "dl" \\
\emptyset & \text{otherwise}
\end{cases}
```

### Backward Compatibility → `find_system_libraries` function

```math
find\_system\_libraries: \{\} \to List(LibraryInfo)
```

**Specialized libc discovery**:
```math
system\_libraries = \{lib \in find\_libraries(\{\}, \{"c"\}) : lib.type \in \{GLIBC, MUSL\}\}
```

## Complexity Analysis

```math
\begin{align}
T_{library\_detection}(f) &= O(f) \quad \text{– File pattern matching and type detection} \\
T_{path\_discovery}(p,f) &= O(p \cdot f) \quad \text{– Multi-path directory traversal} \\
T_{symbol\_resolution}(s,l) &= O(s \cdot l) \quad \text{– Symbol lookup across libraries} \\
T_{total\_search}(p,f,s,l) &= O(p \cdot f + s \cdot l) \quad \text{– Combined search and resolution}
\end{align}
```

**Critical path**: Library discovery with O(p·f) path traversal operations.

## Transformation Pipeline

**Library discovery pipeline**:
```math
search\_paths \xrightarrow{filter} valid\_paths \xrightarrow{scan} all\_files \xrightarrow{match} library\_files \xrightarrow{classify} typed\_libraries
```

**Symbol resolution pipeline**:
```math
unresolved\_symbols \xrightarrow{lookup} candidate\_libraries \xrightarrow{match} providing\_library \xrightarrow{resolve} resolved\_symbols
```

## Set-Theoretic Operations

**Library path union with precedence**:
```math
all\_search\_paths = custom\_paths \cup default\_paths \text{ (preserving order)}
```

**Symbol availability across libraries**:
```math
available\_symbols = \bigcup_{lib \in discovered\_libraries} lib.symbols
```

**Library filtering by name**:
```math
filtered\_libraries = \{lib \in all\_libraries : lib.name \in requested\_names\}
```

**Resolution status partitioning**:
```math
resolved\_symbols = \{s \in symbols : s.resolved = true\}
unresolved\_symbols = \{s \in symbols : s.resolved = false\}
```

## Invariant Preservation

```math
\text{Library type consistency: }
\forall lib: classify(lib) \in \{GLIBC, MUSL, STATIC, SHARED, UNKNOWN\}
```

```math
\text{Search path precedence: }
\forall p_1, p_2: p_1 \text{ before } p_2 \text{ in input} \implies p_1 \text{ searched before } p_2
```

```math
\text{Symbol availability: }
\forall lib: lib.type \neq UNKNOWN \implies lib.symbols \neq \emptyset \lor lib.name \in known\_libraries
```

```math
\text{Pattern matching correctness: }
\forall file: matches\_library\_pattern(file) \iff (file \text{ starts with } "lib" \land file \text{ ends with } (".a" \lor ".so*"))
```

## Optimization Trigger Points

- **Inner loops**: Multi-path directory traversal with potential parallel scanning
- **Memory allocation**: Library list pre-allocation based on typical system library counts  
- **Bottleneck operations**: File pattern matching with compiled regex optimization
- **Search optimization**: Path deduplication and caching of directory contents
- **Symbol lookup**: Hash-based symbol set membership testing