--[[
	LIFECYCLE API

	Lifecycle is a cleanup / ownership utility for Roblox systems.

	It lets you track connections, loops, tasks, instances, callbacks,
	tables, and temporary objects, then clean them manually or automatically.

	Core idea:
	- A Lifecycle owns resources.
	- A resource can also be bound to an Instance.
	- When that Instance is destroyed, every resource bound to it is cleaned.

	------------------------------------------------------------
	BASIC SETUP
	------------------------------------------------------------

	local Lifecycle = require(path.to.Lifecycle)

	local life = Lifecycle.new("MySystem")

	------------------------------------------------------------
	BASIC CLEANUP
	------------------------------------------------------------

	life:Add(value, method?, groupName?)
	life:Give(value, method?, groupName?)

	Tracks a value for cleanup.

	Supported values:
	- RBXScriptConnection
	- Instance
	- thread
	- function
	- table with :Destroy()
	- table with :Disconnect()
	- table with :Stop()
	- table with :Clean()

	Examples:

	local connection = RunService.Heartbeat:Connect(function(dt)
		print(dt)
	end)

	life:Add(connection, nil, "Loops")

	local part = Instance.new("Part")
	part.Parent = workspace

	life:Add(part, "Destroy", "TemporaryParts")

	------------------------------------------------------------
	CONNECTIONS
	------------------------------------------------------------

	life:Connect(signal, callback, groupName?)

	Connects a signal and tracks the connection.

	Example:

	life:Connect(workspace.ChildAdded, function(child)
		print(child.Name)
	end, "World")

	life:Once(signal, callback, groupName?)

	Connects once, then disconnects after the first call.

	------------------------------------------------------------
	INSTANCE-BOUND CLEANUP
	------------------------------------------------------------

	life:BindToInstance(instance, value, method?, groupName?)
	life:Bind(instance, value, method?, groupName?)

	Binds a resource to an Instance.
	When the Instance is destroyed, the resource is cleaned automatically.

	Example:

	local loop = RunService.RenderStepped:Connect(function(dt)
		print(dt)
	end)

	life:BindToInstance(part, loop, nil, "PartLoop")

	When part is destroyed, loop is disconnected automatically.

	------------------------------------------------------------
	INSTANCE-BOUND CONNECTIONS
	------------------------------------------------------------

	life:ConnectFor(instance, signal, callback, groupName?)
	life:LoopFor(instance, signal, callback, groupName?)

	Connects a signal and binds it to an Instance.
	When the Instance is destroyed, the connection is disconnected.

	Example:

	life:ConnectFor(character, RunService.RenderStepped, function(dt)
		print("Character render:", dt)
	end, "CharacterRender")

	life:ConnectFor(character, humanoid.Died, function()
		print("Dead")
	end, "CharacterEvents")

	------------------------------------------------------------
	INSTANCE-BOUND TASKS / OBJECTS
	------------------------------------------------------------

	life:BindConnection(instance, connection, groupName?)
	life:BindTask(instance, thread, groupName?)
	life:BindObject(instance, object, method?, groupName?)

	Examples:

	life:BindConnection(character, connection, "Character")

	life:BindObject(character, temporaryFolder, "Destroy", "Character")

	------------------------------------------------------------
	CREATE / CLONE
	------------------------------------------------------------

	life:Create(className, props?, parent?, groupName?)

	Creates an Instance and tracks it.

	Example:

	local folder = life:Create("Folder", {
		Name = "TempFolder"
	}, workspace, "Instances")

	life:CreateForInstance(ownerInstance, className, props?, parent?, groupName?)

	Creates an Instance and binds it to another Instance.

	Example:

	local highlight = life:CreateForInstance(character, "Highlight", {
		FillTransparency = 0.5
	}, character, "CharacterVisuals")

	When character is destroyed, highlight is destroyed.

	life:Clone(template, parent?, groupName?)
	life:CloneForInstance(ownerInstance, template, parent?, groupName?)

	------------------------------------------------------------
	TASKS
	------------------------------------------------------------

	life:Defer(callback, groupName?)
	life:Delay(seconds, callback, groupName?)
	life:Spawn(callback, groupName?)

	Runs a task and tracks it.

	life:Loop(interval, callback, groupName?)

	Runs a repeating task while the Lifecycle is alive.
	Return false from the callback to stop the loop.

	Example:

	life:Loop(1, function(dt)
		print("Tick")
	end, "Loops")

	life:LoopToInstance(instance, interval, callback, groupName?)

	Runs a repeating task bound to an Instance.
	When the Instance is destroyed, the loop stops.

	------------------------------------------------------------
	SCOPES
	------------------------------------------------------------

	life:Scope(name)

	Creates a child Lifecycle.
	When the parent is destroyed, the child is destroyed too.

	Example:

	local npcLife = life:Scope("NPC_01")

	life:CreateInstanceScope(instance, groupName?)

	Creates a child Lifecycle bound to an Instance.

	Example:

	local characterLife = life:CreateInstanceScope(character, "Characters")

	When character is destroyed, characterLife is destroyed.

	------------------------------------------------------------
	GROUP CLEANUP
	------------------------------------------------------------

	life:ClearGroup(groupName)
	life:DisconnectGroup(groupName)
	life:DestroyGroup(groupName)

	Cleans only one group.

	Example:

	life:ClearGroup("RenderLoops")

	life:ClearExcept({ "Permanent", "UI" })

	Cleans everything except the listed groups.

	------------------------------------------------------------
	INSTANCE CLEANUP
	------------------------------------------------------------

	life:ClearInstance(instance)

	Manually clears everything bound to one Instance.

	------------------------------------------------------------
	VALUES
	------------------------------------------------------------

	life:SetValue(key, value)
	life:GetValue(key, default?)
	life:ClearValue(key)

	Stores temporary values inside the Lifecycle.

	------------------------------------------------------------
	DESTROY
	------------------------------------------------------------

	life:Clean()

	Cleans all tracked resources but keeps the Lifecycle reusable.

	life:Destroy()

	Cleans all tracked resources and permanently marks the Lifecycle as dead.

	life:IsAlive()

	Returns true if the Lifecycle is still active.

	------------------------------------------------------------
	RECOMMENDED STRUCTURE
	------------------------------------------------------------

	Use one Lifecycle per major system:

	- ServerBoot
	- ClientBoot
	- PlaneSpawner
	- NPCService
	- WeatherService
	- DisasterService
	- UIController
	- CharacterController

	Use groups:

	- "Connections"
	- "RenderLoops"
	- "HeartbeatLoops"
	- "Instances"
	- "Character"
	- "Plane"
	- "NPC"
	- "Effects"
	- "Temporary"

	This makes debugging much easier:
	you can disable one group or one system without leaving leaks behind.
]]

local Lifecycle = {}
Lifecycle.__index = Lifecycle

local function isConnection(value)
	return typeof(value) == "RBXScriptConnection"
end

local function isInstance(value)
	return typeof(value) == "Instance"
end

local function isThread(value)
	return typeof(value) == "thread"
end

local function safeCall(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Lifecycle] Cleanup error:", err)
	end
end

local function cleanupItem(item)
	if not item or item.Cleaned then
		return
	end

	item.Cleaned = true

	local value = item.Value
	local method = item.Method

	if value == nil then
		return
	end

	if method then
		if type(method) == "function" then
			safeCall(method, value)
			return
		end

		if type(method) == "string" and value[method] then
			safeCall(function()
				value[method](value)
			end)
			return
		end
	end

	if isConnection(value) then
		if value.Connected then
			value:Disconnect()
		end
		return
	end

	if isInstance(value) then
		value:Destroy()
		return
	end

	if isThread(value) then
		safeCall(task.cancel, value)
		return
	end

	if type(value) == "function" then
		safeCall(value)
		return
	end

	if type(value) == "table" then
		if type(value.Destroy) == "function" then
			safeCall(function()
				value:Destroy()
			end)
			return
		end

		if type(value.Disconnect) == "function" then
			safeCall(function()
				value:Disconnect()
			end)
			return
		end

		if type(value.Stop) == "function" then
			safeCall(function()
				value:Stop()
			end)
			return
		end

		if type(value.Clean) == "function" then
			safeCall(function()
				value:Clean()
			end)
			return
		end
	end
end

function Lifecycle.new(name)
	local self = setmetatable({}, Lifecycle)

	self.Name = name or "Lifecycle"
	self.Alive = true

	self.Items = {}
	self.Groups = {}
	self.LinkedInstances = {}
	self.InstanceDestroyConnections = {}
	self.Values = {}

	return self
end

function Lifecycle:IsAlive()
	return self.Alive == true
end

function Lifecycle:_assertAlive()
	if not self.Alive then
		error("[Lifecycle] Tried to use destroyed lifecycle: " .. tostring(self.Name), 2)
	end
end

function Lifecycle:_trackItem(item)
	table.insert(self.Items, item)

	if item.Group then
		self.Groups[item.Group] = self.Groups[item.Group] or {}
		table.insert(self.Groups[item.Group], item)
	end

	if item.Instance then
		self.LinkedInstances[item.Instance] = self.LinkedInstances[item.Instance] or {}
		table.insert(self.LinkedInstances[item.Instance], item)
	end

	return item.Value
end

function Lifecycle:_removeItem(item)
	if not item then
		return
	end

	for i = #self.Items, 1, -1 do
		if self.Items[i] == item then
			table.remove(self.Items, i)
			break
		end
	end

	if item.Group and self.Groups[item.Group] then
		local group = self.Groups[item.Group]

		for i = #group, 1, -1 do
			if group[i] == item then
				table.remove(group, i)
				break
			end
		end

		if #group == 0 then
			self.Groups[item.Group] = nil
		end
	end

	if item.Instance and self.LinkedInstances[item.Instance] then
		local list = self.LinkedInstances[item.Instance]

		for i = #list, 1, -1 do
			if list[i] == item then
				table.remove(list, i)
				break
			end
		end

		if #list == 0 then
			self.LinkedInstances[item.Instance] = nil
		end
	end
end

function Lifecycle:_ensureInstanceBinding(instance)
	if self.InstanceDestroyConnections[instance] then
		return
	end

	local connection

	connection = instance.Destroying:Connect(function()
		self:ClearInstance(instance)
	end)

	local item = {
		Value = connection,
		Method = nil,
		Group = "InstanceBindings",
		Instance = nil,
		Cleaned = false,
		IsBindingConnection = true,
		BoundInstance = instance,
	}

	self.InstanceDestroyConnections[instance] = item
	self:_trackItem(item)
end

function Lifecycle:Add(value, method, groupName)
	self:_assertAlive()

	if value == nil then
		return nil
	end

	local item = {
		Value = value,
		Method = method,
		Group = groupName or "Default",
		Instance = nil,
		Cleaned = false,
	}

	return self:_trackItem(item)
end

function Lifecycle:Give(value, method, groupName)
	return self:Add(value, method, groupName)
end

function Lifecycle:Connect(signal, callback, groupName)
	self:_assertAlive()

	local connection = signal:Connect(function(...)
		if not self.Alive then
			return
		end

		callback(...)
	end)

	self:Add(connection, nil, groupName or "Connections")

	return connection
end

function Lifecycle:Once(signal, callback, groupName)
	self:_assertAlive()

	local connection

	connection = signal:Connect(function(...)
		if connection and connection.Connected then
			connection:Disconnect()
		end

		if not self.Alive then
			return
		end

		callback(...)
	end)

	self:Add(connection, nil, groupName or "Connections")

	return connection
end

function Lifecycle:BindToInstance(instance, value, method, groupName)
	self:_assertAlive()

	if not isInstance(instance) then
		error("[Lifecycle] BindToInstance expected Instance, got " .. typeof(instance), 2)
	end

	if value == nil then
		return nil
	end

	self:_ensureInstanceBinding(instance)

	local item = {
		Value = value,
		Method = method,
		Group = groupName or "LinkedToInstance",
		Instance = instance,
		Cleaned = false,
	}

	return self:_trackItem(item)
end

function Lifecycle:Bind(instance, value, method, groupName)
	return self:BindToInstance(instance, value, method, groupName)
end

function Lifecycle:BindConnection(instance, connection, groupName)
	return self:BindToInstance(instance, connection, nil, groupName or "InstanceConnections")
end

function Lifecycle:BindTask(instance, thread, groupName)
	return self:BindToInstance(instance, thread, nil, groupName or "InstanceTasks")
end

function Lifecycle:BindObject(instance, object, method, groupName)
	return self:BindToInstance(instance, object, method, groupName or "InstanceObjects")
end

function Lifecycle:ConnectFor(instance, signal, callback, groupName)
	self:_assertAlive()

	if not isInstance(instance) then
		error("[Lifecycle] ConnectFor expected Instance, got " .. typeof(instance), 2)
	end

	local connection

	connection = signal:Connect(function(...)
		if not self.Alive then
			return
		end

		if not instance.Parent then
			if connection and connection.Connected then
				connection:Disconnect()
			end

			self:ClearInstance(instance)
			return
		end

		callback(...)
	end)

	self:BindToInstance(instance, connection, nil, groupName or "InstanceConnections")

	return connection
end

function Lifecycle:LoopFor(instance, signal, callback, groupName)
	return self:ConnectFor(instance, signal, callback, groupName or "InstanceLoops")
end

function Lifecycle:OnceFor(instance, signal, callback, groupName)
	self:_assertAlive()

	if not isInstance(instance) then
		error("[Lifecycle] OnceFor expected Instance, got " .. typeof(instance), 2)
	end

	local connection

	connection = signal:Connect(function(...)
		if connection and connection.Connected then
			connection:Disconnect()
		end

		if not self.Alive then
			return
		end

		if not instance.Parent then
			self:ClearInstance(instance)
			return
		end

		callback(...)
	end)

	self:BindToInstance(instance, connection, nil, groupName or "InstanceConnections")

	return connection
end

function Lifecycle:Defer(callback, groupName)
	self:_assertAlive()

	local thread = task.defer(function()
		if self.Alive then
			callback()
		end
	end)

	self:Add(thread, nil, groupName or "Tasks")

	return thread
end

function Lifecycle:Delay(seconds, callback, groupName)
	self:_assertAlive()

	local thread = task.delay(seconds, function()
		if self.Alive then
			callback()
		end
	end)

	self:Add(thread, nil, groupName or "Tasks")

	return thread
end

function Lifecycle:Spawn(callback, groupName)
	self:_assertAlive()

	local thread = task.spawn(function()
		if self.Alive then
			callback()
		end
	end)

	self:Add(thread, nil, groupName or "Tasks")

	return thread
end

function Lifecycle:Loop(interval, callback, groupName)
	self:_assertAlive()

	local cancelled = false

	local thread = task.spawn(function()
		while self.Alive and not cancelled do
			local dt = task.wait(interval)

			if self.Alive and not cancelled then
				local result = callback(dt)

				if result == false then
					break
				end
			end
		end
	end)

	local handle = {}

	function handle:Stop()
		cancelled = true
		task.cancel(thread)
	end

	self:Add(handle, "Stop", groupName or "Loops")

	return handle
end

function Lifecycle:LoopToInstance(instance, interval, callback, groupName)
	self:_assertAlive()

	if not isInstance(instance) then
		error("[Lifecycle] LoopToInstance expected Instance, got " .. typeof(instance), 2)
	end

	local cancelled = false

	local thread = task.spawn(function()
		while self.Alive and not cancelled and instance.Parent do
			local dt = task.wait(interval)

			if self.Alive and not cancelled and instance.Parent then
				local result = callback(dt)

				if result == false then
					break
				end
			end
		end
	end)

	local handle = {}

	function handle:Stop()
		cancelled = true
		task.cancel(thread)
	end

	self:BindToInstance(instance, handle, "Stop", groupName or "InstanceLoops")

	return handle
end

function Lifecycle:Create(className, props, parent, groupName)
	self:_assertAlive()

	local inst = Instance.new(className)

	for key, value in pairs(props or {}) do
		inst[key] = value
	end

	inst.Parent = parent
	self:Add(inst, "Destroy", groupName or "Instances")

	return inst
end

function Lifecycle:CreateForInstance(ownerInstance, className, props, parent, groupName)
	self:_assertAlive()

	if not isInstance(ownerInstance) then
		error("[Lifecycle] CreateForInstance expected Instance, got " .. typeof(ownerInstance), 2)
	end

	local inst = Instance.new(className)

	for key, value in pairs(props or {}) do
		inst[key] = value
	end

	inst.Parent = parent
	self:BindToInstance(ownerInstance, inst, "Destroy", groupName or "InstanceObjects")

	return inst
end

function Lifecycle:Clone(template, parent, groupName)
	self:_assertAlive()

	local clone = template:Clone()
	clone.Parent = parent

	self:Add(clone, "Destroy", groupName or "Instances")

	return clone
end

function Lifecycle:CloneForInstance(ownerInstance, template, parent, groupName)
	self:_assertAlive()

	if not isInstance(ownerInstance) then
		error("[Lifecycle] CloneForInstance expected Instance, got " .. typeof(ownerInstance), 2)
	end

	local clone = template:Clone()
	clone.Parent = parent

	self:BindToInstance(ownerInstance, clone, "Destroy", groupName or "InstanceObjects")

	return clone
end

function Lifecycle:CreateInstanceScope(instance, groupName)
	self:_assertAlive()

	if not isInstance(instance) then
		error("[Lifecycle] CreateInstanceScope expected Instance, got " .. typeof(instance), 2)
	end

	local scope = Lifecycle.new(self.Name .. "." .. instance.Name)
	self:BindToInstance(instance, scope, "Destroy", groupName or "InstanceScopes")

	return scope
end

function Lifecycle:Scope(name)
	self:_assertAlive()

	local child = Lifecycle.new(name or (self.Name .. ".Scope"))
	self:Add(child, "Destroy", "Scopes")

	return child
end

function Lifecycle:SetValue(key, value)
	self:_assertAlive()

	self.Values[key] = value
	return value
end

function Lifecycle:GetValue(key, default)
	local value = self.Values[key]

	if value == nil then
		return default
	end

	return value
end

function Lifecycle:ClearValue(key)
	self.Values[key] = nil
end

function Lifecycle:ClearInstance(instance)
	local list = self.LinkedInstances[instance]

	if list then
		local copy = table.clone(list)

		for _, item in ipairs(copy) do
			cleanupItem(item)
			self:_removeItem(item)
		end
	end

	self.LinkedInstances[instance] = nil

	local bindingItem = self.InstanceDestroyConnections[instance]

	if bindingItem then
		cleanupItem(bindingItem)
		self:_removeItem(bindingItem)
		self.InstanceDestroyConnections[instance] = nil
	end
end

function Lifecycle:ClearGroup(groupName)
	if not groupName then
		return
	end

	local group = self.Groups[groupName]

	if not group then
		return
	end

	local copy = table.clone(group)

	for _, item in ipairs(copy) do
		cleanupItem(item)
		self:_removeItem(item)
	end

	self.Groups[groupName] = nil
end

function Lifecycle:DisconnectGroup(groupName)
	self:ClearGroup(groupName)
end

function Lifecycle:DestroyGroup(groupName)
	self:ClearGroup(groupName)
end

function Lifecycle:ClearExcept(allowedGroups)
	local allowed = {}

	for _, groupName in ipairs(allowedGroups or {}) do
		allowed[groupName] = true
	end

	local copy = table.clone(self.Items)

	for _, item in ipairs(copy) do
		if not allowed[item.Group] then
			cleanupItem(item)
			self:_removeItem(item)
		end
	end
end

function Lifecycle:Clean()
	local copy = table.clone(self.Items)

	for _, item in ipairs(copy) do
		cleanupItem(item)
	end

	table.clear(self.Items)
	table.clear(self.Groups)
	table.clear(self.LinkedInstances)
	table.clear(self.InstanceDestroyConnections)
	table.clear(self.Values)
end

function Lifecycle:Destroy()
	if not self.Alive then
		return
	end

	self.Alive = false
	self:Clean()
end

function Lifecycle:Wrap(callback, groupName)
	self:_assertAlive()

	local active = true

	local function wrapped(...)
		if not self.Alive or not active then
			return
		end

		return callback(...)
	end

	self:Add(function()
		active = false
	end, nil, groupName or "WrappedCallbacks")

	return wrapped
end

return Lifecycle
