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

# Process all command-line arguments (skip $0 which is script name)
for arg in "$@"; do
    case "$arg" in
        -o)
            # Next argument is the output file - we need to handle this specially
            OUTPUT_FILE_NEXT=true
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
            # Skip dynamic linker specification
            SKIP_NEXT=true
            ;;
        -L*)
            # Library search path - ignore for now
            ;;
        *)
            # Handle -o argument value
            if [[ "$OUTPUT_FILE_NEXT" == "true" ]]; then
                OUTPUT_FILE="$arg"
                OUTPUT_FILE_NEXT=false
            elif [[ "$SKIP_NEXT" == "true" ]]; then
                SKIP_NEXT=false
            else
                # Other arguments - could be object files without .o extension
                if [[ -f "$arg" ]]; then
                    OBJECT_FILES+=("$arg")
                fi
            fi
            ;;
    esac
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