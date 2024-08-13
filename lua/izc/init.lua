if SERVER then
    print("Initializing izc on the server")
    include("izc/lib/networking.lua")
    include("izc/lib/material.lua")
    include("izc/lib/shared.lua")
    include("izc/system/core.lua")
else
    print("Initializing izc on the client")
    include("izc/lib/util.lua")
    include("izc/lib/material.lua")
    include("izc/lib/shared.lua")
    include("izc/system/cl_core.lua")
end