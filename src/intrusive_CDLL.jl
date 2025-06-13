

module IntrusiveConcurrentList #Concurrent Doubly Linked List



import ..WorkstealingQueues: push!, pushfirst!, pushlast!, pop!, steal!
mutable struct SpecialNode{T}
    const value::Nothing
    @atomic next_atomic::Union{SpecialNode{T}, T, Nothing}
    @atomic prev_atomic::Union{SpecialNode{T}, T, Nothing}
    function SpecialNode{T}(value, next, prev) where T
        this = new{T}(value, next, nothing)
        @atomic :release this.prev_atomic = prev
        return this
    end
    function SpecialNode(next::Union{SpecialNode{T}, T, Nothing}) where T # Marker
        this = new{T}(nothing, next, nothing)
        @atomic :release this.prev_atomic = this
        return this
    end
end

# A sum type would make this so nice :(
const Node{T} = Union{SpecialNode{T}, T}

@inline function make_node(value::T, next, prev) where {T}
    if T === Nothing
        error("This should've been a SpecialNode")
    end
    value.next_atomic !== nothing || value.prev_atomic !== nothing && error("value is already in a list")
    @atomic :monotonic value.next_atomic = next
    @atomic :release value.prev_atomic = prev
    return value
end


get_next(node::Node{T}) where {T} = (@atomic :acquire node.next_atomic)
set_next(node::Node, next) = @atomic :release node.next_atomic = next
get_prev(node::Node{T}) where {T} = (@atomic :acquire node.prev_atomic)
set_prev(node::Node, prev) = @atomic :release node.prev_atomic = prev
function cas_next(node::Node{T}, exp::Node{T}, desired::Node{T}) where {T}
    _,success = @atomicreplace :acquire_release :monotonic node.next_atomic exp => desired
    return success
end

is_special(node::SpecialNode) = true
is_special(node) = false
is_trailer(node::Node) = get_next(node) === nothing
is_header(node::Node) = get_prev(node) === nothing
is_marker(node::Node) = get_prev(node) === node

@inline function is_deleted(node::Node)
    f = get_next(node)
    return f !== nothing && is_marker(f)
end

@inline function next_nonmarker(node::Node)
    f = get_next(node)
    return (f === nothing || !is_marker(f)) ? f : get_next(f)
end

# function Base.show(io::IO, node::Node)
#     if is_special(node)
#         if is_marker(node)
#             print(io, "MarkerNode")
#             return
#         elseif is_header(node)
#             next = get_next(node)
#             if next === nothing
#                 print(io, "BrokenNode()")
#                 return
#             elseif is_marker(node)
#                 print(io, "HeaderNode(next: MarkerNode)")
#                 return
#             elseif is_trailer(next)
#                 print(io, "HeaderNode(next: TrailerNode)")
#                 return
#             end
#             print(io, "HeaderNode(next: ", next,")")
#             return
#         elseif is_trailer(node)
#             prev = get_prev(node)
#             if prev === nothing
#                 print(io, "BrokenNode()")
#                 return
#             elseif is_marker(node)
#                 print(io, "TrailerNode(prev: MarkerNode)")
#                 return
#             elseif is_header(prev)
#                 print(io, "TrailerNode(prev: HeaderNode)")
#                 return
#             end
#             print(io, "TrailerNode(prev: ", prev,")")
#             return
#         end
#     end
#     print(io, "Node(", node.value,")")
# end

@inline function successor(node::Node)
    f = next_nonmarker(node)
    while true
        if f === nothing
            return nothing
        end
        if !is_deleted(f)
            if get_prev(f) !== node && !is_deleted(node)
                set_prev(f, node) # relink f to node
            end
            return f
        end
        s = next_nonmarker(f)
        if f === get_next(node)
            cas_next(node, f, s)
        end
        f = s
    end
end

@inline function find_predecessor_of(node::Node{T}, target::Node{T}) where {T}
    n = node
    while true
        f = successor(n)
        if (f === target)
            return n
        end
        if (f === nothing)
            return nothing
        end
        n = f
    end
end

@inline function predecessor(node::Node)
    n = node
    while true
        b = get_prev(n)
        if (b === nothing)
            return find_predecessor_of(n, node)
        end
        s = get_next(b)
        if (s === node)
            return b
        end
        if (s === nothing || !is_marker(s))
            p = find_predecessor_of(b, node)
            if (p !== nothing)
                return p
            end
        end
        n = b
    end
end

@inline function forward(node::Node)
    f = successor(node)
    return (f === nothing || is_special(f)) ? nothing : f
end

@inline function back(node::Node)
    f = predecessor(node)
    return (f === nothing || is_special(f)) ? nothing : f
end

@inline function append!(node::Node{T}, val::T) where {T}
    while true
        f = get_next(node)
        if (f === nothing || is_marker(f))
            return nothing
        end
        x = make_node(val, f, node)
        if cas_next(node, f, x)
            set_prev(f, x)
            return x
        end
    end
end

@inline function prepend!(node::Node{T}, val::T) where {T}
    while true
        b = predecessor(node)
        if b === nothing
            return nothing
        end
        x = make_node(val, node, b)
        if cas_next(b, node, x)
            set_prev(node, x)
            return x
        end
    end
end

@inline function delete!(node::Node{T}) where {T}
    b = get_prev(node)
    f = get_next(node)
    if (b !== nothing && f !== nothing && !is_marker(f) && cas_next(node, f, SpecialNode(f)))
        if (cas_next(b, node, f))
            set_prev(f, b)
        end
        return true
    end
    return false
end

@inline function replace!(node::Node{T}, val::T) where {T}
    while true
        b = get_prev(node)
        f = get_next(node)
        if (b === nothing || f === nothing || is_marker(f))
            return nothing
        end
        x = make_node(val, f, b)
        if cas_next(node, f, SpecialNode{T}(x))
            successor(b)
            successor(x)
            return x
        end
    end
end

@inline function usable(node::Node)
    return node !== nothing && !is_special(node)
end

const _PADDING_TUPLE = ntuple(zero, 15)
mutable struct IntrusiveConcurrentDoublyLinkedList{T}
    @atomic header::Union{Node{T}, Nothing} # 8 bytes
    padding::NTuple{15,UInt64} # 120 bytes
    @atomic trailer::Union{Node{T}, Nothing}
    padding2::NTuple{15,UInt64}
    function IntrusiveConcurrentDoublyLinkedList{T}(header::Union{Node{T}, Nothing}, trailer::Union{Node{T}, Nothing}) where {T}
        new{T}(header, _PADDING_TUPLE, trailer, _PADDING_TUPLE)
    end
end

function IntrusiveConcurrentDoublyLinkedList{T}() where {T}
    h = SpecialNode{T}(nothing, nothing, nothing)
    t = SpecialNode{T}(nothing, nothing, h)
    set_next(h, t)
    IntrusiveConcurrentDoublyLinkedList{T}(h, t)
end

const IntrusiveCDLL = IntrusiveConcurrentDoublyLinkedList

@inline function Base.pushfirst!(cdll::IntrusiveCDLL{T}, val::T) where {T}
    while (append!((@atomic :acquire cdll.header), val) === nothing)
    end
end

@inline function pushlast!(cdll::IntrusiveCDLL{T}, val::T) where {T}
    while (prepend!((@atomic :acquire cdll.trailer), val) === nothing)
    end
end

@inline function Base.popfirst!(cdll::IntrusiveCDLL{T}) where {T}
    while true
        n = successor((@atomic :acquire cdll.header))
        if !usable(n)
            return nothing
        end
        if delete!(n)
            return n::T
        end
    end
end

@inline function poplast!(cdll::IntrusiveCDLL{T}) where {T}
    while true
        n = predecessor((@atomic :acquire cdll.trailer))
        if !usable(n)
            return nothing
        end
        if delete!(n)
            return n::T
        end
    end
end

Base.push!(cdll::IntrusiveCDLL{T}, val::T) where {T} = @inline pushfirst!(cdll, val)
Base.pop!(cdll::IntrusiveCDLL) = @inline poplast!(cdll)
steal!(cdll::IntrusiveCDLL) = @inline popfirst!(cdll)
Base.isempty(cdll::IntrusiveCDLL) = !usable(successor(@atomic :acquire cdll.header))

export IntrusiveCDLL
# const Queue = CDLL
end
