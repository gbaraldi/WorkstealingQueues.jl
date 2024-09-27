N = parse(Int, ARGS[1])


path = @__DIR__

for i in 0:N
    k = 2^i
    @info "running" k
    run(`$(Base.julia_cmd()) --project=$(path) --threads=$k $(path)/bfs.jl`)
end