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
