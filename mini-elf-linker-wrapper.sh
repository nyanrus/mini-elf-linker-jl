#!/bin/bash

# Mini-ELF-Linker Wrapper Script for Clang Integration
# This script allows clang to use Mini-ELF-Linker as a drop-in replacement
# Usage: clang -fuse-ld=mini-elf-linker-wrapper.sh [files...]

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MINI_LINKER="$SCRIPT_DIR/mini_elf_linker_cli.jl"

# Parse arguments to extract output file and object files
OUTPUT_FILE=""
OBJECT_FILES=()
LIBRARIES=()
i=0

while [[ $i -lt $# ]]; do
    arg="${!i}"
    case "$arg" in
        -o)
            # Next argument is the output file
            ((i++))
            OUTPUT_FILE="${!i}"
            ;;
        *.o)
            # Object file
            OBJECT_FILES+=("$arg")
            ;;
        -l*)
            # Library (e.g., -lm, -lpthread)
            LIBRARIES+=("$arg")
            ;;
        --dynamic-linker)
            # Skip dynamic linker specification and its argument
            ((i++))
            ;;
        -L*)
            # Library search path - ignore for now
            ;;
        *)
            # Other arguments - ignore for now
            ;;
    esac
    ((i++))
done

# Set default output if not specified
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="a.out"
fi

echo "Mini-ELF-Linker Wrapper: Linking ${#OBJECT_FILES[@]} object files to $OUTPUT_FILE"

# Build command for Mini-ELF-Linker
CMD_ARGS=()
CMD_ARGS+=("-o" "$OUTPUT_FILE")
CMD_ARGS+=("${OBJECT_FILES[@]}")
CMD_ARGS+=("${LIBRARIES[@]}")

# Execute Mini-ELF-Linker
julia --project="$SCRIPT_DIR" "$MINI_LINKER" "${CMD_ARGS[@]}"