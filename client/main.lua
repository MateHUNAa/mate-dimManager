ESX   = exports['es_extended']:getSharedObject()
mCore = exports["mCore"]:getSharedObj()


lang = Loc[Config.lan]


RegisterCommand("dim:getBucket", (function(src, args, raw)
     local dim = lib.callback.await("mate-dimManager->GetCurrentDim", false)
     print("CurrentDim :", dim)
end))
