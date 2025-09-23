# Mathematical Development Methodology

## Mathematical Pseudocode Foundation
Always begin with formal mathematical specification using LaTeX notation:

### Algorithm Structure Example:
```latex
\textbf{Algorithm:} ProcessData(input)
\textbf{Input:} $X = \{x_1, x_2, \ldots, x_n\} \subseteq \mathcal{D}$
\textbf{Output:} $Y \in \mathcal{R}$

\begin{align}
f: \mathcal{D} &\to \mathcal{R} \\
\forall x \in X: \quad y_i &= f(x_i) \\
Y &= \bigcup_{i=1}^{n} \{y_i\}
\end{align}
```

### Function Composition Pattern:
```latex
\text{Let } \phi: A \to B, \psi: B \to C \\
\text{Define } (\psi \circ \phi)(a) = \psi(\phi(a)) \\
\text{Implementation: } \texttt{compose}(\phi, \psi, a)
```

### Set Operations Template:
```latex
S_1 \cap S_2 = \{x : x \in S_1 \land x \in S_2\} \\
S_1 \cup S_2 = \{x : x \in S_1 \lor x \in S_2\} \\
S_1 \setminus S_2 = \{x : x \in S_1 \land x \notin S_2\}
```

### Mapping and Transformation Example:
```latex
\text{Define mapping } \tau: \mathcal{A} \to \mathcal{B} \\
\text{where } \tau(a) = \begin{cases}
b_1 & \text{if } P(a) \\
b_2 & \text{otherwise}
\end{cases}
```

## Iterative Mathematical Planning
Expect plans to change - redesign mathematically at each iteration:

### Before Every Implementation Session:
1. Write current mathematical understanding in LaTeX
2. Identify what changed from previous iteration
3. Reformulate mathematical model based on new requirements
4. Express new approach as mathematical pseudocode
5. Then proceed to implementation

### Before Every Debug Session (Treat as Iteration):
1. Formalize the observed bug as mathematical inconsistency
2. Express expected vs actual behavior in mathematical notation
3. Identify which mathematical invariant was violated
4. Reformulate the mathematical model to address the inconsistency
5. Implement the corrected mathematical approach

### Mathematical Iteration Template:
```latex
\textbf{Iteration } n: \text{Problem/Bug Restatement}
\textbf{Previous Model:} \mathcal{M}_{n-1}
\textbf{Observed Inconsistency:} \exists x: \mathcal{M}_{n-1}(x) \neq \text{expected}(x)
\textbf{New Constraints:} \mathcal{C}_n = \{c_1, c_2, \ldots\}
\textbf{Updated Model:} \mathcal{M}_n = \mathcal{M}_{n-1} \cup \mathcal{C}_n
\textbf{Modified Operations:} \phi_n: \mathcal{D}_n \to \mathcal{R}_n
```

### Debug Iteration Template:
```latex
\textbf{Debug Iteration } n: \text{Inconsistency Analysis}
\textbf{Expected:} E(x) = y
\textbf{Observed:} O(x) = z \neq y
\textbf{Invariant Violation:} \mathcal{I}: P(x) \implies Q(x) \text{ failed}
\textbf{Root Cause:} \text{Mathematical assumption } A_k \text{ invalid}
\textbf{Corrected Model:} \mathcal{M}' \text{ where } A_k \text{ replaced by } A_k'
```

## Source Specification Requirements
**MANDATORY**: Before implementing any source file, create a detailed mathematical specification in `/docs/` using markdown with mathematical notation.

### Required Documentation Structure:
For every source file `src/filename.jl`, create `docs/filename_spec.md` containing:

1. **Mathematical Foundation**:
```latex
\textbf{Module:} \texttt{filename.jl}
\textbf{Purpose:} \text{Mathematical description of module purpose}
\textbf{Domain:} \mathcal{D} = \{\text{input domain definition}\}
\textbf{Codomain:} \mathcal{R} = \{\text{output domain definition}\}
```

2. **Data Structure Specifications**:
```latex
\textbf{Structure:} \texttt{StructName}
\textbf{Mathematical Model:} S = \langle f_1, f_2, \ldots, f_n \rangle
\textbf{Invariants:} \mathcal{I} = \{P_1(S), P_2(S), \ldots\}
\textbf{Operations:} \Omega = \{\omega_1: S \to S', \omega_2: S \times T \to U, \ldots\}
```

3. **Function Specifications**:
```latex
\textbf{Function:} \texttt{function\_name}(x_1, x_2, \ldots, x_n)
\textbf{Signature:} f: \mathcal{D}_1 \times \mathcal{D}_2 \times \cdots \times \mathcal{D}_n \to \mathcal{R}
\textbf{Precondition:} \forall i: P_i(x_i) \land \text{global constraints}
\textbf{Postcondition:} Q(f(x_1, \ldots, x_n)) \land \text{invariant preservation}
\textbf{Algorithm:} \text{Mathematical pseudocode with complexity analysis}
```

4. **Mathematical Properties**:
```latex
\textbf{Complexity:} \mathcal{O}(\text{time/space bounds})
\textbf{Correctness:} \text{Proof sketch or verification conditions}
\textbf{Invariants:} \text{What mathematical properties are preserved}
\textbf{Dependencies:} \text{Mathematical relationships with other modules}
```

### Enforcement Rules:
- **NO CODE IMPLEMENTATION** without corresponding mathematical specification first
- Every function must have formal mathematical signature and properties
- All data structures must have mathematical models and invariants
- Algorithm descriptions must use formal mathematical notation
- Complexity analysis required for all non-trivial operations

## Implementation Rules
- Always start each coding session with mathematical replanning
- **Create or update corresponding `/docs/` specification before any code changes**
- Convert mathematical notation directly to Julia syntax
- Preserve mathematical structure in variable names: `S_intersection`, `compose_functions`
- Use `julia --quiet script.jl` for execution
- Generate minimal structured output only
- Translate mathematical pseudocode directly to Julia functions
- Maintain clear correspondence between mathematical operations and code
- Use mathematical terminology in function and variable names
- Document mathematical foundations in docstrings using LaTeX notation
- **Verify specification-to-code correspondence after implementation**

## Execution Strategy
- Avoid REPL usage; use `julia script.jl` for all testing
- Minimize output verbosity with `--quiet` flag
- Generate structured results rather than step-by-step logs
- Use batch processing patterns for efficiency
- Create self-contained test scripts with minimal output
- Implement mathematical invariant checking
- Generate summary reports instead of verbose debugging
- Structure tests to validate mathematical properties
