using JET
using TOML

PACKAGE_NAME = TOML.parsefile("Project.toml")["name"]
@eval using $(Symbol(PACKAGE_NAME))

println(report_package(getfield(Main, Symbol(PACKAGE_NAME))))
