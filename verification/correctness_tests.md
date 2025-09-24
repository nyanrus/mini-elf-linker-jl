# Correctness Tests

Mathematical verification of functional correctness following the Mathematical-Driven AI Development methodology.

## Current Test Organization

Tests are currently organized in `test/` directory following standard Julia conventions:

- `test/runtests.jl` - Main test suite runner with mathematical property verification
- `test/test_cli.jl` - Command-line interface mathematical model testing
- `test/test_linker.jl` - Core linker functionality with mathematical invariants
- `test/test_library_support.jl` - Library support mathematical operations testing
- `test/test_extended_library_support.jl` - Extended library functionality testing

## Mathematical Property Testing

Each test module verifies mathematical properties defined in specifications:

### Symbol Resolution Invariants
```julia
# Mathematical property: Symbol uniqueness
@test all(symbol -> count(==(symbol), resolved_symbols) == 1, unique_symbols)

# Mathematical property: Resolution completeness  
@test isempty(unresolved_symbols) || all(s -> s.binding != STB_STRONG, unresolved_symbols)
```

### Memory Layout Consistency
```julia
# Mathematical property: Non-overlapping memory regions
@test all(regions) do region
    all(other_regions) do other
        region == other || !overlaps(region, other)
    end
end
```

### ELF Format Compliance
```julia
# Mathematical property: Format correctness
@test elf_file.header.e_magic == ELF_MAGIC
@test elf_file.header.e_class ∈ [ELFCLASS32, ELFCLASS64]
```

## Integration with Mathematical Specifications

Tests maintain direct correspondence with mathematical specifications:

1. **Specification → Test**: Each mathematical property has corresponding test
2. **Mathematical naming**: Test variables use same mathematical conventions as specs
3. **Invariant verification**: Tests validate mathematical invariants explicitly
4. **Complexity bounds**: Performance tests verify mathematical complexity analysis

## Future Verification Framework

When verification/ directory is fully utilized:

- **Correctness proofs**: Mathematical verification of algorithmic correctness
- **Property-based testing**: Generate test cases from mathematical specifications
- **Formal verification**: Integration with formal methods tools
- **Performance validation**: Empirical verification of mathematical complexity bounds