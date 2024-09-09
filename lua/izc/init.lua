if SERVER then
	print("Initializing izc on the server")
	include("izc/lib/networking.lua")
	include("izc/system/core.lua")
	AddCSLuaFile("izc/lib/constants.lua")
	AddCSLuaFile("izc/lib/util.lua")
	AddCSLuaFile("izc/lib/material.lua")
	AddCSLuaFile("izc/lib/shared.lua")
	AddCSLuaFile("izc/system/cl_core.lua")
else
	print("Initializing izc on the client")
	include("izc/system/cl_core.lua")
end
