using WorkstealingQueues

mutable struct Foo
    origin::Int
end

mutable struct Counter
    @atomic counter::Int64
end

function main(::Type{Queue}, N = Threads.nthreads(); verbose=false) where Queue
    pushcounter = ntuple(_->Counter(0), N)
    popcounter  = ntuple(_->Counter(0), N)
    wsqueues    = ntuple(_->Queue{Foo}(), N)
    objvecs     = ntuple(_->Vector{Foo}(), N)
    initobjs    = Vector{Foo}()
    finobjs     = Vector{Foo}()

    DONE = Counter(0)

    function print_stats()
        push_tot = 0
        pop_tot = 0
        for i in 1:N
            push_tot += pushcounter[i].counter
            pop_tot += popcounter[i].counter
            stolen = count(f->f.origin!=i, objvecs[i])
            println("pushes[$i]: ", pushcounter[i].counter, " pops[$i]: ", popcounter[i].counter, " stolen[$i]: ", stolen)
        end
        println("pushes: ", push_tot, " pops: ", pop_tot)
    end

    function combine_objs()
        for i in 1:N
            append!(finobjs, objvecs[i])
        end
    end

    function do_work(n::Int64)
        wsqueue = wsqueues[n]
        thief = false
        steal_attempts = 0
        while (@atomic DONE.counter) < N || (thief && steal_attempts > 10N)
            yield()
            foo = pop!(wsqueue)
            if foo === nothing
                # become thief
                if !thief
                    thief = true
                    @atomic DONE.counter += 1
                end
                for _ in 1:N # N steal attempts
                    victim = rand(1:N)
                    if victim == n
                        continue
                    end
                    foo = steal!(wsqueues[victim])
                    if foo !== nothing
                        steal_attempts = 0
                        break
                    end
                    yield()
                    steal_attempts += 1
                end
                if foo === nothing
                    continue
                end
            end
            push!(objvecs[n], foo)
            @atomic popcounter[n].counter += 1
        end
    end

    for j in 1:N
        if rand((false,true))
            continue
        end
        for i in 1:rand(100:5000)
            foo = Foo(j)
            push!(initobjs, foo)
            @atomic  pushcounter[j].counter += 1
            push!(wsqueues[j], foo)
        end
    end

    function parallel_work()
        @sync begin
            for i in 1:N
                Threads.@spawn do_work(i)
            end
        end
    end

    verbose && print_stats()
    if verbose
        @time parallel_work()
    else
        parallel_work()
    end

    for queue in wsqueues
        isempty(queue) || println("queue not empty")
    end

    combine_objs()

    if length(initobjs) != length(finobjs)
        println("lengths not equal")
        @show length(initobjs)
        @show length(finobjs)
        println()
    end
    # length(initobjs) == length(finobjs) || println("lengths not equal")

    verbose && print_stats()
end

if !isinteractive()
    main(CDLL)
    main(BaseQueue)
    main(WSQueue)
    main(CDLL)
    main(BaseQueue)
    main(WSQueue)
end