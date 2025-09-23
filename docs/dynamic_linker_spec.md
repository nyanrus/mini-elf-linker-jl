# Dynamic Linker Specification

## Mathematical Foundation

**Module:** `dynamic_linker.jl`

**Purpose:** Mathematical operations for symbol resolution, memory allocation, and object linking

**Domain:** 
$$\mathcal{D} = \{\text{ELF objects}\} \times \{\text{Symbol tables}\} \times \{\text{Memory layouts}\}$$

**Codomain:** 
$$\mathcal{R} = \{\text{Linked executables}\} \cup \{\text{Resolved symbols}\} \cup \{\text{Memory mappings}\}$$

## Data Structure Specifications

### Symbol Representation

**Structure:** `Symbol`

**Mathematical Model:** 
$$S = \langle n, v, s, b, t, \text{sec}, d, \text{src} \rangle$$

**Field Definitions:**
$$\begin{align}
n &\in \text{String} &&\text{Symbol name} \\
v &\in \mathbb{N}_{64} &&\text{Symbol value/address} \\
s &\in \mathbb{N}_{64} &&\text{Symbol size} \\
b &\in \{0, 1, 2, 10, 11, 12, 13\} &&\text{Binding type} \\
t &\in \{0, 1, 2, 3, 4\} &&\text{Symbol type} \\
\text{sec} &\in \mathbb{N}_{16} &&\text{Section index} \\
d &\in \{\text{true}, \text{false}\} &&\text{Definition status} \\
\text{src} &\in \text{String} &&\text{Source file}
\end{align}$$

**Invariants:** 
$$\mathcal{I}_S = \left\{
\begin{aligned}
&d = \text{true} \implies v \neq 0 \\
&b \in \{\text{STB\_LOCAL}, \text{STB\_GLOBAL}, \text{STB\_WEAK}\}
\end{aligned}
\right\}$$

### Memory Region Model

**Structure:** `MemoryRegion`

**Mathematical Model:** $M = \langle data, base, size, perms \rangle$

**Memory Mapping:**
$$\begin{align}
\text{Address Space} &: [base, base + size) \subseteq \mathbb{N}_{64} \\
\text{Data Mapping} &: \text{Addr} \to \text{Byte} \\
\text{Permissions} &: \{R, W, X\} \subseteq \text{perms}
\end{align}$$

**Invariants:** $\mathcal{I}_M = \{
  |data| = size, \quad
  \text{base} \bmod \text{PAGE\_SIZE} = 0, \quad
  \text{size} > 0
\}$

### Dynamic Linker State

**Structure:** `DynamicLinker`

**Mathematical Model:** $L = \langle objs, syms, mem, base \rangle$

**State Components:**
$$\begin{align}
objs &: \text{List}(\texttt{ElfFile}) && \text{Loaded objects} \\
syms &: \text{Map}(\text{String}, \texttt{Symbol}) && \text{Global symbol table} \\
mem &: \text{List}(\texttt{MemoryRegion}) && \text{Memory layout} \\
base &: \mathbb{N}_{64} && \text{Base load address}
\end{align}$$

**Invariants:** $\mathcal{I}_L = \{
  \text{Unique symbols: } \forall s_1, s_2 \in \text{dom}(syms): s_1 \neq s_2 \implies syms[s_1].v \neq syms[s_2].v, \quad
  \text{Non-overlapping memory: } \forall m_1, m_2 \in mem: \text{disjoint}(m_1, m_2)
\}$

## Function Specifications

### Symbol Resolution

**Function:** `resolve_symbols(linker)`

**Signature:** 
$$f_{\text{resolve}}: \texttt{DynamicLinker} \to \texttt{DynamicLinker} \cup \{\text{Error}\}$$

**Precondition:** 
$$\text{All objects loaded into linker state}$$

**Postcondition:** 
$$\text{All resolvable symbols have defined values}$$

**Algorithm:**
$$\begin{align}
&\textbf{Input:} \quad \text{DynamicLinker } L \\
&\textbf{Step 1:} \quad \text{Collect all symbol definitions} \\
&\textbf{Step 2:} \quad \text{For each undefined symbol } u: \\
&\qquad\qquad \text{Find definition } d \text{ in global table} \\
&\qquad\qquad \text{If strong binding: assign } u.v \leftarrow d.v \\
&\qquad\qquad \text{If weak binding: use default or skip} \\
&\textbf{Step 3:} \quad \text{Verify no unresolved strong symbols} \\
&\textbf{Output:} \quad \text{Updated linker state}
\end{align}$$

### Object Loading

**Function:** `load_object(linker, elf_file)`

**Signature:** $f_{load}: \texttt{DynamicLinker} \times \texttt{ElfFile} \to \texttt{DynamicLinker}$

**Precondition:** Valid ELF object file

**Postcondition:** Object symbols added to global table, sections allocated

**Algorithm:**
$$\begin{align}
&\textbf{Input:} \text{DynamicLinker } L, \text{ElfFile } F \\
&\textbf{Step 1:} \text{Allocate memory for loadable sections} \\
&\textbf{Step 2:} \text{Add symbols to global symbol table} \\
&\textbf{Step 3:} \text{Update memory layout} \\
&\textbf{Step 4:} \text{Record object in loaded objects list} \\
&\textbf{Output:} \text{Updated linker } L'
\end{align}$$

### Relocation Processing

**Function:** `apply_relocations(linker, relocations)`

**Signature:** $f_{relocate}: \texttt{DynamicLinker} \times \text{List}(\texttt{RelocationEntry}) \to \texttt{DynamicLinker}$

**Precondition:** All referenced symbols resolved

**Postcondition:** All relocations applied to memory regions

**Algorithm:**
$$\begin{align}
&\textbf{For each relocation } r \in \text{relocations}: \\
&\quad \text{Let } sym = \text{resolve\_symbol}(r.\text{symbol}) \\
&\quad \text{Let } addr = r.\text{offset} + \text{section\_base} \\
&\quad \text{Apply relocation type:} \\
&\quad\quad \text{R\_X86\_64\_64: } \text{mem}[addr] \leftarrow sym.v \\
&\quad\quad \text{R\_X86\_64\_PC32: } \text{mem}[addr] \leftarrow sym.v - addr \\
&\quad\quad \text{Other types similarly}
\end{align}$$

### Memory Allocation

**Function:** `allocate_section(linker, section, size)`

**Signature:** $f_{alloc}: \texttt{DynamicLinker} \times \texttt{SectionHeader} \times \mathbb{N} \to \texttt{MemoryRegion}$

**Precondition:** 
$$\begin{align}
&\text{size} > 0 \\
&\text{section permissions valid}
\end{align}$$

**Postcondition:** Non-overlapping memory region allocated

**Algorithm:**
$$\begin{align}
&\text{Find next available address } addr \\
&\text{Align } addr \text{ to section alignment} \\
&\text{Create memory region } M = \langle \text{data}, addr, \text{size}, \text{perms} \rangle \\
&\text{Add } M \text{ to linker memory layout}
\end{align}$$

### Executable Generation

**Function:** `link_to_executable(object_files, output_name)`

**Signature:** $f_{link}: \text{List}(\text{String}) \times \text{String} \to \{\text{true}, \text{false}\}$

**Precondition:** All object files are valid ELF objects

**Postcondition:** Executable file created or error reported

**Algorithm:**
$$\begin{align}
&\textbf{Step 1:} \text{Create linker instance } L \\
&\textbf{Step 2:} \text{Load all object files into } L \\
&\textbf{Step 3:} \text{Resolve all symbols} \\
&\textbf{Step 4:} \text{Apply all relocations} \\
&\textbf{Step 5:} \text{Generate executable ELF file} \\
&\textbf{Step 6:} \text{Write to output file}
\end{align}$$

## Mathematical Properties

### Complexity Analysis

**Symbol Resolution:** 
$$\mathcal{O}(n \cdot m) \text{ where } n = \text{symbols}, m = \text{objects}$$

**Object Loading:** 
$$\mathcal{O}(s + \text{sym}) \text{ where } s = \text{sections}, \text{sym} = \text{symbols}$$

**Relocation:** 
$$\mathcal{O}(r) \text{ where } r = \text{number of relocations}$$

**Memory Allocation:** 
$$\mathcal{O}(\log(m)) \text{ with sorted memory regions}$$

**Complete Linking:** 
$$\mathcal{O}(n \cdot m + r + s \cdot \log(s))$$

### Correctness Properties

**Symbol Uniqueness:**
$$\forall s_1, s_2 \in \text{GlobalSymbols}: s_1.name = s_2.name \implies s_1 = s_2$$

**Memory Safety:**
$$\forall m_1, m_2 \in \text{MemoryRegions}: m_1 \neq m_2 \implies \text{disjoint}(m_1, m_2)$$

**Relocation Correctness:**
$$\forall r \in \text{Relocations}: \text{applied}(r) \implies \text{target\_address\_valid}(r)$$

**Link Completeness:**
$$\text{successful\_link}(objs) \implies \forall sym \in \text{undefined}: \exists def \in \text{definitions}: \text{resolves}(def, sym)$$

### Verification Conditions

**Symbol Resolution Termination:** No circular symbol dependencies

**Memory Layout Validity:** All sections fit within address space

**Relocation Bounds:** All relocations target valid memory regions

**Type Safety:** Symbol types compatible with usage contexts

## Dependencies

**Module Dependencies:**
$$\begin{align}
\text{elf\_format.jl} &\implies \text{Data structure definitions} \\
\text{elf\_parser.jl} &\implies \text{Object file parsing} \\
\text{elf\_writer.jl} &\implies \text{Executable generation} \\
\text{library\_support.jl} &\implies \text{System library resolution}
\end{align}$$

**Mathematical Dependencies:**
$$\begin{align}
\text{Graph algorithms} &\implies \text{Symbol dependency resolution} \\
\text{Memory management} &\implies \text{Address space allocation} \\
\text{Set theory} &\implies \text{Symbol table operations} \\
\text{Function composition} &\implies \text{Linking pipeline}
\end{align}$$