-- player.lua
local Utils = require("utils") -- Or "your_project_name.utils" if in a subdir
local Card = require("game_logic.card") -- To create card instances

local Player = {}
Player.__index = Player

function Player.new(id, name)
  local self = setmetatable({}, Player)
  self.id = id
  self.name = name
  self.deck = {}
  self.hand = {}
  self.discard_pile = {}
  self.mana = 0
  self.score = 0
  self.max_hand_size = 7
  return self
end

function Player:create_deck(card_definitions_db, game_instance_ref) -- Pass the game instance for card registration
  local deck_card_names = {}
  -- Example: 2 of each of the first 5 defined cards + fill to 20
  local example_cards_for_deck = {"Wooden Cow", "Pegasus", "Zeus", "Ares", "Helios"}
  for i = 1, 2 do
    for _, name in ipairs(example_cards_for_deck) do table.insert(deck_card_names, name) end
  end
  while #deck_card_names < 20 do
    table.insert(deck_card_names, "Wooden Cow") -- Fill with basic cards
  end

  for _, card_name_in_recipe in ipairs(deck_card_names) do
    local card_data_from_db = _G.CARD_DATABASE[card_name_in_recipe] -- Accessing global CARD_DATABASE
    if card_data_from_db then
      local new_card_instance = Card.new(
        card_data_from_db.name,
        card_data_from_db.cost,
        card_data_from_db.power,
        card_data_from_db.text,
        card_data_from_db.ability_on_reveal,
        card_data_from_db.ability_on_end_of_turn,
        card_data_from_db.ability_ongoing,
        card_data_from_db.ability_on_discard
      )
      new_card_instance.owner_id = self.id
      table.insert(self.deck, new_card_instance)
      game_instance_ref:register_card_instance(new_card_instance) -- Register with the game
    else
      print("Warning: Card recipe name not found in CARD_DATABASE: " .. card_name_in_recipe)
    end
  end
  Utils.shuffle_deck(self.deck)
  print(self.name .. "'s deck created with " .. #self.deck .. " cards.")
end

function Player:draw_card(game_instance_ref) -- Pass game for discard abilities
  if #self.deck == 0 then
    print(self.name .. " has no cards left to draw!")
    return nil
  end
  if #self.hand >= self.max_hand_size then
    local card_to_discard_from_deck = table.remove(self.deck, 1) -- Draw then discard
    print(self.name .. " hand is full (" .. #self.hand .. "/" .. self.max_hand_size .. "). Drawn card " .. card_to_discard_from_deck.name .. " is discarded.")
    table.insert(self.discard_pile, card_to_discard_from_deck)
    if card_to_discard_from_deck.ability_on_discard then
        card_to_discard_from_deck:ability_on_discard(card_to_discard_from_deck, game_instance_ref, self)
    end
    return nil
  end
  local drawn_card = table.remove(self.deck, 1)
  table.insert(self.hand, drawn_card)
  print(self.name .. " drew " .. drawn_card.name .. ". Hand ("..#self.hand.."): " .. drawn_card.name)
  return drawn_card
end

function Player:play_card_from_hand_by_instance_id(card_instance_id, target_location_idx, game_instance_ref)
    local card_to_play = nil
    local card_idx_in_hand = nil

    for i, card_in_hand_instance in ipairs(self.hand) do
        if card_in_hand_instance.unique_id_in_game == card_instance_id then -- Use unique_id_in_game
            card_to_play = card_in_hand_instance
            card_idx_in_hand = i
            break
        end
    end

    if not card_to_play then
        print("Error: " .. self.name .. " does not have card with unique ID " .. card_instance_id .. " in hand.")
        return false
    end

    if card_to_play:get_display_cost() > self.mana then
        print("Error: " .. self.name .. " not enough mana for " .. card_to_play.name .. " (Cost: " .. card_to_play:get_display_cost() .. ", Mana: " .. self.mana .. ")")
        return false
    end

    local location = game_instance_ref.locations[target_location_idx]
    if not location then
        print("Error: Invalid location index: " .. target_location_idx)
        return false
    end

    local empty_slot_idx = nil
    if location.slots[self.id] then
        for i = 1, location.max_slots_per_player do
            if not location.slots[self.id][i] then
                empty_slot_idx = i
                break
            end
        end
    end

    if not empty_slot_idx then
        print("Error: No empty slots for " .. self.name .. " at location " .. target_location_idx)
        return false
    end

    self.mana = self.mana - card_to_play:get_display_cost()
    location.slots[self.id][empty_slot_idx] = card_to_play.unique_id_in_game -- Store unique_id_in_game
    table.remove(self.hand, card_idx_in_hand)

    card_to_play.is_revealed = false -- Will be revealed in reveal phase
    card_to_play.location_idx = target_location_idx -- Track where it is
    card_to_play.slot_idx = empty_slot_idx

    game_instance_ref.staged_cards_this_turn[self.id] = game_instance_ref.staged_cards_this_turn[self.id] or {}
    table.insert(game_instance_ref.staged_cards_this_turn[self.id], {
        card_unique_id = card_to_play.unique_id_in_game,
        location_idx = target_location_idx,
        slot_idx = empty_slot_idx
    })

    print(self.name .. " played " .. card_to_play.name .. " to Loc " .. target_location_idx .. ", Slot " .. empty_slot_idx .. ". Mana left: " .. self.mana)
    return true
end


return Player