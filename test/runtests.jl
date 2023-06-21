using WorkstealingQueues

mutable struct Foo
    should_push::Bool
end

mutable struct Counter
    @atomic counter::Int64
end

const pushcounter = (Counter(0), Counter(0), Counter(0), Counter(0))
const popcounter = (Counter(0), Counter(0), Counter(0), Counter(0))
const wsqueues = (CDLL{Foo}(), CDLL{Foo}(), CDLL{Foo}(), CDLL{Foo}())
const objvecs = (Vector{Foo}(), Vector{Foo}(), Vector{Foo}(), Vector{Foo}())
const initobjs = Vector{Foo}()
const finobjs = Vector{Foo}()


function print_stats()
    push_tot = 0
    pop_tot = 0
    for i in 1:4
        push_tot += pushcounter[i].counter
        pop_tot += popcounter[i].counter
        println("pushes[$i]: ", pushcounter[i].counter, " pops[$i]: ", popcounter[i].counter)
    end
    println("pushes: ", push_tot, " pops: ", pop_tot)
end

function combine_objs()
    for i in 1:4
        append!(finobjs, objvecs[i])
    end
end

function do_work(n::Int64)
    wsqueue = wsqueues[n]
    cnt = 1
    failed_steals = 0
    while failed_steals < 10
        sleep(0.001)
        foo = popfirst!(wsqueue)
        if foo === nothing
            for i in 1:4
                if cnt == n
                    cnt = mod1(cnt + 1, 4)
                    continue
                end
                foo = steal!(wsqueues[cnt])
                cnt = mod1(cnt + 1, 4)
                if foo !== nothing
                    failed_steals = 0
                    @goto found
                end
                failed_steals += 1
            end
            continue
        end
        @label found
        push!(objvecs[n], foo)
        @atomic popcounter[n].counter += 1
        if foo.should_push
            @atomic  pushcounter[n].counter += 1
            pushlast!(wsqueue, Foo(rand() > 0.51))
        end
    end
end

for j in 2:4
    for i in 1:rand(100:5000)
        foo = Foo(rand() > 0.8)
        push!(initobjs, foo)
        @atomic  pushcounter[j].counter += 1
        pushfirst!(wsqueues[j], foo)
    end
end

function parallel_work()
    @sync begin
        for i in 1:4
            Threads.@spawn do_work(i)
        end
    end
end

print_stats()

parallel_work()

for queue in wsqueues
    isempty(queue) || println("queue not empty")
end

combine_objs()

length(initobjs) == length(finobjs) || println("lengths not equal")

print_stats()