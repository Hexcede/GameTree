-- GameTree.lua by Hexcede
--[[
	This script gathers a list of Instances and puts them into a script in the workspace
--]]

local onlyScripts = true -- Only find scripts? (LuaSourceContainers)
local ignoreModules = true -- Should modules be excluded? (Recommended)
local slowMode = true -- You should probably keep this enabled. With this disabled the game will probably freeze.
local detectRequiresNonNumeric = false -- Should non-numeric required be detected?
local detectIsStudio = true -- Should IsStudio calls be detected?
local detectLoadstring = false -- Should loadstring references be detected?
local detectStoreRequire = true -- Should storing require in a variable be detected?

local testMode = false -- Test mode

if testMode then
	detectRequiresNonNumeric = true
	detectLoadstring = true
end

-- NOT IMPLEMENTED --
local detectUnwantedKeywords = true -- Should unwanted keywords be detected? (See keyword list below)
---------------------

local slowModeIter = 200 -- How many iterations before yielding when slowMode is enabled?

local unwantedKeywords = {
	["virus"] = true,
	["the creator of this place thanks"] = {WhiteSpace = true},
	["backdoor"] = true,
	["back door"] = {WhiteSpace = true},
	["Instance.new(\"Message\")"] = {Case = true, Symbol = true, Quotes = true},
	["Instance.new(\"Hint\")"] = {Case = true, Symbol = true, Quotes = true}
}

local tokenCache = {}
local function getTokens(source)
	if tokenCache[source] then
		return tokenCache[source]
	end
	local tokenMatch = "([%s]*[%w%p]+[%s]*)"
	local tokens = {}
	source:gsub(tokenMatch, function(token)
		if token then
			table.insert(tokens, token)
		end
		return ""
	end)

	tokenCache[source] = tokens

	return tokens
end

local largestKeywordTokenSize = 0
local unwantedKeywordsProcessed = {}

local function cleanToken(token)
	local tokens = {}
	token:gsub("[%s]*(%w+)[%s]*", function(token)
		if token then
			table.insert(tokens, token)
		end
		return ""
	end)
	return tokens
end

if detectUnwantedKeywords then
	for keyword, setting in pairs(unwantedKeywords) do
		if typeof(setting) == "boolean" and setting then
			setting = {}
		else
			setting = nil
		end

		if setting then
			local tokens = getTokens(keyword)

			if #tokens > largestKeywordTokenSize then
				largestKeywordTokenSize = #tokens
			end

			setting.Keyword = keyword

			unwantedKeywordsProcessed[tokens] = setting
		end
	end
end

local function scan(source)
	local tokens = getTokens(source)

	local warnings = {}

	local cleanTokens = {}
	for index, tokenUnclean in pairs(tokens) do
		local newTokens = cleanToken(tokenUnclean)
		table.insert(cleanTokens, {Unclean=tokenUnclean, RealIndex=index})
		for _, token in ipairs(newTokens) do
			table.insert(cleanTokens, {Token=token, RealIndex=index})
		end
	end

	for cleanIndex, tokenData in pairs(cleanTokens) do
		local index = tokenData.RealIndex
		local token = tokenData.Token
		local tokenUnclean = tokenData.Unclean
		if token then
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
					table.insert(warnings, "References require with non-numeric id!")
				end
			elseif token == "getfenv" or token == "setfenv" then
				table.insert(warnings, "References fenv functions! The script may be running obfuscated code meaning some detections may not work.")
			elseif token == "HttpService" then
				table.insert(warnings, "References HttpService!")
			elseif detectIsStudio and token == "IsStudio" then
				table.insert(warnings, "References IsStudio!")
			elseif detectLoadstring and token == "loadstring" then
				table.insert(warnings, "References loadstring!")
			end
		end

		if tokenUnclean then
			if detectStoreRequire and tokenUnclean:find("=") and cleanToken(tokens[index+1])[1] == "require" then
				table.insert(warnings, "Require storage detected!")
			end
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
