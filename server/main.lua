local ESX = nil
local QBCore = nil

CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        pcall(function()
            ESX = exports['es_extended']:getSharedObject()
        end)
    end

    if GetResourceState('qb-core') == 'started' then
        pcall(function()
            QBCore = exports['qb-core']:GetCoreObject()
        end)
    end
end)

local freezeStates = {}
local muteStates = {}

local function hasPermission(source)
    if Config.RequireAcePermission then
        return IsPlayerAceAllowed(source, Config.AcePermission)
    end

    return true
end

local function ensurePermission(source)
    if not hasPermission(source) then
        TriggerClientEvent('admin:addLog', source, 'Permission insuffisante pour cette action')
        return false
    end

    return true
end

local function notify(source, message)
    TriggerClientEvent('chat:addMessage', source, {
        color = {0, 153, 255},
        multiline = true,
        args = {'ADMIN', message}
    })
end

RegisterNetEvent('admin:requestPlayers', function()
    local src = source
    if not ensurePermission(src) then
        return
    end

    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(playerId)
        local coords = GetEntityCoords(ped)
        table.insert(players, {
            id = tonumber(playerId),
            name = GetPlayerName(playerId),
            ping = GetPlayerPing(playerId),
            coords = {x = coords.x, y = coords.y, z = coords.z}
        })
    end

    TriggerClientEvent('admin:receivePlayers', src, players)
end)

RegisterNetEvent('admin:bring', function(targetId, coords)
    local src = source
    if not ensurePermission(src) then return end

    if targetId and coords then
        TriggerClientEvent('admin:teleportTo', targetId, coords)
    end
end)

RegisterNetEvent('admin:teleportToWaypoint', function(targetId, coords)
    local src = source
    if not ensurePermission(src) then return end

    if targetId and coords then
        TriggerClientEvent('admin:teleportTo', targetId, coords)
    end
end)

RegisterNetEvent('admin:privateMessage', function(targetId, message)
    local src = source
    if not ensurePermission(src) then return end

    if not targetId or not message then return end

    notify(targetId, ('MP de %s: %s'):format(GetPlayerName(src), message))
    notify(src, ('MP envoyé à %s'):format(GetPlayerName(targetId)))
end)

RegisterNetEvent('admin:toggleFreeze', function(targetId)
    local src = source
    if not ensurePermission(src) then return end

    if not targetId then return end

    freezeStates[targetId] = not freezeStates[targetId]
    TriggerClientEvent('admin:toggleFreeze', targetId, freezeStates[targetId])
end)

RegisterNetEvent('admin:killPlayer', function(targetId)
    local src = source
    if not ensurePermission(src) then return end
    if not targetId then return end

    TriggerClientEvent('admin:setHealth', targetId, 0, 0)
end)

RegisterNetEvent('admin:revivePlayer', function(targetId)
    local src = source
    if not ensurePermission(src) then return end
    if not targetId then return end

    TriggerClientEvent('admin:setHealth', targetId, 200, 100)
end)

RegisterNetEvent('admin:healPlayer', function(targetId, health, armour)
    local src = source
    if not ensurePermission(src) then return end
    if not targetId then return end

    TriggerClientEvent('admin:setHealth', targetId, health or 200, armour or 100)
end)

RegisterNetEvent('admin:openSkinMenu', function(targetId)
    local src = source
    if not ensurePermission(src) then return end
    if not targetId then return end

    if GetResourceState('esx_skin') == 'started' then
        TriggerClientEvent('esx_skin:openSaveableMenu', targetId, targetId)
    elseif GetResourceState('qb-clothing') == 'started' then
        TriggerClientEvent('qb-clothing:client:openMenu', targetId)
    else
        notify(src, 'Aucune ressource de skin supportée n\'est démarrée')
    end
end)

local function getFrameworkPlayer(targetId)
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(targetId)
        if xPlayer then
            return xPlayer, 'esx'
        end
    end

    if QBCore then
        local qbPlayer = QBCore.Functions.GetPlayer(targetId)
        if qbPlayer then
            return qbPlayer, 'qbcore'
        end
    end

    return nil, nil
end

RegisterNetEvent('admin:giveMoney', function(targetId, account, amount)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    amount = tonumber(amount)
    if not targetId or not amount then return end

    local player, framework = getFrameworkPlayer(targetId)

    if framework == 'esx' then
        if account == 'cash' then
            player.addMoney(amount)
        elseif account == 'bank' then
            player.addAccountMoney('bank', amount)
        else
            player.addAccountMoney('black_money', amount)
        end
    elseif framework == 'qbcore' then
        local moneyType = account == 'bank' and 'bank' or (account == 'black' and 'crypto' or 'cash')
        player.Functions.AddMoney(moneyType, amount)
    else
        notify(src, 'Aucun framework économique détecté pour donner de l\'argent')
    end
end)

RegisterNetEvent('admin:takeMoney', function(targetId, amount)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    amount = tonumber(amount)
    if not targetId or not amount then return end

    local player, framework = getFrameworkPlayer(targetId)

    if framework == 'esx' then
        player.removeAccountMoney('bank', amount)
        player.removeAccountMoney('black_money', amount)
        player.removeMoney(amount)
    elseif framework == 'qbcore' then
        player.Functions.RemoveMoney('cash', amount)
        player.Functions.RemoveMoney('bank', amount)
    else
        notify(src, 'Aucun framework économique détecté pour retirer de l\'argent')
    end
end)

RegisterNetEvent('admin:setJob', function(targetId, job, grade)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    grade = tonumber(grade) or 0
    if not targetId or not job then return end

    local player, framework = getFrameworkPlayer(targetId)

    if framework == 'esx' then
        player.setJob(job, grade)
    elseif framework == 'qbcore' then
        player.Functions.SetJob(job, grade)
    else
        notify(src, 'Impossible de changer le job : framework non supporté')
    end
end)

RegisterNetEvent('admin:viewInventory', function(targetId)
    local src = source
    if not ensurePermission(src) then return end

    if GetResourceState('mf-inventory') == 'started' then
        TriggerClientEvent('mf-inventory:viewOtherInventory', src, targetId)
    else
        notify(src, 'Aucun inventaire compatible détecté')
    end
end)

RegisterNetEvent('admin:inspectPlayer', function(targetId)
    local src = source
    if not ensurePermission(src) then return end

    TriggerClientEvent('admin:addLog', src, 'Inspection demandée - implémentez l\'event côté serveur selon votre inventaire')
end)

RegisterNetEvent('admin:kickPlayer', function(targetId, reason)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    if not targetId then return end

    DropPlayer(targetId, reason or 'Kick administrateur')
end)

RegisterNetEvent('admin:banPlayer', function(targetId, duration, reason)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    if not targetId then return end

    -- Intégration spécifique au système de ban à ajouter ici
    DropPlayer(targetId, ('Banni (%s): %s'):format(duration or 'permanent', reason or ''))
    notify(src, 'Aucun système de ban persistant détecté, kick exécuté à la place')
end)

RegisterNetEvent('admin:warnPlayer', function(targetId, reason)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    if not targetId then return end

    notify(targetId, ('Avertissement: %s'):format(reason or ''))
end)

RegisterNetEvent('admin:requestSanctions', function(targetId)
    local src = source
    if not ensurePermission(src) then return end
    notify(src, 'Implémentez la récupération des sanctions selon votre base de données')
end)

RegisterNetEvent('admin:toggleMute', function(targetId)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    if not targetId then return end

    muteStates[targetId] = not muteStates[targetId]
    TriggerClientEvent('admin:addLog', src, ('Mute du joueur %s: %s'):format(targetId, muteStates[targetId] and 'ON' or 'OFF'))
end)

RegisterNetEvent('admin:broadcast', function(message)
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('chat:addMessage', -1, {
        color = {255, 0, 0},
        multiline = true,
        args = {'ANNONCE ADMIN', message}
    })
end)

RegisterNetEvent('admin:requestServerLogs', function()
    local src = source
    if not ensurePermission(src) then return end
    notify(src, 'Consultez la console serveur pour les logs détaillés')
end)

RegisterNetEvent('admin:createSafeZone', function(radius)
    local src = source
    if not ensurePermission(src) then return end
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('admin:createSafeZone', -1, src, {x = coords.x, y = coords.y, z = coords.z}, radius or 50.0)
end)

RegisterNetEvent('admin:spawnVehicle', function(model)
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('admin:spawnVehicleClient', src, model)
end)

RegisterNetEvent('admin:cleanupArea', function()
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('admin:cleanupAreaClient', src)
end)

RegisterNetEvent('admin:fixVehicle', function()
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('admin:fixVehicleClient', src)
end)

RegisterNetEvent('admin:setWeather', function(weather)
    local src = source
    if not ensurePermission(src) then return end

    weather = weather or 'CLEAR'
    SetWeatherTypeOverTime(weather, 1.0)
    Wait(1000)
    SetWeatherTypeNowPersist(weather)
    TriggerClientEvent('chat:addMessage', -1, {
        color = {0, 153, 255},
        args = {'METEO', ('Météo définie sur %s'):format(weather)}
    })
end)

RegisterNetEvent('admin:setTime', function(hour, minute)
    local src = source
    if not ensurePermission(src) then return end
    hour = tonumber(hour) or 12
    minute = tonumber(minute) or 0

    NetworkOverrideClockTime(hour, minute, 0)
    TriggerClientEvent('chat:addMessage', -1, {
        color = {0, 153, 255},
        args = {'TEMPS', ('Heure définie sur %02d:%02d'):format(hour, minute)}
    })
end)

RegisterNetEvent('admin:requestScreenshot', function(targetId)
    local src = source
    if not ensurePermission(src) then return end

    if GetResourceState('screenshot-basic') == 'started' then
        exports['screenshot-basic']:requestClientScreenshot(targetId, {
            encoding = 'jpg'
        }, function(data)
            if data then
                notify(src, 'Screenshot reçu (voir console serveur)')
                print(('Screenshot %s -> %s bytes'):format(targetId, #data))
            else
                notify(src, 'Échec du screenshot')
            end
        end)
    else
        notify(src, 'Resource screenshot-basic non démarrée')
    end
end)

RegisterNetEvent('admin:manageResource', function(action, resource)
    local src = source
    if not ensurePermission(src) then return end
    if not action or not resource then return end

    ExecuteCommand(('%s %s'):format(action, resource))
end)

RegisterNetEvent('admin:playAnimationAll', function(dict, anim)
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('admin:playAnimation', -1, dict, anim)
end)

RegisterNetEvent('admin:teleportAllToPoint', function(coords)
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('admin:teleportTo', -1, coords)
end)

RegisterNetEvent('admin:spawnVehiclesForAll', function(model)
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('admin:spawnVehicleClient', -1, model)
end)

RegisterNetEvent('admin:explodeArea', function(radius)
    local src = source
    if not ensurePermission(src) then return end
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    TriggerClientEvent('admin:explodeAreaClient', -1, {x = coords.x, y = coords.y, z = coords.z}, radius or 5.0)
end)

RegisterNetEvent('admin:toggleGlobalInvis', function()
    local src = source
    if not ensurePermission(src) then return end
    TriggerClientEvent('admin:toggleGlobalInvisClient', -1)
end)

RegisterNetEvent('admin:giveItem', function(targetId, item, amount)
    local src = source
    if not ensurePermission(src) then return end
    targetId = tonumber(targetId)
    amount = tonumber(amount) or 1
    if not targetId or not item then return end

    local player, framework = getFrameworkPlayer(targetId)

    if framework == 'esx' then
        player.addInventoryItem(item, amount)
    elseif framework == 'qbcore' then
        player.Functions.AddItem(item, amount)
        if QBCore and QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[item] then
            TriggerClientEvent('inventory:client:ItemBox', targetId, QBCore.Shared.Items[item], 'add')
        end
    else
        notify(src, 'Impossible de donner l\'item : framework non détecté')
    end
end)

RegisterNetEvent('admin:createItemDrop', function(item, amount)
    local src = source
    if not ensurePermission(src) then return end
    amount = tonumber(amount) or 1
    TriggerClientEvent('admin:createItemDropClient', src, item, amount)
end)

RegisterNetEvent('admin:listResources', function()
    local src = source
    if not ensurePermission(src) then return end

    local count = GetNumResources()
    for i = 0, count - 1 do
        local resource = GetResourceByFindIndex(i)
        if resource and GetResourceState(resource) == 'started' then
            notify(src, ('%s (running)'):format(resource))
        end
    end
end)

RegisterNetEvent('admin:showBlipData', function()
    local src = source
    if not ensurePermission(src) then return end
    notify(src, 'Affichage des blips à implémenter selon vos besoins')
end)

RegisterNetEvent('admin:refreshDatabase', function()
    local src = source
    if not ensurePermission(src) then return end
    notify(src, 'Refresh base de données : implémentez selon votre système')
end)

RegisterNetEvent('admin:testTrigger', function(eventName)
    local src = source
    if not ensurePermission(src) then return end
    if eventName then
        TriggerEvent(eventName, src)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    freezeStates[src] = nil
    muteStates[src] = nil
end)
