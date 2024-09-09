local IZCUtil = {}

-- https://subscription.packtpub.com/book/game-development/9781849515504/1/ch01lvl1sec14/extending-ipairs-for-use-in-sparse-arrays
function IZCUtil.ipairs_sparse(t)
	-- tmpIndex will hold sorted indices, otherwise
	-- this iterator would be no different from pairs iterator
	local tmpIndex = {}
	local index, _ = next(t)
	while index do
		tmpIndex[#tmpIndex + 1] = index
		index, _ = next(t, index)
	end

	-- sort table indices
	table.sort(tmpIndex)
	local j = 1
	-- get index value
	return function()
		local i = tmpIndex[j]
		j = j + 1
		if i then
			return i, t[i]
		end
	end
end

return IZCUtil
