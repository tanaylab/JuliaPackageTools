using JuliaWorkspaces

source_directory = abspath("src")

# Only the package itself, so the tool environments in `deps/` aren't indexed.
workspace = JuliaWorkspace(; dynamic = DynamicIndexingOnly)
add_file_from_disc!(workspace, abspath("Project.toml"))
for file_name in readdir(source_directory)
    if endswith(file_name, ".jl")
        add_file_from_disc!(workspace, joinpath(source_directory, file_name))
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
