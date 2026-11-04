--!nocheck
-- Falls back to an in-memory store when DataStores are unavailable
-- (e.g. Studio with API access disabled or an unpublished file).
local DataStoreService = game:GetService("DataStoreService")

local SafeDataStore = {}

local function memoryStore()
	local data = {}
	local m = {}
	function m:GetAsync(k)
		return data[k]
	end
	function m:SetAsync(k, v)
		data[k] = v
	end
	function m:RemoveAsync(k)
		local v = data[k]
		data[k] = nil
		return v
	end
	function m:UpdateAsync(k, fn)
		local v = fn(data[k])
		if v ~= nil then
			data[k] = v
		end
		return data[k]
	end
	function m:GetSortedAsync()
		return {
			IsFinished = true,
			GetCurrentPage = function()
				return {}
			end,
			AdvanceToNextPageAsync = function() end,
		}
	end
	return m
end

function SafeDataStore.Get(name: string, ordered: boolean?)
	local ok, store = pcall(function()
		if ordered then
			return DataStoreService:GetOrderedDataStore(name)
		end
		return DataStoreService:GetDataStore(name)
	end)
	if ok and store then
		local probeOk, err = pcall(function()
			store:GetAsync("__probe")
		end)
		if probeOk then
			return store
		end
		warn("[SafeDataStore] DataStore kullanılamıyor, bellek içi kayıt:", err)
	end
	return memoryStore()
end

return SafeDataStore
