#!/usr/bin/env julia --project=.

"""
Mini ELF Linker - Production CLI
Direct linker interface for real-world usage
"""

using MiniElfLinker

function main()
    try
        # Parse command line arguments and execute linker
        exit_code = MiniElfLinker.main(ARGS)
        exit(exit_code)
    catch e
        println(stderr, "Linker error: $e")
        exit(1)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end