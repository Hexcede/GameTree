-- GameTree.lua by Hexcede
--[[
	This script gathers a list of Instances and puts them into a script in the workspace
--]]

local onlyScripts = true -- Only find scripts? (LuaSourceContainers)
local ignoreModules = true -- Should modules be excluded? (Recommended)
local slowMode = true -- You should probably keep this enabled. With this disabled the game will probably freeze.
local detectRequiresNonNumeric = false -- Should non-numeric required be detected?

local slowModeIter = 200 -- How many iterations before yielding when slowMode is enabled?

local function getTokens(source)
	local tokenMatch = "[%w%p]-([%a%d]+)[%w%p]-"
	local tokens = {}
	source:gsub(tokenMatch, function(token)
		if token then
			table.insert(tokens, token)
		end
		return ""
	end)
	return tokens
end
local function scan(source)
	local tokens = getTokens(source)

	local warnings = {}
	for index, token in pairs(tokens) do
		if token == "require" then
			local offset = 1
			local number = ""
			while tonumber(tokens[index+offset]) do
				number = number..tokens[index+offset]
				offset = offset + 1
			end
			if tonumber(number) then
				table.insert(warnings, "References require with numeric id! Numeric id: "..tostring(number))
			elseif detectRequiresNonNumeric then
				table.insert(warnings, "References require!")
			end
		elseif token == "getfenv" or token == "setfenv" then
			table.insert(warnings, "References fenv functions! The script may be running obfuscated code.")
		elseif token == "HttpService" then
			table.insert(warnings, "References HttpService!")
		end
	end
	return warnings
end
local function getPath(instance)
	local function stringEscape(str)
		return str:gsub("'", "\\'")
	end

	local path = ""
	local currentInstance = instance
	while currentInstance do
		path = path.."['"..stringEscape(currentInstance.Name).."' {"..currentInstance.ClassName.."}]"
		currentInstance = currentInstance.Parent
	end

	if instance:IsA("LuaSourceContainer") then
		pcall(function()
			local warnings = scan(instance.Source)
			for _, warning in ipairs(warnings) do
				path = path.."\n\t[!] "..warning
			end
		end)
	end

	return path
end

local Selection = game:GetService("Selection")
local instanceListExport = Instance.new("ModuleScript")
instanceListExport.Name = "Instance List"

local progressIndicator = Instance.new("Message") -- Don't use this for your game. I'm just super lazy and didn't want to make a GUI.
progressIndicator.Archivable = false

progressIndicator.Parent = workspace

local instanceList = ""
local iterations = 0
local descendants = game:GetDescendants()
local totalIterations = #descendants
for _, instance in ipairs(descendants) do
	iterations = iterations + 1

	if slowMode then
		if iterations%slowModeIter == 0 then
			wait()
		end
	end

	progressIndicator.Text = "Scanning "..(math.floor(iterations/totalIterations*1000)/10).."% complete..."

	pcall(function()
		local shouldKeep = (onlyScripts and instance:IsA("LuaSourceContainer") and not instance:IsA("CoreScript")) or not onlyScripts
		if shouldKeep and ignoreModules and instance:IsA("ModuleScript") then
			shouldKeep = false
		end

		if shouldKeep then
			instanceList = instanceList..getPath(instance).."\n"
		end
	end)
end

instanceListExport.Source = instanceList
instanceListExport.Parent = workspace

progressIndicator:Destroy()

Selection:Set({instanceListExport})
warn("A list of instances has been placed in the Workspace and selected.")
