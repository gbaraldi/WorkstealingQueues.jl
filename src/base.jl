# This file is a part of Julia. License is MIT: https://julialang.org/license

module JLBase

import Base: IntrusiveLinkedList

mutable struct Node{T}
    const item::T
    next::Union{Nothing, Node{T}}
    queue::Union{Nothing, IntrusiveLinkedList{T}}
    Node(item::T) where T = new{T}(nothing, nothing, item)
end

struct IntrusiveLinkedListSynchronized{T}
    queue::IntrusiveLinkedList{T} # Invasive list requires that T have a field `.next >: U{T, Nothing}` and `.queue >: U{ILL{T}, Nothing}`
    lock::Threads.SpinLock
    IntrusiveLinkedListSynchronized{T}() where {T} = new(IntrusiveLinkedList{T}(), Threads.SpinLock())
end
isempty(W::IntrusiveLinkedListSynchronized) = isempty(W.queue)
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
function pushfirst!(W::IntrusiveLinkedListSynchronized{T}, t::T) where T
    lock(W.lock)
    try
        pushfirst!(W.queue, t)
    finally
        unlock(W.lock)
    end
    return W
end
function pop!(W::IntrusiveLinkedListSynchronized)
    lock(W.lock)
    try
        return pop!(W.queue)
    finally
        unlock(W.lock)
    end
end
function popfirst!(W::IntrusiveLinkedListSynchronized)
    lock(W.lock)
    try
        return popfirst!(W.queue)
    finally
        unlock(W.lock)
    end
end
function list_deletefirst!(W::IntrusiveLinkedListSynchronized{T}, t::T) where T
    lock(W.lock)
    try
        list_deletefirst!(W.queue, t)
    finally
        unlock(W.lock)
    end
    return W
end


end # module 
