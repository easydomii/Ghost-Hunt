RegisterCommand(GetCurrentResourceName() .. '_restart', function(source)
    local _source = source
    
    TriggerClientEvent(GetCurrentResourceName() .. ':client:safeRestart', -1, _source)
end, true)

local GhostHunt = {}


local playerProgress = {}
GhostHunt.__index = GhostHunt

-- Constructor for creating a new GhostHunt instance
function GhostHunt:new()
    local self = setmetatable({}, GhostHunt)
    self.allPlayersPhotos = {}
    return self
end


-- Register usable item for cameraZ
function GhostHunt:RegisterUsableItem()
    exports.kq_link:RegisterUsableItem('ls_camera', function(source)
        TriggerClientEvent('ls_ghost_hunt:capture', source)
    end)
end

-- Load player's progress when they join the server
function GhostHunt:OnPlayerConnecting()
    AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
        local src = source
        local identifier = self:GetIdentifier(src)
        if not self.allPlayersPhotos[identifier] then
            self.allPlayersPhotos[identifier] = {} -- Initialize player's photo data if not found
        end
    end)
end

-- Load progress event for client
function GhostHunt:LoadProgressEvent()
    RegisterNetEvent('ls_ghost_hunt:loadProgress')
    AddEventHandler('ls_ghost_hunt:loadProgress', function()
        local playerId = source
        local progress = playerProgress[playerId] or { caughtGhosts = {}, huntCompleted = false }
        
        TriggerClientEvent('ls_ghost_hunt:loadProgress', playerId, progress.caughtGhosts, progress.huntCompleted)
    end)

end



-- Handle when a player takes a photo
function GhostHunt:PhotoTakenEvent()
    RegisterNetEvent('ls_ghost_hunt:photoTaken')
    AddEventHandler('ls_ghost_hunt:photoTaken', function(ghostID)
        local playerId = source -- Get the player ID
        if not playerProgress[playerId] then
            playerProgress[playerId] = {
                caughtGhosts = {},
                huntCompleted = false,
            }
        end

        -- Mark the ghost as photographed
        playerProgress[playerId].caughtGhosts[ghostID] = true
        TriggerClientEvent('ls_ghost_hunt:photoConfirmed', playerId, ghostID)
        -- Check if all ghosts are photographed
        if CheckAllPhotosTaken(playerId) then
            playerProgress[playerId].huntCompleted = true
            TriggerClientEvent('ls_ghost_hunt:notifyCompletion', playerId, true) -- Notify the player of completion
            
        end
    end)
end

function CheckAllPhotosTaken(playerId)
    local totalGhosts = #Config.ghosts -- Total number of ghosts
    local photographedCount = 0

    for _, caught in pairs(playerProgress[playerId].caughtGhosts) do
        if caught then
            photographedCount = photographedCount + 1
        end
    end

    return photographedCount == totalGhosts
end

-- Handle giving a camera to the player
function GhostHunt:GetCameraEvent()
    RegisterNetEvent('ls_ghost_hunt:getCamera')
    AddEventHandler('ls_ghost_hunt:getCamera', function()
        local src = source
        local itemCount = exports.kq_link:GetPlayerItemCount(src, 'ls_camera')
        if itemCount < 1 then
            exports.kq_link:AddPlayerItem(src, 'ls_camera', 1, 0)
        end
    end)
end

-- Utility function to get player identifier
function GhostHunt:GetIdentifier(src)
    -- Use your specific method for getting a player's identifier
    local identifier = GetPlayerIdentifier(src, 0)
    return identifier
end

-- Initialize the GhostHunt instance and events
local ghostHuntInstance = GhostHunt:new()
ghostHuntInstance:RegisterUsableItem()
ghostHuntInstance:OnPlayerConnecting()
ghostHuntInstance:LoadProgressEvent()
ghostHuntInstance:PhotoTakenEvent()
ghostHuntInstance:GetCameraEvent()
