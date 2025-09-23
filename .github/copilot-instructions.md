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

## Implementation Rules
- Always start each coding session with mathematical replanning
- Convert mathematical notation directly to Julia syntax
- Preserve mathematical structure in variable names: `S_intersection`, `compose_functions`
- Use `julia --quiet script.jl` for execution
- Generate minimal structured output only
- Translate mathematical pseudocode directly to Julia functions
- Maintain clear correspondence between mathematical operations and code
- Use mathematical terminology in function and variable names
- Document mathematical foundations in docstrings using LaTeX notation

## Execution Strategy
- Avoid REPL usage; use `julia script.jl` for all testing
- Minimize output verbosity with `--quiet` flag
- Generate structured results rather than step-by-step logs
- Use batch processing patterns for efficiency
- Create self-contained test scripts with minimal output
- Implement mathematical invariant checking
- Generate summary reports instead of verbose debugging
- Structure tests to validate mathematical properties
