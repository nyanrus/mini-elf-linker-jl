#!/usr/bin/env julia

"""
Facebook ZSTD Production Testing with Mini-ELF-Linker
Comprehensive test to verify production readiness with a real-world complex project
"""

using Printf
using Dates

"""
Mathematical Framework for ZSTD Production Testing:
```math
Production_{zstd} = ∏_{phase ∈ {setup, compile, link, validate}} Success_{phase}
```

Where each phase follows:
```math
Phase_i = {
    input: I_i,
    process: P_i,
    output: O_i,
    validation: V_i
}
```
"""

struct ZSTDTestConfig
    name::String
    compiler::String
    linker::String
    description::String
    expected_success::Bool
end

struct ZSTDTestResult
    config::ZSTDTestConfig
    setup_success::Bool
    compile_success::Bool
    link_success::Bool
    validation_success::Bool
    build_time::Float64
    binary_size::Int64
    errors::Vector{String}
    warnings::Vector{String}
    output_path::String
end

# Test configurations for comprehensive comparison
const ZSTD_CONFIGS = [
    ZSTDTestConfig(
        "gcc_ld",
        "gcc",
        "ld",
        "Baseline: GCC with GNU ld",
        true
    ),
    ZSTDTestConfig(
        "clang_lld", 
        "clang",
        "ld.lld",
        "Reference: Clang with LLD",
        true
    ),
    ZSTDTestConfig(
        "clang_mini",
        "clang", 
        "mini-elf-linker",
        "Test: Clang with Mini-ELF-Linker",
        false  # Expected to need improvements
    )
]

"""
    setup_zstd_project() -> String

Download and setup ZSTD project for testing.
Returns the project directory path.
"""
function setup_zstd_project()
    zstd_dir = "/tmp/zstd_production_test"
    
    println("📦 Setting up ZSTD project...")
    
    # Clean and setup directory
    if isdir(zstd_dir)
        rm(zstd_dir, recursive=true)
    end
    
    try
        # Clone ZSTD repository
        run(`git clone https://github.com/facebook/zstd.git $zstd_dir --depth 1`)
        println("✅ ZSTD repository cloned successfully")
        
        # Analyze project structure
        analyze_zstd_structure(zstd_dir)
        
        return zstd_dir
        
    catch e
        println("❌ Failed to setup ZSTD project: $e")
        return ""
    end
end

"""
    analyze_zstd_structure(zstd_dir::String)

Analyze ZSTD project structure to understand compilation requirements.
"""
function analyze_zstd_structure(zstd_dir::String)
    println("🔍 Analyzing ZSTD structure...")
    
    # Count source files
    c_files = []
    h_files = []
    
    for (root, dirs, files) in walkdir(joinpath(zstd_dir, "lib"))
        for file in files
            if endswith(file, ".c")
                push!(c_files, joinpath(root, file))
            elseif endswith(file, ".h")
                push!(h_files, joinpath(root, file))
            end
        end
    end
    
    println("   📊 ZSTD Library Analysis:")
    println("      C source files: $(length(c_files))")
    println("      Header files: $(length(h_files))")
    
    # Examine main program
    prog_dir = joinpath(zstd_dir, "programs")
    if isdir(prog_dir)
        prog_files = filter(f -> endswith(f, ".c"), readdir(prog_dir))
        println("      Program files: $(length(prog_files))")
    end
    
    # Check build system
    makefile = joinpath(zstd_dir, "Makefile")
    if isfile(makefile)
        println("   ✅ Makefile found - build system available")
    end
    
    cmake_file = joinpath(zstd_dir, "build", "cmake", "CMakeLists.txt")
    if isfile(cmake_file)
        println("   ✅ CMake build system available")
    end
    
    return c_files, h_files
end

"""
    compile_zstd_objects(zstd_dir::String, config::ZSTDTestConfig) -> Bool

Compile ZSTD source files to object files using specified compiler.
"""
function compile_zstd_objects(zstd_dir::String, config::ZSTDTestConfig)
    println("🔨 Compiling ZSTD objects with $(config.compiler)...")
    
    build_dir = joinpath(zstd_dir, "build_$(config.name)")
    if isdir(build_dir)
        rm(build_dir, recursive=true)
    end
    mkdir(build_dir)
    
    try
        # Find all C source files in lib/ directory
        lib_dir = joinpath(zstd_dir, "lib")
        source_files = String[]
        
        for (root, dirs, files) in walkdir(lib_dir)
            for file in files
                if endswith(file, ".c")
                    push!(source_files, joinpath(root, file))
                end
            end
        end
        
        println("   Found $(length(source_files)) source files to compile")
        
        # Compile each source file to object file
        object_files = String[]
        for src_file in source_files
            # Generate object file name
            rel_path = relpath(src_file, lib_dir)
            obj_name = replace(rel_path, ".c" => ".o", "/" => "_")
            obj_path = joinpath(build_dir, obj_name)
            push!(object_files, obj_path)
            
            # Compile command
            include_flags = ["-I$(joinpath(zstd_dir, \"lib\"))", "-I$(joinpath(zstd_dir, \"lib\", \"common\"))", "-I$(joinpath(zstd_dir, \"lib\", \"compress\"))", "-I$(joinpath(zstd_dir, \"lib\", \"decompress\"))"]
            cmd = `$(config.compiler) -c $src_file -o $obj_path $(include_flags) -O2 -DZSTD_MULTITHREAD`
            
            println("      Compiling: $(basename(src_file))")
            run(cmd)
        end
        
        # Also compile main program
        prog_dir = joinpath(zstd_dir, "programs")
        main_src = joinpath(prog_dir, "zstdcli.c")
        if isfile(main_src)
            main_obj = joinpath(build_dir, "zstdcli.o")
            include_flags = ["-I$(joinpath(zstd_dir, \"lib\"))", "-I$(joinpath(zstd_dir, \"programs\"))"]
            cmd = `$(config.compiler) -c $main_src -o $main_obj $(include_flags) -O2 -DZSTD_MULTITHREAD`
            run(cmd)
            push!(object_files, main_obj)
        end
        
        println("✅ Compilation successful: $(length(object_files)) object files")
        return true
        
    catch e
        println("❌ Compilation failed: $e")
        return false
    end
end

"""
    link_zstd_executable(zstd_dir::String, config::ZSTDTestConfig) -> ZSTDTestResult

Link ZSTD executable using specified linker.
"""
function link_zstd_executable(zstd_dir::String, config::ZSTDTestConfig)
    println("🔗 Linking ZSTD executable with $(config.linker)...")
    
    errors = String[]
    warnings = String[]
    build_success = false
    build_time = 0.0
    binary_size = 0
    output_path = ""
    
    build_dir = joinpath(zstd_dir, "build_$(config.name)")
    output_path = joinpath(build_dir, "zstd_$(config.name)")
    
    start_time = time()
    
    try
        # Find all object files
        object_files = filter(f -> endswith(f, ".o"), readdir(build_dir))
        object_paths = [joinpath(build_dir, obj) for obj in object_files]
        
        println("   Linking $(length(object_files)) object files...")
        
        if config.linker == "mini-elf-linker"
            # Use our mini linker
            mini_linker_path = abspath(joinpath(@__DIR__, "..", "mini_elf_linker_cli.jl"))
            
            # Prepare linker command  
            cmd = `julia --project=$(dirname(mini_linker_path)) $mini_linker_path -o $output_path $(object_paths) -lpthread -lm`
            println("   Command: $(join(cmd.exec, \" \"))")
            run(cmd)
            
        elseif config.linker == "ld.lld"
            # Use LLD
            cmd = `ld.lld -o $output_path $(object_paths) -lc -lm -lpthread --dynamic-linker /lib64/ld-linux-x86-64.so.2`
            run(cmd)
            
        else  # GNU ld
            # Use system linker with gcc
            cmd = `$(config.compiler) -o $output_path $(object_paths) -lpthread -lm`
            run(cmd)
        end
        
        build_time = time() - start_time
        
        if isfile(output_path)
            binary_size = stat(output_path).size
            build_success = true
            println("✅ Linking successful: $(basename(output_path)) ($(binary_size) bytes)")
        else
            push!(errors, "Output file not created")
        end
        
    catch e
        build_time = time() - start_time
        push!(errors, "Linking failed: $e")
        println("❌ Linking failed: $e")
    end
    
    return ZSTDTestResult(
        config, true, true, build_success, false,
        build_time, binary_size, errors, warnings, output_path
    )
end

"""
    validate_zstd_executable(result::ZSTDTestResult) -> ZSTDTestResult

Validate the generated ZSTD executable.
"""
function validate_zstd_executable(result::ZSTDTestResult)
    if !result.link_success || !isfile(result.output_path)
        return ZSTDTestResult(
            result.config, result.setup_success, result.compile_success,
            result.link_success, false, result.build_time, result.binary_size,
            result.errors, result.warnings, result.output_path
        )
    end
    
    println("✅ Validating $(basename(result.output_path))...")
    
    errors = copy(result.errors)
    warnings = copy(result.warnings)
    validation_success = false
    
    try
        # Test 1: Check if executable runs
        version_result = read(`$(result.output_path) --version`, String)
        if contains(version_result, "zstd")
            println("   ✅ Version test passed")
            validation_success = true
        else
            push!(warnings, "Version output unexpected")
        end
        
        # Test 2: Create test file and compress/decompress
        test_dir = dirname(result.output_path)
        test_file = joinpath(test_dir, "test.txt")
        compressed_file = joinpath(test_dir, "test.txt.zst")
        decompressed_file = joinpath(test_dir, "test_out.txt")
        
        # Create test content
        write(test_file, "Hello ZSTD compression test!\n" ^ 100)
        
        # Compress
        run(`$(result.output_path) $test_file -o $compressed_file`)
        
        # Decompress
        run(`$(result.output_path) -d $compressed_file -o $decompressed_file`)
        
        # Verify
        original = read(test_file, String)
        decompressed = read(decompressed_file, String)
        
        if original == decompressed
            println("   ✅ Compression/decompression test passed")
            validation_success = true
        else
            push!(errors, "Compression/decompression verification failed")
            validation_success = false
        end
        
        # Cleanup
        for f in [test_file, compressed_file, decompressed_file]
            isfile(f) && rm(f)
        end
        
    catch e
        push!(errors, "Validation failed: $e")
        validation_success = false
        println("   ❌ Validation failed: $e")
    end
    
    return ZSTDTestResult(
        result.config, result.setup_success, result.compile_success,
        result.link_success, validation_success, result.build_time,
        result.binary_size, errors, warnings, result.output_path
    )
end

"""
    run_zstd_production_tests()

Main function to run comprehensive ZSTD production tests.
"""
function run_zstd_production_tests()
    println("🚀 Facebook ZSTD Production Testing with Mini-ELF-Linker")
    println("=" ^ 70)
    println("Testing production readiness with real-world complex project")
    println("Timestamp: $(Dates.now())")
    println()
    
    # Setup project
    zstd_dir = setup_zstd_project()
    if isempty(zstd_dir)
        println("❌ Failed to setup ZSTD project")
        return
    end
    
    results = ZSTDTestResult[]
    
    # Run tests for each configuration
    for config in ZSTD_CONFIGS
        println("\n🧪 Testing configuration: $(config.name)")
        println("   $(config.description)")
        println("-" ^ 50)
        
        # Compile objects
        compile_success = compile_zstd_objects(zstd_dir, config)
        if !compile_success
            push!(results, ZSTDTestResult(
                config, true, false, false, false, 0.0, 0,
                ["Compilation failed"], String[], ""
            ))
            continue
        end
        
        # Link executable
        result = link_zstd_executable(zstd_dir, config)
        
        # Validate if linking succeeded
        if result.link_success
            result = validate_zstd_executable(result)
        end
        
        push!(results, result)
    end
    
    # Generate comprehensive report
    generate_zstd_report(results)
end

"""
    generate_zstd_report(results::Vector{ZSTDTestResult})

Generate comprehensive report of ZSTD production test results.
"""
function generate_zstd_report(results::Vector{ZSTDTestResult})
    println("\n" * "=" ^ 70)
    println("📊 ZSTD PRODUCTION TEST RESULTS")
    println("=" ^ 70)
    
    # Summary table
    println("\n📋 Summary:")
    @printf("%-15s %-10s %-10s %-10s %-12s %-15s\n", 
            "Config", "Compile", "Link", "Validate", "Time (s)", "Size (bytes)")
    println("-" ^ 75)
    
    for result in results
        compile_str = result.compile_success ? "✅ PASS" : "❌ FAIL"
        link_str = result.link_success ? "✅ PASS" : "❌ FAIL"
        validate_str = result.validation_success ? "✅ PASS" : "❌ FAIL"
        
        @printf("%-15s %-10s %-10s %-10s %-12.2f %-15d\n",
                result.config.name, compile_str, link_str, validate_str,
                result.build_time, result.binary_size)
    end
    
    # Detailed analysis
    println("\n🔍 Detailed Analysis:")
    
    successful_builds = filter(r -> r.link_success && r.validation_success, results)
    
    if length(successful_builds) > 1
        println("\n📏 Performance Comparison:")
        baseline = successful_builds[1]
        for result in successful_builds[2:end]
            time_diff = result.build_time - baseline.build_time
            size_diff = result.binary_size - baseline.binary_size
            time_pct = (time_diff / baseline.build_time) * 100
            size_pct = (size_diff / baseline.binary_size) * 100
            
            @printf("   %s vs %s:\n", result.config.name, baseline.config.name)
            @printf("      Build time: %+.2fs (%+.1f%%)\n", time_diff, time_pct)
            @printf("      Binary size: %+d bytes (%+.1f%%)\n", size_diff, size_pct)
        end
    end
    
    # Issues and recommendations
    println("\n🚨 Issues and Recommendations:")
    
    for result in results
        if !result.compile_success || !result.link_success || !result.validation_success
            println("\n$(result.config.name) ($(result.config.description)):")
            
            for error in result.errors
                println("   ❌ Error: $error")
            end
            
            for warning in result.warnings
                println("   ⚠️  Warning: $warning")
            end
            
            if result.config.name == "clang_mini"
                println("   💡 Mini-ELF-Linker improvement suggestions:")
                println("      - Review ZSTD library symbol requirements")
                println("      - Check pthread and math library integration")
                println("      - Verify complex relocation handling")
                println("      - Compare with LLD for missing features")
                println("      - Test with simplified ZSTD subset first")
            end
        end
    end
    
    # Production readiness assessment
    println("\n🏁 Production Readiness Assessment:")
    
    mini_result = findfirst(r -> r.config.name == "clang_mini", results)
    if mini_result !== nothing
        result = results[mini_result]
        if result.validation_success
            println("   ✅ PRODUCTION READY: Mini-ELF-Linker successfully built and validated ZSTD!")
            println("      - Complex real-world project compilation: SUCCESS")
            println("      - Multi-threaded library support: SUCCESS")
            println("      - Functional validation: SUCCESS")
        else
            println("   ⚠️  PARTIALLY READY: Mini-ELF-Linker needs improvements for ZSTD")
            println("      - Compilation phase: $(result.compile_success ? "SUCCESS" : "NEEDS WORK")")
            println("      - Linking phase: $(result.link_success ? "SUCCESS" : "NEEDS WORK")")
            println("      - Validation phase: $(result.validation_success ? "SUCCESS" : "NEEDS WORK")")
            
            println("\n   📋 Next Steps:")
            println("      1. Address specific linking errors identified above")
            println("      2. Enhance library dependency resolution")
            println("      3. Improve symbol table handling for complex projects")
            println("      4. Test with incremental ZSTD components")
        end
    end
end

# Run the tests when script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_zstd_production_tests()
end