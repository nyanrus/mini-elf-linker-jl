#!/usr/bin/env julia --project=.

"""
Final Production Validation for Mini ELF Linker
Comprehensive demonstration of production-ready capabilities
"""

push!(LOAD_PATH, joinpath(dirname(@__FILE__), "src"))
using MiniElfLinker

function validate_production_capabilities()
    println("🎯 FINAL PRODUCTION VALIDATION: Mini ELF Linker")
    println("=" ^ 60)
    
    results = Dict{String, Bool}()
    
    # Test 1: Simple executable linking
    println("\n📋 Test 1: Simple Executable Linking")
    try
        write("simple.c", "int main() { return 0; }")
        run(`gcc -c simple.c -o simple.o`)
        
        success = MiniElfLinker.link_to_executable(
            ["simple.o"], "simple_test"; 
            base_address=UInt64(0x400000), 
            enable_system_libraries=false
        )
        
        if success && isfile("simple_test")
            println("   ✅ Simple executable linking: PASSED")
            results["simple_linking"] = true
        else
            println("   ❌ Simple executable linking: FAILED")
            results["simple_linking"] = false
        end
    catch e
        println("   ❌ Simple executable linking: FAILED ($e)")
        results["simple_linking"] = false
    end
    
    # Test 2: Multi-object linking
    println("\n📋 Test 2: Multi-Object Linking")
    try
        write("main.c", """
        extern int helper();
        int main() { return helper(); }
        """)
        write("helper.c", "int helper() { return 42; }")
        
        run(`gcc -c main.c -o main.o`)
        run(`gcc -c helper.c -o helper.o`)
        
        success = MiniElfLinker.link_to_executable(
            ["main.o", "helper.o"], "multi_test";
            base_address=UInt64(0x400000), 
            enable_system_libraries=false
        )
        
        if success && isfile("multi_test")
            println("   ✅ Multi-object linking: PASSED")
            results["multi_object"] = true
        else
            println("   ❌ Multi-object linking: FAILED")
            results["multi_object"] = false
        end
    catch e
        println("   ❌ Multi-object linking: FAILED ($e)")
        results["multi_object"] = false
    end
    
    # Test 3: Static library linking (using existing TinyCC)
    println("\n📋 Test 3: Static Library Archive Linking")
    try
        if isfile("tinycc/libtcc.a") && isfile("tinycc/tcc.o")
            cd("tinycc") do
                success = MiniElfLinker.link_to_executable(
                    ["tcc.o", "libtcc.a"], "tcc_validation";
                    base_address=UInt64(0x400000)
                )
                
                if success && isfile("tcc_validation")
                    filesize = stat("tcc_validation").size
                    println("   ✅ Static library linking: PASSED ($(round(filesize/1024/1024, digits=1))MB)")
                    results["static_library"] = true
                else
                    println("   ❌ Static library linking: FAILED")
                    results["static_library"] = false
                end
            end
        else
            println("   ⚠️  Static library linking: SKIPPED (TinyCC not available)")
            results["static_library"] = false
        end
    catch e
        println("   ❌ Static library linking: FAILED ($e)")
        results["static_library"] = false
    end
    
    # Test 4: CLI Interface Validation
    println("\n📋 Test 4: CLI Interface Validation")
    try
        # Test help command
        help_result = read(`julia --project=. bin/mini-elf-linker --help`, String)
        
        if occursin("Mini ELF Linker", help_result) && occursin("LLD Compatible", help_result)
            println("   ✅ CLI help interface: PASSED")
            results["cli_help"] = true
        else
            println("   ❌ CLI help interface: FAILED")
            results["cli_help"] = false
        end
        
        # Test version command  
        version_result = read(`julia --project=. bin/mini-elf-linker --version`, String)
        
        if occursin("Mini ELF Linker", version_result)
            println("   ✅ CLI version interface: PASSED")
            results["cli_version"] = true
        else
            println("   ❌ CLI version interface: FAILED")
            results["cli_version"] = false
        end
    catch e
        println("   ❌ CLI interface validation: FAILED ($e)")
        results["cli_help"] = false  
        results["cli_version"] = false
    end
    
    # Test 5: ELF Structure Validation
    println("\n📋 Test 5: ELF Structure Validation")
    try
        if isfile("simple_test")
            # Check ELF header
            elf_info = read(`readelf -h simple_test`, String)
            
            has_elf_magic = occursin("ELF", elf_info)
            has_x86_64 = occursin("x86-64", elf_info) || occursin("X86-64", elf_info)
            has_entry_point = occursin("Entry point", elf_info)
            
            if has_elf_magic && has_x86_64 && has_entry_point
                println("   ✅ ELF structure validation: PASSED")
                results["elf_structure"] = true
            else
                println("   ❌ ELF structure validation: FAILED")
                results["elf_structure"] = false
            end
        else
            println("   ⚠️  ELF structure validation: SKIPPED (no test executable)")
            results["elf_structure"] = false
        end
    catch e
        println("   ❌ ELF structure validation: FAILED ($e)")
        results["elf_structure"] = false
    end
    
    # Summary
    println("\n" * "=" ^ 60)
    println("🎯 PRODUCTION VALIDATION SUMMARY")
    println("=" ^ 60)
    
    passed = sum(values(results))
    total = length(results)
    percentage = round(passed / total * 100, digits=1)
    
    println("📊 Test Results: $passed/$total passed ($(percentage)%)")
    println()
    
    for (test, result) in results
        status = result ? "✅ PASSED" : "❌ FAILED"
        println("   $(rpad(test, 20)): $status")
    end
    
    println()
    if percentage >= 80
        println("🚀 PRODUCTION STATUS: READY FOR DEPLOYMENT")
        println("   Mini ELF Linker demonstrates production-level capabilities")
        println("   Suitable for educational, development, and research environments")
    elseif percentage >= 60
        println("🔧 PRODUCTION STATUS: NEARLY READY")
        println("   Core functionality working, minor issues remain")
    else
        println("🛠️  PRODUCTION STATUS: DEVELOPMENT REQUIRED")  
        println("   Additional development needed for production deployment")
    end
    
    # Cleanup
    for file in ["simple.c", "simple.o", "simple_test", "main.c", "main.o", "helper.c", "helper.o", "multi_test"]
        isfile(file) && rm(file)
    end
    
    return percentage >= 80
end

if abspath(PROGRAM_FILE) == @__FILE__
    validate_production_capabilities()
end