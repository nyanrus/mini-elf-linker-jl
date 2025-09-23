# ELF Format Specification

## Mathematical Foundation

**Module:** `elf_format.jl`

**Purpose:** Mathematical representation of ELF (Executable and Linkable Format) file structures

**Domain:** 
$$\mathcal{D} = \{\text{Binary file data}\} \cup \{\text{Memory byte sequences}\}$$

**Codomain:** 
$$\mathcal{R} = \{\text{Structured ELF representations}\}$$

## Data Structure Specifications

### ELF Header Structure

**Structure:** `ElfHeader`

**Mathematical Model:** 
$$H = \langle m, c, d, v, o, a, p, t, \text{mach}, v', e, \text{ph}, \text{sh}, f, \text{eh}, \text{phe}, \text{phn}, \text{she}, \text{shn}, \text{shs} \rangle$$

**Fields Definition:**
$$\begin{align}
m &: \{0x7f, 0x45, 0x4c, 0x46\} && \text{Magic number (invariant)} \\
c &: \{1, 2\} && \text{Class (32/64-bit)} \\
d &: \{1, 2\} && \text{Data encoding (little/big endian)} \\
v &: \mathbb{N} && \text{ELF version} \\
t &: \{1, 2, 3, 4\} && \text{Object file type} \\
e &: \mathbb{N}_{64} && \text{Entry point address}
\end{align}$$

**Invariants:** 
$$\mathcal{I} = \left\{
\begin{aligned}
&m = (0x7f, 0x45, 0x4c, 0x46) \\
&c \in \{1, 2\} \\
&d \in \{1, 2\}
\end{aligned}
\right\}$$

### Section Header Structure

**Structure:** `SectionHeader`

**Mathematical Model:** 
$$S = \langle n, t, f, a, o, s, l, i, \text{al}, \text{es} \rangle$$

**Type Constraints:**
$$\begin{align}
t &\in \{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11\} &&\text{Section types} \\
f &\in 2^{\{0, 1, 2, 3, 4, 5, 6, 7\}} &&\text{Section flags (bit set)} \\
a &\in \mathbb{N}_{64} &&\text{Virtual address} \\
s &\in \mathbb{N}_{64} &&\text{Section size}
\end{align}$$

**Invariants:** 
$$\mathcal{I}_S = \left\{
\begin{aligned}
&s \geq 0 \\
&\text{al} \in 2^{\mathbb{N}} \\
&t = \text{NOBITS} \implies o = 0
\end{aligned}
\right\}$$

## Function Specifications

### Symbol Table Operations

**Function:** `st_bind(info)`

**Signature:** 
$$f_{\text{bind}}: \mathbb{Z}_{256} \to \{0, 1, 2, 10, 11, 12, 13\}$$

**Definition:** 
$$f_{\text{bind}}(x) = \left\lfloor \frac{x}{16} \right\rfloor \land 0xF$$

**Precondition:** 
$$x \in [0, 255]$$

**Postcondition:** 
$$f_{\text{bind}}(x) \in \{\text{STB\_LOCAL}, \text{STB\_GLOBAL}, \text{STB\_WEAK}, \ldots\}$$

---

**Function:** `st_type(info)`

**Signature:** 
$$f_{\text{type}}: \mathbb{Z}_{256} \to \{0, 1, 2, 3, 4\}$$

**Definition:** 
$$f_{\text{type}}(x) = x \land 0xF$$

**Precondition:** 
$$x \in [0, 255]$$

**Postcondition:** 
$$f_{\text{type}}(x) \in \{\text{STT\_NOTYPE}, \text{STT\_OBJECT}, \text{STT\_FUNC}, \ldots\}$$

### Relocation Operations

**Function:** `elf64_r_sym(info)`

**Signature:** 
$$f_{\text{sym}}: \mathbb{N}_{64} \to \mathbb{N}_{32}$$

**Definition:** 
$$f_{\text{sym}}(x) = \left\lfloor \frac{x}{2^{32}} \right\rfloor$$

**Mathematical Property:** 
$$f_{\text{sym}}\left(f_{\text{info}}(s, t)\right) = s$$

## Mathematical Properties

### Complexity Analysis

**Structure Access:** 
$$\mathcal{O}(1) \text{ — Direct field access}$$

**Symbol Extraction:** 
$$\mathcal{O}(1) \text{ — Bitwise operations}$$

**Memory Footprint:**
$$\begin{align}
|\texttt{ElfHeader}| &= 64 \text{ bytes} \\
|\texttt{SectionHeader}| &= 64 \text{ bytes} \\
|\texttt{SymbolTableEntry}| &= 24 \text{ bytes}
\end{align}$$

### Correctness Properties

**Bidirectional Symbol Info:**
$$\forall s, t \in \mathbb{Z}: f_{\text{info}}\left(f_{\text{bind}}\left(f_{\text{info}}(s,t)\right), f_{\text{type}}\left(f_{\text{info}}(s,t)\right)\right) = f_{\text{info}}(s,t)$$

**Relocation Decomposition:**
$$\forall x \in \mathbb{N}_{64}: f_{\text{info}}\left(f_{\text{sym}}(x), f_{\text{type}}(x)\right) \text{ reconstructs } x \text{ modulo platform constraints}$$

**Structure Invariant Preservation:**
$$\forall H \in \texttt{ElfHeader}: \text{parse}\left(\text{serialize}(H)\right) = H$$

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