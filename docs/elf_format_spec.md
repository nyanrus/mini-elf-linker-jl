# ELF Format Specification

## Mathematical Foundation

**Module:** `elf_format.jl`

**Purpose:** Mathematical representation of ELF (Executable and Linkable Format) file structures

**Domain:** $\mathcal{D} = \{\text{Binary file data}\} \cup \{\text{Memory byte sequences}\}$

**Codomain:** $\mathcal{R} = \{\text{Structured ELF representations}\}$

## Data Structure Specifications

### ELF Header Structure

**Structure:** `ElfHeader`

**Mathematical Model:** $H = \langle m, c, d, v, o, a, p, t, mach, v', e, ph, sh, f, eh, phe, phn, she, shn, shs \rangle$

**Fields Definition:**
$$\begin{align}
m &: \{0x7f, 0x45, 0x4c, 0x46\} && \text{Magic number (invariant)} \\
c &: \{1, 2\} && \text{Class (32/64-bit)} \\
d &: \{1, 2\} && \text{Data encoding (little/big endian)} \\
v &: \mathbb{N} && \text{ELF version} \\
t &: \{1, 2, 3, 4\} && \text{Object file type} \\
e &: \mathbb{N}_{64} && \text{Entry point address}
\end{align}$$

**Invariants:** $\mathcal{I} = \{
  m = (0x7f, 0x45, 0x4c, 0x46), \quad
  c \in \{1, 2\}, \quad
  d \in \{1, 2\}
\}$

### Section Header Structure

**Structure:** `SectionHeader`

**Mathematical Model:** $S = \langle n, t, f, a, o, s, l, i, al, es \rangle$

**Type Constraints:**
$$\begin{align}
t &\in \{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11\} && \text{Section types} \\
f &\in 2^{\{0, 1, 2, 3, 4, 5, 6, 7\}} && \text{Section flags (bit set)} \\
a &: \mathbb{N}_{64} && \text{Virtual address} \\
s &: \mathbb{N}_{64} && \text{Section size}
\end{align}$$

**Invariants:** $\mathcal{I}_S = \{
  s \geq 0, \quad
  al \in 2^{\mathbb{N}}, \quad
  \text{if } t = \text{NOBITS} \text{ then } o = 0
\}$

## Function Specifications

### Symbol Table Operations

**Function:** `st_bind(info)`

**Signature:** $f_{bind}: \mathbb{Z}_{256} \to \{0, 1, 2, 10, 11, 12, 13\}$

**Definition:** $f_{bind}(x) = \lfloor x / 16 \rfloor \land 0xF$

**Precondition:** $x \in [0, 255]$

**Postcondition:** $f_{bind}(x) \in \{STB\_LOCAL, STB\_GLOBAL, STB\_WEAK, \ldots\}$

---

**Function:** `st_type(info)`

**Signature:** $f_{type}: \mathbb{Z}_{256} \to \{0, 1, 2, 3, 4\}$

**Definition:** $f_{type}(x) = x \land 0xF$

**Precondition:** $x \in [0, 255]$

**Postcondition:** $f_{type}(x) \in \{STT\_NOTYPE, STT\_OBJECT, STT\_FUNC, \ldots\}$

### Relocation Operations

**Function:** `elf64_r_sym(info)`

**Signature:** $f_{sym}: \mathbb{N}_{64} \to \mathbb{N}_{32}$

**Definition:** $f_{sym}(x) = \lfloor x / 2^{32} \rfloor$

**Mathematical Property:** $f_{sym}(f_{info}(s, t)) = s$

## Mathematical Properties

### Complexity Analysis

**Structure Access:** $\mathcal{O}(1)$ - Direct field access

**Symbol Extraction:** $\mathcal{O}(1)$ - Bitwise operations

**Memory Footprint:**
$$\begin{align}
|\texttt{ElfHeader}| &= 64 \text{ bytes} \\
|\texttt{SectionHeader}| &= 64 \text{ bytes} \\
|\texttt{SymbolTableEntry}| &= 24 \text{ bytes}
\end{align}$$

### Correctness Properties

**Bidirectional Symbol Info:**
$$\forall s, t: f_{info}(f_{bind}(f_{info}(s,t)), f_{type}(f_{info}(s,t))) = f_{info}(s,t)$$

**Relocation Decomposition:**
$$\forall x: f_{info}(f_{sym}(x), f_{type}(x)) \text{ reconstructs } x \text{ modulo platform constraints}$$

**Structure Invariant Preservation:**
$$\forall H \in \texttt{ElfHeader}: \text{parse}(\text{serialize}(H)) = H$$

### Dependencies

**Mathematical Dependencies:**
$$\begin{align}
\text{Constants} &\implies \text{Type constraints} \\
\text{Bit manipulation} &\implies \text{Platform word size} \\
\text{Memory layout} &\implies \text{Architecture alignment}
\end{align}$$

### Verification Conditions

**Type Safety:** All field access operations preserve type constraints

**Memory Safety:** No buffer overflows in structure operations

**Semantic Consistency:** ELF specification compliance maintained