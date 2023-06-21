# This file is a part of Julia. License is MIT: https://julialang.org/license

module DoubleLink

# Double Linked Queue
#
# Double Linked Queue based on the short paper by Andreia Correia and Pedro Ramalhete
# https://github.com/pramalhe/ConcurrencyFreaks/blob/master/papers/doublelink-2016.pdf

mutable struct Node{T}
    next::Union{Nothing, Node{T}}
    prev::Union{Nothing, Node{T}}
    const item::T
    Node(item::T) where T = new{T}(nothing, nothing, item)
    Node{T}() where T = new{T}(nothing, nothing)
end

mutable struct DoubleLinkQueue{T}
    @atomic head::Node{T}
    @atomic tail::Node{T}
    function DoubleLinkQueue{T}() where T
        prevSentinel = Node{T}()
        startSentinel = Node{T}()
        startSentinel.prev = prevSentinel
        prevSentinel.next = startSentinel
        new(startSentinel, startSentinel)
    end
end

function enqueue!(q::DoubleLinkQueue{T}, item::T) where T
    node = Node(item)
    while true
        ltail = @atomic q.tail
        lprev = ltail.prev
        # Help the previous enqueue to complete
        if lprev.next === nothing && lprev !== ltail
            lprev.next = ltail
        end
        node.prev = ltail
        _, success = @atomicreplace q.tail ltail => node
        if success
            ltail.next = node
            return
        end
    end
end

function dequeue!(q::DoubleLinkQueue{T}) where T
    while true
        lhead = @atomic q.head
        ltail = @atomic q.tail
        lprev = ltail.prev
        # Help the previous enqueue to complete
        if lprev.next === nothing && lprev !== ltail
            lprev.next = ltail
        end        
        if lhead == ltail || lnext === nothing
            return nothing # queue is empty
        end
        if lnext == lhead
            continue # Re-read head if it's self-linked
        end 

        _, success = @atomicreplace q.head lhead => lnext
        if success
            lnext.prev = lnext
            lhead.next = lhead
            return lnext.item
        end
    end
end

end # module
