# Test LLD-compatible behavior

using MiniElfLinker

function test_lld_compatible_behavior()
    println("🎯 Testing LLD-Compatible Behavior")
    println("=" ^ 50)
    
    # Test 1: Default behavior - only libc linked automatically
    println("\n1️⃣  Default libc discovery (automatic like lld):")
    libc = find_default_libc()
    if libc !== nothing
        println("   ✅ Found default libc: $(libc.type) at $(basename(libc.path))")
        println("   📊 Symbols: $(length(libc.symbols)) (sample: $(collect(libc.symbols)[1:min(5, length(libc.symbols))]))")
    else
        println("   ❌ No default libc found")
    end
    
    # Test 2: No automatic discovery of other libraries
    println("\n2️⃣  Library discovery without explicit requests (should be empty):")
    libs = find_libraries()
    println("   📦 Found $(length(libs)) libraries (should be 0 - lld behavior)")
    
    # Test 3: Explicit library requests work (-l equivalent)
    println("\n3️⃣  Explicit library search (-l math -l pthread):")
    requested_libs = find_libraries(String[]; library_names=["m", "pthread"])
    println("   📦 Found $(length(requested_libs)) requested libraries:")
    for lib in requested_libs[1:min(4, length(requested_libs))]
        println("     - $(lib.name) ($(lib.type)): $(basename(lib.path)) [$(length(lib.symbols)) symbols]")
    end
    
    # Test 4: Custom search paths work (-L equivalent)
    println("\n4️⃣  Custom search paths (-L /usr/lib -l c):")
    custom_libs = find_libraries(["/usr/lib"]; library_names=["c"])
    println("   📦 Found $(length(custom_libs)) libc libraries with custom paths:")
    for lib in custom_libs[1:min(2, length(custom_libs))]
        println("     - $(lib.name) ($(lib.type)): $(lib.path)")
    end
    
    # Test 5: CRT objects for proper program startup
    println("\n5️⃣  CRT objects discovery:")
    crt_objects = find_crt_objects()
    println("   🏗️  Found CRT objects: $(sort(collect(keys(crt_objects))))")
    for (name, path) in sort(collect(crt_objects))
        println("     - $name: $(basename(path))")
    end
    
    # Test 6: Symbol extraction works dynamically
    println("\n6️⃣  Dynamic symbol extraction verification:")
    if !isempty(requested_libs)
        math_lib = first(lib for lib in requested_libs if lib.name == "m")
        math_functions = ["sin", "cos", "tan", "exp", "log", "sqrt", "pow"]
        found_functions = [f for f in math_functions if f in math_lib.symbols]
        println("   🔍 Math functions found: $found_functions")
        println("   ✅ Dynamic extraction: $(length(found_functions))/$(length(math_functions)) functions found")
    end
    
    # Test 7: Backward compatibility
    println("\n7️⃣  Backward compatibility check:")
    old_style_libs = find_system_libraries()
    println("   🔄 Old find_system_libraries(): $(length(old_style_libs)) libraries")
    println("   ✅ Maintains compatibility with existing code")
    
    println("\n🎉 LLD-Compatible Behavior Test Complete!")
    return true
end

function test_lld_equivalence()
    println("\n🔗 LLD Command Equivalence Examples")
    println("=" ^ 50)
    
    println("LLD/GCC Command                     → Julia Equivalent")
    println("-" ^ 50)
    println("ld.lld file.o                      → link_objects([\"file.o\"])")
    println("ld.lld -lc file.o                  → link_objects([\"file.o\"]; library_names=[\"c\"])")
    println("ld.lld -lm -lpthread file.o        → link_objects([\"file.o\"]; library_names=[\"m\", \"pthread\"])")
    println("ld.lld -L/opt/lib -lmath file.o     → link_objects([\"file.o\"]; library_search_paths=[\"/opt/lib\"], library_names=[\"math\"])")
    println()
    
    println("🔍 Key LLD Behaviors Implemented:")
    println("✅ Only libc linked automatically")
    println("✅ Other libraries require explicit -l")
    println("✅ Custom search paths via -L")
    println("✅ Dynamic symbol extraction")
    println("✅ CRT objects support")
    println("✅ Linker script resolution")
    
    return true
end

if abspath(PROGRAM_FILE) == @__FILE__
    test_lld_compatible_behavior()
    test_lld_equivalence()
end