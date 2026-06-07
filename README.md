# Lifecycle

**Lifecycle** is a cleanup and ownership utility for Roblox systems.

It helps you track and clean resources such as connections, loops, tasks, instances, callbacks, tables, and temporary objects in a safe and organized way.

Lifecycle is especially useful for large Roblox projects where systems create many temporary resources that must be cleaned properly to avoid memory leaks, duplicated connections, or dead background tasks.

---

## Why Lifecycle?

In Roblox, systems often create resources that need to be cleaned later:

- `RBXScriptConnection`
- `Instance`
- `thread`
- callbacks
- temporary folders
- visual effects
- character-bound objects
- NPC-bound logic
- render loops
- heartbeat loops
- child controllers

Lifecycle gives you one place to own all of those resources.

```lua
local Lifecycle = require(path.to.Lifecycle)

local life = Lifecycle.new("MySystem")
```

When you are done:

```lua
life:Destroy()
```

Everything owned by that Lifecycle is cleaned automatically.

---

## Core Concept

A Lifecycle owns resources.

A resource can also be bound to an `Instance`.

When that `Instance` is destroyed, every resource bound to it is cleaned automatically.

```lua
local part = Instance.new("Part")
part.Parent = workspace

local connection = part.Touched:Connect(function(hit)
	print("Touched:", hit.Name)
end)

life:BindToInstance(part, connection)
```

When `part` is destroyed, the connection is disconnected automatically.

---

## Installation

Place the `Lifecycle` module anywhere inside your Roblox project, for example:

```txt
ReplicatedStorage
└── Packages
    └── Lifecycle
```

Then require it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Packages.Lifecycle)
```

---

## Creating a Lifecycle

```lua
local Lifecycle = require(path.to.Lifecycle)

local life = Lifecycle.new("NPCService")
```

The name is optional, but recommended for debugging.

```lua
local life = Lifecycle.new()
```

---

## Basic Cleanup

Use `Add` or `Give` to track a resource.

```lua
life:Add(value, method, groupName)
life:Give(value, method, groupName)
```

`Give` is an alias of `Add`.

### Supported resources

Lifecycle can automatically clean:

- `RBXScriptConnection`
- `Instance`
- `thread`
- `function`
- table with `:Destroy()`
- table with `:Disconnect()`
- table with `:Stop()`
- table with `:Clean()`

### Example

```lua
local RunService = game:GetService("RunService")

local connection = RunService.Heartbeat:Connect(function(dt)
	print(dt)
end)

life:Add(connection, nil, "HeartbeatLoops")
```

The connection will be disconnected when the Lifecycle is cleaned.

---

## Cleaning Instances

Instances are destroyed automatically.

```lua
local part = Instance.new("Part")
part.Name = "TemporaryPart"
part.Parent = workspace

life:Add(part, "Destroy", "TemporaryParts")
```

Later:

```lua
life:Clean()
```

This destroys the part.

---

## Connections

### `Connect`

Connects a signal and tracks the connection.

```lua
life:Connect(workspace.ChildAdded, function(child)
	print("New child:", child.Name)
end, "World")
```

Equivalent to:

```lua
local connection = workspace.ChildAdded:Connect(function(child)
	print(child.Name)
end)

life:Add(connection)
```

But shorter and safer.

---

### `Once`

Connects a signal once, then disconnects after the first call.

```lua
life:Once(workspace.ChildAdded, function(child)
	print("First child added:", child.Name)
end, "World")
```

---

## Instance-Bound Cleanup

Use `BindToInstance` when a resource should only live as long as an Instance exists.

```lua
life:BindToInstance(instance, value, method, groupName)
life:Bind(instance, value, method, groupName)
```

`Bind` is an alias of `BindToInstance`.

### Example

```lua
local RunService = game:GetService("RunService")

local part = Instance.new("Part")
part.Parent = workspace

local connection = RunService.RenderStepped:Connect(function(dt)
	print("Rendering while part exists")
end)

life:BindToInstance(part, connection, nil, "PartRender")
```

When `part` is destroyed, the render connection is disconnected automatically.

---

## Instance-Bound Connections

### `ConnectFor`

Connects a signal and binds the connection to an Instance.

```lua
life:ConnectFor(character, humanoid.Died, function()
	print("Character died")
end, "CharacterEvents")
```

When `character` is destroyed, the connection is disconnected.

---

### `LoopFor`

Alias-style helper for signal-based loops bound to an Instance.

```lua
life:LoopFor(character, RunService.RenderStepped, function(dt)
	print("Character render:", dt)
end, "CharacterRender")
```

---

### `OnceFor`

Connects once and binds the connection to an Instance.

```lua
life:OnceFor(character, humanoid.Died, function()
	print("This runs once")
end, "CharacterEvents")
```

---

## Binding Existing Resources

Lifecycle also includes explicit helpers for common resource types.

```lua
life:BindConnection(instance, connection, groupName)
life:BindTask(instance, thread, groupName)
life:BindObject(instance, object, method, groupName)
```

### Example

```lua
life:BindConnection(character, connection, "Character")
life:BindObject(character, temporaryFolder, "Destroy", "Character")
```

When `character` is destroyed, those resources are cleaned.

---

## Creating Instances

### `Create`

Creates an Instance and tracks it.

```lua
local folder = life:Create("Folder", {
	Name = "TempFolder"
}, workspace, "Instances")
```

This is equivalent to:

```lua
local folder = Instance.new("Folder")
folder.Name = "TempFolder"
folder.Parent = workspace

life:Add(folder, "Destroy", "Instances")
```

---

### `CreateForInstance`

Creates an Instance and binds it to another Instance.

```lua
local highlight = life:CreateForInstance(character, "Highlight", {
	FillTransparency = 0.5,
	OutlineTransparency = 0
}, character, "CharacterVisuals")
```

When `character` is destroyed, the highlight is destroyed automatically.

---

## Cloning

### `Clone`

Clones an Instance and tracks the clone.

```lua
local clone = life:Clone(template, workspace, "Clones")
```

---

### `CloneForInstance`

Clones an Instance and binds the clone to another Instance.

```lua
local clone = life:CloneForInstance(character, template, character, "CharacterObjects")
```

When `character` is destroyed, the clone is destroyed.

---

## Tasks

Lifecycle can track Roblox tasks.

### `Defer`

```lua
life:Defer(function()
	print("Deferred task")
end, "Tasks")
```

---

### `Delay`

```lua
life:Delay(5, function()
	print("Runs after 5 seconds if Lifecycle is still alive")
end, "Tasks")
```

---

### `Spawn`

```lua
life:Spawn(function()
	print("Spawned task")
end, "Tasks")
```

---

## Loops

### `Loop`

Runs a repeating task while the Lifecycle is alive.

```lua
local loop = life:Loop(1, function(dt)
	print("Tick")
end, "Loops")
```

Return `false` to stop the loop.

```lua
life:Loop(1, function()
	print("Running once")
	return false
end, "Loops")
```

You can also stop the loop manually:

```lua
loop:Stop()
```

---

### `LoopToInstance`

Runs a repeating task while both the Lifecycle and the Instance are alive.

```lua
life:LoopToInstance(character, 0.25, function(dt)
	print("Character loop")
end, "CharacterLoops")
```

When `character` is destroyed, the loop stops automatically.

---

## Scopes

A scope is a child Lifecycle owned by another Lifecycle.

When the parent is destroyed, the child is destroyed too.

```lua
local npcLife = life:Scope("NPC_01")
```

Example:

```lua
local npcLife = life:Scope("NPC_01")

npcLife:Connect(npc.Humanoid.Died, function()
	print("NPC died")
end, "NPCEvents")
```

When `life` is destroyed, `npcLife` is also destroyed.

---

## Instance Scopes

Use `CreateInstanceScope` to create a child Lifecycle bound to an Instance.

```lua
local characterLife = life:CreateInstanceScope(character, "Characters")
```

When `character` is destroyed, `characterLife` is destroyed automatically.

This is useful for character controllers, NPC controllers, temporary entities, and spawned objects.

---

## Groups

Every tracked item can belong to a group.

Groups make it easy to clean only one category of resources.

```lua
life:Add(connection, nil, "Connections")
life:Add(part, "Destroy", "TemporaryParts")
life:Loop(1, callback, "Loops")
```

---

### Clear a Group

```lua
life:ClearGroup("TemporaryParts")
```

Aliases:

```lua
life:DisconnectGroup("Connections")
life:DestroyGroup("TemporaryParts")
```

All three call the same cleanup logic.

---

### Clear Everything Except Some Groups

```lua
life:ClearExcept({ "Permanent", "UI" })
```

This cleans every group except `"Permanent"` and `"UI"`.

---

## Instance Cleanup

You can manually clear everything bound to a specific Instance.

```lua
life:ClearInstance(character)
```

This cleans all resources linked to `character`.

---

## Temporary Values

Lifecycle can also store temporary values.

```lua
life:SetValue("CurrentTarget", target)
```

```lua
local target = life:GetValue("CurrentTarget")
```

With a default value:

```lua
local state = life:GetValue("State", "Idle")
```

Clear a value:

```lua
life:ClearValue("CurrentTarget")
```

Values are cleared when the Lifecycle is cleaned.

---

## Wrapped Callbacks

`Wrap` creates a callback that only runs while the Lifecycle is alive.

```lua
local callback = life:Wrap(function(message)
	print(message)
end, "Callbacks")

callback("Hello")
```

After the Lifecycle is destroyed, the wrapped callback will no longer run.

```lua
life:Destroy()

callback("This will not run")
```

This is useful for delayed callbacks, async logic, UI callbacks, or external APIs.

---

## Clean vs Destroy

### `Clean`

Cleans all tracked resources but keeps the Lifecycle reusable.

```lua
life:Clean()
```

After cleaning, you can still add new resources.

```lua
life:Add(connection)
```

---

### `Destroy`

Cleans all tracked resources and permanently marks the Lifecycle as dead.

```lua
life:Destroy()
```

After destroying, trying to use the Lifecycle again will throw an error.

```lua
life:Add(connection) -- error
```

---

### `IsAlive`

Checks if the Lifecycle is still active.

```lua
if life:IsAlive() then
	print("Lifecycle is alive")
end
```

---

## Complete Example

```lua
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lifecycle = require(ReplicatedStorage.Packages.Lifecycle)

local CharacterController = {}
CharacterController.__index = CharacterController

function CharacterController.new(character)
	local self = setmetatable({}, CharacterController)

	self.Character = character
	self.Life = Lifecycle.new("CharacterController")

	local humanoid = character:WaitForChild("Humanoid")

	self.Life:ConnectFor(character, humanoid.Died, function()
		print("Character died")
	end, "CharacterEvents")

	self.Life:LoopToInstance(character, 0.1, function(dt)
		print("Character update:", dt)
	end, "CharacterLoops")

	self.Highlight = self.Life:CreateForInstance(character, "Highlight", {
		FillTransparency = 0.8,
		OutlineTransparency = 0
	}, character, "CharacterVisuals")

	return self
end

function CharacterController:Destroy()
	self.Life:Destroy()
end

return CharacterController
```

---

## Recommended Project Structure

Use one Lifecycle per major system.

Examples:

- `ServerBoot`
- `ClientBoot`
- `PlaneSpawner`
- `NPCService`
- `WeatherService`
- `DisasterService`
- `UIController`
- `CharacterController`
- `CombatController`

Use child scopes for temporary entities:

```lua
local npcLife = npcServiceLife:Scope("NPC_" .. npc.Name)
local characterLife = clientLife:CreateInstanceScope(character)
```

---

## Recommended Groups

Good default group names:

- `"Connections"`
- `"RenderLoops"`
- `"HeartbeatLoops"`
- `"Instances"`
- `"Character"`
- `"Plane"`
- `"NPC"`
- `"Effects"`
- `"Temporary"`
- `"UI"`
- `"Tasks"`
- `"Scopes"`

Example:

```lua
life:Connect(signal, callback, "Connections")
life:Loop(1, callback, "HeartbeatLoops")
life:Create("Folder", props, parent, "Instances")
```

This makes debugging easier because you can disable, clear, or inspect one category without destroying the whole system.

---

## API Reference

### Constructor

```lua
Lifecycle.new(name: string?)
```

Creates a new Lifecycle.

---

### State

```lua
life:IsAlive(): boolean
```

Returns whether the Lifecycle is still active.

---

### Basic Tracking

```lua
life:Add(value: any, method: string | function?, groupName: string?)
life:Give(value: any, method: string | function?, groupName: string?)
```

Tracks a value for cleanup.

---

### Connections

```lua
life:Connect(signal: RBXScriptSignal, callback: function, groupName: string?)
life:Once(signal: RBXScriptSignal, callback: function, groupName: string?)
```

Connects a signal and tracks the connection.

---

### Instance Binding

```lua
life:BindToInstance(instance: Instance, value: any, method: string | function?, groupName: string?)
life:Bind(instance: Instance, value: any, method: string | function?, groupName: string?)
```

Binds a resource to an Instance.

---

### Instance-Bound Connections

```lua
life:ConnectFor(instance: Instance, signal: RBXScriptSignal, callback: function, groupName: string?)
life:LoopFor(instance: Instance, signal: RBXScriptSignal, callback: function, groupName: string?)
life:OnceFor(instance: Instance, signal: RBXScriptSignal, callback: function, groupName: string?)
```

Connects a signal and binds the connection to an Instance.

---

### Instance-Bound Resources

```lua
life:BindConnection(instance: Instance, connection: RBXScriptConnection, groupName: string?)
life:BindTask(instance: Instance, thread: thread, groupName: string?)
life:BindObject(instance: Instance, object: any, method: string | function?, groupName: string?)
```

Binds common resource types to an Instance.

---

### Instance Creation

```lua
life:Create(className: string, props: table?, parent: Instance?, groupName: string?): Instance
life:CreateForInstance(ownerInstance: Instance, className: string, props: table?, parent: Instance?, groupName: string?): Instance
```

Creates and tracks Instances.

---

### Cloning

```lua
life:Clone(template: Instance, parent: Instance?, groupName: string?): Instance
life:CloneForInstance(ownerInstance: Instance, template: Instance, parent: Instance?, groupName: string?): Instance
```

Clones and tracks Instances.

---

### Tasks

```lua
life:Defer(callback: function, groupName: string?): thread
life:Delay(seconds: number, callback: function, groupName: string?): thread
life:Spawn(callback: function, groupName: string?): thread
```

Runs and tracks tasks.

---

### Loops

```lua
life:Loop(interval: number, callback: function, groupName: string?): table
life:LoopToInstance(instance: Instance, interval: number, callback: function, groupName: string?): table
```

Runs repeating tasks.

The callback can return `false` to stop the loop.

---

### Scopes

```lua
life:Scope(name: string?): Lifecycle
life:CreateInstanceScope(instance: Instance, groupName: string?): Lifecycle
```

Creates child Lifecycles.

---

### Groups

```lua
life:ClearGroup(groupName: string)
life:DisconnectGroup(groupName: string)
life:DestroyGroup(groupName: string)
life:ClearExcept(allowedGroups: { string })
```

Cleans grouped resources.

---

### Instance Cleanup

```lua
life:ClearInstance(instance: Instance)
```

Cleans everything bound to one Instance.

---

### Values

```lua
life:SetValue(key: any, value: any): any
life:GetValue(key: any, default: any?): any
life:ClearValue(key: any)
```

Stores temporary values inside the Lifecycle.

---

### Wrapped Callbacks

```lua
life:Wrap(callback: function, groupName: string?): function
```

Returns a callback that only runs while the Lifecycle is alive.

---

### Cleanup

```lua
life:Clean()
life:Destroy()
```

`Clean` makes the Lifecycle reusable.

`Destroy` permanently kills it.

---

## Best Practices

### Use one Lifecycle per system

```lua
local serviceLife = Lifecycle.new("NPCService")
```

### Use scopes for temporary entities

```lua
local npcLife = serviceLife:Scope("NPC_" .. npc.Name)
```

### Bind character resources to the character

```lua
local characterLife = life:CreateInstanceScope(character)
```

### Use groups for debugging

```lua
life:ClearGroup("Effects")
```

### Destroy systems when they stop

```lua
life:Destroy()
```

---

## Notes

Lifecycle is designed for Roblox Luau.

It does not force a specific architecture. You can use it in services, controllers, components, NPC systems, UI systems, character controllers, tools, effects, and temporary gameplay objects.

The goal is simple:

> If your system creates it, your Lifecycle should own it.
