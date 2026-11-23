# Pin each tool to its latest version that resolves together with all the packages in the given directory (each
# `<name>.jl` with a `Project.toml`), their tests and the other tools. The pins are written into the `[compat]` of the
# tool environments here. A dependency of a tool environment which a package also depends on is left unpinned, so it
# follows the packages. Run from the root of this repository: `julia pin_tools.jl ~/data/src`.

using Pkg
using TOML

source_directory = ARGS[1]
environment_names = ["aqua_env", "coverage_env", "document_env", "format_env", "jet_env", "lint_env"]
package_paths = [
    path for path in readdir(source_directory; join = true) if
    endswith(path, ".jl") && isfile(joinpath(path, "Project.toml"))
]
package_names = Set{String}(TOML.parsefile(joinpath(path, "Project.toml"))["name"] for path in package_paths)
package_dependency_names = Set{String}(
    name for path in package_paths for name in keys(get(TOML.parsefile(joinpath(path, "Project.toml")), "deps", Dict()))
)

uuid_per_name = Dict{String, String}()
version_spec_per_name = Dict{String, Pkg.Versions.VersionSpec}()
pinned_names = Set{String}()

function add_requirements!(project::AbstractDict; is_tool::Bool)::Nothing
    compat = get(project, "compat", Dict{String, Any}())
    for (name, uuid) in get(project, "deps", Dict{String, Any}())
        if name in package_names || Pkg.Types.is_stdlib(Base.UUID(uuid))
            continue
        end
        uuid_per_name[name] = uuid
        is_pinned = is_tool && !(name in package_dependency_names)
        if is_pinned
            push!(pinned_names, name)
        end
        version_spec = if !is_pinned && haskey(compat, name)
            Pkg.Versions.semver_spec(compat[name])
        else
            Pkg.Versions.VersionSpec()
        end
        previous_version_spec = get(version_spec_per_name, name, Pkg.Versions.VersionSpec())
        version_spec_per_name[name] = intersect(previous_version_spec, version_spec)
    end
    return nothing
end

for path in package_paths
    test_project_path = joinpath(path, "test", "Project.toml")
    if isfile(test_project_path)
        add_requirements!(TOML.parsefile(test_project_path); is_tool = false)
    end
end
for environment_name in environment_names
    add_requirements!(TOML.parsefile(joinpath(environment_name, "Project.toml")); is_tool = true)
end

Pkg.activate(; temp = true)
Pkg.develop([PackageSpec(; path) for path in package_paths])
Pkg.add([
    PackageSpec(; name, uuid = Base.UUID(uuid_per_name[name]), version = version_spec_per_name[name]) for
    name in sort!(collect(keys(uuid_per_name)))
])
version_per_name = Dict{String, VersionNumber}(
    info.name => info.version for info in values(Pkg.dependencies()) if info.version !== nothing
)

for environment_name in environment_names
    project_path = joinpath(environment_name, "Project.toml")
    dependencies = sort!(collect(get(TOML.parsefile(project_path), "deps", Dict{String, Any}())))
    open(project_path, "w") do file
        println(file, "[deps]")
        for (name, uuid) in dependencies
            println(file, "$(name) = \"$(uuid)\"")
        end
        pins = [(name, version_per_name[name]) for (name, _) in dependencies if name in pinned_names]
        if !isempty(pins)
            println(file)
            println(file, "[compat]")
            for (name, version) in pins
                println(file, "$(name) = \"=$(version)\"")
            end
        end
        return nothing
    end
    println("$(project_path): ", join(["$(name) $(version_per_name[name])" for (name, _) in dependencies], ", "))
end
