# JuliaPackageTools

The development and CI scripts shared by the Tanay lab Julia packages.

Each package keeps a committed copy of these files in its `deps/` directory, so a plain `git clone` of the package
just works. The root of this repository mirrors that `deps/` directory. Only this `README.md` is not copied.

A package's `Makefile` includes `deps/common.mk`, then adds any rules of its own. The package name and the
documentation version are read from the package's `Project.toml`.

Everything package-specific about the documentation is in the package's `docs/metadata.toml`. Package-only
scripts stay in the package's own `deps/`, beside the shared ones.

`make fetch_tools` copies the files of this repository into the package's `deps/`. It also writes
`deps/tools_version`, with the commit and a hash of each file. The last step of `make ci` verifies the files still
match these hashes. To try a change, edit it in one package's `deps/` and run `make ci` there: every check runs, and
only the last step fails. Then push the change here and run `make fetch_tools` in each package.
`make fetch_tools TOOLS=../JuliaPackageTools` fetches from a local clone instead of GitHub.
