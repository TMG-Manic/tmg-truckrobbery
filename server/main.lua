local TMGCore = exports['tmg-core']:GetCoreObject()
local ActiveMission = 0


RegisterServerEvent('tmg-armored:server:initiateHeist', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    exports['tmgnosql']:FetchOne('world_states', { ["id"] = "truck_robbery_state" }, function(state)
        local currentTime = os.time()
        
        if state and state.active and currentTime < state.resetAt then
            local remaining = math.ceil((state.resetAt - currentTime) / 60)
            return TriggerClientEvent('TMGCore:Notify', src, 'Logistics Warning: Interception window currently locked (' .. remaining .. ' mins).', 'error')
        end

        local accountMoney = Player.PlayerData.money['bank']
        if accountMoney < Config.ActivationCost then
            return TriggerClientEvent('TMGCore:Notify', src, 'Registry Error: Insufficient bank balance for decryption keys.', 'error')
        end

        local copsOnDuty = 0
        local players = TMGCore.Functions.GetPlayers()
        for _, v in pairs(players) do
            local Target = TMGCore.Functions.GetPlayer(v)
            if Target and (Target.PlayerData.job.type == 'leo') and Target.PlayerData.job.onduty then
                copsOnDuty = copsOnDuty + 1
            end
        end

        if copsOnDuty >= Config.ActivePolice then
            if Player.Functions.RemoveMoney('bank', Config.ActivationCost, 'armored-truck-initialization') then
                
                local cooldownTime = os.time() + (Config.ResetTimer or 1800)
                
                exports['tmgnosql']:UpdateOne('world_states', 
                    { ["id"] = "truck_robbery_state" }, 
                    {
                        ["$set"] = { 
                            ["id"] = "truck_robbery_state",
                            ["active"] = true, 
                            ["resetAt"] = cooldownTime,
                            ["initiator"] = Player.PlayerData.citizenid,
                            ["type"] = "heist_lockout"
                        }
                    }, 
                    { ["upsert"] = true }
                )

                TriggerClientEvent('tmg-armored:client:enableIntercept', src)
            end
        else
            TriggerClientEvent('TMGCore:Notify', src, 'Signal Interference: (Need ' .. Config.ActivePolice .. ' LEO on duty).', 'error')
        end
    end)
end)


RegisterServerEvent('qb-armoredtruckheist:server:callCops', function(streetLabel, coords)
    local alertData = {
        title = '10-90 | Armored Truck Robbery',
        coords = { x = coords.x, y = coords.y, z = coords.z },
        description = string.format("The alarm has been activated from an Armored Truck at %s", streetLabel)
    }

    local players = QBCore.Functions.GetPlayers() -- Utilizing the Mainframe bridge
    
    for _, src in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(src)
        
        if Player and (Player.PlayerData.job.name == "police" or Player.PlayerData.job.type == "leo") and Player.PlayerData.job.onduty then
            TriggerClientEvent('qb-armoredtruckheist:client:robberyCall', src, streetLabel, coords)
            TriggerClientEvent('qb-phone:client:addPoliceAlert', src, alertData)
        end
    end

    print(string.format("^5[TMG]^7 Dispatch: Armored Truck alert routed to Law Enforcement at %s", streetLabel))
end)

function OdpalTimer()
    local duration = (Config.ResetTimer or 1800) 
    local expiresAt = os.time() + duration

    exports['tmgnosql']:UpdateOne('world_states', 
        { ["id"] = "truck_robbery_state" }, 
        { 
            ["$set"] = { 
                ["id"] = "truck_robbery_state",
                ["active"] = true, 
                ["resetAt"] = expiresAt,
                ["type"] = "heist_cooldown"
            } 
        }, 
        { ["upsert"] = true }
    )

    SetTimeout(duration * 1000, function()
        exports['tmgnosql']:UpdateOne('world_states', 
            { ["id"] = "truck_robbery_state" }, 
            { ["$set"] = { ["active"] = false } }
        )
        
        TriggerClientEvent('tmg-armored:client:CleanUp', -1)
        
        print(string.format("^5[TMG]^7 Heist: Armored Truck lockout expired at %s", os.date("%H:%M:%S", expiresAt)))
    end)
end


RegisterServerEvent('AttackTransport:zawiadompsy', function(x, y, z)
    local coords = vector3(x, y, z)
    
    local players = QBCore.Functions.GetPlayers() -- Utilizing the Mainframe bridge
    
    for _, src in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(src)
        
        if Player and (Player.PlayerData.job.name == "police" or Player.PlayerData.job.type == "leo") and Player.PlayerData.job.onduty then
            TriggerClientEvent('AttackTransport:InfoForLspd', src, x, y, z)
            
            -- TriggerClientEvent('qb-dispatch:client:addCall', src, "10-90", "Armored Truck", coords)
        end
    end

    print(string.format("^5[TMG]^7 Intel: Hijack coordinates pulsed to Law Enforcement terminals."))
end)


RegisterServerEvent('AttackTransport:graczZrobilnapad', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local bags = math.random(1, 3)
    local info = { 
        worth = math.random(Config.Payout.Min or 5000, Config.Payout.Max or 10000) 
    }

    if Player.Functions.AddItem('markedbills', bags, false, info) then
        TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['markedbills'], 'add', bags)
        TriggerClientEvent('QBCore:Notify', src, 'Materialized ' .. bags .. ' bags of marked bills.', 'success')
        
        if math.random(1, 100) >= 95 then
            if Player.Functions.AddItem('security_card_01', 1) then
                TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items['security_card_01'], 'add', 1)
            end
        end
    end

    print(string.format("^5[TMG]^7 Heist: Terminal %s secured armored truck assets.", src))
end)