# JuliaPackageTools

The development and CI scripts shared by the Tanay lab Julia packages.

Each package keeps a committed copy of these files in its `deps/` directory, so a plain `git clone` of the package
just works. The root of this repository mirrors that `deps/` directory. Only this `README.md`, `pin_tools.jl`,
`fetch_all.sh` and `tools_users.sh` are not copied.

A package's `Makefile` includes `deps/common.mk`, then adds any rules of its own. The package name and the
documentation version are read from the package's `Project.toml`. `make -j ci` runs the independent stages in
parallel.

Everything package-specific about the documentation is in the package's `docs/metadata.toml`. Package-only
scripts stay in the package's own `deps/`, beside the shared ones.

A package's `Project.toml` makes it a workspace with its tests and its tools:

```toml
[workspace]
projects = [
    "test",
    "deps/aqua_env",
    "deps/coverage_env",
    "deps/document_env",
    "deps/format_env",
    "deps/jet_env",
    "deps/lint_env",
]
```

Its `test/Project.toml` lists the package itself, from `..` (in `[sources]`). The package, its tests and its tools then
share one `Manifest.toml`, so every tool has one version, and the package and its dependencies are compiled once for
all of them. The first stage of the build, `make precompile`, resolves the workspace and compiles each of the
package's projects. The package and its tests are compiled for the plain flags and for the tests' `--check-bounds=yes`,
and the tools for the plain flags. Every stage which loads the package runs after it, with `--compiled-modules=strict`,
so a stage which would compile anything fails instead. Only Aqua's persistent tasks check compiles, a wrapper package
of its own.

The other packages of the lab which a package uses are given in its `[sources]` by their relative paths (e.g.
`TanayLabUtilities = {path = "../TanayLabUtilities.jl"}`). These are used only when the package's own environment is
active, so a normal installation from a registry is not affected.

`make lint` checks the package's sources with JuliaWorkspaces, under the rules in `deps/JuliaLint.toml`: the `strict`
preset, without the style rules `bare_using` and `string_concat_style`. A `# NOLINT` comment on a line skips its
findings, and an unused `# NOLINT` is an error. An editor's language server looks for a `JuliaLint.toml` from the source
file upward instead, so it shows the default rules.

Each tool is pinned to an exact version in the `[compat]` of its environment, so every package, worktree and clone is
checked by the same tools. A dependency of a tool environment which a package also depends on is not pinned, and
follows the packages. `julia pin_tools.jl ~/data/src`, run here, moves the pins to the latest versions which resolve
together with all the packages there which use these tools, their tests and the other tools. `tools_users.sh` lists
these packages: each directory, one or two levels down, with a `deps/tools_version`, in the main checkout of its
repository. Commit the change here, then run `./fetch_all.sh ~/data/src`, also here. It runs `fetch_tools.sh` in each
of these packages, and then moves each of their manifests to the new pins. A plain resolve can't do that, since it keeps
the versions the manifest already has. The packages' own dependencies are not pinned. `Pkg.update()` in the workspace
moves them.

The packages are developed side by side in one directory, which is itself a workspace over all of them. They then share
one `Manifest.toml`, so a package is compiled once for itself and for every package which uses it. A worktree of a
package needs its siblings beside it. `make worktree TAG=<tag>` creates a worktree of the package beside it (e.g.
`DataAxesFormats.jl.gate`), with a copy of the shared manifest. It uses the live trees of its siblings and their
compiled files. Add `COMMIT=<commit>` to check out another commit than `HEAD`.

`make fetch_tools` copies the files of this repository into the package's `deps/`. It also writes
`deps/tools_version`, with the commit and a hash of each file. The last step of `make ci` verifies the files still
match these hashes. To try a change, edit it in one package's `deps/` and run `make ci` there: every check runs, and
only the last step fails. Then push the change here and run `make fetch_tools` in each package.
`make fetch_tools TOOLS=../JuliaPackageTools` fetches from a local clone instead of GitHub.
