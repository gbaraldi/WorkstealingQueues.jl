# WorkstealingQueues.jl
Repo for comparing implementations of workstealing queues with julia

The expected interface for a queue is `Queue{T}()` for instantiation, `push!(q::Queue{T}, x::T)` for pushing an element to the queue, `steal!(q::Queue{T})::T` for popping an element from the back of the queue, `steal!` needs to be safe to be called from multiple threads while `pop!` only needs to be correct for the thread that owns the queue. Also `isempty(q::Queue{T})::Bool` for checking if the queue is empty.