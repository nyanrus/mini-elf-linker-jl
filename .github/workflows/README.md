# GitHub Workflows for Mini-ELF-Linker

This directory contains GitHub Actions workflows for testing and validating the Mini-ELF-Linker project.

## Workflows

### 1. `ci.yml` - Continuous Integration
**Triggers**: Push/PR to main/master branches  
**Purpose**: Fast feedback for development  
**Runtime**: ~5-10 minutes

**Jobs**:
- **test**: Runs Julia package tests on multiple Julia versions (1.6, 1.9)
- **spec-check**: Quick ELF specification compliance analysis
- **linker-smoke-test**: Basic functionality test with simple C program

This workflow runs on every push/PR and provides quick feedback on basic functionality.

### 2. `production-testing.yml` - Production Testing Framework
**Triggers**: Push/PR to main/master, Manual dispatch  
**Purpose**: Comprehensive production readiness testing  
**Runtime**: ~30-60 minutes (depending on selected tests)

**Jobs**:
- **specification-analysis**: Complete ELF specification compliance analysis
- **cmake-integration**: CMake integration testing with synthetic projects
- **lld-comparison**: Binary analysis comparing outputs with LLD
- **cmake-real-build**: Real Kitware/CMake repository testing (manual trigger only)
- **julia-tests**: Core Julia package testing
- **test-summary**: Generates comprehensive test report

**Manual Execution**:
You can manually trigger this workflow from the GitHub Actions tab with options:
- `all`: Run all tests (except real CMake build)
- `spec-analysis`: Only specification analysis
- `cmake-integration`: Only CMake integration tests
- `lld-comparison`: Only LLD comparison tests
- `cmake-real-build`: Only real CMake repository testing

## Test Scripts

The workflows execute the following test scripts:

1. **`scripts/spec_analysis.jl`**: ELF specification compliance analysis
2. **`scripts/cmake_production_test.jl`**: CMake integration testing framework
3. **`scripts/lld_comparison.jl`**: LLD comparison and binary analysis
4. **`scripts/cmake_real_build_test.jl`**: Real CMake repository cloning and testing
5. **`test/runtests.jl`**: Core Julia package tests

## Artifacts

Both workflows generate artifacts that are stored for analysis:

- **specification-analysis-results**: ELF compliance reports
- **cmake-integration-results**: CMake build test outputs
- **lld-comparison-results**: Binary comparison reports
- **cmake-real-build-results**: Real CMake build artifacts
- **test-summary**: Comprehensive testing summary (markdown report)

Artifacts are retained for 30-90 days depending on importance.

## Usage Examples

### Running Quick Tests (CI)
The CI workflow runs automatically on push/PR. To manually trigger:

```bash
# Push to main branch - triggers CI automatically
git push origin main

# Create PR - triggers CI automatically  
gh pr create --title "My changes" --body "Description"
```

### Running Production Tests
To run comprehensive production tests:

1. Go to the GitHub Actions tab in your repository
2. Select "Production Testing Framework" 
3. Click "Run workflow"
4. Choose test suite:
   - **all**: Complete testing suite (recommended for releases)
   - **spec-analysis**: Quick compliance check
   - **cmake-integration**: CMake compatibility testing
   - **lld-comparison**: Binary compatibility analysis
   - **cmake-real-build**: Real-world project testing (slow)

### Analyzing Results
After workflow completion:

1. Check the "Summary" tab for overall results
2. Download artifacts for detailed analysis
3. Review the test-summary artifact for comprehensive report
4. For PRs, check the auto-generated comment with results

## System Requirements

The workflows install these system dependencies:
- **build-essential**: GCC, make, etc.
- **clang**: Modern C/C++ compiler
- **llvm**: LLVM toolchain
- **lld**: LLD linker for comparison
- **lldb**: LLDB debugger for analysis
- **cmake**: CMake build system
- **git**: Version control (for repository cloning)
- **binutils**: Binary analysis tools

## Performance Considerations

- **CI workflow**: Lightweight, runs quickly (~5-10 min)
- **Production testing**: Resource-intensive, longer runtime (~30-60 min)
- **Real CMake testing**: Very resource-intensive, only run on manual trigger
- **Parallel execution**: Multiple jobs run in parallel when possible
- **Caching**: Julia packages are cached to improve performance

## Troubleshooting

### Common Issues

1. **Test timeout**: Increase timeout-minutes in workflow if needed
2. **System dependency issues**: Check apt-get install commands
3. **Julia package issues**: Verify Project.toml dependencies
4. **Artifact upload failures**: Check path specifications

### Debugging Failed Tests

1. Check the workflow logs in GitHub Actions
2. Download artifacts for detailed analysis
3. Run tests locally to reproduce issues:
   ```bash
   julia --project=. scripts/spec_analysis.jl
   julia --project=. test/runtests.jl
   ```

### Local Development

To run the same tests locally:

```bash
# Install system dependencies (Ubuntu/Debian)
sudo apt-get install build-essential clang llvm lld lldb cmake

# Install Julia dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run individual test scripts
julia --project=. scripts/spec_analysis.jl
julia --project=. scripts/cmake_production_test.jl
julia --project=. test/runtests.jl
```

## Contributing

When adding new test scripts:

1. Add the script to the appropriate workflow
2. Ensure proper error handling and output formatting
3. Add artifact collection if the script generates useful files
4. Update this README with documentation
5. Test the workflow changes on a feature branch first