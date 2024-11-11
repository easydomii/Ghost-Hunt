GhostHunt = {
    ghostEntities = {},
    ghostMetadata = {},
    playerPhotos = {},
    cooldown = false,
    bone = 28422,
    loc = { x = 0.0, y = 0.0, z = 0.0 },
    rot = { x = 0.0, y = 0.0, z = 0.0 },
    capturing = false
}

-- Initialization
function GhostHunt:Init()
    Citizen.CreateThread(function()
        TriggerServerEvent('ls_ghost_hunt:loadProgress')
    end)
    self:RegisterEvents()
end

-- Register all events in a separate function
function GhostHunt:RegisterEvents()
    RegisterNetEvent('ls_ghost_hunt:loadProgress')
    AddEventHandler('ls_ghost_hunt:loadProgress', function(caughtGhosts)
        self:LoadProgress(caughtGhosts)
    end)

    RegisterNetEvent('ls_ghost_hunt:capture')
    AddEventHandler('ls_ghost_hunt:capture', function()
        if not self.capturing and not self.cooldown then
            GhostHunt:SetCooldown(2500)
            self:HandleGhostHuntEvent()
        else
            exports.kq_link:Notify("You have to wait a bit more to do that.", 'error')
        end
    end)

    RegisterNetEvent('ls_ghost_hunt:photoConfirmed')
    AddEventHandler('ls_ghost_hunt:photoConfirmed', function(ghostIndex)
        self:PhotoConfirmed(ghostIndex)
    end)

    RegisterNetEvent(GetCurrentResourceName() .. ':client:safeRestart')
    AddEventHandler(GetCurrentResourceName() .. ':client:safeRestart', function(caller)
        self:SafeRestart(caller)
    end)
    RegisterNetEvent('ls_ghost_hunt:notifyCompletion')
    AddEventHandler('ls_ghost_hunt:notifyCompletion', function(completed)


        GhostHunt:Alert("Ghost Hunt Completed", "You can use the camera by ~g~/hcam ~w~ now", 5000) -- Display alert for 5 seconds
        -- Optionally, you could also trigger other actions here, like playing a sound:
        PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
    end)
end

function GhostHunt:Alert(title, message, duration)
    Citizen.CreateThread(function()
        local scaleformHandle = RequestScaleformMovie("mp_big_message_freemode") -- The scaleform you want to use
        
        while not HasScaleformMovieLoaded(scaleformHandle) do -- Ensure the scaleform is actually loaded before using
            Citizen.Wait(0)
        end

        -- Begin the scaleform method
        BeginScaleformMovieMethod(scaleformHandle, "SHOW_SHARD_CENTERED_MP_MESSAGE")
        PushScaleformMovieMethodParameterString(title) -- Title
        PushScaleformMovieMethodParameterString(message) -- Message
        PushScaleformMovieMethodParameterInt(2) -- Color ID
        PushScaleformMovieMethodParameterInt(64) -- Color ID
        EndScaleformMovieMethod()

        local startTime = GetGameTimer() -- Get the current game time
        local endTime = startTime + duration -- Calculate when to stop displaying

        -- Define position and size for the Scaleform
        local x = 0.5 -- X position (0.0 to 1.0)
        local y = 0.3 -- Y position (0.0 to 1.0)
        local width = 1.0 -- Width (0.0 to 1.0)
        local height = 1.0 -- Height (0.0 to 1.0)

        -- Draw the scaleform until the duration is reached
        while GetGameTimer() < endTime do
            Citizen.Wait(0) -- Wait for the next frame
            
            -- Draw the scaleform at the specified position and size
            DrawScaleformMovie(scaleformHandle, x, y, width, height, 0, 0, 0, 0, 0)
        end

        -- Cleanup the scaleform
        SetScaleformMovieAsNoLongerNeeded(scaleformHandle)
    end)
end

RegisterCommand('hcam', function (source, args, raw)
    local function manageCamera()
        local playerPed = PlayerPedId()
        local isCameraAttached = false
        local cameraData = Config.camera
        -- Check if camera exists and button 'x' is pressed to remove it
        local dict = 'amb@world_human_paparazzi@male@base'
        local anim = 'base'
        local flag = 50
        
        -- If no camera is attached, spawn and attach it
        if not isCameraAttached then
            camera = SpawnObject(cameraData.model, GetEntityCoords(playerPed), 210.0, 270.0)
            SetEntityLights(camera, false)
            AttachEntityToEntity(
                camera, playerPed, GetPedBoneIndex(playerPed, 28422),
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                true, false, true, false, 2, true
            )
            
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do
                Citizen.Wait(100)
            end
            TaskPlayAnim( playerPed, dict, anim, 2.0, 2.0, -1, flag or 1, 0, true, true, false)
            RemoveAnimDict(dict)
            isCameraAttached = true
            Citizen.CreateThread(function ()
                while true do
                    DisableControlAction(0, 24, 1)
                    if IsControlJustPressed(0, 73) then 
                        if camera ~= nil then
                            DetachEntity(camera, true, true)
                            DeleteObject(camera)
                            camera = nil
                            isCameraAttached = false
                            ClearPedTasks(playerPed)
                            return
                        end
                    elseif IsControlPressed(0, 24) then
                        SetEntityLights(camera, true)
                    elseif IsControlReleased(0, 24) then
                        SetEntityLights(camera, false)
                    end
                    Citizen.Wait(5)
                end
            end)
        end
    end
    if not GhostHunt.huntCompleted then
        exports.kq_link:Notify("You need to finish the ghost hunt before using the camera.", 'error')
    else
        manageCamera()
    end
end)

-- Utility Functions
function GhostHunt:SetCooldown(time)
    self.cooldown = true
    Citizen.CreateThread(function()
        Citizen.Wait(time)
        self.cooldown = false
    end)
end

function GhostHunt:HSVToRGB(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6

    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    elseif i == 5 then return v, p, q
    end
end

-- Camera Functions
function GhostHunt:SpawnCamera()
    if self.huntCompleted then return end

    local cameraData = Config.camera
    local camRot = Config.camera.rotation
    local camera = SpawnObject(cameraData.model, cameraData.coords, 210.0, 0)
    FreezeEntityPosition(camera, 1)
    SetEntityCollision(camera, 0, 0)
    SetEntityRotation(camera, camRot[1], camRot[2], camRot[3], 2, true)

    -- self:StartColorLoop(camera)
    self:AddCameraInteraction(camera)
end



function GhostHunt:AddCameraInteraction(camera)
    exports.kq_link:AddInteractionEntity(
        camera, vector3(0, 0, 0.5), L('[E] to get camera'), L('Take camera'),
        38, function() self:OnInteract() end, function() return self:CanInteract() end, {}, 5.0, 'fas fa-hand'
    )
end

-- Core Ghost Hunt Logic
function GhostHunt:LoadProgress(caughtGhosts, huntCompleted)
    self.playerPhotos = caughtGhosts or {}
    self.huntCompleted = huntCompleted or false
    self:SpawnCamera()
    self:SpawnGhosts()
end

-- Utility function to play particle effect and animation
function GhostHunt:PlayGhostEffects(dataTable, newGhost)
    self.ghostMetadata[newGhost].animPlay = true

    RequestAnimDict('ANIM@SCRIPTED@FREEMODE@IG2_GHOST@')
    while not HasAnimDictLoaded('ANIM@SCRIPTED@FREEMODE@IG2_GHOST@') do
        Citizen.Wait(100)
    end
    
    PlayEntityAnim(newGhost, 'float_1', 'ANIM@SCRIPTED@FREEMODE@IG2_GHOST@', 1000.0, true, true, true, 0, 136704)

    local particleDict = "scr_srr_hal"
    local particleName = "scr_ba_club_smoke_machine"
    local ghostCoords = dataTable[newGhost].coords
    RequestNamedPtfxAsset(particleDict)
    while not HasNamedPtfxAssetLoaded(particleDict) do
        Citizen.Wait(0)
    end
    UseParticleFxAsset(particleDict)
    StartParticleFxLoopedOnEntity('scr_srr_hal_ghost_haze', newGhost, 0.0, 0.0, 0.7, 0.0, 0.0, 0.0, 1.0, false, false, false)
    RemoveNamedPtfxAsset('scr_srr_hal')
    RemoveAnimDict('ANIM@SCRIPTED@FREEMODE@IG2_GHOST@')
        
end

-- Function to check distance from ghosts and manage spawning/removal
function GhostHunt:ManageGhostSpawning()
    Citizen.CreateThread(function()
        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())

            for i, ghostData in ipairs(Config.ghosts) do
                local ghost = self.ghostEntities[i]
                local ghostCoords = ghostData.coords
                local distance = #(playerCoords - vector3(ghostCoords[1], ghostCoords[2], ghostCoords[3]))

                if distance > 150.0 then
                    if ghost then
                        self.ghostMetadata[ghost].animPlay = false
                        if Config.blips.enabled then
                            RemoveBlip(self.ghostMetadata[ghost].blip)
                            self.ghostMetadata[ghost].blip = nil
                        end

                        DeleteEntity(ghost)
                        self.ghostEntities[i] = nil
                    end
                elseif distance <= 150.0 and not ghost and not GhostHunt.playerPhotos[i] then
                    local newGhost = SpawnObject(ghostData.model, ghostCoords, ghostCoords[4], 0)
                    SetEntityCollision(newGhost, 0, 0)
                    SetEntityAsMissionEntity(newGhost, true, true)
                    self.ghostEntities[i] = newGhost
                    self.ghostMetadata[newGhost] = {
                        index = i,
                        coords = ghostCoords,
                        animPlay = false
                    }
                    if Config.blips.enabled and not self.ghostMetadata[newGhost].blip then
                        self.ghostMetadata[newGhost].blip = CreateBlip(ghostCoords, 484, 81, 255, 1.0, "Ghost")
                    end
                end

                if ghost and distance <= 50.0 and not self.ghostMetadata[ghost].animPlay then
                    self:PlayGhostEffects(self.ghostMetadata, ghost)
                end
            end

            Citizen.Wait(1000) 
        end
    end)
end

function GhostHunt:SpawnGhosts()
    self:ManageGhostSpawning()
end



function GhostHunt:GhostDisappear(ghostID)
    local alpha = 255
    local groundZ = 0.0
    local ghost = self.ghostEntities[ghostID]
    local coords = self.ghostMetadata[ghost].coords -- Correct access to self

    Citizen.CreateThread(function ()
        while alpha >= 5 do
            alpha = alpha - 5
            Citizen.Wait(60) -- Pause between each fade step
        end
    end)
    Citizen.CreateThread(function ()
        while alpha >= 5 do
            SetEntityAlpha(ghost, alpha, 1)
            groundZ = groundZ + 0.05
            SetEntityCoords(ghost, coords[1], coords[2], coords[3] + groundZ, 0.0, 0.0, 0.0, 0)
            Citizen.Wait(10)
        end
    end)
    RemoveBlip(self.ghostMetadata[ghost].blip)
end

function GhostHunt:HandleGhostHuntEvent()
    local closestGhost = self:ClosestGhost()
    if closestGhost then
        self:TakePhotoOfGhost(closestGhost)
    end
end

function GhostHunt:TakePhotoOfGhost(ghost)
        self.capturing = true 
        local ghostID = self.ghostMetadata[ghost].index
        local playerPed = PlayerPedId()
        local camera = self:AttachCameraToPlayer(playerPed)
        
        GhostHunt:GhostDisappear(ghostID)

        PlayAnim('amb@world_human_paparazzi@male@base', 'base', 1, playerPed, 3000)
        Citizen.Wait(1500)
        PlaySoundFrontend(-1, "Camera_Shoot", "Phone_Soundset_Franklin", 1)
        Citizen.Wait(1500)
        ClearPedTasks(playerPed)
        TriggerServerEvent('ls_ghost_hunt:photoTaken', ghostID)
        DeleteEntity(camera)
        self.capturing = false

end

function GhostHunt:ClosestGhost()
    if not self.capturing and not IsPedInAnyVehicle(PlayerPedId(), 1) then
        for _, ghost in pairs(self.ghostEntities) do
            -- Check if ghost is in range and if the player is oriented correctly
            if self:IsGhostInRange(ghost) then
                -- If the player is within range and facing the ghost, return the ghost entity
                return ghost
            end
        end
        return nil  -- No ghost found in range
    end
end

function GhostHunt:IsGhostInRange(ghost)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local ghostCoords = self.ghostMetadata[ghost].coords
    local distance = #(playerCoords - vector3(ghostCoords[1], ghostCoords[2], ghostCoords[3]))

    if distance <= 20.0 and IsEntityOnScreen(ghost) and not GhostHunt.capturing then
        TaskTurnPedToFaceEntity(PlayerPedId(), ghost, 1000)
        Citizen.Wait(1000)  
        return true
    end
    return false  -- Ghost not in range or visible
end



function GhostHunt:AttachCameraToPlayer(playerPed)
    local cameraData = Config.camera
    local camera = SpawnObject(cameraData.model, GetEntityCoords(playerPed), 150.0, 1)
    AttachEntityToEntity(camera, playerPed, GetPedBoneIndex(playerPed, self.bone), self.loc.x, self.loc.y, self.loc.z, self.rot.x, self.rot.y, self.rot.z, true, false, true, false, 2, true)
    return camera
end

-- Player Interaction
function GhostHunt:OnInteract()
    TriggerServerEvent('ls_ghost_hunt:getCamera')
    self:SetCooldown(5000)
end

function GhostHunt:CanInteract()
    return not self.cooldown and not IsPedInAnyVehicle(PlayerPedId(), 1)
end

function GhostHunt:PhotoConfirmed(ghostIndex)
    self.playerPhotos[ghostIndex] = true
    if self.ghostEntities[ghostIndex] then
        RemoveBlip(self.ghostMetadata[self.ghostEntities[ghostIndex]].blip)
        DeleteEntity(self.ghostEntities[ghostIndex])
        self.ghostMetadata[self.ghostEntities[ghostIndex]] = nil
        self.ghostEntities[ghostIndex] = nil
    end
end





function GhostHunt:SafeRestart(caller)
    local entities = GetGamePool('CObject')
    for _, entity in pairs(entities) do
        if DoesEntityExist(entity) and self:IsDeletableModel(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end
    
    if caller == GetPlayerServerId(PlayerId()) then
        Citizen.Wait(2000)
        ExecuteCommand('ensure ' .. GetCurrentResourceName())
    end
end

function GhostHunt:IsDeletableModel(entity)
    local deleteModels = { 'ls_hunt_camera', 'm23_1_prop_m31_ghostrurmeth_01a', 'm23_1_prop_m31_ghostskidrow_01a', 'm23_1_prop_m31_ghostzombie_01a', 'm23_1_prop_m31_ghostjohnny_01a', 'm23_1_prop_m31_ghostsalton_01a' }
    local entityModel = GetEntityModel(entity)
    for _, model in ipairs(deleteModels) do
        if GetHashKey(model) == entityModel then
            return true
        end
    end
    return false
end

GhostHunt:Init()
