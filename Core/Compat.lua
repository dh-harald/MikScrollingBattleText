-------------------------------------------------------------------------------
-- Lua 5.0 / 5.1 shim layer (MikSBT.Compat).
--
-- The real 1.12.1 client runs Lua 5.0, Unreal Azeroth runs Lua 5.1. Every
-- helper prefers the native 5.1 function and falls back to a 5.0-safe
-- implementation. Nothing here writes to the global string/table/math
-- libraries.
--
-- Syntax that does not even parse on Lua 5.0 and must never appear in a file
-- of this addon: `...` used as an expression (use the implicit `arg` table and
-- argCount/argUnpack), the `#` length operator (use getn / string.len) and the
-- `%` modulo operator (use mod). Pattern adapted from ElvUI-UA.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local Compat = {}
MikSBT.Compat = Compat

-- Client detection. GetUECvar exists only on the Unreal engine client and 5875
-- is its interface number. Only for the few places where the same API has to
-- be driven differently per client; feature-detect everything else.
Compat.isUA = false
if GetUECvar then
	Compat.isUA = true
elseif type(GetBuildInfo) == "function" then
	local ok, _, _, _, tocVersion = pcall(GetBuildInfo)
	if ok and tonumber(tocVersion) == 5875 then
		Compat.isUA = true
	end
end

-- string.match is missing on Lua 5.0.
if string.match then
	Compat.match = string.match
else
	function Compat.match(str, pattern, index)
		local results = { string.find(str, pattern, index) }
		if not results[1] then
			return nil
		end
		if results[3] == nil then
			return string.sub(str, results[1], results[2])
		end
		table.remove(results, 1)
		table.remove(results, 1)
		return unpack(results)
	end
end

-- Lua 5.0 has string.gfind with the same iterator semantics.
Compat.gmatch = string.gmatch or string.gfind

Compat.getn = table.getn or function(t)
	local n = 0
	while t[n + 1] ~= nil do
		n = n + 1
	end
	return n
end

-- Replacements for select('#', ...) / select(i, ...) on a captured `arg` table.
function Compat.argCount(argTable)
	return argTable.n or Compat.getn(argTable)
end

function Compat.argUnpack(argTable, i, j)
	return unpack(argTable, i or 1, j or Compat.argCount(argTable))
end

-- math.mod is the Lua 5.0 name; 5.1 may only have math.fmod.
Compat.mod = math.mod or math.fmod or function(a, b)
	return a - math.floor(a / b) * b
end

-- Yes/no API returns come as 1/nil, 1/0 or true/false depending on client and
-- function. Only for flags, never for real numbers or GetCVar strings.
function Compat.bool(value)
	return value ~= nil and value ~= false and value ~= 0
end

-- Lua 5.0 remembers an array's size set by table.insert (table.setn) and
-- does not lower it when elements are set to nil, so the next table.insert
-- would leave a hole. On 5.0 the stored size is reset as well; 5.1 has no
-- stored size (and its table.setn raises an error).
-- Detected by behaviour: another addon (LibConfig-1.0 among them) may install
-- a global string.gmatch on 5.0, so the presence of 5.1 functions proves
-- nothing.
local isLua50 = table.setn ~= nil and pcall(table.setn, {}, 0)
Compat.isLua50 = isLua50

-- Empties a table in place (table.wipe is missing on both clients). Safe for
-- arrays filled with table.insert.
function Compat.wipe(t)
	for k in pairs(t) do
		t[k] = nil
	end
	if isLua50 then
		table.setn(t, 0)
	end
	return t
end

-- Appends a value to an array without the # operator.
function Compat.push(t, value)
	t[Compat.getn(t) + 1] = value
end

-- Plain-text split into a new array.
function Compat.split(text, delimiter)
	local result = {}
	local start = 1
	local s, e = string.find(text, delimiter, start, true)
	while s do
		table.insert(result, string.sub(text, start, s - 1))
		start = e + 1
		s, e = string.find(text, delimiter, start, true)
	end
	table.insert(result, string.sub(text, start))
	return result
end
