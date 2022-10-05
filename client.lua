local pedCoords = GetEntityCoords(PlayerPedId())
local markerCoords = vector3(-1491.4, 4981.56, 63.31)
local vehicle
local startedHunting = false
local atSpot = false
local animalAtBait = false
local animalDead = false
local collectingCarcass = false
local bait
local animalPed
local random = math.random

local spots = {
    { x = -1642, y = 4728.94, z = 53.64, },
    { x = -1520.67, y = 4698.74, z = 40.36 },
    { x = -1579.73, y = 4662.88, z = 46.23 }
}

local animals = {
    'a_c_deer',
    'a_c_boar',
    'a_c_coyote',
    'a_c_mtlion'
}

AddTextEntry('start_hunting', 'Press ~INPUT_WEAPON_SPECIAL_TWO~ to start hunting.')
AddTextEntry('collect_carcass', 'Press ~INPUT_WEAPON_SPECIAL_TWO~ to collect carcass.')

-- Display's a notification anchored to the minimap.
---@param text string
local function notify(text)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(text)
    DrawNotification(false, false)
end

-- Create's the hunting-vehicle, and returns the vehicle handle.
---@return CVehicle
local function spawnVehicle()
    RequestModel(`bodhi2`)

    while not HasModelLoaded(`bodhi2`) do
        Wait(0)
    end

    vehicle = CreateVehicle(`bodhi2`, -1497.13, 4968.39, 63.54, 178.29, true, false)
    SetVehicleOnGroundProperly(vehicle)
    SetModelAsNoLongerNeeded(`bodhi2`)
    return vehicle
end

-- Randomly selects an item from a specified table.
---@param table table
---@return index
local function randomItem(table)
    local keys = {}
    for key, value in pairs(table) do
        keys[#keys + 1] = key
    end
    index = keys[random(1, #keys)]
    return table[index]
end

---@param model string | number
local function LoadModel(model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Wait(0)
    end
end

---@param dict string
local function LoadDict(dict)
    RequestAnimDict(dict)

    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

-- Ends the hunting session.
local function endHunt()
    SetEntityAsMissionEntity(vehicle, false, false)
    DeleteEntity(vehicle)
    DeleteEntity(animalPed)
    DeleteEntity(bait)
    RemoveWeaponFromPed(PlayerPedId(), `weapon_sniperrifle`)
    RemoveWeaponFromPed(PlayerPedId(), `weapon_combatpistol`)
    SetEntityCoords(PlayerPedId(), markerCoords.x, markerCoords.y, markerCoords.z)
    SetWaypointOff()
    notify('You\'ve ~r~ended~s~ the hunt.')
    startedHunting = false
    atSpot = false
    vehicle = nil
    bait = nil
    animalPed = nil
    animalAtBait = false
    animalDead = false
    collectingCarcass = false
end

-- Main Thread
CreateThread(function()
    while true do
        Wait(0)

        if not startedHunting and #(pedCoords - markerCoords) <= 15.0 then
            DrawMarker(1, markerCoords.x, markerCoords.y, markerCoords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 2.0, 2.0, 2.0, 153, 51, 255, 50, false, true, 2.0, nil, nil, false)

            if #(pedCoords - markerCoords) <= 2.0 then
                DisplayHelpTextThisFrame('start_hunting')

                if IsControlJustPressed(0, 51) and not IsPedInAnyVehicle(PlayerPedId(), true) then
                    startedHunting = true

                    local waypoint = randomItem(spots)

                    GiveWeaponToPed(PlayerPedId(), `weapon_sniperrifle`, 100, false, false)
                    GiveWeaponToPed(PlayerPedId(), `weapon_combatpistol`, 100, false, false)
                    SetWaypointOff()
                    SetNewWaypoint(waypoint.x, waypoint.y)
                    local wpCoords = vector3(waypoint.x, waypoint.y, waypoint.z)

                    notify('I\'ve marked the first ~y~hunting spot~s~ on your minimap, ~y~drive~s~ to it to get started.')
                    notify('Press ~y~F5~s~ or use the ~y~endhunt~s~ command to ~r~end the hunt~s~ at anytime.')

                    vehicle = spawnVehicle()

                    if DoesEntityExist(vehicle) then
                        SetVehicleEngineOn(vehicle, true, true, false)
                        SetVehRadioStation(vehicle, 'OFF')
                        TaskEnterVehicle(PlayerPedId(), vehicle, 9000, -1, 2.0, 1, 0)
                    else
                        print('^1something went wrong while spawning the hunting-vehicle^0!')
                        break
                    end

                    while startedHunting and not atSpot do
                        Wait(0)

                        if #(pedCoords - wpCoords) <= 25.0 then
                            atSpot = true
                            break
                        else
                            Wait(1000)
                        end
                    end

                    if atSpot then
                        notify('You\'ve arrived at your ~g~hunting spot~s~, leave your vehicle and press ~y~E~s~ to drop ~g~bait~s~!')
                        SetWaypointOff()
                    end

                    while atSpot do
                        Wait(0)

                        if IsControlJustPressed(0, 51) and not IsPedInAnyVehicle(PlayerPedId(), true) and not collectingCarcass then
                            LoadModel(`prop_food_tray_02`)
                            LoadDict('amb@medic@standing@kneel@base')
                            LoadDict('anim@gangops@facility@servers@bodysearch@')

                            notify('Placing ~g~bait~s~...')
                            TaskPlayAnim(PlayerPedId(), 'amb@medic@standing@kneel@base', 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
                            TaskPlayAnim(PlayerPedId(), 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, -8.0, -1, 48, 0, false, false, false)

                            Wait(5000)

                            ClearPedTasks(PlayerPedId())

                            bait = CreateObject(`prop_food_tray_02`, pedCoords.x + 1.0, pedCoords.y, pedCoords.z, true, true, false)
                            PlaceObjectOnGroundProperly(bait)
                            FreezeEntityPosition(bait, true)
                            SetEntityCanBeDamaged(bait, false)
                            SetModelAsNoLongerNeeded(`prop_food_tray_02`)
                            notify('You\'ve dropped ~g~bait~s~, now get to a safe place and wait for an ~y~animal~s~ to come!')

                            Wait(25000)

                            local animal = joaat(randomItem(animals))

                            LoadModel(animal)

                            animalPed = CreatePed(0, animal, -1527.95, 4818.62, 75.04, 0.0, true, true)
                            SetModelAsNoLongerNeeded(animal)
                            TaskGoToEntity(animalPed, bait, -1, 4.0, 100, 1073741824, 0)
                            RemoveAnimDict('amb@medic@standing@kneel@base')
                            RemoveAnimDict('anim@gangops@facility@servers@bodysearch@')
                        elseif IsControlJustPressed(0, 51) and IsPedInAnyVehicle(PlayerPedId(), true) then
                            notify('You ~y~can\'t~s~ drop ~g~bait~s~ while in a vehicle!')
                        end
                    end
                elseif IsControlJustPressed(0, 51) and IsPedInAnyVehicle(PlayerPedId(), true) then
                    notify('You ~y~can\'t~s~ start hunting in a vehicle.')
                end
            end
        else
            Wait(2000)
        end
    end
end)

CreateThread(function()
    local timer = GetGameTimer()

    while true do
        Wait(0)

        if startedHunting then
            if #(pedCoords - markerCoords) >= 600.0 then
                notify('You\'ve ~r~left~s~ the hunting area, ~r~ending~s~ the hunt.')
                endHunt()
            end
        else
            Wait(2500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(0)

        if animalDead then
            if #(pedCoords - GetEntityCoords(animalPed)) <= 2.0 then
                DisplayHelpTextThisFrame('collect_carcass')

                if IsControlJustPressed(0, 51) then
                    collectingCarcass = true

                    LoadDict('amb@medic@standing@kneel@base')
                    LoadDict('anim@gangops@facility@servers@bodysearch@')

                    TaskPlayAnim(PlayerPedId(), 'amb@medic@standing@kneel@base', 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
                    TaskPlayAnim(PlayerPedId(), 'anim@gangops@facility@servers@bodysearch@', 'player_search', 8.0, -8.0, -1, 48, 0, false, false, false)

                    Wait(5000)

                    ClearPedTasks(PlayerPedId())
                    DeleteEntity(animalPed)
                    notify('Good job! You\'ve ~g~collected~s~ the ~y~carcass~s~, ~y~ending the hunt.')
                    Wait(3500)
                    endHunt()
                    RemoveAnimDict('amb@medic@standing@kneel@base')
                    RemoveAnimDict('anim@gangops@facility@servers@bodysearch@')
                end
            end
        else
            Wait(2000)
        end
    end
end)

CreateThread(function()
    while true do
        pedCoords = GetEntityCoords(PlayerPedId())

        if atSpot and animalPed ~= nil and not IsPedDeadOrDying(animalPed, 1) then
            if #(GetEntityCoords(animalPed) - GetEntityCoords(bait)) <= 15.0 then
                animalAtBait = true
                notify('You\'ve spotted an ~y~animal~s~, get your ~y~sniper~s~ out and ~y~take the shot~s~!')
            end
        elseif atSpot and animalPed ~= nil and IsPedDeadOrDying(animalPed, 1) then
            notify('Nice shot! Now go and ~g~collect the carcass~s~.')
            animalDead = true
        end

        if atSpot and animalPed ~= nil and animalAtBait and not collectingCarcass then
            if #(GetEntityCoords(animalPed) - GetEntityCoords(bait)) >= 25.0 then
                notify('You\'ve ~r~missed~s~ the shot and startled the ~y~animal~s~, the hunt\'s been ~r~ended~s~.')
                Wait(3500)
                endHunt()
            end
        end

        Wait(500)
    end
end)

CreateThread(function()
    while true do
        Wait(0)

        if startedHunting then
            if IsControlJustPressed(0, 166) then
                endHunt()
            end
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    local blip = AddBlipForCoord(markerCoords.x, markerCoords.y, markerCoords.z)
    SetBlipSprite(blip, 141)
    SetBlipColour(blip, 83)
    SetBlipScale(blip, 1.2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Hunting')
    EndTextCommandSetBlipName(blip)
end)

RegisterCommand('endhunt', function()
    if startedHunting then endHunt() else notify('You\'re ~r~NOT~s~ currently in a hunt.') end
end, false)