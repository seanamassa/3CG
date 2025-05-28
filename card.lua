-- game_logic/card.lua
local Card = {}
Card.__index = Card

-- Placeholder for CARD_DATABASE
-- In a real game, you'd load this from a file or a more structured data source
-- It needs to be defined before Card.new uses it, or Card.new needs to not rely on it directly
-- For now, ability functions will be directly embedded.
-- Forward declare Game for ability function signatures if needed, though ideally abilities are self-contained or only take primitive types.
local Game -- Forward declaration if ability functions need to type hint or know about 'Game' methods directly.

-- CARD_DATABASE will be populated below Card.new or at the end of the file.
_G.CARD_DATABASE = _G.CARD_DATABASE or {} -- Using _G for simplicity here to ensure it's globally accessible by Player/Game,
                                       -- or pass CARD_DATABASE explicitly where needed. A more robust solution
                                       -- would be a dedicated CardManager module that loads and provides cards.


function Card.new(name, cost, power, text, ability_on_reveal, ability_on_end_of_turn, ability_ongoing, ability_on_discard)
  local self = setmetatable({}, Card)
  self.name = name
  self.base_cost = cost
  self.current_cost = cost
  self.base_power = power
  self.current_power = power
  self.text = text -- Descriptive text
  self.id = tostring(os.time() .. math.random(10000, 99999)) -- More unique ID
  self.unique_id_in_game = nil -- This will be set by the Game instance to guarantee uniqueness during a game session

  self.ability_on_reveal = ability_on_reveal
  self.ability_on_end_of_turn = ability_on_end_of_turn
  self.ability_ongoing = ability_ongoing or {}
  self.ability_on_discard = ability_on_discard

  self.is_revealed = false
  self.owner_id = nil
  self.location_idx = nil -- Track which location it's at
  self.slot_idx = nil -- Track which slot it's in
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

_G.CARD_DATABASE["Helios"] = {
    name = "Helios", cost = 3, power = 7, text = "End of Turn: Discard this.",
    ability_on_end_of_turn = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " activates End of Turn: Discarding itself from Loc: " .. location_idx .. ", Slot: " .. card_instance.slot_idx)
      game:discard_card_from_play(card_instance, player, location_idx, card_instance.slot_idx)
    end
}
-- ... Add all other card definitions from your list here!
_G.CARD_DATABASE["Demeter"] = {
    name = "Demeter", cost = 2, power = 2, text = "When Revealed: Both players draw a card",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")

    
_G.CARD_DATABASE["Dionysus"] = {
    name = "Dionysus", cost = 3, power = 2, text = "When Revealed: Gain +2 power for each of your other cards here.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")

    
_G.CARD_DATABASE["Ship of Theseus"] = {
    name = "Demeter", cost = 2, power = 1, text = "When Revealed: Add a copy with +1 power to your hand.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
    end
    
_G.CARD_DATABASE["Sword of Damocles"] = {
    name = "Sword of Damocles", cost = 4, power = 7, text = "End of Turn: Loses 1 power if not winning this location.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")

    end

_G.CARD_DATABASE["Aphrodite"] = {
    name = "Aphrodite", cost = 3, power = 3, text = "When Revealed: Lower the power of each enemy card here by 1.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")
 

_G.CARD_DATABASE["Apollo"] = {
    name = "Apollo", cost = 2, power = 1, text = "When Revealed: Gain +1 Mana next turn.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")
 
    
_G.CARD_DATABASE["Persephone"] = {
    name = "Persephone", cost = 2, power = 4, text = "When Revealed: Discard the lowest power card in your hand.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")

return Card