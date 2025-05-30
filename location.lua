-- location
local Location = {}
Location.__index = Location

function Location.new(idx, name)
  local self = setmetatable({}, Location)
  self.id = idx 
  self.name = name
  self.slots = {} 
  self.max_slots_per_player = 4
  return self
end

function Location:add_player_slots(player_id_string)
    self.slots[player_id_string] = {} -- Initialize as an empty table for ordered slots
    for i = 1, self.max_slots_per_player do
        self.slots[player_id_string][i] = nil 
    end
end

function Location:get_player_power(player_id_string, game_instance_ref)
    local total_power = 0
    if self.slots[player_id_string] then
        for i = 1, self.max_slots_per_player do
            local card_unique_id = self.slots[player_id_string][i]
            if card_unique_id then
                local card = game_instance_ref:get_card_instance_by_id(card_unique_id)
                if card and card.is_revealed then
                    total_power = total_power + card:get_display_power()
                end
            end
        end
    end
    return total_power
end

return Location