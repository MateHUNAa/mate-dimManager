Shared = {
     GameTimeToLocalTime = (function(gameTime)
          local totalSeconds = math.floor(gameTime / 1000)
          local hours        = math.floor(totalSeconds / 3600)
          local minutes      = math.floor((totalSeconds % 3600) / 60)
          local seconds      = totalSeconds % 60

          if hours > 0 then
               return string.format("%02d:%02d:%02d", hours, minutes, seconds)
          else
               return string.format("%02d:%02d", minutes, seconds)
          end
     end),
     RandomID = (function(length)
          local possibleCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

          if not length or length == 0 then
               length = 6
          end

          local rID = ""

          for i = 1, length do
               local randomIndex = math.random(1, #possibleCharacters)

               rID = rID .. possibleCharacters:sub(randomIndex, randomIndex)
          end

          return rID
     end),
     CapitalizeFirstLetter = (function(word)
          return word:sub(1, 1):upper() .. word:sub(2)
     end),
     StarsWith = (function(inputStr, letter)
          if string.sub(inputStr, 1, 1) == letter then
               return string.sub(inputStr, 2)
          else
               return inputStr
          end
     end),
}
