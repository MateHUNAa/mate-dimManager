mCore = exports["mCore"]:getSharedObj()

local Peds = {}


local count = 0
Editable = {}
Functions = {
     FindPlayerPointInRadius = (function(r, centerCoord)
          DoScreenFadeOut(650)
          while not IsScreenFadedOut() do
               Wait(0)
          end

          local ped = ESX.PlayerData.ped
          local oldCoords = GetEntityCoords(ped)

          local x, y, groundZ, Z_START = centerCoord["x"], centerCoord["y"], 850.0, 950.0
          local found = false
          FreezeEntityPosition(ped, true)

          math.randomseed(GetGameTimer())

          for i = Z_START, 0, -25.0 do
               local z = (i % 2) ~= 0 and Z_START - i or i

               NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
               local curTime = GetGameTimer()
               while IsNetworkLoadingScene() do
                    if GetGameTimer() - curTime > 1000 then
                         break
                    end
                    Wait(0)
               end
               NewLoadSceneStop()
               SetPedCoordsKeepVehicle(ped, x, y, z)

               while not HasCollisionLoadedAroundEntity(ped) do
                    RequestCollisionAtCoord(x, y, z)
                    if GetGameTimer() - curTime > 1000 then
                         break
                    end
                    Wait(0)
               end

               local radius = ESX.Math.Round(r / 1.2)
               local coords = centerCoord + vec3(math.random(-radius, radius), math.random(-radius, radius), 0)

               found, groundZ, normal = GetGroundZAndNormalFor_3dCoord(coords.x, coords.y, coords.z)
               if found then
                    DoScreenFadeIn(650)
                    FreezeEntityPosition(ped, false)
                    return vec3(coords.x, coords.y, groundZ)
               end

               Wait(0)
          end

          DoScreenFadeIn(650)
          FreezeEntityPosition(ped, false)
          SetPedCoordsKeepVehicle(ped, oldCoords['x'], oldCoords['y'], oldCoords['z'] - 1.0)

          return oldCoords
     end),
     FindPointInRadius = (function(r, centerCoord)
          local radius = ESX.Math.Round(r / 1.2)
          math.randomseed(GetGameTimer())
          local coords = centerCoord + vec3(math.random(-radius, radius), math.random(-radius, radius), 0)
          local found, groundz = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, true)

          SetTimeout(2000, function()
               found = true
          end)

          while not found do
               Wait(50)
          end

          return vec3(coords.x, coords.y, groundz)
     end),
     loadModel = (function(model)
          lib.requestModel(model, 5000)
     end),
     unloadModel = (function(model)
          mCore.debug.log("^2Removing Model^7: '^6" .. model .. "^7'")
          SetModelAsNoLongerNeeded(model)
     end),
     loadAnimDict = (function(dict)
          if not HasAnimDictLoaded(dict) then
               mCore.debug.log("^2Loading Anim Dictionary^7: '^6" .. dict .. "^7'")
               while not HasAnimDictLoaded(dict) do
                    RequestAnimDict(dict)
                    Wait(5)
               end
          end
     end),
     unloadAnimDict = (function(dict)
          if not dict then return end
          mCore.debug.log("^2Removing Anim Dictionary^7: '^6" .. dict .. "^7'")
          RemoveAnimDict(dict)
     end),
     loadPtfxDict = (function(dict)
          if not HasNamedPtfxAssetLoaded(dict) then
               mCore.debug.log("^2Loading Ptfx Dictionary^7: '^6" .. dict .. "^7'")
               while not HasNamedPtfxAssetLoaded(dict) do
                    RequestNamedPtfxAsset(dict)
                    Wait(5)
               end
          end
     end),
     unloadPtfxDict = (function(dict)
          mCore.debug.log("^2Removing Ptfx Dictionary^7: '^6" .. dict .. "^7'")
          RemoveNamedPtfxAsset(dict)
     end),
     makeProp = (function(data, freeze, synced)
          Functions.loadModel(data.prop)
          local prop = CreateObject(data.prop, data.coords.x, data.coords.y, data.coords.z - 1.03, synced or false, false,
               false)
          SetEntityHeading(prop, data.coords.w + 180.0)
          FreezeEntityPosition(prop, freeze or false)

          if mCore.isDebug() then
               local coords = {
                    string.format("%.2f", data.coords.x),
                    string.format("%.2f", data.coords.y),
                    string.format("%.2f", data.coords.z),
                    string.format("%.2f", data.coords.w or 0.0)
               }

               mCore.debug.log("^1Prop ^2Created^7: '^6" ..
                    prop ..
                    "^7' | ^2Hash^7: ^7'^6" ..
                    data.prop ..
                    "^7' | ^2Coord^7: ^5vec4^7(^6" ..
                    coords[1] .. "^7, ^6" .. coords[2] .. "^7, ^6" .. coords[3] .. "^7, ^6" .. coords[4] .. "^7)")
          end
          SetModelAsNoLongerNeeded(data.prop)
          return prop
     end),
     makeBlip = (function(data)
          local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
          SetBlipAsShortRange(blip, true)
          SetBlipSprite(blip, data.sprite or 1)
          SetBlipColour(blip, data.col or 0)
          SetBlipScale(blip, data.scale or 0.7)
          SetBlipDisplay(blip, (data.disp or 6))
          if data.category then SetBlipCategory(blip, data.category) end
          BeginTextCommandSetBlipName('STRING')
          AddTextComponentString(tostring(data.name))
          EndTextCommandSetBlipName(blip)
          -- mCore.debug.log("^6Blip ^2created for location^7: '^6" .. data.name .. "^7'")
          return blip
     end),

     ---@class makePedData
     ---@field coords vector4
     ---@field freeze boolean
     ---@field collision boolean
     ---@field scenario string
     ---@field anim table
     ---@param data makePedData
     makePed = (function(model, data, options)
          if not IsModelValid(model) then
               return mCore.debug.log("^4Invalid Model^7: '^6" .. model .. "^7'")
          end

          if options then
               for _, option in pairs(options) do
                    if option.onSelect then
                         count += 1

                         local event = ("option_%p_%s"):format(option.onSelect, count)
                         ---@type function
                         local onSelect = option.onSelect

                         AddEventHandler(event, (function()
                              onSelect(option.args)
                         end))
                         option.event = event
                         option.onSelect = nil
                    end

                    if option.icon then
                         option.icon = ("fa-solid fa-%s"):format(option.icon)
                    end
               end
          end


          local ped, id
          local p = lib.points.new({
               coords = data.coords.xyz,
               distance = Config.PedRenderDistance,
               onEnter = (function()
                    Functions.loadModel(model)

                    Peds[#Peds + 1] = CreatePed(0, model, data.coords.x, data.coords.y, data.coords.z - 1.03,
                         data.coords.w,
                         false,
                         true)
                    ped = Peds[#Peds]

                    SetEntityInvincible(ped, true)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    FreezeEntityPosition(ped, data.freeze or true)

                    if data.collision then
                         SetEntityNoCollisionEntity(ped, PlayerPedId(), false)
                    end

                    if data.scenario then
                         TaskStartScenarioInPlace(ped, data.scenario, 0, true)
                    end
                    if data.anim then
                         Functions.loadAnimDict(data.anim[1])
                         TaskPlayAnim(ped, data.anim[1], data.anim[2], 1.0, 1.0, -1, 1, 0.2, false, false, false)
                    end

                    if options then
                         id = ("%s_ped_%s"):format(Config.eventPrefix, ped)

                         exports["ox_target"]:addLocalEntity(ped, options)
                    end
               end),

               onExit = (function()
                    if id then
                         exports["ox_target"]:removeLocalEntity(ped)
                         id = nil
                    end
                    DeleteEntity(ped)
                    SetModelAsNoLongerNeeded(model)
                    ped = nil
               end)
          })


          function p:onExit()
               if DoesEntityExist(Peds[#Peds]) then
                    DeleteEntity(Peds[#Peds])
               end
          end

          mCore.debug.log(("^6Ped  ^2created for location^7: '^6%s^7'"):format(model))
     end),
     destoryProp = (function(entity)
          mCore.debug.log("^2Destroying Prop^7: '^6" .. entity .. "^7'")
          SetEntityAsMissionEntity(entity)
          Wait(5)
          DetachEntity(entity, true, true)
          Wait(5)
          DeleteObject(entity)
     end),

     loadDrillSound = (function()
          mCore.debug.log(("^2Loading Drill Sound Banks^7"))
          RequestAmbientAudioBank("DLC_HEIST_FLEECA_SOUNDSET", false)
          RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL", false)
          RequestAmbientAudioBank("DLC_MPHEIST\\HEIST_FLEECA_DRILL_2", false)
     end),
     unloadDrillSound = (function()
          mCore.debug.log(("^2Removeing Drill Sounds Banks^7"))
          ReleaseScriptAudioBank()
     end),
     lookAtMe = (function(entity)
          if DoesEntityExist(entity) then
               if not IsPedHeadingTowardsPosition(entity, GetEntityCoords(PlayerPedId()), 30.0) then
                    TaskTurnPedToFaceCoord(entity, GetEntityCoords(PlayerPedId()), 1500)
                    mCore.debug.log("^2Turning Player to^7: '^6" .. entity .. "^7'")
                    Wait(1500)
               end
          end
     end),
     lookEnt = (function(entity)
          if type(entity) == "vec3" then
               if not IsPedHeadingTowardsPosition(PlayerPedId(), entity, 10.0) then
                    TaskTurnPedToFaceCoord(PlayerPedId(), entity, 1500)
                    mCore.debug.log("^2Turning Player to^7: '^6" .. json.encode(entity) .. "^7'")
                    Wait(1500)
               end
          else
               if DoesEntityExist(entity) then
                    if not IsPedHeadingTowardsPosition(PlayerPedId(), GetEntityCoords(entity), 30.0) then
                         TaskTurnPedToFaceCoord(PlayerPedId(), GetEntityCoords(entity), 1500)
                         mCore.debug.log("^2Turning Player to^7: '^6" .. entity .. "^7'")
                         Wait(1500)
                    end
               end
          end
     end),
     lockInv = (function(toggle)
          FreezeEntityPosition(PlayerPedId(), toggle)
          LocalPlayer.state:set("inv_busy", toggle, true)
          TriggerEvent("inventory:client:busy:status", toggle)
          TriggerEvent("canUseInventoryAndHotbar:toggle", toggle)
     end),
     progressBar = (function(data)
          local result = nil

          if exports["ox_lib"]:progressBar({
                   duration = data.time,
                   label = data.label,
                   useWhileDead = data.dead or false,
                   canCancel = data.cancel or true,
                   anim = { dict = data.dict, clip = data.anim, flag = (data.flag == 8 and 32 or data.flag) or nil, scenario = data.task }, disable = { combat = true }
              }) then
               result = true
               Functions.lockInv(false)
          else
               result = false
               Functions.lockInv(false)
          end

          while result == nil do Wait(10) end
          return result
     end),
     toggleItem = (function(give, item, amount)
          TriggerServerEvent("mCore:server:toggleItem", give, item, amount)
     end),
     HasItem = (function(items, amount)
          local count = exports["ox_inventory"]:Search("count", items)
          local amount = (amount or 1)
          if count >= amount then
               mCore.debug.log(("^3HasItem^7: ^5FOUND^7 ^3     %s ^7/^3 %s %s^7"):format(count, amount, items))
               return true
          else
               mCore.debug.log(("^3HasItem^7: ^1NOT FOUND ^2 %s ^7"):format(tostring(items)))
               return false
          end
     end),
     pairsByKeys = (function(t)
          local a = {}
          for n in pairs(t) do a[#a + 1] = n end
          table.sort(a)
          local i = 0
          local iter = function()
               i = i + 1
               if a[i] == nil then return nil else return a[i], t[a[i]] end
          end
          return iter
     end),
     CapitalizeFirstLetter = (function(word)
          return word:sub(1, 1):upper() .. word:sub(2)
     end),
     MoveTo = (function(destination)
          if not type(destination) == "vector3" or not type(destination) == "table" then
               if not DoesEntityExist(destination) then return false end
               local endPos = GetEntityCoords(destination)

               local dist = #(endPos.xy - GetEntityCoords(cache.ped).xy)

               if dist >= 3.0 then
                    return false
               end

               local to = (dist * 1000 * .6)
               TaskGoStraightToCoord(cache.ped, endPos.x - .2, endPos.y - .2, GetEntityCoords(cache.ped).z, 1.0, to,
                    GetEntityHeading(cache.ped), 0)
               Wait(to)
               return true
          end

          local dist = #(destination.xy - GetEntityCoords(cache.ped).xy)

          if dist >= 3.0 then
               return false
          end

          local to = (dist * 1000 * .6)
          TaskGoStraightToCoord(cache.ped, destination.x - .2, destination.y - .2, GetEntityCoords(cache.ped).z, 1.0, to,
               GetEntityHeading(cache.ped), 0)
          Wait(to)
          return true
     end),
     RotToDir = (function(rotation)
          local adjustedRot = vec3(
               math.rad(rotation.x),
               math.rad(rotation.y),
               math.rad(rotation.z)
          )

          local direction = vec3(
               -math.sin(adjustedRot.z) * math.abs(math.cos(adjustedRot.x)),
               math.cos(adjustedRot.z) * math.abs(math.cos(adjustedRot.x)),
               math.sin(adjustedRot.x)
          )

          return direction
     end),
     GetVehicleProps = (function(model)
          lib.requestModel(model, Config.modelTimeOut)

          local mypos = GetEntityCoords(cache.ped)
          local vehicle = CreateVehicle(model, mypos.x, mypos.y, mypos.z, GetEntityHeading(cache.ped), false, false)

          local ret = lib.waitFor(function()
               return vehicle
          end)

          assert(ret, "Vehicle model is not loaded!")


          FreezeEntityPosition(vehicle, true)
          SetEntityCollision(vehicle, false, false)
          SetEntityVisible(vehicle, false, false)
          SetEntityVisible(cache.ped, false, false)
          TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
          SetModelAsNoLongerNeeded(model)

          local props = ESX.Game.GetVehicleProperties(vehicle)
          Wait(200)
          DeleteEntity(vehicle)
          SetEntityVisible(cache.ped, true, false)
          return props
     end),
}


Error = (function(msg)
     mCore.Notify(lang.Title, msg, "error", 5000)
end)

Info = (function(msg)
     mCore.Notify(lang.Title, msg, "info", 5000)
end)

Success = (function(msg)
     mCore.Notify(lang.Title, msg, "success", 5000)
end)


AddEventHandler("onResourceStop", (function(res)
     if GetCurrentResourceName() ~= res then return end

     for i = 1, #Peds do
          if DoesEntityExist(Peds[i]) then
               DeleteEntity(Peds[i])
          end
     end
end))
