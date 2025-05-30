-- card
local Card = {}
Card.__index = Card

local Game 

_G.CARD_DATABASE = _G.CARD_DATABASE or {} 

function Card.new(name, cost, power, text, ability_on_reveal, ability_on_end_of_turn, ability_ongoing, ability_on_discard)
  local self = setmetatable({}, Card)
  self.name = name
  self.base_cost = cost
  self.current_cost = cost
  self.base_power = power
  self.current_power = power
  self.text = text 
  self.id = tostring(os.time() .. math.random(10000, 99999)) 
  self.unique_id_in_game = nil 

  self.ability_on_reveal = ability_on_reveal
  self.ability_on_end_of_turn = ability_on_end_of_turn
  self.ability_ongoing = ability_ongoing or {}
  self.ability_on_discard = ability_on_discard

  self.is_revealed = false
  self.owner_id = nil
  self.location_idx = nil
  self.slot_idx = nil 
  return self
end

function Card:get_display_power()
    return self.current_power
end

function Card:get_display_cost()
    return self.current_cost
end

-- Define CARD_DATABASE entries here
-- These functions will be passed the card instance ('self' in their original context, now 'card_instance'),
-- the 'game' instance, the 'player' instance who owns/played the card, and 'location_idx'.

_G.CARD_DATABASE["Wooden Cow"] = {name = "Wooden Cow", cost = 1, power = 2, text = "A sturdy, if unremarkable, bovine construct."} -- Adjusted power
_G.CARD_DATABASE["Pegasus"]    = {name = "Pegasus", cost = 3, power = 6, text = "A majestic winged steed."} -- Adjusted power
_G.CARD_DATABASE["Minotaur"]   = {name = "Minotaur", cost = 5, power = 10, text = "A fearsome beast of the labyrinth."} -- Adjusted power
_G.CARD_DATABASE["Titan"]      = {name = "Titan", cost = 6, power = 12, text = "A being of immense, primordial power."}

_G.CARD_DATABASE["Zeus"] = {
    name = "Zeus", cost = 4, power = 4, text = "When Revealed: Lower the power of each card in your opponent's hand by 1.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals! Lowering opponent hand power.")
      local opponent = game:get_opponent(player)
      for _, card_in_hand in ipairs(opponent.hand) do
        card_in_hand.current_power = math.max(0, card_in_hand.current_power - 1)
        print("  - Reduced " .. card_in_hand.name .. " in opponent's hand to " .. card_in_hand.current_power .. " power.")
      end
    end
}

_G.CARD_DATABASE["Ares"] = {
    name = "Ares", cost = 3, power = 2, text = "When Revealed: Gain +2 power for each enemy card here.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")
      local enemy_cards_at_location = 0
      local opponent = game:get_opponent(player)
      local location = game.locations[location_idx]
      -- Ensure slots are properly checked
      if location.slots[opponent.id] then
          for _, slot_card_id in ipairs(location.slots[opponent.id]) do
            if slot_card_id then
              local slot_card = game:get_card_instance_by_id(slot_card_id)
              if slot_card and slot_card.is_revealed then
                 enemy_cards_at_location = enemy_cards_at_location + 1
              end
            end
          end
      end
      card_instance.current_power = card_instance.current_power + (2 * enemy_cards_at_location)
      print("  - Ares gains " .. (2 * enemy_cards_at_location) .. " power. New power: " .. card_instance.current_power)
    end
}

_G.CARD_DATABASE["Demeter"] = {
    name = "Demeter", cost = 2, power = 2, text = "When Revealed: Both players draw a card.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " (Demeter) reveals! Both players draw.")
      player:draw_card(game) -- Current player draws
      local opponent = game:get_opponent(player)
      if opponent then
        opponent:draw_card(game) -- Opponent draws
      end
    end
}
    
_G.CARD_DATABASE["Dionysus"] = {
    name = "Dionysus", cost = 3, power = 2, text = "When Revealed: Gain +2 power for each of your other cards here.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " (Dionysus) reveals at Loc " .. location_idx .. "!")
      local friendly_other_cards = 0
      local location = game.locations[location_idx]
      if location and location.slots[player.id] then
        for _, slot_card_id in ipairs(location.slots[player.id]) do
          if slot_card_id then
            local slot_card = game:get_card_instance_by_id(slot_card_id)
            -- Check if it's revealed and *not* the card_instance itself
            if slot_card and slot_card.is_revealed and slot_card.unique_id_in_game ~= card_instance.unique_id_in_game then
              friendly_other_cards = friendly_other_cards + 1
            end
          end
        end
      end
      card_instance.current_power = card_instance.current_power + (2 * friendly_other_cards)
      print("  - Dionysus gains " .. (2 * friendly_other_cards) .. " power from other friendly cards. New power: " .. card_instance.current_power)
    end  
}
    
_G.CARD_DATABASE["Ship of Theseus"] = {
    name = "Ship of Theseus", cost = 2, power = 1, text = "When Revealed: Add a copy with +1 power to your hand.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
        print(card_instance.name .. " (Ship of Theseus) reveals! Adding a modified copy to hand.")
        local base_card_data = _G.CARD_DATABASE["Ship of Theseus"] -- Get base data to create a fresh copy

        if not base_card_data then
            print("Error (Ship of Theseus): Could not find its own base data in CARD_DATABASE.")
            return
        end

        -- Create a new instance of Ship of Theseus
        local new_copy = Card.new(
            base_card_data.name,
            base_card_data.cost,
            base_card_data.power + 1, -- Add +1 power to the new copy's base power
            base_card_data.text,
            base_card_data.ability_on_reveal, -- Copy abilities too
            base_card_data.ability_on_end_of_turn,
            base_card_data.ability_ongoing,
            base_card_data.ability_on_discard
        )
        new_copy.owner_id = player.id
        game:register_card_instance(new_copy) -- IMPORTANT: Register the new card with the game

        if #player.hand < player.max_hand_size then
            table.insert(player.hand, new_copy)
            print("  - Added a copy of " .. new_copy.name .. " (Power: " .. new_copy.current_power .. ") to " .. player.name .. "'s hand.")
        else
            print("  - " .. player.name .. "'s hand is full. Could not add copy of Ship of Theseus. Discarding the copy.")
            table.insert(player.discard_pile, new_copy) -- Discard if hand is full
            if new_copy.ability_on_discard then
                new_copy:ability_on_discard(new_copy, game, player)
            end
        end
    end
}  

_G.CARD_DATABASE["Sword of Damocles"] = {
    name = "Sword of Damocles", cost = 4, power = 7, text = "End of Turn: Loses 1 power if not winning this location.",
    ability_on_end_of_turn = function(card_instance, game, player, location_idx) -- Corrected to on_end_of_turn
      print(card_instance.name .. " (Sword of Damocles) EOT effect at Loc " .. location_idx)
      local location = game.locations[location_idx]
      local opponent = game:get_opponent(player)

      if not location or not opponent then
        print("  - Error (Sword of Damocles): Invalid location or opponent.")
        return
      end

      local player_power_at_loc = location:get_player_power(player.id, game)
      local opponent_power_at_loc = location:get_player_power(opponent.id, game)

      if player_power_at_loc <= opponent_power_at_loc then -- Loses power if not strictly winning
        print("  - Not winning location. Losing 1 power.")
        card_instance.current_power = math.max(0, card_instance.current_power - 1)
      else
        print("  - Winning location. Power remains: " .. card_instance.current_power)
      end
      print("  - Sword of Damocles new power: " .. card_instance.current_power)
    end
}

_G.CARD_DATABASE["Aphrodite"] = {
    name = "Aphrodite", cost = 3, power = 3, text = "When Revealed: Lower the power of each enemy card here by 1.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " (Aphrodite) reveals at Loc " .. location_idx .. "!")
      local opponent = game:get_opponent(player)
      local location = game.locations[location_idx]

      if location and location.slots[opponent.id] then
        for _, slot_card_id in ipairs(location.slots[opponent.id]) do
          if slot_card_id then
            local enemy_card = game:get_card_instance_by_id(slot_card_id)
            if enemy_card and enemy_card.is_revealed then
              enemy_card.current_power = math.max(0, enemy_card.current_power - 1)
              print("  - Lowered " .. enemy_card.name .. "'s power to " .. enemy_card.current_power)
            end
          end
        end
      end
    end
}

_G.CARD_DATABASE["Apollo"] = {
    name = "Apollo", cost = 2, power = 1, text = "When Revealed: Gain +1 Mana next turn.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " (Apollo) reveals! Player gains +1 mana next turn.")
      player.mana_next_turn_bonus = (player.mana_next_turn_bonus or 0) + 1
      -- The Game:start_turn_procedure will need to use and reset this:
      -- player.mana = self.current_turn + (player.mana_next_turn_bonus or 0)
      -- player.mana_next_turn_bonus = 0
    end
}
    
_G.CARD_DATABASE["Persephone"] = {
    name = "Persephone", 
    cost = 2, 
    power = 4, 
    text = "When Revealed: Discard the lowest power card in your hand.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " (Persephone) reveals! Attempting to discard lowest power card from " .. player.name .. "'s hand.")

      if #player.hand == 0 then
        print("  - " .. player.name .. "'s hand is empty. No card to discard.")
        return -- Exit if hand is empty
      end

      local lowest_power_card_to_discard = nil
      local lowest_power_value = math.huge -- Initialize with a very large number
      local index_of_card_to_discard = -1

      -- Iterate through the hand to find the card with the absolute lowest power
      -- If multiple cards share the same lowest power, this will select the first one encountered.
      for i, card_in_hand in ipairs(player.hand) do
        -- Persephone (card_instance) is on the board, so it won't be in player.hand here.
        -- No need to explicitly exclude card_instance from this search.
        if card_in_hand.current_power < lowest_power_value then
          lowest_power_value = card_in_hand.current_power
          lowest_power_card_to_discard = card_in_hand
          index_of_card_to_discard = i
        end
      end

      -- If a card to discard was found (i.e., hand was not empty)
      if lowest_power_card_to_discard and index_of_card_to_discard > 0 then
        print("  - Identified '" .. lowest_power_card_to_discard.name .. "' (Power: " .. lowest_power_value .. ") as the lowest power card to discard.")

        -- Remove the card from hand using its found index
        local discarded_card_object = table.remove(player.hand, index_of_card_to_discard)
        
        -- Add it to the discard pile
        table.insert(player.discard_pile, discarded_card_object)
        print("  - '" .. discarded_card_object.name .. "' moved from hand to " .. player.name .. "'s discard pile.")

        -- Trigger its OnDiscard ability, if it has one
        if discarded_card_object.ability_on_discard then
          print("  - Triggering OnDiscard ability for " .. discarded_card_object.name .. ".")
          discarded_card_object:ability_on_discard(discarded_card_object, game, player)
        end
      else
        -- This case should theoretically not be reached if the hand was not empty at the start.
        -- It might indicate an issue if all cards had non-numeric power or some other edge case.
        print("  - No suitable card was identified for discard in " .. player.name .. "'s hand (this is unexpected if hand wasn't empty).")
      end
    end
}

_G.CARD_DATABASE["Helios"] = {
    name = "Helios", cost = 3, power = 7, text = "End of Turn: Discard this.",
    ability_on_end_of_turn = function(card_instance, game, player, location_idx) -- Corrected to on_end_of_turn
      print(card_instance.name .. " (Helios) EOT effect at Loc " .. location_idx .. ", Slot " .. card_instance.slot_idx)
      -- The card_instance itself has its location_idx and slot_idx properties set when played
      game:discard_card_from_play(card_instance, player, card_instance.location_idx, card_instance.slot_idx)
    end
    -- Removed misleading ability_on_reveal from your skeleton if it was there for Helios
}

-- Make sure this is the VERY LAST line of your card.lua file
return Card