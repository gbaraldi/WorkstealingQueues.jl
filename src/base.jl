# This file is a part of Julia. License is MIT: https://julialang.org/license

module JLBase

import Base: IntrusiveLinkedList

import ..WorkstealingQueues: push!, pushfirst!, pushlast!, pop!, steal!

struct IntrusiveLinkedListSynchronized{T}
    queue::IntrusiveLinkedList{T} # Invasive list requires that T have a field `.next >: U{T, Nothing}` and `.queue >: U{ILL{T}, Nothing}`
    lock::Threads.SpinLock
    IntrusiveLinkedListSynchronized{T}() where {T} = new(IntrusiveLinkedList{T}(), Threads.SpinLock())
end

mutable struct Node{T}
    const item::T
    next::Union{Nothing, Node{T}}
    queue::Union{Nothing, IntrusiveLinkedList{Node{T}}}
    Node(item::T) where T = new{T}(item, nothing, nothing)
end
const BaseQueue{T} = IntrusiveLinkedListSynchronized{Node{T}}


Base.isempty(W::IntrusiveLinkedListSynchronized) = isempty(W.queue)
length(W::IntrusiveLinkedListSynchronized) = length(W.queue)
function push!(W::IntrusiveLinkedListSynchronized{T}, t::T) where T
    lock(W.lock)
    try
        push!(W.queue, t)
    finally
        unlock(W.lock)
    end
    return W
end
function pushfirst!(W::IntrusiveLinkedListSynchronized{Node{T}}, t::T) where T
    lock(W.lock)
    try
        pushfirst!(W.queue, Node(t))
    finally
        unlock(W.lock)
    end
    return W
end

# Modified from Base
function Base.popfirst!(W::IntrusiveLinkedListSynchronized)
    lock(W.lock)
    try
        if isempty(W.queue)
            return nothing
        end
        return popfirst!(W.queue).item
    finally
        unlock(W.lock)
    end
end
function steal!(W::IntrusiveLinkedListSynchronized)
    lock(W.lock)
    try
        if isempty(W.queue)
            return nothing
        end
        return pop!(W.queue).item
    finally
        unlock(W.lock)
    end
end

end # module 
