module WorkstealingQueues

include("CDLL.jl")
using .JavaList
export CDLL, pushlast!, pushfirst!, pop!, steal!

end