using JET
using TOML

# The tool environment doesn't depend on the package. The package's own project comes first, so JET finds the package
# in the current directory, and not another copy in the default environment.
pushfirst!(LOAD_PATH, ".")

PACKAGE_NAME = TOML.parsefile("Project.toml")["name"]
@eval using $(Symbol(PACKAGE_NAME))

println(report_package(getfield(Main, Symbol(PACKAGE_NAME))))
