using TOML

@assert 1 <= length(ARGS) <= 2 "usage: deps/worktree.sh <tag> [<commit>]"
TAG = ARGS[1]
COMMIT = length(ARGS) > 1 ? ARGS[2] : "HEAD"
PACKAGE_DIRECTORY = pwd()
WORKTREE_DIRECTORY = "$(PACKAGE_DIRECTORY).$(TAG)"

@assert !ispath(WORKTREE_DIRECTORY) "the worktree already exists: $(WORKTREE_DIRECTORY)"
run(`git worktree add --quiet --detach $(WORKTREE_DIRECTORY) $(COMMIT)`)

# The manifest of the workspace which holds the package, so the worktree resolves to the same versions and reuses their
# compiled files. Each path in it is made relative to the worktree, and the package itself is taken from the worktree.
manifest_path = Base.project_file_manifest_path(joinpath(PACKAGE_DIRECTORY, "Project.toml"))
if manifest_path !== nothing && isfile(manifest_path)
    manifest = TOML.parsefile(manifest_path)
    for entries in values(manifest["deps"]), entry in entries
        if haskey(entry, "path")
            entry_directory = joinpath(dirname(manifest_path), entry["path"])
            if realpath(entry_directory) == realpath(PACKAGE_DIRECTORY)
                entry_directory = WORKTREE_DIRECTORY
            end
            entry["path"] = relpath(entry_directory, WORKTREE_DIRECTORY)
        end
    end
    open(joinpath(WORKTREE_DIRECTORY, "Manifest.toml"), "w") do file
        return TOML.print(file, manifest)
    end
end

println("Created: $(WORKTREE_DIRECTORY)")
println("Remove it with: git worktree remove --force $(WORKTREE_DIRECTORY)")
