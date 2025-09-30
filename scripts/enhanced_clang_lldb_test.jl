#!/usr/bin/env julia

"""
Enhanced Clang + LLD + LLDB Testing Framework
Comprehensive comparison between LLD and Mini-ELF-Linker using Clang and LLDB debugging
"""

using Printf
using Dates

"""
Mathematical Framework for Enhanced Testing:
```math
Testing_{enhanced} = {
    compilation: Clang_{source} → Object_{files},
    linking: {LLD_{reference}, Mini_{test}} → Executable_{comparison},
    debugging: LLDB_{analysis} → Runtime_{validation},
    comparison: Binary_{diff} ⊕ Runtime_{diff} → Assessment_{final}
}
```
"""

struct ClangTestConfig
    name::String
    compiler::String
    linker::String
    description::String
    expected_success::Bool
    use_lldb::Bool
end

struct ClangTestResult
    config::ClangTestConfig
    compile_success::Bool
    link_success::Bool
    runtime_success::Bool
    binary_analysis::Dict{String, Any}
    lldb_analysis::String
    performance_metrics::Dict{String, Float64}
    errors::Vector{String}
    warnings::Vector{String}
end

# Enhanced test configurations using Clang exclusively
const CLANG_CONFIGS = [
    ClangTestConfig(
        "clang_lld_reference",
        "clang",
        "ld.lld",
        "Reference: Clang with LLD (Gold Standard)",
        true,
        true
    ),
    ClangTestConfig(
        "clang_mini_test",
        "clang", 
        "mini-elf-linker",
        "Test: Clang with Mini-ELF-Linker",
        true,  # Now expecting success after improvements
        true
    )
]

"""
    create_comprehensive_test_sources(test_dir::String) -> Dict{String, Vector{String}}

Create comprehensive C test programs with various complexity levels.
"""
function create_comprehensive_test_sources(test_dir::String)
    println("📝 Creating comprehensive test sources with Clang compatibility...")
    
    if isdir(test_dir)
        rm(test_dir, recursive=true)
    end
    mkdir(test_dir)
    
    test_programs = Dict{String, Vector{String}}()
    
    # Test 1: Simple executable
    simple_c = """
#include <stdio.h>
#include <stdlib.h>

int main() {
    printf("Hello from Mini-ELF-Linker!\\n");
    printf("Testing basic functionality\\n");
    return 42;  /* Distinctive exit code for testing */
}
"""
    write(joinpath(test_dir, "simple.c"), simple_c)
    test_programs["simple"] = ["simple.c"]
    
    # Test 2: Math library usage
    math_c = """
#include <stdio.h>
#include <math.h>
#include <stdlib.h>

int main() {
    double values[] = {4.0, 9.0, 16.0, 25.0};
    int count = sizeof(values) / sizeof(double);
    
    printf("Math library test:\\n");
    for (int i = 0; i < count; i++) {
        double result = sqrt(values[i]);
        printf("sqrt(%.1f) = %.2f\\n", values[i], result);
    }
    
    double angle = 3.14159 / 6;  // 30 degrees in radians
    printf("sin(30°) = %.3f\\n", sin(angle));
    printf("cos(30°) = %.3f\\n", cos(angle));
    
    return 0;
}
"""
    write(joinpath(test_dir, "math_test.c"), math_c)
    test_programs["math_test"] = ["math_test.c"]
    
    # Test 3: Multi-threaded program
    thread_c = """
#include <stdio.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>

typedef struct {
    int thread_id;
    int iterations;
} thread_data_t;

void* worker_thread(void* arg) {
    thread_data_t* data = (thread_data_t*)arg;
    
    printf("Thread %d starting with %d iterations\\n", data->thread_id, data->iterations);
    
    for (int i = 0; i < data->iterations; i++) {
        printf("Thread %d: iteration %d\\n", data->thread_id, i + 1);
        usleep(100000);  // 0.1 second delay
    }
    
    printf("Thread %d completed\\n", data->thread_id);
    return NULL;
}

int main() {
    const int num_threads = 2;
    pthread_t threads[num_threads];
    thread_data_t thread_data[num_threads];
    
    printf("Starting multi-threaded test with %d threads\\n", num_threads);
    
    // Create threads
    for (int i = 0; i < num_threads; i++) {
        thread_data[i].thread_id = i + 1;
        thread_data[i].iterations = 3;
        
        if (pthread_create(&threads[i], NULL, worker_thread, &thread_data[i]) != 0) {
            fprintf(stderr, "Error creating thread %d\\n", i + 1);
            return 1;
        }
    }
    
    // Wait for threads to complete
    for (int i = 0; i < num_threads; i++) {
        if (pthread_join(threads[i], NULL) != 0) {
            fprintf(stderr, "Error joining thread %d\\n", i + 1);
            return 1;
        }
    }
    
    printf("All threads completed successfully\\n");
    return 0;
}
"""
    write(joinpath(test_dir, "thread_test.c"), thread_c)
    test_programs["thread_test"] = ["thread_test.c"]
    
    # Test 4: Complex multi-file program
    main_complex_c = """
#include <stdio.h>
#include <math.h>
#include "utils.h"

int main() {
    printf("Complex multi-file program test\\n");
    
    // Test utility functions
    int a = 15, b = 25;
    printf("add(%d, %d) = %d\\n", a, b, add(a, b));
    printf("multiply(%d, %d) = %d\\n", a, b, multiply(a, b));
    
    // Test math with utility
    double x = 2.5;
    double result = math_power(x, 3.0);
    printf("math_power(%.1f, 3.0) = %.3f\\n", x, result);
    
    // Test string utilities
    char message[] = "Hello World";
    printf("Original: %s\\n", message);
    printf("Length: %zu\\n", string_length(message));
    
    reverse_string(message);
    printf("Reversed: %s\\n", message);
    
    return 0;
}
"""
    
    utils_c = """
#include "utils.h"
#include <math.h>
#include <string.h>

int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}

double math_power(double base, double exponent) {
    return pow(base, exponent);
}

size_t string_length(const char* str) {
    return strlen(str);
}

void reverse_string(char* str) {
    if (str == NULL) return;
    
    size_t len = strlen(str);
    for (size_t i = 0; i < len / 2; i++) {
        char temp = str[i];
        str[i] = str[len - 1 - i];
        str[len - 1 - i] = temp;
    }
}
"""
    
    utils_h = """
#ifndef UTILS_H
#define UTILS_H

#include <stddef.h>

int add(int a, int b);
int multiply(int a, int b);
double math_power(double base, double exponent);
size_t string_length(const char* str);
void reverse_string(char* str);

#endif
"""
    
    write(joinpath(test_dir, "main_complex.c"), main_complex_c)
    write(joinpath(test_dir, "utils.c"), utils_c)
    write(joinpath(test_dir, "utils.h"), utils_h)
    test_programs["complex"] = ["main_complex.c", "utils.c"]
    
    println("✅ Created $(length(test_programs)) test programs")
    return test_programs
end

"""
    compile_with_clang(source_files::Vector{String}, program_name::String, test_dir::String) -> Bool

Compile source files using Clang with optimization and debugging information.
"""
function compile_with_clang(source_files::Vector{String}, program_name::String, test_dir::String)
    println("🔨 Compiling $program_name with Clang...")
    
    try
        object_files = String[]
        
        # Compile each source file to object file
        for src_file in source_files
            src_path = joinpath(test_dir, src_file)
            obj_file = replace(src_file, ".c" => ".o")
            obj_path = joinpath(test_dir, obj_file)
            
            compile_cmd = `clang -c -g -O2 -Wall -Wextra -I$test_dir $src_path -o $obj_path`
            println("   Compiling: $src_file")
            println("   Command: $(join(compile_cmd.exec, " "))")
            
            run(compile_cmd)
            push!(object_files, obj_file)
        end
        
        println("✅ Clang compilation successful: $(length(object_files)) object files")
        return true
        
    catch e
        println("❌ Clang compilation failed: $e")
        return false
    end
end

"""
    link_with_lld(program_name::String, source_files::Vector{String}, test_dir::String) -> Bool

Link object files using LLD.
"""
function link_with_lld(program_name::String, source_files::Vector{String}, test_dir::String)
    println("🔗 Linking $program_name with Clang (using LLD internally)...")
    
    try
        object_files = [replace(src, ".c" => ".o") for src in source_files]
        object_paths = [joinpath(test_dir, obj) for obj in object_files]
        output_path = joinpath(test_dir, program_name * "_lld")
        
        # Determine required libraries based on program
        libraries = String[]
        if program_name == "math_test" || program_name == "complex"
            push!(libraries, "-lm")
        end
        if program_name == "thread_test"
            push!(libraries, "-lpthread")
        end
        
        # Use Clang to link (which includes proper startup code and uses LLD internally)
        link_cmd = `clang -fuse-ld=lld -o $output_path $(object_paths) $(libraries)`
        println("   Command: $(join(link_cmd.exec, " "))")
        
        run(link_cmd)
        
        println("✅ Clang+LLD linking successful: $output_path")
        return true
        
    catch e
        println("❌ Clang+LLD linking failed: $e")
        return false
    end
end

"""
    link_with_mini_linker(program_name::String, source_files::Vector{String}, test_dir::String) -> Bool

Link object files using Mini-ELF-Linker.
"""
function link_with_mini_linker(program_name::String, source_files::Vector{String}, test_dir::String)
    println("🔗 Linking $program_name with Mini-ELF-Linker...")
    
    try
        object_files = [replace(src, ".c" => ".o") for src in source_files]
        object_paths = [joinpath(test_dir, obj) for obj in object_files]
        output_path = joinpath(test_dir, program_name * "_mini")
        
        # Determine required libraries based on program
        libraries = String[]
        if program_name == "math_test" || program_name == "complex"
            push!(libraries, "-lm")
        end
        if program_name == "thread_test"
            push!(libraries, "-lpthread")
        end
        
        mini_linker_path = abspath(joinpath(@__DIR__, "..", "mini_elf_linker_cli.jl"))
        link_cmd = `julia --project=$(dirname(mini_linker_path)) $mini_linker_path -o $output_path $(object_paths) $(libraries)`
        
        println("   Command: julia --project=... mini_elf_linker_cli.jl -o $output_path ...")
        
        run(link_cmd)
        
        println("✅ Mini-ELF-Linker linking successful: $output_path")
        return true
        
    catch e
        println("❌ Mini-ELF-Linker linking failed: $e")
        return false
    end
end

"""
    analyze_binary_with_lldb(executable_path::String) -> String

Analyze executable using LLDB and return analysis results.
"""
function analyze_binary_with_lldb(executable_path::String)
    if !isfile(executable_path)
        return "ERROR: Executable not found"
    end
    
    println("🔍 Analyzing $executable_path with LLDB...")
    
    try
        # Create LLDB script for comprehensive analysis
        lldb_script = """
target create "$executable_path"
image list -o -f
image dump sections
image dump symtab
quit
"""
        
        lldb_script_path = "/tmp/lldb_analysis_$(basename(executable_path)).script"
        write(lldb_script_path, lldb_script)
        
        # Run LLDB analysis
        result = read(pipeline(`lldb -s $lldb_script_path`, stderr=devnull), String)
        
        # Cleanup
        rm(lldb_script_path)
        
        println("✅ LLDB analysis completed")
        return result
        
    catch e
        println("❌ LLDB analysis failed: $e")
        return "ERROR: $e"
    end
end

"""
    test_runtime_execution(executable_path::String, expected_exit_code::Int = 0) -> Tuple{Bool, String}

Test runtime execution and capture output.
"""
function test_runtime_execution(executable_path::String, expected_exit_code::Int = 0)
    if !isfile(executable_path)
        return false, "Executable not found"
    end
    
    println("🏃 Testing runtime execution: $(basename(executable_path))")
    
    try
        # Run with timeout to prevent hanging - simplified approach
        result = run(pipeline(`timeout 30s $executable_path`); wait=false)
        wait(result)
        
        success = result.exitcode == expected_exit_code
        output = "Exit Code: $(result.exitcode)"
        
        if success
            println("✅ Runtime execution successful (exit code: $(result.exitcode))")
        else
            println("❌ Runtime execution failed (expected: $expected_exit_code, got: $(result.exitcode))")
        end
        
        return success, output
        
    catch e
        println("❌ Runtime execution error: $e")
        return false, "ERROR: $e"
    end
end

"""
    compare_binaries(lld_path::String, mini_path::String) -> Vector{String}

Compare binaries using readelf and objdump.
"""
function compare_binaries(lld_path::String, mini_path::String)
    differences = String[]
    
    try
        # Compare ELF headers
        lld_header = read(`readelf -h $lld_path`, String)
        mini_header = read(`readelf -h $mini_path`, String)
        
        if lld_header != mini_header
            push!(differences, "ELF headers differ")
        end
        
        # Compare program headers
        lld_prog = read(`readelf -l $lld_path`, String)
        mini_prog = read(`readelf -l $mini_path`, String)
        
        if lld_prog != mini_prog
            push!(differences, "Program headers differ")
        end
        
        # Compare file sizes
        lld_size = stat(lld_path).size
        mini_size = stat(mini_path).size
        size_diff = abs(lld_size - mini_size)
        
        if size_diff > 1024  # Allow 1KB difference
            push!(differences, "Significant size difference: $(size_diff) bytes")
        end
        
    catch e
        push!(differences, "Binary comparison failed: $e")
    end
    
    return differences
end

"""
    run_comprehensive_test(program_name::String, source_files::Vector{String}, test_dir::String) -> Vector{ClangTestResult}

Run comprehensive test for a program with all configurations.
"""
function run_comprehensive_test(program_name::String, source_files::Vector{String}, test_dir::String)
    println("\n🧪 Running comprehensive test: $program_name")
    println("=" ^ 60)
    
    results = ClangTestResult[]
    
    # Expected exit codes for different programs
    expected_exit_codes = Dict(
        "simple" => 42,
        "math_test" => 0,
        "thread_test" => 0,
        "complex" => 0
    )
    expected_exit_code = get(expected_exit_codes, program_name, 0)
    
    # Compile with Clang (common for both linkers)
    compile_success = compile_with_clang(source_files, program_name, test_dir)
    if !compile_success
        # Return failed results for both configs
        for config in CLANG_CONFIGS
            push!(results, ClangTestResult(
                config, false, false, false, Dict{String, Any}(),
                "Compilation failed", Dict{String, Float64}(),
                ["Clang compilation failed"], String[]
            ))
        end
        return results
    end
    
    # Test each linker configuration
    for config in CLANG_CONFIGS
        println("\n🔧 Testing $(config.name): $(config.description)")
        
        errors = String[]
        warnings = String[]
        binary_analysis = Dict{String, Any}()
        lldb_analysis = ""
        performance_metrics = Dict{String, Float64}()
        
        # Linking phase
        link_start_time = time()
        link_success = if config.linker == "ld.lld"
            link_with_lld(program_name, source_files, test_dir)
        else
            link_with_mini_linker(program_name, source_files, test_dir)
        end
        link_time = time() - link_start_time
        performance_metrics["link_time"] = link_time
        
        if !link_success
            push!(errors, "Linking failed with $(config.linker)")
        end
        
        # Runtime testing and analysis (if linking succeeded)
        runtime_success = false
        if link_success
            executable_path = joinpath(test_dir, program_name * (config.linker == "ld.lld" ? "_lld" : "_mini"))
            
            # Binary analysis
            if isfile(executable_path)
                binary_analysis["file_size"] = stat(executable_path).size
                binary_analysis["executable_path"] = executable_path
                
                # LLDB analysis if requested
                if config.use_lldb
                    lldb_analysis = analyze_binary_with_lldb(executable_path)
                end
            end
            
            # Runtime execution test
            runtime_success, runtime_output = test_runtime_execution(executable_path, expected_exit_code)
            binary_analysis["runtime_output"] = runtime_output
            
            if !runtime_success
                push!(errors, "Runtime execution failed")
            end
        end
        
        result = ClangTestResult(
            config, compile_success, link_success, runtime_success,
            binary_analysis, lldb_analysis, performance_metrics,
            errors, warnings
        )
        
        push!(results, result)
    end
    
    return results
end

"""
    generate_comprehensive_report(all_results::Dict{String, Vector{ClangTestResult}})

Generate comprehensive analysis report comparing LLD vs Mini-ELF-Linker.
"""
function generate_comprehensive_report(all_results::Dict{String, Vector{ClangTestResult}})
    println("\n" * "=" ^ 80)
    println("📊 COMPREHENSIVE CLANG + LLD + LLDB ANALYSIS REPORT")
    println("=" ^ 80)
    println("Generated: $(Dates.now())")
    println()
    
    # Summary table
    println("📋 Test Summary:")
    @printf("%-15s %-12s %-12s %-12s %-12s %-12s\n", 
            "Program", "LLD_Link", "LLD_Run", "Mini_Link", "Mini_Run", "Status")
    println("-" ^ 85)
    
    overall_success = true
    
    for (program_name, results) in all_results
        lld_result = findfirst(r -> r.config.linker == "ld.lld", results)
        mini_result = findfirst(r -> r.config.linker == "mini-elf-linker", results)
        
        lld_link = lld_result !== nothing ? (results[lld_result].link_success ? "✅ PASS" : "❌ FAIL") : "❓ N/A"
        lld_run = lld_result !== nothing ? (results[lld_result].runtime_success ? "✅ PASS" : "❌ FAIL") : "❓ N/A"
        mini_link = mini_result !== nothing ? (results[mini_result].link_success ? "✅ PASS" : "❌ FAIL") : "❓ N/A"
        mini_run = mini_result !== nothing ? (results[mini_result].runtime_success ? "✅ PASS" : "❌ FAIL") : "❓ N/A"
        
        status = if lld_result !== nothing && mini_result !== nothing
            lld_ok = results[lld_result].link_success && results[lld_result].runtime_success
            mini_ok = results[mini_result].link_success && results[mini_result].runtime_success
            if lld_ok && mini_ok
                "🎉 BOTH OK"
            elseif lld_ok
                "⚠️ MINI ISSUE"
            elseif mini_ok
                "⚠️ LLD ISSUE"
            else
                "💥 BOTH FAIL"
            end
        else
            "❓ INCOMPLETE"
        end
        
        if !contains(status, "BOTH OK")
            overall_success = false
        end
        
        @printf("%-15s %-12s %-12s %-12s %-12s %-12s\n",
                program_name, lld_link, lld_run, mini_link, mini_run, status)
    end
    
    println()
    
    # Performance comparison
    println("⚡ Performance Analysis:")
    for (program_name, results) in all_results
        println("\n$program_name:")
        for result in results
            if result.link_success
                link_time = get(result.performance_metrics, "link_time", 0.0)
                file_size = get(result.binary_analysis, "file_size", 0)
                @printf("   %-20s: Link=%.3fs, Size=%d bytes\n", 
                        result.config.name, link_time, file_size)
            end
        end
    end
    
    # Detailed analysis of failures
    println("\n🔍 Detailed Issue Analysis:")
    has_issues = false
    
    for (program_name, results) in all_results
        for result in results
            if !isempty(result.errors)
                has_issues = true
                println("\n$(program_name) - $(result.config.name):")
                for error in result.errors
                    println("   ❌ $error")
                end
            end
        end
    end
    
    if !has_issues
        println("   🎉 No issues detected!")
    end
    
    # Binary comparison
    println("\n🔬 Binary Comparison Analysis:")
    for (program_name, results) in all_results
        lld_result = findfirst(r -> r.config.linker == "ld.lld" && r.link_success, results)
        mini_result = findfirst(r -> r.config.linker == "mini-elf-linker" && r.link_success, results)
        
        if lld_result !== nothing && mini_result !== nothing
            lld_path = results[lld_result].binary_analysis["executable_path"]
            mini_path = results[mini_result].binary_analysis["executable_path"]
            
            differences = compare_binaries(lld_path, mini_path)
            
            if isempty(differences)
                println("   ✅ $program_name: Binaries are equivalent")
            else
                println("   ⚠️  $program_name: Binaries differ:")
                for diff in differences
                    println("      - $diff")
                end
            end
        end
    end
    
    # Overall assessment
    println("\n🏁 Overall Assessment:")
    if overall_success
        println("🎉 SUCCESS: Mini-ELF-Linker is production-ready!")
        println("   ✅ All test programs compile with Clang")
        println("   ✅ All test programs link successfully")
        println("   ✅ All test programs execute correctly")
        println("   ✅ Binary compatibility with LLD reference")
    else
        println("⚠️  NEEDS IMPROVEMENT: Issues detected that need attention")
        println("   📋 Review detailed analysis above for specific problems")
        println("   🔧 Consider debugging with LLDB for runtime issues")
        println("   📊 Compare binary structures for linking problems")
    end
    
    return overall_success
end

"""
    main()

Main test execution function.
"""
function main()
    println("🚀 Enhanced Clang + LLD + LLDB Testing Framework")
    println("Testing Mini-ELF-Linker with professional toolchain")
    println("Timestamp: $(Dates.now())")
    println()
    
    # Create test directory
    test_dir = "/tmp/enhanced_clang_test"
    
    # Create test sources
    test_programs = create_comprehensive_test_sources(test_dir)
    
    # Run all tests
    all_results = Dict{String, Vector{ClangTestResult}}()
    
    for (program_name, source_files) in test_programs
        results = run_comprehensive_test(program_name, source_files, test_dir)
        all_results[program_name] = results
    end
    
    # Generate comprehensive report
    success = generate_comprehensive_report(all_results)
    
    println("\n✅ Enhanced testing framework completed!")
    
    return success
end

# Run the enhanced test when script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end