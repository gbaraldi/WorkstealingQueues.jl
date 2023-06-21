using WorkstealingQueues

mutable struct Foo
    should_push::Bool
end

mutable struct Counter
    @atomic counter::Int64
end

const pushcounter = Counter(0)
const popcounter = (Counter(0), Counter(0))
const wsqueue = CDLL{Foo}()
const objvecs = (Vector{Foo}(), Vector{Foo}())
const initobjs = Vector{Foo}()
const finobjs = Vector{Foo}()

const done = Ref(0)
usleep(x) = @ccall usleep(x::UInt32)::Cint

for i in 1:5000
    foo = Foo(rand() > 0.8)
    push!(initobjs, foo)
    @atomic :monotonic pushcounter.counter += 1
    pushfirst!(wsqueue, foo)
end

function pusher()
    for i in 1:5000
        usleep(50)
        foo = Foo(rand() > 0.51)
        pushfirst!(wsqueue, foo)
        @atomic :monotonic pushcounter.counter += 1
    end
    done[] = 1
end

function popper()
    while !isempty(wsqueue) || done[] == 0
        foo = popfirst!(wsqueue)
        usleep(50)
        if foo === nothing
            continue
        end
        push!(objvecs[1], foo)
        @atomic :monotonic popcounter[1].counter += 1
    end
end

function stealer()
    while !isempty(wsqueue) || done[] == 0
        foo = steal!(wsqueue)
        usleep(50)
        if foo === nothing
            continue
        end
        push!(objvecs[2], foo)
        @atomic :monotonic popcounter[2].counter += 1
    end
end

function parallel_job()
    @sync begin
        Threads.@spawn pusher()
        Threads.@spawn pusher()
        Threads.@spawn stealer()
    end
end

parallel_job()

if (popcounter[1].counter+popcounter[2].counter) != pushcounter.counter
    println("Something went wrong")
else
    println("All good")
end
