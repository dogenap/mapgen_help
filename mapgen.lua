local Players = game:GetService("Players")
local hallwaysFolder = game.ReplicatedStorage:WaitForChild("Hallways")
local cleanupFolder = workspace:WaitForChild("Cleanup")
local unlockEvent = game.ReplicatedStorage:WaitForChild("Unlock")
local safeRoom = workspace:WaitForChild("saferoom")

local backroomsPackage = hallwaysFolder:FindFirstChild("BackroomsPackage")
local straightTemplate = backroomsPackage:FindFirstChild("Straight")
local turnTemplate    = backroomsPackage:FindFirstChild("Turn")   -- add this model to BackroomsPackage
local safeRoomTemplate = hallwaysFolder:WaitForChild("SafeRoom")
local trigger = safeRoom:WaitForChild("spawn"):WaitForChild("Trigger")

local fired = false
local NUM_TO_SPAWN = math.random(10, 20)
local TURN_CHANCE  = 0.2  -- 20% chance any given segment is a turn

-- Returns the CFrame of a named node relative to the model's pivot.
-- The node should be a Part or Attachment named entryNode / exitNode.
local function getNodeLocalCF(template, nodeName)
	local node = template:FindFirstChild(nodeName, true)
	if not node then
		warn("[Hallway] Node not found: " .. nodeName .. " in " .. template.Name)
		return CFrame.new()
	end
	-- node.CFrame works for both Part and Attachment
	return template:GetPivot():ToObjectSpace(node.CFrame)
end

-- Places `template` so that its entryNode aligns with `exitCF` (world CFrame).
-- Returns the spawned model and the world CFrame of its exitNode.
local function spawnAndChain(template, exitCF, entryLocalCF, exitLocalCF)
	local piece = template:Clone()
	-- Align the piece so entryNode lands exactly on exitCF
	piece:PivotTo(exitCF * entryLocalCF:Inverse())
	piece.Parent = cleanupFolder
	-- World CFrame of this piece's exit, ready for the next piece
	local nextExitCF = piece:GetPivot():ToWorldSpace(exitLocalCF)
	return piece, nextExitCF
end

local function generateHallway(startCF)
	task.defer(function()
		-- Pre-cache all local node CFrames (read from templates once)
		local strEntry = getNodeLocalCF(straightTemplate,  "entryNode")
		local strExit  = getNodeLocalCF(straightTemplate,  "exitNode")
		local trnEntry = getNodeLocalCF(turnTemplate,      "entryNode")
		local trnExit  = getNodeLocalCF(turnTemplate,      "exitNode")
		local srEntry  = getNodeLocalCF(safeRoomTemplate,  "exitNode")
		

		-- Seed the chain from the starting safeRoom's exitNode
		local exitNode = safeRoom:FindFirstChild("exitNode", true)
		local currentExitCF = exitNode and exitNode.CFrame or startCF

		for i = 1, NUM_TO_SPAWN do
			task.wait()
			if math.random() < TURN_CHANCE then
				_, currentExitCF = spawnAndChain(turnTemplate,     currentExitCF, trnEntry, trnExit)
			else
				_, currentExitCF = spawnAndChain(straightTemplate, currentExitCF, strEntry, strExit)
			end
		end

		task.wait()
		-- Attach the exit safeRoom so its entryNode lines up with the last exitNode
		local newSafeRoom = safeRoomTemplate:Clone()
		newSafeRoom.Name = "SafeRoom0"
		newSafeRoom:PivotTo(currentExitCF * srEntry:Inverse())
		newSafeRoom.Parent = cleanupFolder

		unlockEvent:Fire()
		print("Spawned", NUM_TO_SPAWN, "hallway segments + 1 saferoom")
	end)
end

trigger.Touched:Connect(function(hit)
	print("Triggered");
	if fired then return end
	fired = true
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		fired = false
		return
	end
	generateHallway(safeRoom:GetPivot())
end)
