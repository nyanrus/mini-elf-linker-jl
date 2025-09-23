# Test CLI functionality for Mini ELF Linker

using Test
using MiniElfLinker

@testset "CLI Functionality Tests" begin
    
    @testset "Argument Parsing" begin
        # Test basic argument parsing
        options = MiniElfLinker.parse_arguments(["file.o"])
        @test options.input_files == ["file.o"]
        @test options.output_file === nothing
        @test options.base_address == 0x400000
        @test options.entry_symbol == "main"
        @test options.enable_system_libraries == true
        
        # Test output file parsing
        options = MiniElfLinker.parse_arguments(["-o", "program", "file.o"])
        @test options.output_file == "program"
        @test options.input_files == ["file.o"]
        
        # Test -ofile format
        options = MiniElfLinker.parse_arguments(["-oprogram", "file.o"])
        @test options.output_file == "program"
        
        # Test library paths
        options = MiniElfLinker.parse_arguments(["-L/usr/lib", "-L", "/opt/lib", "file.o"])
        @test "/usr/lib" in options.library_search_paths
        @test "/opt/lib" in options.library_search_paths
        
        # Test library names
        options = MiniElfLinker.parse_arguments(["-lm", "-l", "pthread", "file.o"])
        @test "m" in options.library_names
        @test "pthread" in options.library_names
        
        # Test entry symbol
        options = MiniElfLinker.parse_arguments(["--entry", "start", "file.o"])
        @test options.entry_symbol == "start"
        
        # Test help and version flags
        options = MiniElfLinker.parse_arguments(["--help"])
        @test options.help == true
        
        options = MiniElfLinker.parse_arguments(["--version"])
        @test options.version == true
        
        # Test verbose flag
        options = MiniElfLinker.parse_arguments(["-v", "file.o"])
        @test options.verbose == true
        
        # Test static flag
        options = MiniElfLinker.parse_arguments(["-static", "file.o"])
        @test options.static == true
        @test options.enable_system_libraries == false
    end
    
    @testset "Help and Version" begin
        # Test help output
        help_code = MiniElfLinker.main(["--help"])
        @test help_code == 0
        
        # Test version output  
        version_code = MiniElfLinker.main(["--version"])
        @test version_code == 0
    end
    
    @testset "Error Handling" begin
        # Test no input files
        error_code = MiniElfLinker.main(String[])
        @test error_code == 1
        
        # Test invalid option (should continue with warning)
        options = MiniElfLinker.parse_arguments(["--unknown-flag", "file.o"])
        @test options.input_files == ["file.o"]
    end
    
    @testset "LLD Compatibility Examples" begin
        # Test various LLD-compatible command formats
        
        # ld.lld file.o
        options = MiniElfLinker.parse_arguments(["file.o"])
        @test options.input_files == ["file.o"]
        @test options.output_file === nothing
        
        # ld.lld -o program file.o  
        options = MiniElfLinker.parse_arguments(["-o", "program", "file.o"])
        @test options.output_file == "program"
        @test options.input_files == ["file.o"]
        
        # ld.lld -lm -lpthread file.o
        options = MiniElfLinker.parse_arguments(["-lm", "-lpthread", "file.o"])
        @test "m" in options.library_names
        @test "pthread" in options.library_names
        @test options.input_files == ["file.o"]
        
        # ld.lld -L/opt/lib -lmath file.o
        options = MiniElfLinker.parse_arguments(["-L/opt/lib", "-lmath", "file.o"])
        @test "/opt/lib" in options.library_search_paths
        @test "math" in options.library_names
        @test options.input_files == ["file.o"]
    end
end

println("✅ All CLI tests completed successfully!")