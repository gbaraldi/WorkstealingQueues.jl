using WorkstealingQueues
using Graphs

import Base.Threads: nthreads, threadid, @threads


function bfs_tree(g::AbstractGraph, source::Int)
    n = nv(g)

    parents = AtomicMemory{Int}(undef, n)
    for i in 1:n
        @atomic parents[i] = 0
    end
    queues = [WSQueue{Int}() for _ in 1:nthreads()]

    push!(queues[threadid()], source)
    @atomic parents[source] = source

    working = Base.Threads.Atomic{Int}(nthreads())

    @threads :static for _ in 1:nthreads()
        tid = threadid()
        queue = queues[tid]
        while working[] > 0
            vertex = pop!(queue)
            # Become stealer (own queue is empty)
            if vertex === nothing
                Base.Threads.atomic_sub!(working, 1)
            end
            while vertex === nothing
                for _ in 1:4
                    tid2 = Base.Partr.cong(nthreads() % UInt32)
                    tid == tid2 && continue
                    vertex = steal!(queues[tid2])
                    if vertex !== nothing
                        Base.Threads.atomic_add!(working, 1) # Become worker
                        break
                    end
                end
                if vertex === nothing
                    for tid2 in 1:nthreads()
                        tid2 = mod1(tid2 + tid, nthreads())
                        tid == tid2 && continue
                        vertex = steal!(queues[tid2])
                        if vertex !== nothing
                            Base.Threads.atomic_add!(working, 1) # Become worker
                            break
                        end
                    end
                end
                if vertex === nothing
                    if working[] == 0 # Terminate
                        return
                    end
                    yield()
                end
            end
            @assert vertex !== nothing
            for other in neighbors(g, vertex)
                _, success = @atomicreplace parents[other] 0 => vertex
                if success
                    @assert 0 < other <= nv(g)
                    push!(queue, other)
                end
            end
        end
    end
    return parents
end

function key_sampling(g::AbstractGraph)
    n_v = nv(g)
    NBFS = n_v > 64 ? 64 : n_v
    length_keys = 0
    i = 0  # Exit loop after a fixed number of iterations

    keys = Set{eltype(g)}()

    while length_keys < NBFS && i < 1000
        keys_required = (NBFS - length_keys)
        rand_keys = Graphs.sample(1:n_v,keys_required)
        union!(keys, filter(x->degree(g,x)>0, rand_keys))
        length_keys = length(keys)
        i = i + 1;
    end

    return keys
end

g6 = smallgraph(:house)

@time g = Graphs.SimpleGraphs.kronecker(16, 16) # 20, 16 is more interesting
roots = key_sampling(g)

@time for source in roots
    bfs_tree(g, source)
 end
# g = Graphs.SimpleGraphs.kronecker(SCALE, edgefactor, A=0.57, B=0.19, C=0.19; rng=nothing, seed=nothing)

# using GraphIO
# using GraphIO.EdgeList

# g = loadgraph(
#     "large_twitch_edges.csv", "twitch user network", EdgeListFormat()
# )