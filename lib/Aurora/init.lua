local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Resources = require(ReplicatedStorage:WaitForChild("Resources"))

local Registerable = require(script.Registerable)
local AuraAgent = Resources:LoadLibrary("AuraAgent")

local SyncEvent = Resources:GetRemoteEvent(".Aurora")
local SyncFunction = Resources:GetRemoteFunction(".Aurora")
local IsServer = RunService:IsServer()

-- Library

local Aurora = {
	Auras = Registerable.new("Auras");
	Effects = Registerable.new("Effects");
	TickRate = 0.5;
	SafeMemoryMode = true;
	MaxAgentTimeInactive = math.huge;
	SyncActionIndex = -1;
	InitialSyncCompleted = IsServer;
}

local Agents = setmetatable({}, {
	__mode = "k";
	__index = function(self, instance)
		local agent = AuraAgent.new(instance, Aurora.Auras, Aurora.Effects, IsServer and Aurora.SyncAction)
		self[instance] = agent
		return agent
	end
})

function Aurora.GetAgent(instance)
	return Agents[instance]
end

function Aurora.RegisterAurasIn(object)
	Aurora.Auras:LookIn(object)
end

function Aurora.RegisterEffectsIn(object)
	Aurora.Effects:LookIn(object)
end

function Aurora.SetTickRate(seconds)
	Aurora.TickRate = seconds
end

function Aurora.SetSafeMemoryMode(mode)
	Aurora.SafeMemoryMode = mode
end

function Aurora.SetMaxAgentTimeInactive(seconds)
	Aurora.MaxAgentTimeInactive = seconds
end

function Aurora.SyncAction(agent, method, ...)
	Aurora.SyncActionIndex = Aurora.SyncActionIndex + 1
	SyncEvent:FireAllClients({
		Type = "SyncAction";
		ActionIndex = Aurora.SyncActionIndex;
		Payload = {
			Instance = agent.Instance;
			Method = method;
			Args = {...}
		}
	})
end

--- Creates a snapshot of every agent's auras as they are in this moment
-- to be sent to a newly connected client (agents with no auras are excluded)
function Aurora.Snapshot()
	local snapshot = {}
	for instance, agent in pairs(Agents) do
		local agentSnapshot = agent:Snapshot()

		if agentSnapshot then
			snapshot[#snapshot + 1] = {
				Instance = instance;
				Auras = agentSnapshot;
			}
		end
	end
	return snapshot
end

-- Event connections

if IsServer then
	local lastRequest = {}
	SyncFunction.OnServerInvoke = function (player)
		-- rate limit
		if lastRequest[player] and tick() - lastRequest[player] < 60 then
			return nil
		end
		lastRequest[player] = tick()

		return Aurora.Snapshot()
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
else
	require(script.ClientNetwork)(Aurora)
end

Aurora.RegisterAurasIn(script.BuiltInAuras)
Aurora.RegisterEffectsIn(script.BuiltInEffects)

-- Update loop

spawn(function()
	while true do
		local dt = wait(Aurora.TickRate)

		for instance, agent in pairs(Agents) do
			if
				agent.TimeInactive > Aurora.MaxAgentTimeInactive
				or (
					Aurora.SafeMemoryMode == true
					and not agent.Destroyed
					and instance:IsDescendantOf(game) == false
				)
			then
				-- dump agents referring to instances that are not parented to the game tree
				agent:Destroy()
				Agents[instance] = nil
			elseif agent.Destroyed then
				-- agent was destroyed externally
				Agents[instance] = nil
			else
				agent:Update(dt)
			end
		end
	end
end)

return Aurora