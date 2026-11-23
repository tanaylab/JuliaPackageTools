using JuliaWorkspaces
using TOML

source_directory = abspath("src")

# Only the package itself, so the tool environments in `deps/` aren't indexed.
workspace = JuliaWorkspace(; dynamic = DynamicIndexingOnly)
add_file_from_disc!(workspace, abspath("Project.toml"))

# The package's environment is the manifest of its workspace, declared by the project beside it. Without these, the
# workspace resolves a scratch project of its own in a child process, which may still run when this process exits.
manifest_path = Base.project_file_manifest_path(abspath("Project.toml"))
add_file_from_disc!(workspace, manifest_path)
root_project_path = joinpath(dirname(manifest_path), "Project.toml")
if root_project_path != abspath("Project.toml")
    add_file_from_disc!(workspace, root_project_path)
end

for file_name in readdir(source_directory)
    if endswith(file_name, ".jl")
        add_file_from_disc!(workspace, joinpath(source_directory, file_name))
    end
end

# The lab packages which the package uses are developed from their paths, so they have no symbol caches. Their sources
# are given to the workspace, which indexes them as it does the package's own. Only the package's own files are
# reported.
manifest_entry_per_name = Dict(name => only(entries) for (name, entries) in TOML.parsefile(manifest_path)["deps"])
pending_names = collect(keys(get(TOML.parsefile("Project.toml"), "deps", Dict{String, Any}())))
seen_names = Set{String}()
while !isempty(pending_names)
    name = pop!(pending_names)
    if name in seen_names || !haskey(manifest_entry_per_name, name)
        continue
    end
    push!(seen_names, name)
    entry = manifest_entry_per_name[name]
    dependencies = get(entry, "deps", String[])
    append!(pending_names, dependencies isa AbstractDict ? collect(keys(dependencies)) : dependencies)
    if haskey(entry, "path")
        dependency_directory = abspath(dirname(manifest_path), entry["path"])
        add_file_from_disc!(workspace, joinpath(dependency_directory, "Project.toml"))
        for (directory, _, file_names) in walkdir(joinpath(dependency_directory, "src"))
            for file_name in file_names
                if endswith(file_name, ".jl")
                    add_file_from_disc!(workspace, joinpath(directory, file_name))
                end
            end
        end
    end
end

# The rules are in `deps/JuliaLint.toml`. They are given to the workspace as the `JuliaLint.toml` of the package root,
# so they govern all of the package's files.
add_file!(
    workspace,
    TextFile(
        JuliaWorkspaces.URIs2.filepath2uri(abspath("JuliaLint.toml")),
        SourceText(read("deps/JuliaLint.toml", String), "toml"),
    ),
)
diagnostics_per_path = Dict(
    JuliaWorkspaces.URIs2.uri2filepath(uri) => (uri, diagnostics) for
    (uri, diagnostics) in get_diagnostics_blocking(workspace)
)

global errors = 0
global skipped = 0
global unused = 0
for file_name in sort!(readdir(source_directory))
    if !endswith(file_name, ".jl")
        continue
    end
    path = joinpath(source_directory, file_name)
    no_lint_lines = Set{Int}()
    unused_no_lint_lines = Set{Int}()
    for (line_number, line_text) in enumerate(readlines(path))
        if contains(line_text, "NOLINT")
            push!(no_lint_lines, line_number)
            push!(unused_no_lint_lines, line_number)
        end
        if contains(line_text, "DEFAULT")
            push!(no_lint_lines, line_number)
        end
    end
    if haskey(diagnostics_per_path, path)
        uri, diagnostics = diagnostics_per_path[path]
        source_text = get_text_file(workspace, uri).content
        for diagnostic in diagnostics
            position = position_at(source_text, first(diagnostic.range))
            if position.line in no_lint_lines
                delete!(unused_no_lint_lines, position.line)
                global skipped
                skipped += 1
            else
                println("$(path):$(position.line):$(position.column): $(diagnostic.message) ($(diagnostic.code))")
                global errors
                errors += 1
            end
        end
    end
    for line_number in sort(collect(unused_no_lint_lines))
        global unused
        unused += 1
        println("$(path):$(line_number): unused NOLINT directive)")
    end
end
shutdown!(workspace)

# Whether this process has a child process, other than the `ps` that answers (which lists itself).
function has_child_processes()::Bool
    children_count = count(readlines(`ps -A -o pid= -o ppid=`)) do line
        return parse(Int, split(line)[2]) == getpid()
    end
    return children_count > 1
end

# `shutdown!` only signals the workspace's child processes. Exiting while this process still tears them down may crash
# it, so wait until they are gone.
if Sys.isunix()
    while has_child_processes()
        sleep(0.1)
    end
    sleep(0.1)
end

message = "StaticLint:"
separator = ""
if errors > 0
    message *= " $(errors) errors"
    separator = ","
end
if skipped > 0
    message *= "$(separator) $(skipped) skipped"
    separator = ","
end
if unused > 0
    message *= "$(separator) $(unused) unused"
end

if errors + skipped + unused > 0
    println(message)
else
    println("StaticLint: clean!")
end

if errors + unused > 0
    exit(1)
end
