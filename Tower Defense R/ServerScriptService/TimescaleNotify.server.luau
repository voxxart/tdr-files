local Rep = game:GetService("ReplicatedStorage")



Rep.Events.NotifcationSend.OnServerEvent:Connect(function(plr)
	Rep.Events.NotifcationSend:FireClient(plr, "Unlock Timescale In Lobby To Use!")
end)