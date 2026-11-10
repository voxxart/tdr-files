-- Query-only group: no physical parts are assigned to it.
-- Hover should see visible bodies regardless of their physics collision matrix.
local Physics=game:GetService('PhysicsService')
local Rep=game:GetService('ReplicatedStorage')
local group='InteractionQuery'
if not Physics:IsCollisionGroupRegistered(group) then Physics:RegisterCollisionGroup(group) end
for _,entry in Physics:GetRegisteredCollisionGroups() do
 Physics:CollisionGroupSetCollidable(group,entry.name,true)
end
Rep:SetAttribute('InteractionQueryGroup',group)
