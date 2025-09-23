# Test runner for MiniElfLinker

using MiniElfLinker
using Test

include("test_linker.jl")
include("test_library_support.jl")

@testset "MiniElfLinker Tests" begin
    @testset "Basic Linker Functionality" begin
        test_elf_linker()
    end
    
    @testset "Library Support" begin
        test_library_detection()
    end
end