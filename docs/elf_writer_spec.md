# ELF Writer Specification

## Mathematical Foundation

**Module:** `elf_writer.jl`

**Purpose:** Mathematical serialization operations from structured ELF data to binary executable format

**Domain:** $\mathcal{D} = \{\text{Linked objects}\} \times \{\text{Memory layouts}\} \times \{\text{Symbol tables}\}$

**Codomain:** $\mathcal{R} = \{\text{Binary ELF files}\} \cup \{\text{IO streams}\}$

## Data Structure Specifications

### Executable Layout Model

**Structure:** `ExecutableLayout`

**Mathematical Model:** $E = \langle h, ph, sh, data \rangle$

**Layout Components:**
$$\begin{align}
h &: \texttt{ElfHeader} && \text{File header} \\
ph &: \text{List}(\texttt{ProgramHeader}) && \text{Program headers} \\
sh &: \text{List}(\texttt{SectionHeader}) && \text{Section headers} \\
data &: \text{Map}(\text{Offset}, \text{Bytes}) && \text{File content mapping}
\end{align}$$

**Invariants:** $\mathcal{I}_E = \{
  |ph| = h.\text{phnum}, \quad
  |sh| = h.\text{shnum}, \quad
  \forall p \in ph: p.\text{offset} + p.\text{filesz} \leq \text{file\_size}
\}$

### Binary Layout Constraints

**File Structure Ordering:**
$$\begin{align}
\text{ELF Header} &: [0, 64) \\
\text{Program Headers} &: [h.\text{phoff}, h.\text{phoff} + h.\text{phnum} \times h.\text{phentsize}) \\
\text{Section Content} &: \bigcup_{s \in \text{sections}} [s.\text{offset}, s.\text{offset} + s.\text{size}) \\
\text{Section Headers} &: [h.\text{shoff}, h.\text{shoff} + h.\text{shnum} \times h.\text{shentsize})
\end{align}$$

**Alignment Constraints:**
$$\begin{align}
\forall p \in \text{ProgramHeaders}: &\quad p.\text{vaddr} \bmod p.\text{align} = 0 \\
\forall s \in \text{SectionHeaders}: &\quad s.\text{offset} \bmod s.\text{addralign} = 0
\end{align}$$

## Function Specifications

### Header Writing

**Function:** `write_elf_header(io, header)`

**Signature:** $f_{write\_header}: \text{IO} \times \texttt{ElfHeader} \to \text{IO}$

**Precondition:** io is writable, header is valid

**Postcondition:** 64 bytes written to io, io position advanced

**Algorithm:**
$$\begin{align}
&\textbf{Input:} \text{IO } io, \texttt{ElfHeader} \text{ } h \\
&\textbf{Step 1:} \text{Write magic bytes } (0x7f, 0x45, 0x4c, 0x46) \\
&\textbf{Step 2:} \text{Write identification fields sequentially} \\
&\textbf{Step 3:} \text{Write header fields in little-endian format} \\
&\textbf{Output:} \text{Updated IO stream}
\end{align}$$

### Program Header Generation

**Function:** `create_program_headers(memory_regions)`

**Signature:** $f_{prog\_headers}: \text{List}(\texttt{MemoryRegion}) \to \text{List}(\texttt{ProgramHeader})$

**Precondition:** Memory regions are non-overlapping and valid

**Postcondition:** Each loadable region has corresponding program header

**Algorithm:**
$$\begin{align}
&\textbf{For each region } r \in \text{memory\_regions}: \\
&\quad \text{Create } ph = \texttt{ProgramHeader}( \\
&\quad\quad \text{type} = \text{PT\_LOAD}, \\
&\quad\quad \text{flags} = \text{permissions}(r), \\
&\quad\quad \text{offset} = \text{file\_offset}(r), \\
&\quad\quad \text{vaddr} = r.\text{base\_address}, \\
&\quad\quad \text{paddr} = r.\text{base\_address}, \\
&\quad\quad \text{filesz} = |r.\text{data}|, \\
&\quad\quad \text{memsz} = r.\text{size}, \\
&\quad\quad \text{align} = \text{PAGE\_SIZE} \\
&\quad )
\end{align}$$

### Section Header Creation

**Function:** `create_section_headers(sections, string_table)`

**Signature:** $f_{sect\_headers}: \text{List}(\text{Section}) \times \text{StringTable} \to \text{List}(\texttt{SectionHeader})$

**Precondition:** All section names in string table

**Postcondition:** Complete section header table

**Algorithm:**
$$\begin{align}
&\text{Create null section header at index 0} \\
&\textbf{For each section } s: \\
&\quad \text{name\_offset} \leftarrow \text{string\_table\_offset}(s.\text{name}) \\
&\quad \text{Create section header with computed offsets} \\
&\text{Add string table section header} \\
&\text{Add symbol table section header if present}
\end{align}$$

### Executable File Generation

**Function:** `write_elf_executable(linker, filename, entry_point)`

**Signature:** $f_{executable}: \texttt{DynamicLinker} \times \text{String} \times \mathbb{N}_{64} \to \{\text{true}, \text{false}\}$

**Precondition:** Linker state is fully resolved

**Postcondition:** Valid executable ELF file created

**Algorithm:**
$$\begin{align}
&\textbf{Step 1:} \text{Calculate file layout and offsets} \\
&\textbf{Step 2:} \text{Create ELF header with entry point} \\
&\textbf{Step 3:} \text{Generate program headers for loadable segments} \\
&\textbf{Step 4:} \text{Write headers and content sequentially} \\
&\textbf{Step 5:} \text{Set executable permissions on output file}
\end{align}$$

### Layout Computation

**Function:** `compute_file_layout(memory_regions)`

**Signature:** $f_{layout}: \text{List}(\texttt{MemoryRegion}) \to \text{FileLayout}$

**Precondition:** Memory regions represent complete program

**Postcondition:** Non-overlapping file offsets assigned

**Algorithm:**
$$\begin{align}
&\text{current\_offset} \leftarrow 64 \quad \text{(after ELF header)} \\
&\text{Compute program header table size and offset} \\
&\textbf{For each memory region } r: \\
&\quad \text{Align current\_offset to page boundary} \\
&\quad r.\text{file\_offset} \leftarrow \text{current\_offset} \\
&\quad \text{current\_offset} \leftarrow \text{current\_offset} + |r.\text{data}| \\
&\text{Compute section header table offset}
\end{align}$$

## Mathematical Properties

### Complexity Analysis

**Header Writing:** $\mathcal{O}(1)$ - Fixed size operations

**Program Header Generation:** $\mathcal{O}(n)$ where $n = \text{memory regions}$

**Layout Computation:** $\mathcal{O}(n \cdot \log(n))$ with sorting

**File Writing:** $\mathcal{O}(s)$ where $s = \text{total file size}$

**Complete Generation:** $\mathcal{O}(n \cdot \log(n) + s)$

### Correctness Properties

**Format Compliance:**
Generated files conform to ELF specification

**Layout Consistency:**
$$\begin{align}
&\forall p \in \text{ProgramHeaders}: p.\text{offset} + p.\text{filesz} \leq \text{file\_size} \\
&\forall s \in \text{SectionHeaders}: s.\text{offset} + s.\text{size} \leq \text{file\_size}
\end{align}$$

**Address Space Mapping:**
$$\forall p \in \text{ProgramHeaders}: \text{file\_content}[p.\text{offset}:p.\text{offset}+p.\text{filesz}] \mapsto \text{memory}[p.\text{vaddr}:p.\text{vaddr}+p.\text{memsz}]$$

**Executability:**
Generated executable has valid entry point and loadable segments

### Binary Format Constraints

**ELF Header Validity:**
$$\begin{align}
h.\text{magic} &= (0x7f, 0x45, 0x4c, 0x46) \\
h.\text{class} &= 2 \quad \text{(64-bit)} \\
h.\text{data} &= 1 \quad \text{(little-endian)} \\
h.\text{type} &= 2 \quad \text{(ET\_EXEC)}
\end{align}$$

**Program Header Constraints:**
$$\begin{align}
\forall p \in \text{LoadableSegments}: &\quad p.\text{type} = \text{PT\_LOAD} \\
&\quad p.\text{vaddr} \geq 0x400000 \quad \text{(typical base)} \\
&\quad p.\text{align} = 0x1000 \quad \text{(page size)}
\end{align}$$

### Verification Conditions

**File Structure Integrity:** All offsets and sizes are consistent

**Memory Layout Validity:** Virtual addresses don't conflict

**Permission Consistency:** Segment permissions match section requirements

**Symbol Resolution:** All required symbols have valid addresses

## Dependencies

**Module Dependencies:**
$$\begin{align}
\text{elf\_format.jl} &\implies \text{Structure definitions} \\
\text{dynamic\_linker.jl} &\implies \text{Linked object state} \\
\text{IO operations} &\implies \text{File system interface}
\end{align}$$

**Mathematical Dependencies:**
$$\begin{align}
\text{Binary serialization} &\implies \text{Endianness handling} \\
\text{Memory layout} &\implies \text{Address space management} \\
\text{File format} &\implies \text{ELF specification compliance} \\
\text{Executable generation} &\implies \text{Operating system loader compatibility}
\end{align}$$