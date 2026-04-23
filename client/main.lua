local TMGCore = exports['tmg-core']:GetCoreObject()
local BlowBackdoor = 0
local SilenceAlarm = 0
local PoliceAlert = 0
local PoliceBlip = 0
local LootTime = 1
local GuardsDead = 0
local prop
local lootable = 0
local BlownUp = 0
local TruckBlip
local transport
local MissionStart = 0
local warning = 0
local VehicleCoords = nil
local dealer
local PlayerJob = {}
local pilot
local navigator
local navigator2
local bag

PlayerJob = PlayerJob or {}

local function RefreshJobData()
    local PlayerData = TMGCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job then
        PlayerJob = PlayerData.job
    end
end

RegisterNetEvent('TMGCore:Client:OnPlayerLoaded', function()
    RefreshJobData()
end)

RegisterNetEvent('TMGCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
end)

local function hintToDisplay(text)
    exports['tmg-core']:DrawText(text, 'left') 
end

local function hideLastHint()
    exports['tmg-core']:HideText()
end

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    end
end


local dealerSpawned = false

CreateThread(function()
    while true do
        local sleep = 1000 
        local plyCoords = GetEntityCoords(PlayerPedId())
        local dist = #(plyCoords - vector3(Config.MissionMarker.x, Config.MissionMarker.y, Config.MissionMarker.z))

        if dist <= 40.0 then
            sleep = 500 
            
            if not dealerSpawned and not DoesEntityExist(dealer) then
                local model = `s_m_y_dealer_01`
                RequestModel(model)
                while not HasModelLoaded(model) do Wait(10) end
                
                dealer = CreatePed(26, model, Config.DealerCoords.x, Config.DealerCoords.y, Config.DealerCoords.z, Config.DealerCoords.w, false, false)
                
                SetEntityAsMissionEntity(dealer, true, true)
                SetBlockingOfNonTemporaryEvents(dealer, true)
                SetEntityInvincible(dealer, true) 
                FreezeEntityPosition(dealer, true) 
                TaskStartScenarioInPlace(dealer, "WORLD_HUMAN_AA_SMOKE", 0, false)
                
                dealerSpawned = true
                SetModelAsNoLongerNeeded(model) 
            end

            if dist <= 2.5 then
                sleep = 0 
                DrawText3D(Config.MissionMarker.x, Config.MissionMarker.y, Config.MissionMarker.z, "~b~[E]~w~ To accept mission")
                
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent("AttackTransport:akceptujto")
                    Wait(2000) 
                end
            end
        elseif dealerSpawned then
            if DoesEntityExist(dealer) then
                DeleteEntity(dealer)
            end
            dealerSpawned = false
        end
        
        Wait(sleep)
    end
end)


local function CheckGuards()
    if GuardsDead == 1 then return end

    local pilotDead = not DoesEntityExist(pilot) or IsPedDeadOrDying(pilot, 1)
    local navDead = not DoesEntityExist(navigator) or IsPedDeadOrDying(navigator, 1)

    if pilotDead or navDead then
        GuardsDead = 1
    end
end


function AlertPolice()
    if not DoesEntityExist(transport) then return end
    
    local coords = GetEntityCoords(transport)
    
    TriggerServerEvent('AttackTransport:zawiadompsy', coords)
    
    
end

RegisterNetEvent('AttackTransport:InfoForLspd', function(coords)
    if not PlayerJob or PlayerJob.name ~= 'police' then return end

    if PoliceBlip == 0 then
        PoliceBlip = 1
        
        local alertBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(alertBlip, 67)
        SetBlipScale(alertBlip, 1.0)
        SetBlipColour(alertBlip, 2)
        SetBlipAsShortRange(alertBlip, true) 
        
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName('Assault: Armored Transport')
        EndTextCommandSetBlipName(alertBlip)

        CreateThread(function()
            local timeout = 20 
            while timeout > 0 do
                Wait(1000)
                timeout = timeout - 1
            end
            if DoesBlipExist(alertBlip) then RemoveBlip(alertBlip) end
            PoliceBlip = 0
        end)
    end

    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local dist = #(pos - coords)

    if dist <= 10.0 then
        if dist <= 4.5 and GuardsDead == 1 then
            if SilenceAlarm == 0 then
                hintToDisplay('Press [G] to silence the alarm')
                SilenceAlarm = 1
            end

            if IsControlJustPressed(0, 47) then 
                local dict = "anim@mp_player_intmenu@key_fob@"
                RequestAnimDict(dict)
                while not HasAnimDictLoaded(dict) do Wait(0) end

                hideLastHint()
                TaskPlayAnim(ped, dict, "fob_click_fp", 8.0, 8.0, -1, 48, 1, false, false, false)
                
                TriggerEvent('AttackTransport:CleanUp')
                
                if DoesBlipExist(TruckBlip) then RemoveBlip(TruckBlip) end
                TMGCore.Functions.Notify("Alarm silenced, scene secured.", "success")
            end
        end
    else
        SilenceAlarm = 0 
    end
end)

RegisterNetEvent('tmg-armoredtruckheist:client:911alert', function()
    if PoliceAlert ~= 0 then return end
    PoliceAlert = 1 

    if not DoesEntityExist(transport) then return end
    
    local transCoords = GetEntityCoords(transport)
    
    local offsetX = math.random(-80, 80)
    local offsetY = math.random(-80, 80)
    local dispatchCoords = vector3(transCoords.x + offsetX, transCoords.y + offsetY, transCoords.z)

    local s1, s2 = GetStreetNameAtCoord(transCoords.x, transCoords.y, transCoords.z)
    local streetLabel = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then 
        streetLabel = streetLabel .. " / " .. GetStreetNameFromHashKey(s2)
    end

    TriggerServerEvent("tmg-armoredtruckheist:server:callCops", streetLabel, dispatchCoords, transCoords)
    
    PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
    
    TMGCore.Functions.Notify("The guards have successfully radioed dispatch!", "error")
end)

RegisterNetEvent('tmg-armoredtruckheist:client:robberyCall', function(streetLabel, coords)
    if not PlayerJob or PlayerJob.name ~= "police" then return end

    local callSign = TMGCore.Functions.GetPlayerData().metadata["callsign"] or "UNIT"
    
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
    
    TriggerEvent('tmg-policealerts:client:AddPoliceAlert', {
        timeOut = 10000,
        alertTitle = "10-90: Armored Truck Heist",
        coords = coords,
        details = {
            { icon = '<i class="fas fa-university"></i>', detail = "Armored Transport" },
            { icon = '<i class="fas fa-globe-europe"></i>', detail = streetLabel },
        },
        callSign = callSign,
    })

    CreateThread(function()
        local alpha = 250
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        
        SetBlipSprite(blip, 487)
        SetBlipColour(blip, 1) 
        SetBlipScale(blip, 1.2)
        SetBlipAsShortRange(blip, false)
        
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName("10-90: Armored Truck")
        EndTextCommandSetBlipName(blip)

        while alpha > 0 do
            Wait(1000) 
            alpha = alpha - 2
            SetBlipAlpha(blip, alpha)
            
            if not DoesBlipExist(blip) then break end
        end

        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)


local lastMailTime = 0

function MissionNotification(targetArea)
    local currentTime = GetGameTimer()
    if currentTime - lastMailTime < 5000 then return end
    lastMailTime = currentTime

    local neighborhood = targetArea or "the marked location"
    
    TriggerServerEvent('tmg-phone:server:sendNewMail', {
        sender = "The Boss",
        subject = "New Target: Armored Truck",
        message = string.format(
            "I've got a lead on a Stockade moving through %s. Get your gear ready and head to the coordinates. Don't blow it.", 
            neighborhood
        ),
        button = { 
            enabled = true,
            buttonEvent = "tmg-armoredtruckheist:client:SetGPS",
        }
    })

    TMGCore.Functions.Notify("Check your mail for the contract details.", "primary")
end




RegisterNetEvent('AttackTransport:Pozwolwykonac', function()
    local DrawCoord = math.random(1, #Config.VehicleSpawn)
    VehicleCoords = Config.VehicleSpawn[DrawCoord]
    
    MissionNotification(VehicleCoords.name or "the industrial sector")
    SetNewWaypoint(VehicleCoords.x, VehicleCoords.y)
    
    if DoesEntityExist(dealer) then
        ClearPedTasks(dealer)
        TaskWanderStandard(dealer, 10, 10)
    end
	MissionStart = 1
    local spawned = false
    CreateThread(function()
        while not spawned and MissionStart == 1 do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - vector3(VehicleCoords.x, VehicleCoords.y, VehicleCoords.z))

            if dist < 180 then 
                spawned = true
                
                local models = {`stockade`, `s_m_m_security_01`}
                for _, model in ipairs(models) do
                    RequestModel(model)
                    local timeout = 0
                    while not HasModelLoaded(model) and timeout < 100 do
                        Wait(10)
                        timeout = timeout + 1
                    end
                end

                ClearAreaOfVehicles(VehicleCoords.x, VehicleCoords.y, VehicleCoords.z, 15.0, false, false, false, false, false)
                transport = CreateVehicle(`stockade`, VehicleCoords.x, VehicleCoords.y, VehicleCoords.z, VehicleCoords.h or 52.0, true, true)
                
                SetEntityAsMissionEntity(transport, true, true)
                local netId = NetworkGetNetworkIdFromEntity(transport)
                SetNetworkIdCanMigrate(netId, true)
                SetEntityInvincible(transport, true) 

                local squad = {}
                for i = 1, 3 do
                    local guard = CreatePed(26, `s_m_m_security_01`, VehicleCoords.x, VehicleCoords.y, VehicleCoords.z, 0.0, true, true)
                    
                    SetEntityAsMissionEntity(guard, true, true)
                    SetPedAsCop(guard, true)
                    SetPedCombatAbility(guard, 100)
                    SetPedCombatMovement(guard, 2)
                    SetPedCombatRange(guard, 2)
                    SetPedFleeAttributes(guard, 0, 0)
                    SetPedCombatAttributes(guard, 46, 1)
                    SetPedKeepTask(guard, true)
                    SetBlockingOfNonTemporaryEvents(guard, true)
                    
                    local weapon = (i == 1) and Config.DriverWep or Config.NavWep
                    GiveWeaponToPed(guard, weapon, 250, false, true)
                    
                    squad[i] = guard
                end

                pilot, navigator, navigator2 = squad[1], squad[2], squad[3]

                Wait(200) 
                SetPedIntoVehicle(pilot, transport, -1)
                SetPedIntoVehicle(navigator, transport, 0)
                SetPedIntoVehicle(navigator2, transport, 1)

                TruckBlip = AddBlipForEntity(transport)
                SetBlipSprite(TruckBlip, 57)
                SetBlipColour(TruckBlip, 1)
                SetBlipFlashes(TruckBlip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentSubstringPlayerName('Armored Transport')
                EndTextCommandSetBlipName(TruckBlip)

                TaskVehicleDriveWander(pilot, transport, 20.0, 443)
                
                startMission()
            end
            Wait(1000) 
        end
    end)
    MissionStart = 1
end)

local isTransitioning = false

function stopAndBeAngry()
    if isTransitioning then return end
    isTransitioning = true

    if not NetworkHasControlOfEntity(transport) then
        NetworkRequestControlOfEntity(transport)
        local timeout = 0
        while not NetworkHasControlOfEntity(transport) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
    end

    SetVehicleForwardSpeed(transport, 0)
    SetVehicleBrake(transport, true)
    SetVehicleEngineOn(transport, false, true, true)

    local guards = {pilot, navigator, navigator2}
    local playerPed = PlayerPedId()

    for _, guard in ipairs(guards) do
        if DoesEntityExist(guard) then
            NetworkRequestControlOfEntity(guard)
            
            GiveWeaponToPed(guard, Config.NavWep, 420, false, true)
            SetPedDropsWeaponsWhenDead(guard, false)
            SetPedAsCop(guard, true)
            SetCanAttackFriendly(guard, false, true)
            
            SetPedRelationshipGroupHash(guard, `HATES_PLAYER`) 
            
            TaskCombatPed(guard, playerPed, 0, 16)
        end
    end

    TaskEveryoneLeaveVehicle(transport)
    
    SetTimeout(5000, function()
        isTransitioning = false
    end)
end


function startMission()
    CreateThread(function()
    local plyCoords = GetEntityCoords(PlayerPedId())
        while MissionStart == 1 do
            local sleep = 1000 
            local transCoords = GetEntityCoords(transport)
            local dist = #(plyCoords - transCoords)
            if not DoesEntityExist(transport) then 
                Wait(sleep) 
                goto continue 
            end


            if dist <= 55.0 then
                sleep = 500 
                
                if HasEntityClearLosToEntity(PlayerPedId(), transport, 17) then
                    DrawMarker(0, transCoords.x, transCoords.y, transCoords.z + 4.5, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 135, 31, 35, 100, true, false, 2, false)
                end

                if warning == 0 then
                    warning = 1
                    stopAndBeAngry()
                    TMGCore.Functions.Notify("Get rid of the guards before you place the bomb.", "error")
                    AlertPolice()
                end

                if dist <= 10.0 then
                    sleep = 0 
                    
                    if GuardsDead == 0 then
                        CheckGuards()
                    else
                        if BlownUp == 0 and PlayerJob.name ~= 'police' and BlowBackdoor == 0 then
                            hintToDisplay('Press [G] to blow up the back door')
                            
                            if IsControlJustPressed(0, 47) then 
                                BlowBackdoor = 1
                                hideLastHint()
                                CheckVehicleInformation()
                                TriggerEvent("tmg-armoredtruckheist:client:911alert")
                                sleep = 1000 
                            end
                        end
                    end
                else
                    hideLastHint() 
                end
            end

            ::continue::
            Wait(sleep)
        end
    end)
end

function CheckVehicleInformation()
    local ped = PlayerPedId()
    
    if not IsVehicleStopped(transport) then 
        return TMGCore.Functions.Notify('You cannot rob a moving vehicle.', "error") 
    end
    
    if IsEntityInWater(ped) then 
        return TMGCore.Functions.Notify('Get out of the water!', "error") 
    end

    if not NetworkHasControlOfEntity(transport) then
        NetworkRequestControlOfEntity(transport)
        local timeout = 0
        while not NetworkHasControlOfEntity(transport) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
    end

    local animDict = 'anim@heists@ornate_bank@thermal_charge_heels'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end

    local pos = GetEntityCoords(ped)
    prop = CreateObject(`prop_c4_final_green`, pos.x, pos.y, pos.z + 0.2, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), 0.06, 0.0, 0.06, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    FreezeEntityPosition(ped, true)
    TaskPlayAnim(ped, animDict, "thermal_charge", 3.0, -8, -1, 63, 0, 0, 0, 0)

    TMGCore.Functions.Progressbar("planting_explosive", "Planting Thermite...", 5500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() 
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        
        DetachEntity(prop)
        AttachEntityToEntity(prop, transport, GetEntityBoneIndexByName(transport, 'door_pside_r'), -0.7, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        
        TMGCore.Functions.Notify('Explosive set. Clear the area!', "error")
        
        CreateThread(function()
            local timer = Config.TimeToBlow
            while timer > 0 do
                Wait(1000)
                timer = timer - 1
            end
            
            local boomCoords = GetEntityCoords(prop)
            if DoesEntityExist(prop) then DeleteEntity(prop) end
            
            NetworkRequestControlOfEntity(transport)
            SetVehicleDoorBroken(transport, 2, false)
            SetVehicleDoorBroken(transport, 3, false)
            AddExplosion(boomCoords.x, boomCoords.y, boomCoords.z, 'EXPLOSION_TANKER', 2.0, true, false, 2.0)
            
            BlownUp = 1
            lootable = 1
            TMGCore.Functions.Notify('Rear doors breached. Collect the cash!', "success")
            if DoesBlipExist(TruckBlip) then RemoveBlip(TruckBlip) end
        end)

    end, function() 
        if DoesEntityExist(prop) then DeleteEntity(prop) end
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
    end)
end



CreateThread(function()
    while true do
        local sleep = 1000 
        
        if lootable == 1 and DoesEntityExist(transport) then
            local plyCoords = GetEntityCoords(PlayerPedId())
            local transCoords = GetEntityCoords(transport)
            local dist = #(plyCoords - transCoords)

            if dist <= 10.0 then
                sleep = 500 
                if dist <= 4.5 then
                    sleep = 0 
                    hintToDisplay('Press [E] to take the money')
                    
                    if IsControlJustPressed(0, 38) then
                        lootable = 0 
                        hideLastHint()
                        
                        TakingMoney()
                    end
                else
                    hideLastHint()
                end
            end
        end
        Wait(sleep)
    end
end)


RegisterNetEvent('AttackTransport:CleanUp', function()
    BlowBackdoor, SilenceAlarm, PoliceAlert, PoliceBlip = 0, 0, 0, 0
    GuardsDead, lootable, BlownUp, MissionStart, warning = 0, 0, 0, 0, 0
    LootTime = 1

    if DoesEntityExist(prop) then DeleteEntity(prop) end
    if DoesEntityExist(bag) then DeleteEntity(bag) end
    
    if DoesBlipExist(TruckBlip) then RemoveBlip(TruckBlip) end
    if DoesBlipExist(PoliceBlip) then RemoveBlip(PoliceBlip) end

    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, "anim@heists@ornate_bank@grab_cash_heels", "grab", 3) then
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
    end

    TMGCore.Functions.Notify("Heist state has been reset.", "primary")
end)



function TakingMoney()
    local ped = PlayerPedId()
    local animDict = 'anim@heists@ornate_bank@grab_cash_heels'
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end

    local PedCoords = GetEntityCoords(ped)
    bag = CreateObject(`prop_cs_heist_bag_02`, PedCoords.x, PedCoords.y, PedCoords.z, true, true, true)
    AttachEntityToEntity(bag, ped, GetPedBoneIndex(ped, 57005), 0.0, 0.0, -0.16, 250.0, -30.0, 0.0, false, false, false, false, 2, true)
    
    local netVeh = NetworkGetNetworkIdFromEntity(transport)
    TriggerServerEvent("AttackTransport:server:StartLooting", netVeh)

    TMGCore.Functions.Progressbar("packing_cash", "Packing cash into bag...", 20000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = animDict,
        anim = "grab",
        flags = 1,
    }, {}, {}, function() 
        TriggerServerEvent("AttackTransport:graczZrobilnapad") 
        
        if DoesEntityExist(bag) then DeleteEntity(bag) end
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        SetPedComponentVariation(ped, 5, 45, 0, 2)
        TriggerEvent('AttackTransport:CleanUp')
    end, function() 
        if DoesEntityExist(bag) then DeleteEntity(bag) end
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        TMGCore.Functions.Notify("You bailed out of the robbery!", "error")
        TriggerServerEvent("AttackTransport:server:CancelLooting")
    end)
end
