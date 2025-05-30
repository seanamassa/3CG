-- utils
local Utils = {}

-- Simple function to clone a table 
function Utils.shallow_clone(original)
  local copy = {}
  for k, v in pairs(original) do
    copy[k] = v
  end
  return copy
end

-- Function to shuffle a deck (Fisher-Yates shuffle)
function Utils.shuffle_deck(deck)
  if not deck or #deck == 0 then return deck end
  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
  return deck
end

return Utils