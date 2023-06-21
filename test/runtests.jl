using WorkstealingQueues

mutable struct Foo
    should_push::Bool
end

const wsqueues = (ConcurrentDoublyLinkedList{Foo}(), ConcurrentDoublyLinkedList{Foo}(), ConcurrentDoublyLinkedList{Foo}(), ConcurrentDoublyLinkedList{Foo}())

function do_work(n::Int64)
    wsqueue = wsqueues[n]
    cnt = 1
    failed_steals = 0
    while failed_steals < 10
        foo = popfirst!(wsqueue)
        if foo === nothing
            for i in 1:4
                if cnt == n
                    cnt = mod1(cnt + 1, 4)
                    continue
                end
                foo = poplast!(wsqueues[cnt])
                cnt = mod1(cnt + 1, 4)
                if foo !== nothing
                    @info "stole! $n"
                    failed_steals = 0
                    @goto found
                end
                @info "failed steal $n"
                failed_steals += 1
            end
            continue
        end
        @info "popped! $n"
        @label found
        if foo.should_push
            @info "push! $n"
            sleep(0.01)
            pushlast!(wsqueue, Foo(rand() > 0.51))
        end
    end
end

for j in 2:4
    for i in 1:rand(2:100)
        pushfirst!(wsqueues[j], Foo(rand() > 0.8))
    end
end

function parallel_work()
    for i in 1:4
        Threads.@spawn do_work(i)
    end
end