local runService = game:GetService("RunService")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")

local isServer = runService:IsServer()
local attemptDoorActivated: RemoteFunction
local attemptDoorLocked: RemoteFunction
local replicateDoorActivated: RemoteEvent
local replicateDoorLocked: RemoteEvent
local localPlayer = players.LocalPlayer

local function assignAttributeToObject(object, instance: Instance, attributeName: string, expectedType: string)
	local attributeValue = instance:GetAttribute(attributeName)
	if attributeValue then
		local attributeValueType = typeof(attributeValue)
		if attributeValueType == expectedType then
			object[attributeName] = attributeValue
		end
	end
end

local activeDoors = {} :: {[Model]: door}
local door = {}
door.activationRange = 20
door.defaultAngle = 0
door.openAngle1 = 140
door.openAngle2 = 140
door.locked = false
door.__index = door

local function initializeDoorModel(model: doorModel)
	local hinge = model.Hinge
	local hitbox = model.Hitbox
	hinge.Anchored = true
	for _, modelComponent: BasePart in pairs(model:GetDescendants()) do
		if modelComponent:IsA("BasePart") then
			if modelComponent ~= hinge then
				local weldConstraint: WeldConstraint = Instance.new("WeldConstraint")
				weldConstraint.Part0 = modelComponent
				weldConstraint.Part1 = hinge
				weldConstraint.Parent = modelComponent
				if modelComponent == hitbox then
					modelComponent.CanCollide = true
				end
				modelComponent.Anchored = false
			end
		end
	end
end

local function replicateToAllExcept(event: RemoteEvent, playerWhoToggled: Player, ...)
	for _, player in pairs(players:GetPlayers()) do
		if player ~= playerWhoToggled then
			event:FireClient(player, playerWhoToggled, ...)
		end
	end
end

local function isPlayerInRangeOfDoor(player: Player, model: doorModel, maximumRange: number)
	local character = player.Character
	if character then
		local humanoid: Humanoid = character:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local rootPart = humanoid.RootPart
			if (rootPart.Position - model.Hitbox.Position).Magnitude <= maximumRange then
				return true
			end
		end
	end
end

local function isDoorModel(model: Model)
	return 
	model
	and typeof(model) == "Instance"
	and model:IsA("Model")
	and model:FindFirstChild("Hitbox")
	and model:FindFirstChild("Handle")
	and model:FindFirstChild("Lock")
	and model:FindFirstChild("Hinge"))
end

local function initializeNetwork()
	if isServer then
		attemptDoorActivated = Instance.new("RemoteFunction")
		attemptDoorActivated.Name = "attemptActivated"
		attemptDoorActivated.Parent = script
		attemptDoorLocked = Instance.new("RemoteFunction")
		attemptDoorLocked.Name = "attemptLocked"
		attemptDoorLocked.Parent = script
		replicateDoorActivated = Instance.new("RemoteEvent")
		replicateDoorActivated.Name = "replicateActivated"
		replicateDoorActivated.Parent = script
		replicateDoorLocked = Instance.new("RemoteEvent")
		replicateDoorLocked.Name = "replicateLocked"
		replicateDoorLocked.Parent = script

		attemptDoorActivated.OnServerInvoke = function(player, doorModel: doorModel)
			local doorObject = activeDoors[doorModel]
			if doorObject then
				return doorObject:toggle(player)
			end
		end

		attemptDoorLocked.OnServerInvoke = function(player, doorModel: doorModel)
			local doorObject = activeDoors[doorModel]
			if doorObject then
				return doorObject:lock(player)
			end
		end
	else
		attemptDoorActivated = script:WaitForChild("attemptActivated")
		attemptDoorLocked = script:WaitForChild('attemptLocked')
		replicateDoorActivated = script:WaitForChild("replicateActivated")
		replicateDoorLocked = script:WaitForChild("replicateLocked")

		replicateDoorActivated.OnClientEvent:Connect(function(playerWhoToggled: Player, doorModel: doorModel)
			local doorObject = activeDoors[doorModel]
			doorObject:toggle(playerWhoToggled, true)
		end)

		replicateDoorLocked.OnClientEvent:Connect(function(playerWhoToggled: Player, doorModel: doorModel)
			local doorObject = activeDoors[doorModel]
			doorObject:lock(playerWhoToggled, true)
		end)
	end
end

local function setupClientInput(self: door)
	self.activateClickDetector = Instance.new("ClickDetector")
	self.lockClickDetector = Instance.new("ClickDetector")
	self.activateClickDetector.MaxActivationDistance = self.activationRange
	self.lockClickDetector.MaxActivationDistance = self.activationRange

	self.activateClickDetector.MouseClick:Connect(function()
		self:toggle(localPlayer)
	end)
	
	self.lockClickDetector.MouseClick:Connect(function()
		self:lock(localPlayer)
	end)

	self.activateClickDetector.Parent = self.model.Handle
	self.lockClickDetector.Parent = self.model.Lock
end

local function getTargetAngle(self: door, playerWhoOpened: Player)
	local character = playerWhoOpened.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		local hrp = humanoid.RootPart
		local hinge = self.model.Hinge
		if hinge.CFrame.RightVector:Dot((hinge.Position - hrp.Position).Unit) < 0 then
			return self.openAngle1
		else
			return -self.openAngle2
		end
	end
end

local function createDoorAnim(model: doorModel, targetCF: CFrame)
	local tween = tweenService:Create(
		model.Hinge,
		TweenInfo.new(1, Enum.EasingStyle.Exponential),
		{
			CFrame = targetCF
		}
	)
	return tween
end

local function playAndReplicateDoorAnim(self: door, targetCF: CFrame, playerWhoOpened: Player, replicating: boolean)
	local anim = createDoorAnim(
		self.model, 
		targetCF
	)
	self.transitioning = true
	anim:Play()
	if not replicating then
		task.spawn(function()
			if not attemptDoorActivated:InvokeServer(self.model) then
				anim:Cancel()
				self.opened = false
				self.model.Hinge.CFrame = targetCF
			end
		end)
	end
	if anim.PlaybackState == Enum.PlaybackState.Playing then
		anim.Completed:Wait()
	end
	self.transitioning = false
	return anim
end

local function open(self: door, playerWhoOpened: Player, replicating: boolean)
	playAndReplicateDoorAnim(
		self, 
		self.defaultCF * CFrame.Angles(0, getTargetAngle(self, playerWhoOpened), 0), 
		playerWhoOpened, 
		replicating
	)
end

local function close(self: door, playerWhoClosed: Player, replicating: boolean)
	playAndReplicateDoorAnim(
		self, 
		self.defaultCF * CFrame.Angles(0, self.defaultAngle, 0), 
		playerWhoClosed, 
		replicating
	)
end

function door.new(model: Model)
	if not isDoorModel(model) then 
		warn("Not a proper door model") 
		return
	end
	local self = setmetatable({}, door)
	self.model = model :: doorModel
	self.transitioning = false
	self.opened = false
	self.defaultCF = self.model.Hinge.CFrame
	self.locked = assignAttributeToObject(self, model, "locked", "boolean")
	self.activationRange = assignAttributeToObject(self, model, "activationRange", "number")
	self.defaultAngle = assignAttributeToObject(self, model, "defaultAngle", "number")
	self.openAngle1 = assignAttributeToObject(self, model, "openAngle1", "number")
	self.openAngle2 = assignAttributeToObject(self, model, "openAngle2", "number")
	if isServer then
		model:SetAttribute("opened", self.opened)
		model:SetAttribute("locked", self.locked)
		initializeDoorModel(self.model)
	else
		self.lockClickDetector = Instance.new("ClickDetector")
		self.activateClickDetector = Instance.new("ClickDetector")
		setupClientInput(self)
	end

	activeDoors[self.model] = self
	return self
end

function door.toggle(self: door, playerWhoToggled: Player, replicating: boolean)
	if not self.locked and isPlayerInRangeOfDoor(playerWhoToggled, self.model, self.activationRange) then
		if isServer then
			self.opened = not self.opened
			self.model:SetAttribute("opened", self.opened)
			replicateToAllExcept(replicateDoorActivated, playerWhoToggled, self.model)
			return true
		elseif not self.transitioning then
			self.opened = not self.opened
			if self.opened then
				return open(self, playerWhoToggled, replicating)
			else
				return close(self, playerWhoToggled, replicating)
			end
		end
	end
end

function door.lock(self: door, playerWhoToggled: Player, replicating: boolean)
	if isPlayerInRangeOfDoor(playerWhoToggled, self.model, self.activationRange) then
		self.locked = not self.locked
		if isServer then
			self.model:SetAttribute("locked", self.locked)
			replicateToAllExcept(replicateDoorLocked, playerWhoToggled, self.model)
			return true
		elseif not replicating then
			attemptDoorLocked:InvokeServer(self.model)
		end
	end
end

type doorModel = Model & {
	Hitbox: BasePart,
	Hinge: BasePart,
	Handle: BasePart,
	Lock: BasePart
}
type door = typeof(door.new(table.unpack(...)))

initializeNetwork()
return door
