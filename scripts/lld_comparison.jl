#!/usr/bin/env julia
"""
LLD Comparison and Binary Analysis Framework
Direct comparison between LLD and Mini-ELF-Linker outputs
"""

using Printf
using Dates

"""
Mathematical Framework for Binary Comparison:
```math
Comparison_{binary} = {
    structure: S_{lld} ⊕ S_{mini},
    symbols: Σ_{lld} ⊕ Σ_{mini}, 
    relocations: R_{lld} ⊕ R_{mini},
    runtime: β_{lld} ⊕ β_{mini}
}
```

Where ⊕ represents symmetric difference analysis.
"""

struct BinaryAnalysis
    filename::String
    file_size::Int64
    entry_point::UInt64
    sections::Vector{String}
    symbols::Vector{String}
    dynamic_symbols::Vector{String}
    relocations::Vector{String}
    libraries::Vector{String}
    program_headers::Vector{String}
    readelf_output::String
    objdump_output::String
end

struct ComparisonResult
    test_name::String
    lld_analysis::Union{BinaryAnalysis, Nothing}
    mini_analysis::Union{BinaryAnalysis, Nothing}
    lld_success::Bool
    mini_success::Bool
    differences::Vector{String}
    recommendations::Vector{String}
end

"""
    create_test_sources(test_dir::String)

Create various test source files for comprehensive comparison.
"""
function create_test_sources(test_dir::String)
    println("📝 Creating test source files in: $test_dir")
    
    if isdir(test_dir)
        rm(test_dir, recursive=true)
    end
    mkdir(test_dir)
    
    # Test 1: Simple program with external library call
    simple_c = """
#include <stdio.h>
#include <math.h>

int main() {
    double x = 4.0;
    printf("sqrt(%.1f) = %.2f\\n", x, sqrt(x));
    return 0;
}
"""
    
    # Test 2: Multiple object files with internal linkage
    main_c = """
#include <stdio.h>
extern int add(int a, int b);
extern int multiply(int a, int b);

int main() {
    int x = 10, y = 20;
    printf("add(%d, %d) = %d\\n", x, y, add(x, y));
    printf("multiply(%d, %d) = %d\\n", x, y, multiply(x, y));
    return 0;
}
"""
    
    math_c = """
int add(int a, int b) {
    return a + b;
}

int multiply(int a, int b) {
    return a * b;
}
"""
    
    # Test 3: Program with global variables and BSS
    globals_c = """
#include <stdio.h>

int initialized_global = 42;
int uninitialized_global;
static int static_global = 100;

void print_globals() {
    printf("initialized_global = %d\\n", initialized_global);
    printf("uninitialized_global = %d\\n", uninitialized_global);  
    printf("static_global = %d\\n", static_global);
}

int main() {
    uninitialized_global = 99;
    print_globals();
    return 0;
}
"""
    
    # Test 4: Program with dynamic allocation and multiple library calls
    dynamic_c = """
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int main() {
    // Test dynamic allocation
    char* buffer = malloc(100);
    if (!buffer) return 1;
    
    strcpy(buffer, "Hello, Dynamic!");
    printf("Buffer: %s (length: %zu)\\n", buffer, strlen(buffer));
    
    // Test math library
    double values[] = {1.0, 4.0, 9.0, 16.0};
    int count = sizeof(values) / sizeof(values[0]);
    
    printf("Square roots:\\n");
    for (int i = 0; i < count; i++) {
        printf("  sqrt(%.1f) = %.3f\\n", values[i], sqrt(values[i]));
    }
    
    free(buffer);
    return 0;
}
"""
    
    # Write test files
    write(joinpath(test_dir, "simple.c"), simple_c)
    write(joinpath(test_dir, "main.c"), main_c)
    write(joinpath(test_dir, "math.c"), math_c)
    write(joinpath(test_dir, "globals.c"), globals_c)
    write(joinpath(test_dir, "dynamic.c"), dynamic_c)
    
    println("✅ Test sources created")
    return test_dir
end

"""
    compile_with_clang(source_files::Vector{String}, output::String, test_dir::String) -> Bool

Compile source files to object files using Clang.
"""
function compile_with_clang(source_files::Vector{String}, output::String, test_dir::String)
    println("🔨 Compiling sources with Clang...")
    
    try
        for source in source_files
            source_path = joinpath(test_dir, source)
            object_path = joinpath(test_dir, replace(source, ".c" => ".o"))
            
            # Compile to object file
            cmd = `clang -c -o $object_path $source_path`
            println("   $(join(cmd.exec, " "))")
            run(cmd)
        end
        
        println("✅ Compilation successful")
        return true
    catch e
        println("❌ Compilation failed: $e")
        return false
    end
end

"""
    link_with_lld(object_files::Vector{String}, output::String, test_dir::String) -> Bool

Link object files using LLD.
"""
function link_with_lld(object_files::Vector{String}, output::String, test_dir::String)
    println("🔗 Linking with LLD...")
    
    try
        object_paths = [joinpath(test_dir, obj) for obj in object_files]
        output_path = joinpath(test_dir, output * "_lld")
        
        # Link with LLD
        cmd = `ld.lld -o $output_path $(object_paths) -lc -lm --dynamic-linker /lib64/ld-linux-x86-64.so.2`
        println("   $(join(cmd.exec, " "))")
        run(cmd)
        
        println("✅ LLD linking successful: $output_path")
        return true
    catch e
        println("❌ LLD linking failed: $e")
        return false
    end
end

"""
    link_with_mini_linker(object_files::Vector{String}, output::String, test_dir::String) -> Bool

Link object files using Mini-ELF-Linker.
"""
function link_with_mini_linker(object_files::Vector{String}, output::String, test_dir::String)
    println("🔗 Linking with Mini-ELF-Linker...")
    
    try
        object_paths = [joinpath(test_dir, obj) for obj in object_files]
        output_path = joinpath(test_dir, output * "_mini")
        
        # Link with Mini-ELF-Linker
        linker_path = abspath(joinpath(@__DIR__, "..", "bin", "mini-elf-linker"))
        cmd = `julia --project=. $linker_path -o $output_path $(object_paths) -lm -v`
        println("   $(join(cmd.exec, " "))")
        
        # Change to project directory for proper module loading
        project_dir = abspath(joinpath(@__DIR__, ".."))
        cd(project_dir) do
            run(cmd)
        end
        
        println("✅ Mini-ELF-Linker linking successful: $output_path")
        return true
    catch e
        println("❌ Mini-ELF-Linker linking failed: $e")
        return false
    end
end

"""
    analyze_binary(binary_path::String) -> BinaryAnalysis

Perform comprehensive binary analysis using standard tools.
"""
function analyze_binary(binary_path::String)
    println("🔍 Analyzing binary: $(basename(binary_path))")
    
    if !isfile(binary_path)
        println("❌ Binary not found: $binary_path")
        return BinaryAnalysis("", 0, 0, String[], String[], String[], String[], String[], String[], "", "")
    end
    
    file_size = filesize(binary_path)
    
    # Get readelf output
    readelf_output = ""
    try
        readelf_output = read(`readelf -a $binary_path`, String)
    catch e
        println("   ⚠️  readelf failed: $e")
    end
    
    # Get objdump output  
    objdump_output = ""
    try
        objdump_output = read(`objdump -x $binary_path`, String)
    catch e
        println("   ⚠️  objdump failed: $e")
    end
    
    # Parse entry point
    entry_point = 0x0
    entry_match = match(r"Entry point address:\s+0x([0-9a-fA-F]+)", readelf_output)
    if entry_match !== nothing
        entry_point = parse(UInt64, entry_match.captures[1], base=16)
    end
    
    # Parse sections
    sections = String[]
    for line in split(readelf_output, '\n')
        section_match = match(r"\[\s*\d+\]\s+([\w\.]+)", line)
        if section_match !== nothing
            push!(sections, section_match.captures[1])
        end
    end
    
    # Parse symbols
    symbols = String[]
    in_symtab = false
    for line in split(readelf_output, '\n')
        if contains(line, "Symbol table '.symtab'")
            in_symtab = true
            continue
        elseif contains(line, "Symbol table") && in_symtab
            break
        elseif in_symtab && contains(line, ":")
            parts = split(line)
            if length(parts) >= 8
                push!(symbols, parts[end])
            end
        end
    end
    
    # Parse dynamic symbols
    dynamic_symbols = String[]
    in_dynsym = false
    for line in split(readelf_output, '\n')
        if contains(line, "Symbol table '.dynsym'")
            in_dynsym = true
            continue
        elseif contains(line, "Symbol table") && in_dynsym
            break
        elseif in_dynsym && contains(line, ":")
            parts = split(line)
            if length(parts) >= 8
                push!(dynamic_symbols, parts[end])
            end
        end
    end
    
    # Parse relocations
    relocations = String[]
    for line in split(readelf_output, '\n')
        if contains(line, "R_X86_64_")
            reloc_match = match(r"(R_X86_64_\w+)", line)
            if reloc_match !== nothing
                push!(relocations, reloc_match.captures[1])
            end
        end
    end
    
    # Parse dynamic libraries
    libraries = String[]
    for line in split(readelf_output, '\n')
        lib_match = match(r"Shared library: \[([^\]]+)\]", line)
        if lib_match !== nothing
            push!(libraries, lib_match.captures[1])
        end
    end
    
    # Parse program headers
    program_headers = String[]
    in_pheaders = false
    for line in split(readelf_output, '\n')
        if contains(line, "Program Headers:")
            in_pheaders = true
            continue
        elseif in_pheaders && startswith(line, "  ")
            parts = split(strip(line))
            if !isempty(parts)
                push!(program_headers, parts[1])
            end
        elseif in_pheaders && isempty(strip(line))
            break
        end
    end
    
    return BinaryAnalysis(
        basename(binary_path), file_size, entry_point, sections, symbols, 
        dynamic_symbols, unique(relocations), libraries, unique(program_headers),
        readelf_output, objdump_output
    )
end

"""
    compare_binaries(lld_analysis::BinaryAnalysis, mini_analysis::BinaryAnalysis) -> Vector{String}

Compare two binary analyses and identify differences.
"""
function compare_binaries(lld_analysis::BinaryAnalysis, mini_analysis::BinaryAnalysis)
    differences = String[]
    
    # File size comparison
    size_diff = mini_analysis.file_size - lld_analysis.file_size
    if size_diff != 0
        percentage = (abs(size_diff) / lld_analysis.file_size) * 100
        push!(differences, @sprintf("File size: LLD=%d bytes, Mini=%d bytes (diff: %+d, %.1f%%)", 
                                  lld_analysis.file_size, mini_analysis.file_size, size_diff, percentage))
    end
    
    # Entry point comparison
    if lld_analysis.entry_point != mini_analysis.entry_point
        push!(differences, @sprintf("Entry point: LLD=0x%x, Mini=0x%x", 
                                  lld_analysis.entry_point, mini_analysis.entry_point))
    end
    
    # Section comparison
    lld_sections = Set(lld_analysis.sections)
    mini_sections = Set(mini_analysis.sections)
    missing_sections = setdiff(lld_sections, mini_sections)
    extra_sections = setdiff(mini_sections, lld_sections)
    
    if !isempty(missing_sections)
        push!(differences, "Missing sections in Mini: $(join(missing_sections, ", "))")
    end
    if !isempty(extra_sections)
        push!(differences, "Extra sections in Mini: $(join(extra_sections, ", "))")
    end
    
    # Program headers comparison
    lld_pheaders = Set(lld_analysis.program_headers)
    mini_pheaders = Set(mini_analysis.program_headers)
    missing_pheaders = setdiff(lld_pheaders, mini_pheaders)
    extra_pheaders = setdiff(mini_pheaders, lld_pheaders)
    
    if !isempty(missing_pheaders)
        push!(differences, "Missing program headers in Mini: $(join(missing_pheaders, ", "))")
    end
    if !isempty(extra_pheaders)
        push!(differences, "Extra program headers in Mini: $(join(extra_pheaders, ", "))")
    end
    
    # Dynamic libraries comparison
    lld_libs = Set(lld_analysis.libraries)
    mini_libs = Set(mini_analysis.libraries)
    missing_libs = setdiff(lld_libs, mini_libs)
    extra_libs = setdiff(mini_libs, lld_libs)
    
    if !isempty(missing_libs)
        push!(differences, "Missing libraries in Mini: $(join(missing_libs, ", "))")
    end
    if !isempty(extra_libs)
        push!(differences, "Extra libraries in Mini: $(join(extra_libs, ", "))")
    end
    
    # Relocation types comparison
    lld_relocs = Set(lld_analysis.relocations)
    mini_relocs = Set(mini_analysis.relocations)
    missing_relocs = setdiff(lld_relocs, mini_relocs)
    extra_relocs = setdiff(mini_relocs, lld_relocs)
    
    if !isempty(missing_relocs)
        push!(differences, "Missing relocation types in Mini: $(join(missing_relocs, ", "))")
    end
    if !isempty(extra_relocs)
        push!(differences, "Extra relocation types in Mini: $(join(extra_relocs, ", "))")
    end
    
    return differences
end

"""
    generate_recommendations(differences::Vector{String}) -> Vector{String}

Generate improvement recommendations based on differences found.
"""
function generate_recommendations(differences::Vector{String})
    recommendations = String[]
    
    for diff in differences
        if contains(diff, "Missing sections")
            if contains(diff, ".eh_frame_hdr")
                push!(recommendations, "Add exception handling frame header support")
            elseif contains(diff, ".gnu.hash")
                push!(recommendations, "Implement GNU hash table for faster symbol lookup")
            elseif contains(diff, ".init") || contains(diff, ".fini")
                push!(recommendations, "Add constructor/destructor section support")
            end
        elseif contains(diff, "Missing program headers")
            if contains(diff, "GNU_EH_FRAME")
                push!(recommendations, "Add GNU exception handling frame program header")
            elseif contains(diff, "GNU_STACK")
                push!(recommendations, "Add GNU stack permissions program header")
            elseif contains(diff, "GNU_RELRO")
                push!(recommendations, "Implement read-only after relocation support")
            end
        elseif contains(diff, "Entry point")
            push!(recommendations, "Review entry point calculation and _start symbol handling")
        elseif contains(diff, "File size") && contains(diff, "+")
            push!(recommendations, "Optimize executable size - review padding and alignment")
        elseif contains(diff, "Missing relocation types")
            push!(recommendations, "Implement missing relocation type handlers")
        end
    end
    
    return recommendations
end

"""
    run_comparison_test(test_name::String, source_files::Vector{String}, object_files::Vector{String}, test_dir::String) -> ComparisonResult

Run a complete comparison test for a specific configuration.
"""
function run_comparison_test(test_name::String, source_files::Vector{String}, object_files::Vector{String}, test_dir::String)
    println("\\n🧪 Running comparison test: $test_name")
    println("=" ^ 40)
    
    # Compile sources
    compile_success = compile_with_clang(source_files, test_name, test_dir)
    if !compile_success
        return ComparisonResult(test_name, nothing, nothing, false, false, 
                              ["Compilation failed"], String[])
    end
    
    # Link with LLD
    lld_success = link_with_lld(object_files, test_name, test_dir)
    lld_analysis = nothing
    if lld_success
        lld_path = joinpath(test_dir, test_name * "_lld")
        lld_analysis = analyze_binary(lld_path)
    end
    
    # Link with Mini-ELF-Linker
    mini_success = link_with_mini_linker(object_files, test_name, test_dir)
    mini_analysis = nothing
    if mini_success
        mini_path = joinpath(test_dir, test_name * "_mini")
        mini_analysis = analyze_binary(mini_path)
    end
    
    # Compare results
    differences = String[]
    recommendations = String[]
    
    if lld_success && mini_success && lld_analysis !== nothing && mini_analysis !== nothing
        differences = compare_binaries(lld_analysis, mini_analysis)
        recommendations = generate_recommendations(differences)
        
        # Test execution
        println("\\n🏃 Testing execution...")
        try
            lld_output = read(`$(joinpath(test_dir, test_name * "_lld"))`, String)
            println("   ✅ LLD executable runs successfully")
            
            try
                mini_output = read(`$(joinpath(test_dir, test_name * "_mini"))`, String)
                println("   ✅ Mini executable runs successfully")
                
                if lld_output == mini_output
                    println("   ✅ Outputs match exactly!")
                else
                    push!(differences, "Runtime output differs between LLD and Mini")
                    println("   ⚠️  Runtime outputs differ")
                end
            catch e
                push!(differences, "Mini executable failed to run: $e")
                println("   ❌ Mini executable failed: $e")
            end
        catch e
            push!(differences, "LLD executable failed to run: $e")
            println("   ❌ LLD executable failed: $e")
        end
    end
    
    return ComparisonResult(test_name, lld_analysis, mini_analysis, lld_success, 
                          mini_success, differences, recommendations)
end

"""
    run_lld_comparison_suite()

Run comprehensive LLD comparison tests.
"""
function run_lld_comparison_suite()
    println("🔍 LLD vs Mini-ELF-Linker Comparison Suite")
    println("=" ^ 50)
    println("Timestamp: $(Dates.now())")
    println()
    
    # Setup test directory
    test_dir = "/tmp/lld_comparison_tests"
    create_test_sources(test_dir)
    
    # Define test cases
    test_cases = [
        ("simple", ["simple.c"], ["simple.o"]),
        ("multiobj", ["main.c", "math.c"], ["main.o", "math.o"]),
        ("globals", ["globals.c"], ["globals.o"]),
        ("dynamic", ["dynamic.c"], ["dynamic.o"])
    ]
    
    # Run all tests
    results = ComparisonResult[]
    for (name, sources, objects) in test_cases
        result = run_comparison_test(name, sources, objects, test_dir)
        push!(results, result)
    end
    
    # Generate summary report
    println("\\n📊 Comparison Summary Report")
    println("=" ^ 35)
    
    @printf("%-12s %-8s %-8s %-15s %-10s\\n", "Test", "LLD", "Mini", "Issues", "Runtime")
    println("-" ^ 60)
    
    for result in results
        lld_status = result.lld_success ? "✅" : "❌"
        mini_status = result.mini_success ? "✅" : "❌"
        issue_count = length(result.differences)
        runtime_status = if result.lld_success && result.mini_success
            any(contains(d, "Runtime output") for d in result.differences) ? "❌" : "✅"
        else
            "N/A"
        end
        
        @printf("%-12s %-8s %-8s %-15d %-10s\\n", 
                result.test_name, lld_status, mini_status, issue_count, runtime_status)
    end
    
    # Detailed analysis
    println("\\n🔍 Detailed Analysis")
    println("=" ^ 25)
    
    all_differences = String[]
    all_recommendations = String[]
    
    for result in results
        if !isempty(result.differences)
            println("\\n$(result.test_name) Issues:")
            for diff in result.differences
                println("   ❌ $diff")
                push!(all_differences, diff)
            end
        end
        
        if !isempty(result.recommendations)
            println("\\n$(result.test_name) Recommendations:")
            for rec in result.recommendations
                println("   💡 $rec")
                push!(all_recommendations, rec)
            end
        end
    end
    
    # Overall recommendations
    println("\\n🎯 Priority Improvements for LLD Compatibility")
    println("=" ^ 50)
    
    unique_recommendations = unique(all_recommendations)
    for (i, rec) in enumerate(unique_recommendations)
        println("   $i. $rec")
    end
    
    println("\\n✅ LLD comparison analysis complete!")
    return results
end

# Run comparison if called as main script
if abspath(PROGRAM_FILE) == @__FILE__
    run_lld_comparison_suite()
end