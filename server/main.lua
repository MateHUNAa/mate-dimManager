ESX = exports['es_extended']:getSharedObject()
mCore = exports["mCore"]:getSharedObj()


---@class Dimension
---@field bucket number BucketID
---@field players table PlayersIDS
---@field rules table Rules
---@field owner string Dimension Owned By Resource
---@field playerCount number Number of Players inside a dimension

local Dimensions      = {}
local PlayerBuckets   = {}
local bucketIdCounter = 1000


---@param gm string
---@param mode string
---@param rules? table
---@return number bucket
local function createBucket(gm, mode, rules)
     local invokeRes = GetInvokingResource() or GetCurrentResourceName()
     if not Dimensions[gm] then
          Dimensions[gm] = {
               owner = invokeRes
          }
     end

     if not Dimensions[gm][mode] then
          Dimensions[gm][mode] = {
               bucket      = bucketIdCounter,
               players     = {},
               rules       = rules or {},
               owner       = invokeRes,
               playerCount = 0
          }
          SetRoutingBucketPopulationEnabled(bucketIdCounter, false)
          bucketIdCounter += 1
     end

     return Dimensions[gm][mode].bucket
end
exports("Create", createBucket)

---@param pid number
---@param gamemode string
---@param mode string
exports("AddPlayer", (function(pid, gamemode, mode)
     if not pid then return print(("Expected playerId got %s"):format(type(pid))) end
     if not gamemode then return print(("Expected gamemode got %s"):format(type(gamemode))) end
     if not mode then return print(("Expected mode got %s"):format(type(mode))) end

     local bucket = createBucket(gamemode, mode)

     if not Dimensions[gamemode] or not Dimensions[gamemode][mode] then
          print(("Failed to add player %s "):format(pid))
          return
     end


     local dim = Dimensions[gamemode][mode]

     if not dim.players[pid] then
          table.insert(Dimensions[gamemode][mode].players, {
               sourceId = pid,
               id       = source,
               gamemode = gamemode,
               mode     = mode,
               bucket   = dim.bucket
          })
          dim.playerCount += 1
     end

     SetPlayerRoutingBucket(pid, bucket)
     PlayerBuckets[pid] = { gamemode = gamemode, mode = mode }

     TriggerEvent("mate-dimManager->PlayerJoined", {
          playerId = pid,
          gamemode = gamemode,
          mode     = mode
     })

     TriggerClientEvent("mate-dimManager->PlayerJoined", -1, {
          playerId    = pid,
          gamemode    = gamemode,
          mode        = mode,
          playerCount = dim.playerCount
     })

     TriggerClientEvent("mate-dimManager->Update", pid, {
          gm     = gamemode,
          mode   = mode,
          rules  = dim.rules,
          bucket = dim.bucket
     })
end))

RegisterNetEvent('mate-dimManager->RequestUpdate', (function()
     local source = source

     local keys = PlayerBuckets[source]
     if not keys then return false end

     local dim = Dimensions[keys.gamemode] and Dimensions[keys.gamemode][keys.mode]
     if not dim then return false end

     TriggerClientEvent("mate-dimManager->Update", source, {
          gm     = keys.gamemode,
          mode   = keys.mode,
          rules  = dim.rules,
          bucket = dim.bucket
     })

     return true
end))


---@return boolean success?
exports("RemovePlayer", function(pid, gm, mode)
     print("[Initial:RemovePlayer]", pid, gm, mode)

     local playerData = PlayerBuckets[pid]
     if not playerData then
          mCore.sendMessage(
               ("[RemovePlayer]: No PlayerBucket entry for %s (%s)"):format(GetPlayerName(pid) or "__Unknown__", pid),
               mCore.RequestWebhook("error"),
               ("mCore, %s"):format(GetCurrentResourceName() or "N/A"))
          return (("[RemovePlayer]: No PlayerBucket entry for %s (%s)"):format(GetPlayerName(pid) or "__Unknown__", pid))
     end

     local gamemode = playerData.gamemode
     local mode = playerData.mode

     local dim = Dimensions[gamemode] and Dimensions[gamemode][mode]

     if not dim then
          mCore.sendMessage(("[RemovePlayer] No Dimension entry for [%s - %s]"):format(gamemode, mode),
               mCore.RequestWebhook("error"),
               ("mCore, %s"):format(GetCurrentResourceName() or "N/A"))
          return print(("[RemovePlayer] No Dimension entry for [%s - %s]"):format(gamemode, mode))
     end

     for i = #dim.players, 1, -1 do
          if dim.players[i].sourceId == pid then
               table.remove(dim.players, i)
               mCore.debug.log(("[RemovePlayer]: Removed player %s(%s) from dimension [%s - %s]"):format(
                    GetPlayerName(pid) or "__Unknown__",
                    pid,
                    gamemode,
                    mode
               ))
               break
          end
     end

     dim.playerCount = math.max(0, (dim.playerCount or 1) - 1)
     PlayerBuckets[pid] = nil
     SetPlayerRoutingBucket(pid, 0)

     TriggerEvent("mate-dimManager->PlayerLeft", {
          playerId = pid,
          gamemode = gm,
          mode     = mode
     })

     TriggerClientEvent("mate-dimManager->PlayerLeft", -1, {
          playerId    = pid,
          gamemode    = gm,
          mode        = mode,
          playerCount = dim.playerCount
     })

     TriggerClientEvent("mate-dimManager->Update", pid, {
          gm     = gm,
          mode   = mode,
          rules  = dim.rules,
          bucket = dim.bucket
     })

     return true
end)




---@param gamemode string
---@param mode string
---@return table players, number count
exports("GetPlayersInBucket", (function(gamemode, mode)
     local data = Dimensions[gamemode] and Dimensions[gamemode][mode]

     if not data then
          print(("FAILED [%s - %s]"):format(gamemode, mode))
          mCore.sendMessage(
               ("Failed to get PlayersInBucket [%s - %s]\nInvoke: %s"):format(gamemode, mode,
                    GetInvokingResource() or "N/A"),
               mCore.RequestWebhook("error"), ("mCore, %s"):format(GetCurrentResourceName() or "N/A"))
          return {}, 0
     end

     local players = {}
     for i, v in pairs(data.players) do
          table.insert(players, i)
     end

     return data.players, #players
end))

---@param gamemode string
---@param mode string
---@return number|nil
exports("GetBucket", (function(gamemode, mode)
     local data = Dimensions[gamemode] and Dimensions[gamemode][mode]
     return data and data.bucket or nil
end))

exports("GetPlayerBucket", (function(pid)
     return GetPlayerRoutingBucket(pid)
end))


---@param gm string
---@param mode string
---@param ruleKey string
---@param ruleValue any
---@return boolean success
exports("AddRule", (function(gm, mode, ruleKey, ruleValue)
     if not gm or not mode or not ruleKey then return false end

     local dim = Dimensions[gm] and Dimensions[gm][mode]
     if not dim then
          print(("[AddRule]: Dimension is not exist with [%s - %s]"):format(gm, mode))
          return false
     end

     dim.rules[ruleKey] = ruleValue or true

     return true
end))

---@param gm string
---@param mode string
---@param ruleKey string
---@return boolean success
exports("RemoveRule", (function(gm, mode, ruleKey)
     if not gm or not mode or not ruleKey then return false end

     local dim = Dimensions[gm] and Dimensions[gm][mode]
     if not dim then
          print(("[RemoveRules]: Dimension is not exist with [%s - %s]"):format(gm, mode))
          return false
     end

     dim.rules[ruleKey] = nil
     return true
end))

---@param gm string
---@param mode string
---@return table|nil|false Rules
exports("GetRules", (function(gm, mode)
     if not gm or not mode then return false end

     local dim = Dimensions[gm] and Dimensions[gm][mode]
     if not dim then
          print(("[GetRules]: Dimension is not exist with [%s - %s]"):format(gm, mode))
          return false
     end


     return dim and dim.rules or nil
end))

AddEventHandler("playerDropped", (function(reason)
     local src = source

     exports[GetCurrentResourceName()]:RemovePlayer(src)
end))

AddEventHandler("onResourceStop", (function(res)
     if GetCurrentResourceName() == res then
          local c = 0
          for i, xPlayer in pairs(ESX.GetExtendedPlayers()) do
               SetPlayerRoutingBucket(xPlayer.source, 0)
               c += 1
          end
          return
     end

     players = 0

     for gm, modes in pairs(Dimensions) do
          for mode, data in pairs(modes) do
               if data.owner == res then
                    owner = res
                    print(("Cleaning up dimension [%s - %s] created by %s"):format(gm, mode, res))

                    for pid, _ in pairs(data.players) do
                         mCore.Notify(pid, "[MH SCRIPTS]", "Returning to default dimension!", "error", 8000)
                         SetPlayerRoutingBucket(pid, 0)
                         players += 1
                    end

                    Dimensions[gm][mode] = nil
               end
          end

          if next(Dimensions[gm]) == nil then
               Dimensions[gm] = nil
          end
     end
end))

---@return number|boolean,Dimension|boolean
lib.callback.register("mate-dimManager->GetCurrentDim", (function(src)
     local keys = PlayerBuckets[src]
     if not keys then return false, false end
     return exports[GetCurrentResourceName()]:GetPlayerBucket(src), Dimensions[keys.gamemode][keys.mode]
end))

lib.callback.register("mate-dimManager->GetRules", (function(source, gm, mode)
     local rules = exports[GetCurrentResourceName()]:GetRules(gm, mode)
     return rules
end))

lib.callback.register("mate-dimManager->GetPlayerCount", (function(source, gm, mode)
     local _, NumOfPlayers = exports[GetCurrentResourceName()]:GetPlayersInBucket(gm, mode)
     return NumOfPlayers
end))
