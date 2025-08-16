# Build system design for reproducible language

## Overview

This document describes the design of a build system for a compile-time correct
language that interoperates with C. The system prioritizes reproducibility as
the primary goal while maintaining fast development iteration. The design uses
a hybrid approach combining Nix for reproducible environments and dependency
management with a custom content-addressed incremental builder for development
speed.

## Core principles

### Reproducibility first
Build reproducibility is the primary goal. All builds must be deterministic and
bit-for-bit reproducible across different machines and environments. This
requirement drives most other architectural decisions.

### Hermetic execution
All builds run in sandboxed environments where only declared inputs are
accessible. This prevents hidden dependencies and ensures the build hash
correctly represents input uniqueness.

### Fast development iteration
Despite the focus on reproducibility, the development experience must remain
fast with incremental builds that reuse partial artifacts when possible.

### C ecosystem integration
The language needs seamless integration with existing C/C++ codebases and
libraries, supporting both directions: calling C from the language and being
called from C projects.

## Architecture overview

The system uses a dual-mode approach:

**Development builds** use a custom incremental builder with content-addressed
caching inside a Nix-provided hermetic environment. This provides fast
iteration while maintaining correctness.

**Release builds** generate and execute Nix expressions for full reproducible
builds. These are slower but provide the strongest reproducibility guarantees.

Both modes use the same Lua-based configuration to ensure consistency.

## Configuration format

Projects are configured using Lua files that declare explicit boundaries while
allowing auto-discovery within those boundaries:

```lua
project {
  name = "myapp",
  
  -- Explicit source boundaries
  sources = glob("src/*.your-lang"),
  c_sources = glob("native/*.c"),
  
  -- Explicit external dependencies
  nix_deps = {"zlib", "openssl", "pkg-config"},
  
  -- Build configuration
  compiler_flags = {"-O2", "-Wall"},
  cache_backend = "sccache",
}
```

### Why explicit source globs
While auto-discovery could theoretically find all source files, explicit globs
provide necessary control over build boundaries. This prevents accidentally
including test files, examples, or experimental code in production builds.
Globs provide a good balance between explicitness and maintainability.

### Why explicit external dependencies
External dependencies must be explicit for reproducible builds. The build
system cannot automatically discover that your code will need specific system
libraries at runtime. Nix requires this information upfront to create the
hermetic environment.

## Development builds

Development builds prioritize speed while maintaining correctness through
content-addressed caching.

### Process flow

1. **Environment setup**: Automatically enter a Nix development shell with all
   declared external dependencies available
2. **Dependency analysis**: Parse all source files to discover import
   relationships and header dependencies
3. **Cache lookup**: Check content-addressed cache for each compilation unit
   using `hash = f(source_content + all_dependencies_content + compiler_flags)`
4. **Incremental compilation**: Compile only sources with cache misses
5. **Cache update**: Store new artifacts with their content hashes
6. **Linking**: Produce final binary from cached and newly compiled objects

### Content-addressed caching

The cache uses content hashing to determine when artifacts can be reused:

- **Your language sources**: Hash source file content plus all transitively
  imported modules
- **C sources**: Hash source file content plus all included headers (discovered
  via `gcc -M` or static analysis)
- **Build configuration**: Include compiler flags, target architecture, and
  tool versions in the hash

This ensures cache hits only occur when all inputs are truly identical.

### Why content-addressed caching
Content addressing provides automatic cache invalidation without manual
dependency tracking. When any input changes, the hash changes, triggering
recompilation. This is more reliable than timestamp-based approaches and
naturally handles complex dependency scenarios.

## Release builds

Release builds prioritize reproducibility over speed by using Nix's hermetic
build system.

### Process flow

1. **Nix expression generation**: Convert the Lua configuration and discovered
   dependencies into a complete Nix derivation
2. **Hermetic build**: Execute `nix-build` which runs the entire compilation in
   a sandboxed environment with only declared inputs
3. **Reproducible output**: Produce bit-for-bit identical artifacts regardless
   of the host system

### Nix expression structure

Generated Nix expressions compile entire artifacts (binaries, libraries) in
single derivations rather than per-object granularity. This approach balances
Nix evaluation overhead with reproducibility needs.

```nix
stdenv.mkDerivation {
  name = "myapp";
  src = ./src;
  buildInputs = [ zlib openssl ];
  buildPhase = ''
    your-lang-compiler src/main.your-lang native/ffi.c -o myapp
  '';
}
```

### Why single-artifact derivations
While Nix could theoretically create one derivation per object file, this
approach has significant evaluation overhead. Since release builds prioritize
correctness over incrementality, compiling entire artifacts in single
derivations provides the right trade-off.

## Dependency discovery

The system auto-discovers dependency relationships between known sources to
enable correct incremental builds.

### Source-level dependencies
Static analysis of your language's import statements builds the module
dependency graph:

```your-lang
import MyProject.Utils    // Creates dependency on utils.your-lang
import Graphics.OpenGL    // Creates dependency on external library
```

### C header dependencies
For C sources and C imports from your language, the system discovers header
dependencies using:

- Compiler dependency output (`gcc -M`)
- Static parsing of `#include` statements with preprocessor awareness
- Conservative over-approximation when static analysis is insufficient

### Why auto-discovery
Manual dependency declaration (like Bazel's BUILD files) would be extremely
verbose and error-prone for header dependencies. Auto-discovery leverages the
language's existing import semantics and C's include system to build accurate
dependency graphs without manual maintenance.

## Integration strategies

### Nix ecosystem access
Using Nix for dependency management provides immediate access to the entire
nixpkgs ecosystem of C/C++ libraries. The language can depend on any package
available in nixpkgs without additional packaging work.

### C/C++ project integration

**Consuming the language**: Generated Nix expressions can be imported by other
Nix-based projects, or the build system can emit CMake/pkg-config files for
integration with traditional C++ build systems.

**Calling C code**: The language can directly compile and link C sources
declared in the same project, with full dependency tracking through the
content-addressed cache.

### Why Nix for dependencies
Nix solves the fundamental reproducibility problem for external dependencies.
Traditional package managers provide "version 1.2.3" which can mean different
binaries on different systems. Nix provides content-addressed packages ensuring
bit-identical dependencies across builds.

## Cache implementation

### Abstracted backend
The cache system uses pluggable backends to allow evolution from simple local
caching to sophisticated distributed systems:

- **Local**: Simple file-based cache for single-developer workflows
- **sccache**: Leverage Mozilla's proven distributed compilation cache
- **Custom**: Purpose-built cache optimized for the language's specific needs

### Why abstracted caching
Starting with an existing solution like sccache provides immediate
functionality while the abstraction enables future optimization. Building a
high-performance content-addressed cache from scratch is complex; leveraging
proven solutions reduces initial implementation burden.

## Error handling and correctness

### Hermetic enforcement
Both development and release builds run in sandboxed environments that prevent
access to undeclared inputs. Build failures occur immediately when hidden
dependencies exist rather than succeeding with non-reproducible results.

### Conservative dependency analysis
When static analysis cannot determine dependencies with certainty (conditional
compilation, dynamic imports), the system errs on the side of over-declaring
dependencies rather than missing them.

### Verification mechanisms
The build system includes verification that all discovered dependencies are
actually available in the declared environment, failing fast when mismatches
occur.

## Unified developer experience

Despite the dual-mode architecture, developers interact with a single command
interface:

```bash
# Fast incremental development builds
your-lang build --dev

# Slow but fully reproducible release builds  
your-lang build --release

# Package for distribution
your-lang package
```

The system automatically handles environment setup, dependency resolution, and
caching without requiring developers to understand the underlying Nix
complexity.

### Why unified interface
Reproducible builds are only valuable if developers actually use them.
Providing a simple, consistent interface that automatically handles the
complexity encourages adoption of reproducible practices without sacrificing
development velocity.
