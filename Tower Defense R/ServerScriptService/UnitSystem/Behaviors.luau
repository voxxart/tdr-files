-- Server-only extension points. Hooks must not yield.
local Behaviors = {}
Behaviors.End = {
	Loop = function(context) context.Reset(0) end,
	Despawn = function(context) context.Finish(false) end,
	Death = function(context) context.Finish(true) end,
}
Behaviors.Death = {Default = function() end}
return Behaviors
