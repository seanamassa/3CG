--main

--[[
  Greek Mythology 3CG - Lua Core Structure
  This script provides a basic framework for the card game.
  It includes structures for Cards, Players, Locations, and the Game itself.
]]

-- =============================================================================
-- Utility Functions
-- =============================================================================

-- Simple function to clone a table (useful for creating card instances)
function shallow_clone(original)
  local copy = {}
  for k, v in pairs(original) do
    copy[k] = v
  end
  return copy
end

-- Function to shuffle a deck (Fisher-Yates shuffle)
function shuffle_deck(deck)
  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
  return deck
end

-- =============================================================================
-- Card Definition
-- =============================================================================

Card = {}
Card.__index = Card

function Card.new(name, cost, power, text, ability_on_reveal, ability_on_end_of_turn, ability_ongoing, ability_on_discard)
  local self = setmetatable({}, Card)
  self.name = name
  self.base_cost = cost
  self.current_cost = cost
  self.base_power = power
  self.current_power = power
  self.text = text -- Descriptive text
  self.id = tostring(math.random(100000, 999999)) -- Unique ID for this instance

  -- Placeholder for ability functions
  -- These would be actual functions defined for specific cards
  self.ability_on_reveal = ability_on_reveal or function(card_instance, game, player, location_idx)
    -- print(card_instance.name .. " has no OnReveal ability.")
  end
  self.ability_on_end_of_turn = ability_on_end_of_turn or function(card_instance, game, player, location_idx)
    -- print(card_instance.name .. " has no OnEndOfTurn ability.")
  end
  self.ability_ongoing = ability_ongoing or {} -- Could be a table of functions or flags
   self.ability_on_discard = ability_on_discard or function(card_instance, game, player)
    -- print(card_instance.name .. " has no OnDiscard ability.")
  end

  self.is_revealed = false
  self.owner_id = nil -- Will be set when a player owns the card
  return self
end

function Card:get_display_power()
    return self.current_power
end

function Card:get_display_cost()
    return self.current_cost
end

-- Example: How you might define a specific card's abilities
-- This would typically be loaded from a card database

-- Placeholder for card database
-- In a real game, you'd load this from a file or a more structured data source
CARD_DATABASE = {
  ["Wooden Cow"]      = {cost = 1, power = 1, text = "A sturdy, if unremarkable, bovine construct."},
  ["Pegasus"]         = {cost = 3, power = 5, text = "A majestic winged steed."},
  ["Minotaur"]        = {cost = 5, power = 9, text = "A fearsome beast of the labyrinth."},
  ["Titan"]           = {cost = 6, power = 12, text = "A being of immense, primordial power."},
  ["Zeus"]            = {cost = 4, power = 4, text = "When Revealed: Lower the power of each card in your opponent's hand by 1.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals! Lowering opponent hand power.")
      local opponent = game:get_opponent(player)
      for _, card_in_hand in ipairs(opponent.hand) do
        card_in_hand.current_power = math.max(0, card_in_hand.current_power - 1)
        print("  - Reduced " .. card_in_hand.name .. " in opponent's hand to " .. card_in_hand.current_power .. " power.")
      end
    end
  },
  ["Ares"]            = {cost = 3, power = 2, text = "When Revealed: Gain +2 power for each enemy card here.",
    ability_on_reveal = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " reveals!")
      local enemy_cards_at_location = 0
      local opponent = game:get_opponent(player)
      local location = game.locations[location_idx]
      for _, slot_card_id in ipairs(location.slots[opponent.id]) do
        if slot_card_id then
          local slot_card = game:get_card_instance_by_id(slot_card_id) -- You'll need a way to get card instance
          if slot_card and slot_card.is_revealed then
             enemy_cards_at_location = enemy_cards_at_location + 1
          end
        end
      end
      card_instance.current_power = card_instance.current_power + (2 * enemy_cards_at_location)
      print("  - Ares gains " .. (2 * enemy_cards_at_location) .. " power. New power: " .. card_instance.current_power)
    end
  },
  -- ... Add all other cards from your list here with their respective abilities
  ["Helios"]          = {cost = 3, power = 7, text = "End of Turn: Discard this.",
    ability_on_end_of_turn = function(card_instance, game, player, location_idx)
      print(card_instance.name .. " activates End of Turn: Discarding itself.")
      game:discard_card_from_play(card_instance, player, location_idx)
    end
  },
}


-- =============================================================================
-- Player Definition
-- =============================================================================

Player = {}
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

function Player:create_deck(card_db)
  -- For simplicity, adding 2 of each card from a small subset of the DB
  -- In a real game, players would build decks or have pre-defined ones.
  local deck_card_names = {"Wooden Cow", "Pegasus", "Titan", "Ares", "Helios", "Demeter", "Dionysis", "Ship of Theseus", "Sword of Damocles", "Aphrodite", "Apollo", "Persepone", "Zeus", "Persephone"} -- Example 14 cards
  -- Fill to 20
  for i = 1, 6 do
    table.insert(deck_card_names, "Wooden Cow")
  end


  for _, card_name in ipairs(deck_card_names) do
    local card_data = card_db[card_name]
    if card_data then
      -- Create a new instance for each card in the deck
      local new_card = Card.new(card_name, card_data.cost, card_data.power, card_data.text, card_data.ability_on_reveal, card_data.ability_on_end_of_turn, card_data.ability_ongoing, card_data.ability_on_discard)
      new_card.owner_id = self.id
      table.insert(self.deck, new_card)
    else
      print("Warning: Card not found in database: " .. card_name)
    end
  end
  shuffle_deck(self.deck)
  print(self.name .. "'s deck created with " .. #self.deck .. " cards.")
end

function Player:draw_card()
  if #self.deck == 0 then
    print(self.name .. " has no cards left to draw!")
    return nil
  end
  if #self.hand >= self.max_hand_size then
    local discarded_card = table.remove(self.deck, 1)
    print(self.name .. " hand is full (" .. #self.hand .. "/" .. self.max_hand_size .. "). Drawn card " .. discarded_card.name .. " is discarded.")
    table.insert(self.discard_pile, discarded_card)
    if discarded_card.ability_on_discard then
        discarded_card:ability_on_discard(discarded_card, Game, self) -- Assuming Game is accessible globally or passed
    end
    return nil
  end
  local drawn_card = table.remove(self.deck, 1)
  table.insert(self.hand, drawn_card)
  print(self.name .. " drew " .. drawn_card.name .. ". Hand size: " .. #self.hand)
  return drawn_card
end

function Player:play_card(card_id_to_play, location_idx, game)
    local card_to_play = nil
    local card_idx_in_hand = nil

    for i, card_in_hand in ipairs(self.hand) do
        if card_in_hand.id == card_id_to_play then
            card_to_play = card_in_hand
            card_idx_in_hand = i
            break
        end
    end

    if not card_to_play then
        print("Error: " .. self.name .. " does not have card with ID " .. card_id_to_play .. " in hand.")
        return false
    end

    if card_to_play.current_cost > self.mana then
        print("Error: " .. self.name .. " does not have enough mana to play " .. card_to_play.name .. " (Cost: " .. card_to_play.current_cost .. ", Mana: " .. self.mana .. ")")
        return false
    end

    local location = game.locations[location_idx]
    if not location then
        print("Error: Invalid location index: " .. location_idx)
        return false
    end

    -- Find an empty slot
    local empty_slot_idx = nil
    for i = 1, #location.slots[self.id] do
        if not location.slots[self.id][i] then
            empty_slot_idx = i
            break
        end
    end

    if not empty_slot_idx then
        print("Error: No empty slots for " .. self.name .. " at location " .. location_idx)
        return false
    end

    -- Stage the card (move from hand to location slot)
    self.mana = self.mana - card_to_play.current_cost
    location.slots[self.id][empty_slot_idx] = card_to_play.id -- Store card ID in slot
    table.remove(self.hand, card_idx_in_hand)
    card_to_play.is_revealed = false -- Ensure it's marked as not revealed yet
    game.staged_cards_this_turn[self.id] = game.staged_cards_this_turn[self.id] or {}
    table.insert(game.staged_cards_this_turn[self.id], {card_id = card_to_play.id, location_idx = location_idx, slot_idx = empty_slot_idx})


    print(self.name .. " played " .. card_to_play.name .. " to location " .. location_idx .. ", slot " .. empty_slot_idx .. ". Mana left: " .. self.mana)
    return true
end


-- =============================================================================
-- Location Definition
-- =============================================================================

Location = {}
Location.__index = Location

function Location.new(idx, name)
  local self = setmetatable({}, Location)
  self.id = idx
  self.name = name
  self.slots = {} -- slots[player_id][slot_index] = card_id
  self.max_slots_per_player = 4
  return self
end

function Location:add_player_slots(player_id)
    self.slots[player_id] = {}
    for i = 1, self.max_slots_per_player do
        self.slots[player_id][i] = nil -- nil means empty slot
    end
end

function Location:get_player_power(player_id, game)
    local total_power = 0
    if self.slots[player_id] then
        for _, card_id in ipairs(self.slots[player_id]) do
            if card_id then
                local card = game:get_card_instance_by_id(card_id)
                if card and card.is_revealed then
                    total_power = total_power + card:get_display_power()
                end
            end
        end
    end
    return total_power
end

-- =============================================================================
-- Game Definition
-- =============================================================================

Game = {}
Game.__index = Game

function Game.new()
  local self = setmetatable({}, Game)
  self.players = {
    Player.new("player1", "Player One"),
    Player.new("player2", "Opponent AI") -- Or Player Two
  }
  self.locations = {
    Location.new(1, "Mount Olympus"),
    Location.new(2, "The Underworld"),
    Location.new(3, "Aegean Sea")
  }
  self.current_turn = 0
  self.winning_score = 20
  self.game_over = false
  self.winner = nil
  self.priority_player_idx = nil -- 1 or 2

  -- Initialize player slots at locations
  for _, loc in ipairs(self.locations) do
    loc:add_player_slots(self.players[1].id)
    loc:add_player_slots(self.players[2].id)
  end

  -- Store all card instances in the game for easy lookup by ID
  self.all_card_instances = {} -- map of card_id -> card_object

  self.staged_cards_this_turn = {} -- To track cards played but not yet revealed: staged_cards_this_turn[player_id] = {{card_id, location_idx, slot_idx}, ...}

  return self
end

function Game:register_card_instance(card_instance)
    self.all_card_instances[card_instance.id] = card_instance
end

function Game:get_card_instance_by_id(card_id)
    return self.all_card_instances[card_id]
end


function Game:setup_game()
  print("Setting up game...")
  for _, player in ipairs(self.players) do
    player:create_deck(CARD_DATABASE)
    -- Register all deck cards to the game's instance tracker
    for _, card_in_deck in ipairs(player.deck) do
        self:register_card_instance(card_in_deck)
    end

    for _ = 1, 3 do -- Starting hand
      player:draw_card()
    end
  end
  print("Game setup complete.")
end

function Game:get_opponent(player)
    if player.id == self.players[1].id then
        return self.players[2]
    else
        return self.players[1]
    end
end

function Game:start_turn()
  self.current_turn = self.current_turn + 1
  print("\n--- Starting Turn " .. self.current_turn .. " ---")
  self.staged_cards_this_turn = {} -- Reset staged cards

  for _, player in ipairs(self.players) do
    player.mana = self.current_turn
    print(player.name .. " mana set to " .. player.mana)
    player:draw_card() -- Both players draw at start of turn (including turn 1 as per rules)
  end
end

function Game:determine_priority_player()
    print("Determining priority player...")
    if self.players[1].score > self.players[2].score then
        self.priority_player_idx = 1
        print(self.players[1].name .. " has priority (higher score).")
    elseif self.players[2].score > self.players[1].score then
        self.priority_player_idx = 2
        print(self.players[2].name .. " has priority (higher score).")
    else
        -- Tie in score, or start of game
        if math.random(2) == 1 then
            self.priority_player_idx = 1
            print("Scores tied. Coin flip: " .. self.players[1].name .. " wins priority.")
        else
            self.priority_player_idx = 2
            print("Scores tied. Coin flip: " .. self.players[2].name .. " wins priority.")
        end
    end
end

function Game:reveal_phase()
    print("\n--- Reveal Phase ---")
    self:determine_priority_player()

    local first_player = self.players[self.priority_player_idx]
    local second_player_idx = (self.priority_player_idx == 1) and 2 or 1
    local second_player = self.players[second_player_idx]

    local function reveal_player_cards(player_to_reveal)
        print("Revealing cards for " .. player_to_reveal.name .. ":")
        if self.staged_cards_this_turn[player_to_reveal.id] then
            for _, play_info in ipairs(self.staged_cards_this_turn[player_to_reveal.id]) do
                local card = self:get_card_instance_by_id(play_info.card_id)
                if card then
                    card.is_revealed = true
                    print("  - Revealed " .. card.name .. " (Power: " .. card.current_power .. ") at Location " .. play_info.location_idx .. ", Slot " .. play_info.slot_idx)
                    if card.ability_on_reveal then
                        card:ability_on_reveal(card, self, player_to_reveal, play_info.location_idx)
                    end
                    -- TODO: Implement logic for ongoing abilities activating
                else
                    print("  - Error: Could not find card instance for ID " .. play_info.card_id)
                end
            end
        else
            print("  - " .. player_to_reveal.name .. " played no cards this turn.")
        end
    end

    reveal_player_cards(first_player)
    reveal_player_cards(second_player)

    self.staged_cards_this_turn = {} -- Clear after reveal
end


function Game:scoring_phase()
  print("\n--- Scoring Phase ---")
  for _, loc in ipairs(self.locations) do
    local p1_power = loc:get_player_power(self.players[1].id, self)
    local p2_power = loc:get_player_power(self.players[2].id, self)

    print("Location " .. loc.id .. " (" .. loc.name .. "): " .. self.players[1].name .. " Power: " .. p1_power .. ", " .. self.players[2].name .. " Power: " .. p2_power)

    if p1_power > p2_power then
      local points_earned = p1_power - p2_power
      self.players[1].score = self.players[1].score + points_earned
      print("  " .. self.players[1].name .. " earns " .. points_earned .. " points. Total: " .. self.players[1].score)
    elseif p2_power > p1_power then
      local points_earned = p2_power - p1_power
      self.players[2].score = self.players[2].score + points_earned
      print("  " .. self.players[2].name .. " earns " .. points_earned .. " points. Total: " .. self.players[2].score)
    else
      print("  Power tied at Location " .. loc.id .. ". No points awarded.")
    end
  end
end

function Game:end_of_turn_abilities_phase()
    print("\n--- End of Turn Abilities Phase ---")
    -- Iterate through all revealed cards in play for both players
    for _, player in ipairs(self.players) do
        for loc_idx, location in ipairs(self.locations) do
            if location.slots[player.id] then
                for slot_idx, card_id in ipairs(location.slots[player.id]) do
                    if card_id then
                        local card = self:get_card_instance_by_id(card_id)
                        if card and card.is_revealed and card.ability_on_end_of_turn then
                            print("  Activating End of Turn for " .. card.name .. " (Owner: " .. player.name .. ")")
                            card:ability_on_end_of_turn(card, self, player, loc_idx)
                            -- Card might have been discarded, check if it's still in the slot
                            if self.locations[loc_idx].slots[player.id][slot_idx] ~= card_id then
                                print("    " .. card.name .. " was removed from play by its own EOT effect.")
                            end
                        end
                    end
                end
            end
        end
    end
end


function Game:check_win_condition()
  local p1_wins = self.players[1].score >= self.winning_score
  local p2_wins = self.players[2].score >= self.winning_score

  if p1_wins and p2_wins then
    if self.players[1].score > self.players[2].score then
      self.winner = self.players[1]
    elseif self.players[2].score > self.players[1].score then
      self.winner = self.players[2]
    else
      print("Game ends in a DRAW by score! (Both reached " .. self.winning_score .. "+ with same score)")
      -- Or handle this as no winner, or another tie-break rule
    end
  elseif p1_wins then
    self.winner = self.players[1]
  elseif p2_wins then
    self.winner = self.players[2]
  end

  if self.winner then
    self.game_over = true
    print("\nGAME OVER! " .. self.winner.name .. " wins with " .. self.winner.score .. " points!")
  elseif self.current_turn >= 20 then -- Arbitrary turn limit to prevent infinite games
      self.game_over = true
      print("\nGAME OVER! Turn limit reached. Final Scores: P1=" .. self.players[1].score .. ", P2=" .. self.players[2].score)
      if self.players[1].score > self.players[2].score then self.winner = self.players[1] print(self.players[1].name .. " wins on turn limit.")
      elseif self.players[2].score > self.players[1].score then self.winner = self.players[2] print(self.players[2].name .. " wins on turn limit.")
      else print("It's a draw on turn limit!") end
  end
end

function Game:discard_card_from_play(card_instance, player, location_idx)
    local location = self.locations[location_idx]
    local found_and_removed = false
    if location and location.slots[player.id] then
        for i, slot_card_id in ipairs(location.slots[player.id]) do
            if slot_card_id == card_instance.id then
                location.slots[player.id][i] = nil -- Remove from slot
                table.insert(player.discard_pile, card_instance)
                card_instance.is_revealed = false -- Reset state
                print("  " .. card_instance.name .. " moved from play (Loc " .. location_idx .. ") to " .. player.name .. "'s discard pile.")
                if card_instance.ability_on_discard then
                    card_instance:ability_on_discard(card_instance, self, player)
                end
                found_and_removed = true
                break
            end
        end
    end
    if not found_and_removed then
        print("  Warning: Could not find " .. card_instance.name .. " to discard from play for " .. player.name .. " at Loc " .. location_idx)
    end
end


-- =============================================================================
-- Main Game Loop (Simplified Example)
-- =============================================================================

function main()
  math.randomseed(os.time()) -- Seed random number generator

  local game = Game.new()
  game:setup_game()

  -- Simple loop for a few turns
  while not game.game_over do
    game:start_turn()

    -- Staging Phase (Simulated - needs player input in a real game)
    print("\n--- Staging Phase (Player Actions) ---")
    -- Player 1 plays
    if #game.players[1].hand > 0 and game.players[1].mana > 0 then
        local card_to_play_p1 = game.players[1].hand[1] -- Play first card if possible
        if card_to_play_p1.current_cost <= game.players[1].mana then
            -- Play to a random available location (simplified)
            local played_loc_p1 = math.random(1, #game.locations)
            game.players[1]:play_card(card_to_play_p1.id, played_loc_p1, game)
        else
            print(game.players[1].name .. " cannot afford " .. card_to_play_p1.name)
        end
    else
        print(game.players[1].name .. " has no cards to play or no mana.")
    end

    -- Player 2 plays (AI / second player)
    if #game.players[2].hand > 0 and game.players[2].mana > 0 then
        local card_to_play_p2 = game.players[2].hand[1] -- Play first card if possible
         if card_to_play_p2.current_cost <= game.players[2].mana then
            local played_loc_p2 = math.random(1, #game.locations)
            game.players[2]:play_card(card_to_play_p2.id, played_loc_p2, game)
        else
            print(game.players[2].name .. " cannot afford " .. card_to_play_p2.name)
        end
    else
        print(game.players[2].name .. " has no cards to play or no mana.")
    end

    -- Submission is implicit here for simulation

    game:reveal_phase()
    game:end_of_turn_abilities_phase() -- Process EOT abilities
    game:scoring_phase()
    game:check_win_condition()

    -- Display board state (simplified)
    print("\n--- Board State (End of Turn " .. game.current_turn .. ") ---")
    for _, player in ipairs(game.players) do
        print(player.name .. " - Score: " .. player.score .. ", Mana: " .. player.mana .. ", Hand: " .. #player.hand .. ", Deck: " .. #player.deck .. ", Discard: " .. #player.discard_pile)
    end
    for _, loc in ipairs(game.locations) do
        local p1_cards_str = ""
        for _, c_id in ipairs(loc.slots[game.players[1].id]) do if c_id then local c = game:get_card_instance_by_id(c_id); p1_cards_str = p1_cards_str .. c.name .. "("..c.current_power..") " else p1_cards_str = p1_cards_str .. "[E] " end end
        local p2_cards_str = ""
        for _, c_id in ipairs(loc.slots[game.players[2].id]) do if c_id then local c = game:get_card_instance_by_id(c_id); p2_cards_str = p2_cards_str .. c.name .. "("..c.current_power..") " else p2_cards_str = p2_cards_str .. "[E] " end end
        print("  Loc " .. loc.id .. ": P1> " .. p1_cards_str .. " | P2> " .. p2_cards_str)
    end

    if game.game_over then
      break
    end
  end
end

-- Run the game
main()
