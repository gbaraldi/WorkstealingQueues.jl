module WorkstealingQueues

import Base: push!, pushfirst!, pop!

# Base API
function push! end
function pushfirst! end
function pushlast! end
function pop! end
function steal! end

export push!, pushfirst!, pop!, steal!, pushlast!

include("CDLL.jl")
import .JavaList: CDLL
export CDLL

include("base.jl")
import .JLBase: BaseQueue
export BaseQueue

include("CLL.jl")
import .CLL: WSQueue
export WSQueue

end