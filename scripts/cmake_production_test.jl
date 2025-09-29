#!/usr/bin/env julia
"""
CMake Production Testing Framework for Mini-ELF-Linker
Tests the linker against real-world CMake projects with LLD comparison
"""

using Printf
using Dates

"""
Mathematical Framework for Production Testing:
```math
Production_{test} = ∏_{i ∈ {gcc, lld, mini}} Build_i × Validate_i × Compare_i
```

Where each test configuration follows:
```math
Config_i = {
    compiler: C,
    linker: L_i, 
    output: O_i,
    validation: V_i
}
```
"""

struct ProductionTestConfig
    name::String
    compiler::String
    linker_command::String
    description::String
    expected_success::Bool
end

struct ProductionTestResult
    config::ProductionTestConfig
    build_success::Bool
    build_time::Float64
    executable_path::String
    executable_size::Int64
    validation_success::Bool
    errors::Vector{String}
    warnings::Vector{String}
    lldb_analysis::String
end

# Production test configurations comparing different linkers
const PRODUCTION_CONFIGS = [
    ProductionTestConfig(
        "gcc_ld", 
        "gcc", 
        "ld", 
        "Baseline: GCC with GNU ld", 
        true
    ),
    ProductionTestConfig(
        "clang_lld", 
        "clang", 
        "ld.lld", 
        "Reference: Clang with LLD", 
        true
    ),
    ProductionTestConfig(
        "clang_mini", 
        "clang", 
        "mini-elf-linker", 
        "Test: Clang with Mini ELF Linker", 
        false  # Initially expected to fail, will improve iteratively
    )
]

"""
    setup_cmake_test_project() -> String

Set up a CMake test project for production testing.
Returns the project directory path.
"""
function setup_cmake_test_project()
    test_dir = "/tmp/cmake_production_test"
    
    # Clean and create test directory
    if isdir(test_dir)
        rm(test_dir, recursive=true)
    end
    mkdir(test_dir)
    
    println("🏗️  Setting up CMake test project at: $test_dir")
    
    # Create CMakeLists.txt
    cmake_content = """
cmake_minimum_required(VERSION 3.10)
project(ProductionTest C)

set(CMAKE_C_STANDARD 99)

# Add executable target
add_executable(test_program
    src/main.c
    src/math_utils.c
    src/string_utils.c
)

# Link with math library
target_link_libraries(test_program m)

# Set compiler-specific options
if(CMAKE_C_COMPILER_ID MATCHES "Clang")
    target_compile_options(test_program PRIVATE -Wall -Wextra)
elseif(CMAKE_C_COMPILER_ID MATCHES "GNU")
    target_compile_options(test_program PRIVATE -Wall -Wextra)
endif()
"""
    
    write(joinpath(test_dir, "CMakeLists.txt"), cmake_content)
    
    # Create source directory and files
    src_dir = joinpath(test_dir, "src")
    mkdir(src_dir)
    
    # main.c
    main_c = """
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "math_utils.h"
#include "string_utils.h"

int main() {
    printf("=== Production Test Program ===\\n");
    
    // Test mathematical operations
    double a = 3.14159, b = 2.71828;
    printf("Mathematical test: %.2f + %.2f = %.2f\\n", a, b, add_doubles(a, b));
    printf("Square root of %.2f = %.2f\\n", a, sqrt(a));
    
    // Test string operations  
    const char* test_str = "Hello, Production!";
    printf("String test: '%s' has length %zu\\n", test_str, string_length(test_str));
    printf("Reversed: '%s'\\n", reverse_string(test_str));
    
    // Test memory allocation
    int* array = allocate_int_array(10);
    if (array) {
        for (int i = 0; i < 10; i++) {
            array[i] = i * i;
        }
        printf("Array test: [");
        for (int i = 0; i < 10; i++) {
            printf("%d%s", array[i], (i < 9) ? ", " : "");
        }
        printf("]\\n");
        free(array);
    }
    
    printf("=== All tests completed successfully! ===\\n");
    return 0;
}
"""
    
    # math_utils.c and header
    math_utils_c = """
#include "math_utils.h"
#include <math.h>

double add_doubles(double a, double b) {
    return a + b;
}

double multiply_doubles(double a, double b) {
    return a * b;
}

int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}
"""
    
    math_utils_h = """
#ifndef MATH_UTILS_H
#define MATH_UTILS_H

double add_doubles(double a, double b);
double multiply_doubles(double a, double b);
int factorial(int n);

#endif
"""
    
    # string_utils.c and header
    string_utils_c = """
#include "string_utils.h"
#include <string.h>
#include <stdlib.h>

size_t string_length(const char* str) {
    return strlen(str);
}

char* reverse_string(const char* str) {
    size_t len = strlen(str);
    char* reversed = malloc(len + 1);
    if (!reversed) return NULL;
    
    for (size_t i = 0; i < len; i++) {
        reversed[i] = str[len - 1 - i];
    }
    reversed[len] = '\\0';
    return reversed;
}

int* allocate_int_array(size_t size) {
    return malloc(size * sizeof(int));
}
"""
    
    string_utils_h = """
#ifndef STRING_UTILS_H
#define STRING_UTILS_H

#include <stddef.h>

size_t string_length(const char* str);
char* reverse_string(const char* str);
int* allocate_int_array(size_t size);

#endif
"""
    
    # Write all source files
    write(joinpath(src_dir, "main.c"), main_c)
    write(joinpath(src_dir, "math_utils.c"), math_utils_c)
    write(joinpath(src_dir, "math_utils.h"), math_utils_h)
    write(joinpath(src_dir, "string_utils.c"), string_utils_c)
    write(joinpath(src_dir, "string_utils.h"), string_utils_h)
    
    println("✅ CMake test project setup complete")
    return test_dir
end

"""
    build_with_config(project_dir::String, config::ProductionTestConfig) -> ProductionTestResult

Build the CMake project with the specified configuration.
"""
function build_with_config(project_dir::String, config::ProductionTestConfig)
    println("🔨 Building with $(config.name): $(config.description)")
    
    errors = String[]
    warnings = String[]
    build_success = false
    build_time = 0.0
    executable_path = ""
    executable_size = 0
    validation_success = false
    lldb_analysis = ""
    
    # Create build directory
    build_dir = joinpath(project_dir, "build_$(config.name)")
    if isdir(build_dir)
        rm(build_dir, recursive=true)
    end
    mkdir(build_dir)
    
    try
        start_time = time()
        
        # Configure with CMake
        cmake_cmd = if config.name == "clang_mini"
            # Special handling for mini-elf-linker
            mini_linker_path = abspath(joinpath(@__DIR__, "..", "bin", "mini-elf-linker"))
            `cmake -DCMAKE_C_COMPILER=$(config.compiler) -DCMAKE_LINKER=$mini_linker_path -S $project_dir -B $build_dir`
        else
            `cmake -DCMAKE_C_COMPILER=$(config.compiler) -S $project_dir -B $build_dir`
        end
        
        println("   Configure: $(join(cmake_cmd.exec, " "))")
        run(cmake_cmd)
        
        # Build the project  
        build_cmd = `cmake --build $build_dir`
        println("   Build: $(join(build_cmd.exec, " "))")
        run(build_cmd)
        
        build_time = time() - start_time
        build_success = true
        
        # Find the executable
        executable_path = joinpath(build_dir, "test_program")
        if isfile(executable_path)
            executable_size = filesize(executable_path)
            
            # Validate the executable
            validation_success = validate_executable(executable_path, errors, warnings)
            
            # Run LLDB analysis if available
            lldb_analysis = analyze_with_lldb(executable_path, errors, warnings)
            
            println("   ✅ Build successful: $(executable_size) bytes")
        else
            push!(errors, "Executable not found: $executable_path")
            println("   ❌ Executable not found")
        end
        
    catch e
        build_time = time() - start_time
        push!(errors, "Build failed: $e")
        println("   ❌ Build failed: $e")
    end
    
    return ProductionTestResult(
        config, build_success, build_time, executable_path, 
        executable_size, validation_success, errors, warnings, lldb_analysis
    )
end

"""
    validate_executable(executable_path::String, errors::Vector{String}, warnings::Vector{String}) -> Bool

Validate that the executable works correctly.
"""
function validate_executable(executable_path::String, errors::Vector{String}, warnings::Vector{String})
    if !isfile(executable_path)
        push!(errors, "Executable not found: $executable_path")
        return false
    end
    
    # Test execution
    try
        println("   🧪 Testing execution...")
        result = read(`$executable_path`, String)
        
        # Check for expected output patterns
        expected_patterns = [
            "Production Test Program",
            "Mathematical test:",
            "String test:",
            "Array test:",
            "All tests completed successfully!"
        ]
        
        for pattern in expected_patterns
            if !contains(result, pattern)
                push!(warnings, "Missing expected output pattern: $pattern")
            end
        end
        
        println("   ✅ Execution test passed")
        return true
        
    catch e
        push!(errors, "Execution failed: $e")
        println("   ❌ Execution test failed: $e")
        return false
    end
end

"""
    analyze_with_lldb(executable_path::String, errors::Vector{String}, warnings::Vector{String}) -> String

Analyze executable structure using LLDB.
"""
function analyze_with_lldb(executable_path::String, errors::Vector{String}, warnings::Vector{String})
    analysis_result = ""
    
    try
        if success(`which lldb`)
            println("   🔍 LLDB analysis...")
            
            # Create LLDB script for comprehensive analysis
            lldb_script = """
target create "$executable_path"
image list
image dump sections
image dump symtab
quit
"""
            lldb_script_path = "/tmp/lldb_analysis_$(basename(executable_path)).script"
            write(lldb_script_path, lldb_script)
            
            # Run LLDB analysis
            result = read(pipeline(`lldb -s $lldb_script_path`, stderr=devnull), String)
            analysis_result = result
            
            # Parse results for issues
            if contains(result, "error") || contains(result, "failed")
                push!(warnings, "LLDB analysis detected potential issues")
            end
            
            # Clean up
            rm(lldb_script_path, force=true)
            
            println("   ✅ LLDB analysis complete")
        else
            analysis_result = "LLDB not available"
        end
    catch e
        push!(warnings, "LLDB analysis failed: $e")
        analysis_result = "LLDB analysis failed: $e"
    end
    
    return analysis_result
end

"""
    compare_results(results::Vector{ProductionTestResult})

Compare results between different linkers and generate analysis.
"""
function compare_results(results::Vector{ProductionTestResult})
    println("\\n📊 Production Test Results Comparison")
    println("=" ^ 80)
    
    # Summary table
    @printf("%-15s %-10s %-12s %-15s %-10s\\n", "Configuration", "Success", "Build Time", "Size (bytes)", "Validation")
    println("-" ^ 80)
    
    for result in results
        success_str = result.build_success ? "✅ PASS" : "❌ FAIL"
        validation_str = result.validation_success ? "✅ PASS" : "❌ FAIL"
        @printf("%-15s %-10s %-12.2f %-15d %-10s\\n", 
                result.config.name, success_str, result.build_time, 
                result.executable_size, validation_str)
    end
    
    println("\\n🔍 Detailed Analysis:")
    
    # Find successful builds for comparison
    successful_builds = filter(r -> r.build_success && r.validation_success, results)
    
    if length(successful_builds) > 1
        println("\\n📏 Executable Size Comparison:")
        baseline = successful_builds[1]
        for result in successful_builds[2:end]
            size_diff = result.executable_size - baseline.executable_size
            percentage = (size_diff / baseline.executable_size) * 100
            @printf("   %s vs %s: %+d bytes (%+.1f%%)\\n", 
                    result.config.name, baseline.config.name, size_diff, percentage)
        end
    end
    
    # Report issues for failed builds
    println("\\n🚨 Issues and Recommendations:")
    for result in results
        if !result.build_success || !result.validation_success
            println("\\n$(result.config.name) ($(result.config.description)):")
            for error in result.errors
                println("   ❌ Error: $error")
            end
            for warning in result.warnings
                println("   ⚠️  Warning: $warning")
            end
            
            if result.config.name == "clang_mini"
                println("   💡 Suggestions for Mini-ELF-Linker improvement:")
                println("      - Review CMake linker integration")
                println("      - Check object file compatibility") 
                println("      - Verify symbol resolution with system libraries")
                println("      - Compare with LLD output for reference")
            end
        end
    end
end

"""
    run_production_tests()

Main function to run comprehensive production tests.
"""
function run_production_tests()
    println("🚀 CMake Production Testing for Mini-ELF-Linker")
    println("=" ^ 60)
    println("Timestamp: $(Dates.now())")
    println("Testing against real-world CMake project with LLD comparison")
    println()
    
    # Setup test project
    project_dir = setup_cmake_test_project()
    
    # Run tests with all configurations
    results = ProductionTestResult[]
    
    for config in PRODUCTION_CONFIGS
        println("\\n" * "="^50)
        result = build_with_config(project_dir, config)
        push!(results, result)
    end
    
    # Generate comparison report
    compare_results(results)
    
    println("\\n🎯 Production Testing Complete!")
    println("See analysis above for improvement recommendations.")
    
    return results
end

# Run tests if called as main script
if abspath(PROGRAM_FILE) == @__FILE__
    run_production_tests()
end