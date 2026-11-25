using Aqua
using Pkg
using Test
using TOML

# The tool environment doesn't depend on the package. The package's own project comes first, so Aqua finds the package
# in the current directory, and not another copy in the default environment.
pushfirst!(LOAD_PATH, ".")

PROJECT = TOML.parsefile("Project.toml")
PACKAGE_NAME = Symbol(PROJECT["name"])
@eval using $(PACKAGE_NAME)
PACKAGE = getfield(Main, PACKAGE_NAME)

Aqua.test_ambiguities([PACKAGE])
# Floss reports the unused dependencies, of the tests too, so Aqua's stale dependencies test is off.
Aqua.test_all(
    PACKAGE;
    ambiguities = false,
    unbound_args = false,
    deps_compat = false,
    persistent_tasks = false,
    stale_deps = false,
)

# Whether a process that loads the package exits within `tmax` seconds of the loading. A task left running would keep
# it alive, and block the precompilation of the packages that use this one. As `Aqua.test_persistent_tasks` does, this
# precompiles a new package that loads ours in a separate process. Aqua resolves the new package's environment anew,
# so it compiles every dependency again whenever the versions differ from ours. Here the environment copies the versions
# of the workspace's Manifest, so the precompilation reuses the existing caches.
function is_exiting_after_loading(; tmax::Real)::Bool
    wrapper_directory = mktempdir()
    workspace_manifest_path = Pkg.Types.EnvCache().manifest_file
    workspace_directory = dirname(workspace_manifest_path)
    manifest = TOML.parsefile(workspace_manifest_path)
    for entries in values(manifest["deps"])
        for entry in entries
            if haskey(entry, "path")
                entry["path"] = abspath(workspace_directory, entry["path"])
            end
        end
    end
    open(joinpath(wrapper_directory, "Manifest.toml"), "w") do io
        TOML.print(io, manifest)
        return nothing
    end

    wrapper_name = "$(PACKAGE_NAME)PersistentTasks"
    wrapper_project = Dict(
        "name" => wrapper_name,
        "uuid" => string(Base.UUID(rand(UInt128))),
        "deps" => Dict(String(PACKAGE_NAME) => PROJECT["uuid"]),
    )
    open(joinpath(wrapper_directory, "Project.toml"), "w") do io
        TOML.print(io, wrapper_project)
        return nothing
    end

    status_path = joinpath(wrapper_directory, "done.log")
    mkpath(joinpath(wrapper_directory, "src"))
    open(joinpath(wrapper_directory, "src", "$(wrapper_name).jl"), "w") do io
        println(
            io,
            """
            module $(wrapper_name)
            using $(PACKAGE_NAME)
            open("$(escape_string(status_path))", "w") do io
                println(io, "done")
                return nothing
            end
            end
            """,
        )
        return nothing
    end

    process = run(
        `$(Base.julia_cmd()) --project=$(wrapper_directory) -e 'using Pkg; Pkg.resolve(); Pkg.precompile()'`,
        stdin,
        stdout,
        stderr;
        wait = false,
    )
    while !isfile(status_path) && process_running(process)
        sleep(0.5)
    end
    if !isfile(status_path)
        @error "the precompilation process exited without loading $(PACKAGE_NAME)"
        return false
    end
    loaded_time = time()
    while process_running(process) && time() - loaded_time < tmax
        sleep(0.1)
    end
    is_exiting = !process_running(process)
    if !is_exiting
        kill(process, Base.SIGKILL)
    end
    return is_exiting
end

# The time is that of the whole precompilation process to exit after the loading, which on a loaded machine writing its
# cache over the network is regularly longer than Aqua's default of 10 seconds.
@testset "Persistent tasks" begin
    @test is_exiting_after_loading(; tmax = 60)
end
