local open = false
local isSpectating = false
local spectateTarget = nil
local originalCoords = nil
local originalHeading = nil
local savedPosition = nil
local noclipActive = false
local staffMode = false
local undercoverIdentity = nil
local playerSearch = ''
local lastRefresh = 0.0
local playerList = {}
local filteredPlayers = {}
local selectedPlayer = nil
local actionLogs = {}
local activeSafeZone = nil
local globalInvisibility = false

local function debugPrint(msg)
    print(('[AdminMenu] %s'):format(msg))
end

local function ensurePermissions(section)
    if Config.RequireAcePermission and not IsPlayerAceAllowed(PlayerId(), Config.AcePermission) then
        return false
    end

    if Config.DefaultPermissions[section] == nil then
        return false
    end

    return Config.DefaultPermissions[section]
end

local function formatVector(vec)
    return ('%.2f %.2f %.2f'):format(vec.x, vec.y, vec.z)
end

local function addLog(message)
    table.insert(actionLogs, 1, ('[%s] %s'):format(os.date('%H:%M:%S'), message))

    if #actionLogs > Config.LogLimit then
        table.remove(actionLogs)
    end
end

local function keyboardInput(windowTitle, defaultText, maxLength)
    AddTextEntry('ADMIN_MENU_INPUT', windowTitle)
    DisplayOnscreenKeyboard(1, 'ADMIN_MENU_INPUT', '', defaultText or '', '', '', '', maxLength or 255)

    while UpdateOnscreenKeyboard() == 0 do
        DisableAllControlActions(0)
        Wait(0)
    end

    if GetOnscreenKeyboardResult() then
        return GetOnscreenKeyboardResult()
    end

    return nil
end

local function toggleSpectate(targetId)
    local ped = PlayerPedId()

    if isSpectating then
        NetworkSetInSpectatorMode(false, 0)
        if originalCoords then
            SetEntityCoords(ped, originalCoords.x, originalCoords.y, originalCoords.z)
            SetEntityHeading(ped, originalHeading or 0.0)
        end

        isSpectating = false
        spectateTarget = nil
        addLog('Arrêt du mode spectateur')
        return
    end

    local targetPlayer = GetPlayerFromServerId(targetId)

    if targetPlayer == -1 then
        addLog('Impossible de spectate : joueur introuvable')
        return
    end

    originalCoords = GetEntityCoords(ped)
    originalHeading = GetEntityHeading(ped)

    NetworkSetInSpectatorMode(true, GetPlayerPed(targetPlayer))
    isSpectating = true
    spectateTarget = targetId
    addLog(('Spectate du joueur %s'):format(targetId))
end

local function toggleNoClip()
    local ped = PlayerPedId()
    noclipActive = not noclipActive

    if noclipActive then
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)
        addLog('Activation du noclip')
    else
        SetEntityInvincible(ped, staffMode)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        addLog('Désactivation du noclip')
    end
end

local function toggleStaffMode()
    local ped = PlayerPedId()
    staffMode = not staffMode

    if staffMode then
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityCanBeDamaged(ped, false)
        SetPedCanRagdoll(ped, false)
        addLog('Activation du mode staff')
    else
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityCanBeDamaged(ped, true)
        SetPedCanRagdoll(ped, true)
        addLog('Désactivation du mode staff')
    end
end

local function toggleUndercover()
    local ped = PlayerPedId()

    if undercoverIdentity then
        if undercoverIdentity.model then
            RequestModel(undercoverIdentity.model)
            while not HasModelLoaded(undercoverIdentity.model) do
                Wait(0)
            end
            SetPlayerModel(PlayerId(), undercoverIdentity.model)
            SetModelAsNoLongerNeeded(undercoverIdentity.model)
        end

        addLog('Fin du mode undercover')
        undercoverIdentity = nil
        return
    end

    local pedModel = keyboardInput('Modèle (ex: a_m_m_skater_01)', '', 30)
    if not pedModel or pedModel == '' then
        addLog('Aucun modèle spécifié')
        return
    end

    local hash = GetHashKey(pedModel)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        addLog('Modèle invalide pour le mode undercover')
        return
    end

    undercoverIdentity = {
        model = GetEntityModel(ped)
    }

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)

    addLog(('Mode undercover activé (%s)'):format(pedModel))
end

local function updateFilteredPlayers()
    filteredPlayers = {}

    local search = string.lower(playerSearch or '')
    for _, player in ipairs(playerList) do
        if search == '' then
            table.insert(filteredPlayers, player)
        else
            local haystack = string.format('%s%s', string.lower(player.name or ''), tostring(player.id))
            if string.find(haystack, search, 1, true) then
                table.insert(filteredPlayers, player)
            end
        end
    end
end

local function refreshPlayers(force)
    local now = GetGameTimer() / 1000.0
    if not force and now - lastRefresh < Config.RefreshInterval then
        return
    end

    TriggerServerEvent('admin:requestPlayers')
    lastRefresh = now
end

local function openMenu()
    if open then
        return
    end

    if Config.RequireAcePermission and not IsPlayerAceAllowed(PlayerId(), Config.AcePermission) then
        addLog("Permission refusée pour ouvrir le menu")
        return
    end

    refreshPlayers(true)
    RageUI.Visible(RMenu:Get('admin', 'main'), true)
    open = true
end

local function closeMenu()
    RageUI.Visible(RMenu:Get('admin', 'main'), false)
    open = false
end

RMenu.Add('admin', 'main', RageUI.CreateMenu('Admin', "Gestion complète"))
RMenu.Add('admin', 'players', RageUI.CreateSubMenu(RMenu:Get('admin', 'main'), 'Gestion des joueurs', 'Actions sur les joueurs'))
RMenu.Add('admin', 'player_list', RageUI.CreateSubMenu(RMenu:Get('admin', 'players'), 'Joueurs connectés', 'Sélection d\'un joueur'))
RMenu.Add('admin', 'player_actions', RageUI.CreateSubMenu(RMenu:Get('admin', 'player_list'), 'Actions joueur', 'Options ciblées'))
RMenu.Add('admin', 'player_money', RageUI.CreateSubMenu(RMenu:Get('admin', 'player_actions'), 'Argent', 'Gestion des finances'))
RMenu.Add('admin', 'moderation', RageUI.CreateSubMenu(RMenu:Get('admin', 'main'), 'Modération', 'Sanctions et suivi'))
RMenu.Add('admin', 'utilities', RageUI.CreateSubMenu(RMenu:Get('admin', 'main'), 'Utilitaires', 'Outils d\'intervention'))
RMenu.Add('admin', 'fun', RageUI.CreateSubMenu(RMenu:Get('admin', 'main'), 'Fun & RP', 'Animation et RP'))
RMenu.Add('admin', 'technical', RageUI.CreateSubMenu(RMenu:Get('admin', 'main'), 'Technique', 'Outils développeur'))
RMenu.Add('admin', 'logs', RageUI.CreateSubMenu(RMenu:Get('admin', 'main'), 'Logs', 'Historique des actions'))

RMenu:Get('admin', 'main').Closed = function()
    open = false
end

RegisterCommand(Config.CommandName, function()
    if open then
        closeMenu()
    else
        openMenu()
    end
end, false)

RegisterKeyMapping(Config.CommandName, 'Ouvrir le menu admin', 'keyboard', Config.OpenKey)

RegisterNetEvent('admin:receivePlayers', function(players)
    playerList = players or {}
    updateFilteredPlayers()
end)

RegisterNetEvent('admin:forceClose', function()
    closeMenu()
end)

local function teleportToCoords(coords)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        SetEntityCoords(veh, coords.x, coords.y, coords.z, false, false, false, false)
    else
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    end
end

RegisterNetEvent('admin:teleportTo', function(coords)
    if coords then
        teleportToCoords(vector3(coords.x, coords.y, coords.z))
    end
end)

RegisterNetEvent('admin:setHealth', function(health, armour)
    local ped = PlayerPedId()
    if health then
        SetEntityHealth(ped, health)
    end
    if armour then
        SetPedArmour(ped, armour)
    end
end)

RegisterNetEvent('admin:toggleFreeze', function(state)
    FreezeEntityPosition(PlayerPedId(), state)
end)

RegisterNetEvent('admin:spawnVehicleClient', function(model)
    if not model or model == '' then
        addLog('Modèle de véhicule invalide')
        return
    end

    local ped = PlayerPedId()
    local hash = GetHashKey(model)

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        addLog(('Modèle inconnu: %s'):format(model))
        return
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleNumberPlateText(vehicle, 'ADMIN')
    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('admin:cleanupAreaClient', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if vehicle ~= GetVehiclePedIsIn(ped, false) and #(coords - GetEntityCoords(vehicle)) < 50.0 then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end

    for _, entity in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(entity) and #(coords - GetEntityCoords(entity)) < 40.0 then
            DeleteEntity(entity)
        end
    end

    for _, obj in ipairs(GetGamePool('CObject')) do
        if #(coords - GetEntityCoords(obj)) < 30.0 then
            DeleteEntity(obj)
        end
    end
end)

RegisterNetEvent('admin:fixVehicleClient', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        SetVehicleFixed(vehicle)
        SetVehicleDirtLevel(vehicle, 0.0)
        WashDecalsFromVehicle(vehicle, 1.0)
    else
        addLog('Aucun véhicule à réparer')
    end
end)

RegisterNetEvent('admin:createSafeZone', function(owner, coords, radius)
    if not coords then return end
    activeSafeZone = {
        owner = owner,
        coords = coords,
        radius = radius or 50.0,
        expires = GetGameTimer() + 300000
    }
    addLog(('Zone safe activée (rayon %sm)'):format(activeSafeZone.radius))
end)

RegisterNetEvent('admin:playAnimation', function(dict, anim)
    if not dict or dict == '' or not anim or anim == '' then return end
    local ped = PlayerPedId()
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(dict)
end)

RegisterNetEvent('admin:explodeAreaClient', function(coords, radius)
    if not coords then return end
    AddExplosion(coords.x, coords.y, coords.z, 2, 5.0, true, false, radius or 5.0, false)
end)

RegisterNetEvent('admin:toggleGlobalInvisClient', function()
    globalInvisibility = not globalInvisibility
    local ped = PlayerPedId()
    SetEntityVisible(ped, not globalInvisibility, false)
    SetEntityInvincible(ped, globalInvisibility or staffMode)
end)

RegisterNetEvent('admin:createItemDropClient', function(item, amount)
    local ped = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local baseCoords = GetEntityCoords(ped) + forward * 2.0
    local model = `prop_cs_heist_bag_02`
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    local obj = CreateObject(model, baseCoords.x, baseCoords.y, baseCoords.z, true, true, false)
    PlaceObjectOnGroundProperly(obj)
    SetModelAsNoLongerNeeded(model)
    addLog(('Drop visuel créé pour %s x%s (configurer votre inventaire pour un vrai drop)'):format(item or 'item', amount or 1))
end)

RegisterNetEvent('admin:toggleFreecam', function()
    addLog('Intégrer votre propre freecam et déclencher cet event')
end)

RegisterNetEvent('admin:spawnVehicleClientAll', function(model)
    TriggerEvent('admin:spawnVehicleClient', model)
end)

RegisterNetEvent('admin:addLog', function(message)
    if message then
        addLog(message)
    end
end)

RegisterNetEvent('admin:spawnVehicleClient', function(model)
    if not model or model == '' then
        addLog('Modèle de véhicule invalide')
        return
    end

    local ped = PlayerPedId()
    local hash = GetHashKey(model)

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        addLog(('Modèle inconnu: %s'):format(model))
        return
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleNumberPlateText(vehicle, 'ADMIN')
    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('admin:cleanupAreaClient', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if vehicle ~= GetVehiclePedIsIn(ped, false) and #(coords - GetEntityCoords(vehicle)) < 50.0 then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end

    for _, entity in ipairs(GetGamePool('CPed')) do
        if not IsPedAPlayer(entity) and #(coords - GetEntityCoords(entity)) < 40.0 then
            DeleteEntity(entity)
        end
    end

    for _, obj in ipairs(GetGamePool('CObject')) do
        if #(coords - GetEntityCoords(obj)) < 30.0 then
            DeleteEntity(obj)
        end
    end
end)

RegisterNetEvent('admin:fixVehicleClient', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        SetVehicleFixed(vehicle)
        SetVehicleDirtLevel(vehicle, 0.0)
        WashDecalsFromVehicle(vehicle, 1.0)
    else
        addLog('Aucun véhicule à réparer')
    end
end)

RegisterNetEvent('admin:createSafeZone', function(owner, coords, radius)
    if not coords then return end
    activeSafeZone = {
        owner = owner,
        coords = coords,
        radius = radius or 50.0,
        expires = GetGameTimer() + 300000
    }
    addLog(('Zone safe activée (rayon %sm)'):format(activeSafeZone.radius))
end)

RegisterNetEvent('admin:playAnimation', function(dict, anim)
    if not dict or dict == '' or not anim or anim == '' then return end
    local ped = PlayerPedId()
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(dict)
end)

RegisterNetEvent('admin:explodeAreaClient', function(coords, radius)
    if not coords then return end
    AddExplosion(coords.x, coords.y, coords.z, 2, 5.0, true, false, radius or 5.0, false)
end)

RegisterNetEvent('admin:toggleGlobalInvisClient', function()
    globalInvisibility = not globalInvisibility
    local ped = PlayerPedId()
    SetEntityVisible(ped, not globalInvisibility, false)
    SetEntityInvincible(ped, globalInvisibility or staffMode)
end)

RegisterNetEvent('admin:createItemDropClient', function(item, amount)
    local ped = PlayerPedId()
    local forward = GetEntityForwardVector(ped)
    local baseCoords = GetEntityCoords(ped) + forward * 2.0
    local model = `prop_cs_heist_bag_02`
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    local obj = CreateObject(model, baseCoords.x, baseCoords.y, baseCoords.z, true, true, false)
    PlaceObjectOnGroundProperly(obj)
    SetModelAsNoLongerNeeded(model)
    addLog(('Drop visuel créé pour %s x%s (configurer votre inventaire pour un vrai drop)'):format(item or 'item', amount or 1))
end)

RegisterNetEvent('admin:toggleFreecam', function()
    addLog('Intégrez votre propre freecam et liez cet event')
end)

Citizen.CreateThread(function()
    while true do
        if activeSafeZone then
            local ped = PlayerPedId()
            local zoneCoords = vector3(activeSafeZone.coords.x, activeSafeZone.coords.y, activeSafeZone.coords.z)
            local coords = GetEntityCoords(ped)
            local distance = #(coords - zoneCoords)

            if distance <= activeSafeZone.radius then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 45, true)
                DisableControlAction(0, 47, true)
                DisablePlayerFiring(PlayerId(), true)
                if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then
                    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                end
            end

            if activeSafeZone.expires and GetGameTimer() > activeSafeZone.expires then
                activeSafeZone = nil
                addLog('Zone safe expirée')
            end

            Wait(0)
        else
            Wait(1000)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if noclipActive then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local camRot = GetGameplayCamRot(2)
            local heading = math.rad(camRot.z)
            local forward = vector3(-math.sin(heading), math.cos(heading), 0.0)
            local up = vector3(0.0, 0.0, 1.0)
            local speed = 1.5

            FreezeEntityPosition(ped, true)
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)

            if IsControlPressed(0, 21) then -- shift
                speed = speed * 3.0
            end

            if IsControlPressed(0, 32) then -- W
                coords = coords + forward * speed
            end

            if IsControlPressed(0, 33) then -- S
                coords = coords - forward * speed
            end

            if IsControlPressed(0, 34) then -- A
                coords = coords + vector3(-forward.y, forward.x, 0.0) * speed
            end

            if IsControlPressed(0, 35) then -- D
                coords = coords + vector3(forward.y, -forward.x, 0.0) * speed
            end

            if IsControlPressed(0, 22) then -- jump
                coords = coords + up * speed
            end

            if IsControlPressed(0, 36) then -- ctrl
                coords = coords - up * speed
            end

            SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, true, true, true)
        else
            Wait(250)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(0)
        if RageUI.Visible(RMenu:Get('admin', 'main')) then
            RageUI.IsVisible(RMenu:Get('admin', 'main'), function()
                if ensurePermissions('players') then
                    RageUI.Button('⚙️ Gestion des joueurs', 'Gérer les joueurs connectés.', {RightLabel = '→→'}, true, {
                        onSelected = function()
                            refreshPlayers(true)
                        end
                    }, RMenu:Get('admin', 'players'))
                end

                if ensurePermissions('moderation') then
                    RageUI.Button('🛡️ Modération', 'Sanctions et suivi des comportements.', {RightLabel = '→→'}, true, {}, RMenu:Get('admin', 'moderation'))
                end

                if ensurePermissions('utilities') then
                    RageUI.Button('✨ Utilitaires admin', 'Outils pour intervenir rapidement.', {RightLabel = '→→'}, true, {}, RMenu:Get('admin', 'utilities'))
                end

                if ensurePermissions('fun') then
                    RageUI.Button('😎 Fun & gestion RP', 'Animer des événements et ajouter du fun.', {RightLabel = '→→'}, true, {}, RMenu:Get('admin', 'fun'))
                end

                if ensurePermissions('technical') then
                    RageUI.Button('🧰 Options techniques', 'Outils avancés pour le staff.', {RightLabel = '→→'}, true, {}, RMenu:Get('admin', 'technical'))
                end

                RageUI.Button('🧾 Logs du menu', 'Historique des actions effectuées.', {RightLabel = '→→'}, true, {}, RMenu:Get('admin', 'logs'))
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'players'), function()
                RageUI.Button('🧍 Liste des joueurs connectés', 'Voir tous les joueurs en ligne.', {RightLabel = '→→'}, true, {}, RMenu:Get('admin', 'player_list'))
                RageUI.Button('🔍 Recherche rapide', 'Rechercher par nom ou ID.', {RightLabel = playerSearch ~= '' and playerSearch or 'Entrer'}, true, {
                    onSelected = function()
                        local input = keyboardInput('Recherche par nom ou ID', playerSearch, 50)
                        if input then
                            playerSearch = input
                            updateFilteredPlayers()
                        end
                    end
                })
                RageUI.Button('🔄 Rafraîchir', 'Mettre à jour la liste immédiatement.', {}, true, {
                    onSelected = function()
                        refreshPlayers(true)
                    end
                })
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'player_list'), function()
                if #filteredPlayers == 0 then
                    RageUI.Separator('Aucun joueur correspondant')
                end

                for _, player in ipairs(filteredPlayers) do
                    local description = ("ID: %s | Ping: %s | Position: %s"):format(player.id, player.ping or 'N/A', player.coords and formatVector(player.coords) or 'N/A')
                    RageUI.Button(('👤 %s'):format(player.name), description, {RightLabel = '→→'}, true, {
                        onSelected = function()
                            selectedPlayer = player
                        end
                    }, RMenu:Get('admin', 'player_actions'))
                end
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'player_actions'), function()
                if not selectedPlayer then
                    RageUI.Separator('Sélectionnez un joueur dans la liste')
                    return
                end

                RageUI.Separator(('Joueur: %s (%s)'):format(selectedPlayer.name, selectedPlayer.id))

                RageUI.Button('👀 Spectate', 'Voir le joueur en direct.', {RightLabel = isSpectating and 'ON' or 'OFF'}, true, {
                    onSelected = function()
                        toggleSpectate(selectedPlayer.id)
                    end
                })

                RageUI.Button('🧭 Se téléporter vers le joueur', nil, {}, true, {
                    onSelected = function()
                        local targetPlayer = GetPlayerFromServerId(selectedPlayer.id)
                        if targetPlayer ~= -1 then
                            local ped = GetPlayerPed(targetPlayer)
                            local coords = GetEntityCoords(ped)
                            teleportToCoords(coords)
                            addLog(('Téléportation vers %s'):format(selectedPlayer.name))
                        else
                            addLog('Joueur introuvable pour téléportation')
                        end
                    end
                })

                RageUI.Button('🚀 Téléporter le joueur vers soi', nil, {}, true, {
                    onSelected = function()
                        local coords = GetEntityCoords(PlayerPedId())
                        TriggerServerEvent('admin:bring', selectedPlayer.id, coords)
                        addLog(('Bring du joueur %s'):format(selectedPlayer.name))
                    end
                })

                RageUI.Button('🗺️ TP à un point de la carte', 'Téléporte le joueur sélectionné sur le blip.', {}, true, {
                    onSelected = function()
                        if IsWaypointActive() then
                            local waypointBlip = GetFirstBlipInfoId(8)
                            local waypointCoords = GetBlipCoords(waypointBlip)
                            TriggerServerEvent('admin:teleportToWaypoint', selectedPlayer.id, waypointCoords)
                            addLog(('Téléportation du joueur %s au point de carte'):format(selectedPlayer.name))
                        else
                            addLog('Aucun point GPS défini')
                        end
                    end
                })

                RageUI.Button('💬 Message privé', 'Envoyer un message au joueur.', {}, true, {
                    onSelected = function()
                        local message = keyboardInput('Message privé', '', 120)
                        if message and message ~= '' then
                            TriggerServerEvent('admin:privateMessage', selectedPlayer.id, message)
                            addLog(('MP envoyé à %s: %s'):format(selectedPlayer.name, message))
                        end
                    end
                })

                RageUI.Button('🔒 Freeze / unfreeze', 'Bloque le joueur sur place.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:toggleFreeze', selectedPlayer.id)
                        addLog(('Toggle freeze sur %s'):format(selectedPlayer.name))
                    end
                })

                RageUI.Button('💀 Tuer', 'Mettre le joueur à terre.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:killPlayer', selectedPlayer.id)
                        addLog(('Kill du joueur %s'):format(selectedPlayer.name))
                    end
                })

                RageUI.Button('❤️ Revive', 'Réanimer le joueur.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:revivePlayer', selectedPlayer.id)
                        addLog(('Revive du joueur %s'):format(selectedPlayer.name))
                    end
                })

                RageUI.Button('⚡ Heal / armure', 'Soigner et donner l\'armure.', {}, true, {
                    onSelected = function()
                        local health = 200
                        local armour = 100
                        TriggerServerEvent('admin:healPlayer', selectedPlayer.id, health, armour)
                        addLog(('Heal du joueur %s'):format(selectedPlayer.name))
                    end
                })

                RageUI.Button('🪪 Gestion apparence / skin', 'Ouvrir le menu de skin du joueur.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:openSkinMenu', selectedPlayer.id)
                        addLog(('Demande de menu skin pour %s'):format(selectedPlayer.name))
                    end
                })

                RageUI.Button('🕹️ Job / grade / argent', 'Accéder aux options économiques.', {RightLabel = '→→'}, true, {}, RMenu:Get('admin', 'player_money'))

                RageUI.Button('🕵️ Voir inventaire', 'Ouvre l\'inventaire pour consultation.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:viewInventory', selectedPlayer.id)
                        addLog(('Consultation inventaire de %s'):format(selectedPlayer.name))
                    end
                })

                RageUI.Button('🔍 Inspecter / confisquer', 'Inspecter le joueur et saisir des items.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:inspectPlayer', selectedPlayer.id)
                        addLog(('Inspection du joueur %s'):format(selectedPlayer.name))
                    end
                })
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'player_money'), function()
                if not selectedPlayer then
                    RageUI.Separator('Aucun joueur sélectionné')
                    return
                end

                RageUI.Button('💰 Donner de l\'argent (cash)', nil, {}, true, {
                    onSelected = function()
                        local amount = tonumber(keyboardInput('Montant à donner (cash)', '', 8))
                        if amount then
                            TriggerServerEvent('admin:giveMoney', selectedPlayer.id, 'cash', amount)
                            addLog(('Don de $%s (cash) à %s'):format(amount, selectedPlayer.name))
                        end
                    end
                })

                RageUI.Button('🏦 Donner de l\'argent (banque)', nil, {}, true, {
                    onSelected = function()
                        local amount = tonumber(keyboardInput('Montant à donner (banque)', '', 8))
                        if amount then
                            TriggerServerEvent('admin:giveMoney', selectedPlayer.id, 'bank', amount)
                            addLog(('Don de $%s (banque) à %s'):format(amount, selectedPlayer.name))
                        end
                    end
                })

                RageUI.Button('🪙 Donner de l\'argent sale', nil, {}, true, {
                    onSelected = function()
                        local amount = tonumber(keyboardInput('Montant sale', '', 8))
                        if amount then
                            TriggerServerEvent('admin:giveMoney', selectedPlayer.id, 'black', amount)
                            addLog(('Don de $%s (sale) à %s'):format(amount, selectedPlayer.name))
                        end
                    end
                })

                RageUI.Button('➖ Retirer de l\'argent', 'Retirer un montant au joueur.', {}, true, {
                    onSelected = function()
                        local amount = tonumber(keyboardInput('Montant à retirer', '', 8))
                        if amount then
                            TriggerServerEvent('admin:takeMoney', selectedPlayer.id, amount)
                            addLog(('Retrait de $%s à %s'):format(amount, selectedPlayer.name))
                        end
                    end
                })

                RageUI.Button('🕹️ Changer de job / grade', nil, {}, true, {
                    onSelected = function()
                        local job = keyboardInput('Job (ex: police)', '', 30)
                        if job and job ~= '' then
                            local grade = tonumber(keyboardInput('Grade (nombre)', '', 3)) or 0
                            TriggerServerEvent('admin:setJob', selectedPlayer.id, job, grade)
                            addLog(('Changement job %s -> %s (%s)'):format(selectedPlayer.name, job, grade))
                        end
                    end
                })
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'moderation'), function()
                RageUI.Button('🚫 Kick', 'Expulser le joueur du serveur.', {}, true, {
                    onSelected = function()
                        local id = keyboardInput('ID du joueur', '', 5)
                        local reason = keyboardInput('Raison du kick', '', 120)
                        if id and reason then
                            TriggerServerEvent('admin:kickPlayer', tonumber(id), reason)
                            addLog(('Kick du joueur %s: %s'):format(id, reason))
                        end
                    end
                })

                RageUI.Button('⛔ Ban', 'Bannir un joueur.', {}, true, {
                    onSelected = function()
                        local id = keyboardInput('ID du joueur', '', 5)
                        local duration = keyboardInput('Durée (ex: 1h, 3d, perm)', 'perm', 10)
                        local reason = keyboardInput('Raison du ban', '', 120)
                        if id and reason then
                            TriggerServerEvent('admin:banPlayer', tonumber(id), duration, reason)
                            addLog(('Ban du joueur %s (%s): %s'):format(id, duration or 'perm', reason))
                        end
                    end
                })

                RageUI.Button('⚠️ Warn', 'Avertir un joueur.', {}, true, {
                    onSelected = function()
                        local id = keyboardInput('ID du joueur', '', 5)
                        local reason = keyboardInput('Raison du warn', '', 120)
                        if id and reason then
                            TriggerServerEvent('admin:warnPlayer', tonumber(id), reason)
                            addLog(('Warn du joueur %s: %s'):format(id, reason))
                        end
                    end
                })

                RageUI.Button('🕓 Historique des sanctions', 'Consulter les sanctions d\'un joueur.', {}, true, {
                    onSelected = function()
                        local id = keyboardInput('ID du joueur', '', 5)
                        if id then
                            TriggerServerEvent('admin:requestSanctions', tonumber(id))
                        end
                    end
                })

                RageUI.Button('🔇 Mute vocal / chat', 'Réduit la communication du joueur.', {}, true, {
                    onSelected = function()
                        local id = keyboardInput('ID du joueur', '', 5)
                        if id then
                            TriggerServerEvent('admin:toggleMute', tonumber(id))
                            addLog(('Mute toggle du joueur %s'):format(id))
                        end
                    end
                })

                RageUI.Button('🔔 Message global', 'Envoyer un broadcast à tous.', {}, true, {
                    onSelected = function()
                        local message = keyboardInput('Message global', '', 200)
                        if message and message ~= '' then
                            TriggerServerEvent('admin:broadcast', message)
                            addLog(('Broadcast: %s'):format(message))
                        end
                    end
                })

                RageUI.Button('📄 Logs / journal', 'Voir l\'historique en console.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:requestServerLogs')
                    end
                })

                RageUI.Button('🧱 Zone safe / no-PVP', 'Créer une zone temporaire.', {}, true, {
                    onSelected = function()
                        local radius = tonumber(keyboardInput('Rayon en mètres', '50', 4)) or 50
                        TriggerServerEvent('admin:createSafeZone', radius)
                        addLog(('Zone safe créée (rayon %sm)'):format(radius))
                    end
                })

                RageUI.Button('🛑 Mode staff', 'Devient invisible/invincible.', {RightLabel = staffMode and 'ON' or 'OFF'}, true, {
                    onSelected = function()
                        toggleStaffMode()
                    end
                })
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'utilities'), function()
                RageUI.Button('🛰️ NoClip', 'Se déplacer librement.', {RightLabel = noclipActive and 'ON' or 'OFF'}, true, {
                    onSelected = function()
                        toggleNoClip()
                    end
                })

                RageUI.Button('🔥 Spawn véhicule', 'Faire apparaître un véhicule.', {}, true, {
                    onSelected = function()
                        local model = keyboardInput('Modèle du véhicule', '', 30)
                        if model and model ~= '' then
                            TriggerServerEvent('admin:spawnVehicle', model)
                            addLog(('Spawn véhicule %s'):format(model))
                        end
                    end
                })

                RageUI.Button('🧨 Supprimer véhicule / PNJ / objet', 'Nettoyer les entités proches.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:cleanupArea')
                        addLog('Nettoyage des entités proches')
                    end
                })

                RageUI.Button('🧱 Réparer / nettoyer véhicule', 'Fixe le véhicule actuel.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:fixVehicle')
                        addLog('Réparation du véhicule courant')
                    end
                })

                RageUI.Button('🎭 Mode undercover', 'Changer temporairement d\'identité.', {RightLabel = undercoverIdentity and 'ON' or 'OFF'}, true, {
                    onSelected = function()
                        toggleUndercover()
                    end
                })

                RageUI.Button('💾 Sauvegarder position', 'Sauvegarde la position actuelle.', {}, true, {
                    onSelected = function()
                        savedPosition = GetEntityCoords(PlayerPedId())
                        addLog(('Position sauvegardée %s'):format(formatVector(savedPosition)))
                    end
                })

                RageUI.Button('📂 Charger position', 'Retourne à la dernière position.', {}, true, {
                    onSelected = function()
                        if savedPosition then
                            teleportToCoords(savedPosition)
                            addLog('Position restaurée')
                        else
                            addLog('Aucune position sauvegardée')
                        end
                    end
                })

                RageUI.Button('🌦️ Changer météo', 'Applique une météo sur le serveur.', {}, true, {
                    onSelected = function()
                        local weather = keyboardInput('Type météo (CLEAR, RAIN, etc.)', 'CLEAR', 15)
                        if weather then
                            TriggerServerEvent('admin:setWeather', weather)
                            addLog(('Changement météo -> %s'):format(weather))
                        end
                    end
                })

                RageUI.Button('🕒 Changer heure', 'Fixer l\'heure du serveur.', {}, true, {
                    onSelected = function()
                        local hour = tonumber(keyboardInput('Heure (0-23)', '', 2)) or 12
                        local minute = tonumber(keyboardInput('Minute (0-59)', '', 2)) or 0
                        TriggerServerEvent('admin:setTime', hour, minute)
                        addLog(('Changement heure -> %02d:%02d'):format(hour, minute))
                    end
                })

                RageUI.Button('📸 Screenshot joueur', 'Prendre un screenshot du joueur.', {}, true, {
                    onSelected = function()
                        if selectedPlayer then
                            TriggerServerEvent('admin:requestScreenshot', selectedPlayer.id)
                            addLog(('Screenshot demandé pour %s'):format(selectedPlayer.name))
                        else
                            addLog('Sélectionnez un joueur pour le screenshot')
                        end
                    end
                })

                RageUI.Button('🧠 Redémarrer ressource', 'Restart/stop/start une ressource.', {}, true, {
                    onSelected = function()
                        local action = keyboardInput('Action (start/stop/restart)', 'restart', 10)
                        local resource = keyboardInput('Nom de la ressource', '', 40)
                        if action and resource then
                            TriggerServerEvent('admin:manageResource', action, resource)
                            addLog(('Action %s sur ressource %s'):format(action, resource))
                        end
                    end
                })
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'fun'), function()
                RageUI.Button('🎉 Animation globale', 'Faire une animation à tous.', {}, true, {
                    onSelected = function()
                        local dict = keyboardInput('Dictionnaire animation', '', 40)
                        local anim = keyboardInput('Nom animation', '', 40)
                        if dict and anim then
                            TriggerServerEvent('admin:playAnimationAll', dict, anim)
                            addLog(('Animation globale %s %s'):format(dict, anim))
                        end
                    end
                })

                RageUI.Button('🕹️ Créer un event / TP global', 'Téléporter tout le monde à un point.', {}, true, {
                    onSelected = function()
                        if IsWaypointActive() then
                            local waypointBlip = GetFirstBlipInfoId(8)
                            local waypointCoords = GetBlipCoords(waypointBlip)
                            TriggerServerEvent('admin:teleportAllToPoint', waypointCoords)
                            addLog('Téléportation globale vers le point GPS')
                        else
                            addLog('Définir un point GPS pour l\'event')
                        end
                    end
                })

                RageUI.Button('🚗 Spawn véhicules pour event', 'Spawn un véhicule pour chaque joueur.', {}, true, {
                    onSelected = function()
                        local model = keyboardInput('Modèle du véhicule', '', 30)
                        if model and model ~= '' then
                            TriggerServerEvent('admin:spawnVehiclesForAll', model)
                            addLog(('Spawn véhicules %s pour tous'):format(model))
                        end
                    end
                })

                RageUI.Button('🔥 Explosion contrôlée', 'Faire exploser une zone.', {}, true, {
                    onSelected = function()
                        local radius = tonumber(keyboardInput('Rayon de l\'explosion', '5', 3)) or 5
                        TriggerServerEvent('admin:explodeArea', radius)
                        addLog(('Explosion sur zone (rayon %s)'):format(radius))
                    end
                })

                RageUI.Button('🕵️ Invisibilité / God mode', 'Toggle invisibilité globale.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:toggleGlobalInvis')
                        addLog('Toggle invisibilité/god mode global')
                    end
                })

                RageUI.Button('👁️ Mode spectateur libre', 'Flycam libre.', {}, true, {
                    onSelected = function()
                        TriggerEvent('admin:toggleFreecam')
                    end
                })

                RageUI.Button('🎁 Donner un item / arme', nil, {}, true, {
                    onSelected = function()
                        local item = keyboardInput('Item ou arme', '', 40)
                        local amount = tonumber(keyboardInput('Quantité', '1', 3)) or 1
                        if selectedPlayer and item then
                            TriggerServerEvent('admin:giveItem', selectedPlayer.id, item, amount)
                            addLog(('Don de %s x%s à %s'):format(item, amount, selectedPlayer.name))
                        else
                            addLog('Sélectionnez un joueur pour donner un item')
                        end
                    end
                })

                RageUI.Button('📦 Drop d\'objets public', 'Créer un loot public.', {}, true, {
                    onSelected = function()
                        local item = keyboardInput('Item', '', 40)
                        local amount = tonumber(keyboardInput('Quantité', '1', 3)) or 1
                        TriggerServerEvent('admin:createItemDrop', item, amount)
                        addLog(('Drop public: %s x%s'):format(item, amount))
                    end
                })
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'technical'), function()
                RageUI.Button('🧩 Liste des ressources actives', 'Voir les ressources démarrées.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:listResources')
                    end
                })

                RageUI.Button('💬 Console client', 'Afficher les logs client.', {}, true, {
                    onSelected = function()
                        addLog('Console client ouverte (F8)')
                    end
                })

                RageUI.Button('🧱 Coordonnées du joueur', formatVector(GetEntityCoords(PlayerPedId())), {}, true, {
                    onSelected = function()
                        local coords = GetEntityCoords(PlayerPedId())
                        addLog(('Coords: %s'):format(formatVector(coords)))
                    end
                })

                RageUI.Button('🧭 Afficher blips / zones', 'Affiche les zones connues.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:showBlipData')
                    end
                })

                RageUI.Button('🧠 Refresh base de données', 'Force une mise à jour.', {}, true, {
                    onSelected = function()
                        TriggerServerEvent('admin:refreshDatabase')
                        addLog('Refresh de la base de données demandé')
                    end
                })

                RageUI.Button('⚙️ Tester trigger', 'Tester un event custom.', {}, true, {
                    onSelected = function()
                        local eventName = keyboardInput('Nom de l\'event', '', 60)
                        if eventName and eventName ~= '' then
                            TriggerServerEvent('admin:testTrigger', eventName)
                            addLog(('Test trigger %s'):format(eventName))
                        end
                    end
                })

                RageUI.Button('🎚️ Raccourcis clavier', ('Commande: /%s | Touche: %s'):format(Config.CommandName, Config.OpenKey), {}, true, {
                    onSelected = function()
                        addLog('Configurer la touche dans keybinds FiveM')
                    end
                })
            end)

            RageUI.IsVisible(RMenu:Get('admin', 'logs'), function()
                if #actionLogs == 0 then
                    RageUI.Separator('Aucun log pour le moment')
                end

                for _, log in ipairs(actionLogs) do
                    RageUI.Button(log, nil, {}, true, {})
                end
            end)
        else
            Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        if open then
            refreshPlayers(false)
        end
        Wait(2000)
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(1000)
        if isSpectating and spectateTarget then
            local targetPlayer = GetPlayerFromServerId(spectateTarget)
            if targetPlayer == -1 then
                toggleSpectate(spectateTarget)
            end
        end
    end
end)
