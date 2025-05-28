-- game.lua
local Player = require("game_logic.player")
local Location = require("game_logic.location")
local Card = require("game_logic.card") -- Though cards are mainly created via player decks

local Game = {}
Game.__index = Game

function Game.new()
  local self = setmetatable({}, Game)
  self.players = {
    Player.new("player1", "Player One"),
    Player.new("player2", "Opponent AI")
  }
  self.locations = {
    Location.new(1, "Mount Olympus"),
    Location.new(2, "The Underworld"),
    Location.new(3, "Aegean Sea")
  }
  self.current_turn = 0
  self.winning_score = 20 -- As decided
  self.game_over = false
  self.winner = nil
  self.priority_player_idx = nil -- 1 or 2 (index in self.players table)

  self.all_card_instances = {} -- map of card.unique_id_in_game -> card_object
  self.next_card_unique_id = 1 -- Counter for unique card IDs within a game session

  -- Initialize player slots at locations
  for _, loc in ipairs(self.locations) do
    loc:add_player_slots(self.players[1].id) -- Using player.id as key for slots
    loc:add_player_slots(self.players[2].id)
  end

  self.staged_cards_this_turn = {} -- staged_cards_this_turn[player.id] = list of {card_unique_id, location_idx, slot_idx}
  return self
end

function Game:register_card_instance(card_instance)
    card_instance.unique_id_in_game = "cardInst_" .. self.next_card_unique_id
    self.all_card_instances[card_instance.unique_id_in_game] = card_instance
    self.next_card_unique_id = self.next_card_unique_id + 1
end

function Game:get_card_instance_by_id(unique_id_in_game)
    return self.all_card_instances[unique_id_in_game]
end

function Game:setup_game()
  print("Setting up game...")
  for _, player in ipairs(self.players) do
    player:create_deck(_G.CARD_DATABASE, self) -- Pass self (the game instance)
  end
  -- Starting hand (3 cards)
  for _ = 1, 3 do
    self.players[1]:draw_card(self)
    self.players[2]:draw_card(self)
  end
  print("Game setup complete.")
end

function Game:get_opponent(player_object)
    if player_object.id == self.players[1].id then
        return self.players[2]
    else
        return self.players[1]
    end
end

function Game:start_turn_procedure()
  self.current_turn = self.current_turn + 1
  print("\n--- Starting Turn " .. self.current_turn .. " ---")
  self.staged_cards_this_turn = {}
  self.staged_cards_this_turn[self.players[1].id] = {}
  self.staged_cards_this_turn[self.players[2].id] = {}


  for _, player in ipairs(self.players) do
    player.mana = self.current_turn
    print(player.name .. " mana set to " .. player.mana)
    player:draw_card(self) -- Both players draw (rule: including turn one)
  end
end

function Game:determine_priority_player()
    print("Determining priority player...")
    if self.players[1].score > self.players[2].score then
        self.priority_player_idx = 1
    elseif self.players[2].score > self.players[1].score then
        self.priority_player_idx = 2
    else
        self.priority_player_idx = (math.random(2) == 1) and 1 or 2
    end
    print(self.players[self.priority_player_idx].name .. " has priority.")
end

function Game:reveal_phase_procedure()
    print("\n--- Reveal Phase ---")
    self:determine_priority_player()

    local first_player = self.players[self.priority_player_idx]
    local second_player_idx = (self.priority_player_idx % 2) + 1 -- Works for 1->2, 2->1
    local second_player = self.players[second_player_idx]

    local function reveal_for_player(player_to_reveal)
        print("Revealing cards for " .. player_to_reveal.name .. ":")
        if self.staged_cards_this_turn[player_to_reveal.id] then
            for _, play_info in ipairs(self.staged_cards_this_turn[player_to_reveal.id]) do
                local card = self:get_card_instance_by_id(play_info.card_unique_id)
                if card then
                    card.is_revealed = true
                    print("  - Revealed " .. card.name .. " (Power: " .. card:get_display_power() .. ") at Loc " .. play_info.location_idx .. ", Slot " .. play_info.slot_idx)
                    if card.ability_on_reveal then
                        -- IMPORTANT: The 'player' argument here is the one who OWNS and PLAYED the card.
                        card.ability_on_reveal(card, self, player_to_reveal, play_info.location_idx)
                    end
                    -- TODO: Activate ongoing abilities if applicable
                else
                    print("  - Error: Could not find staged card instance ID " .. play_info.card_unique_id)
                end
            end
        else
            print("  - " .. player_to_reveal.name .. " played no cards this turn.")
        end
    end

    reveal_for_player(first_player)
    reveal_for_player(second_player)

    -- Clear staged cards after they are revealed and processed
    self.staged_cards_this_turn[self.players[1].id] = {}
    self.staged_cards_this_turn[self.players[2].id] = {}
end

function Game:end_of_turn_abilities_procedure()
    print("\n--- End of Turn Abilities Phase ---")
    for _, player in ipairs(self.players) do
        for loc_idx, location in ipairs(self.locations) do
            if location.slots[player.id] then
                -- Iterate carefully as cards might be removed
                local slots_to_check = {}
                for i = 1, location.max_slots_per_player do table.insert(slots_to_check, i) end

                for _, slot_idx in ipairs(slots_to_check) do
                    local card_unique_id = location.slots[player.id][slot_idx]
                    if card_unique_id then
                        local card = self:get_card_instance_by_id(card_unique_id)
                        -- Check if card is still there and revealed (might have been removed by another EOT)
                        if card and card.is_revealed and location.slots[player.id][slot_idx] == card.unique_id_in_game then
                            if card.ability_on_end_of_turn then
                                print("  Activating EOT for " .. card.name .. " (Owner: " .. player.name .. ") at Loc " .. loc_idx .. " Slot " .. slot_idx)
                                card.ability_on_end_of_turn(card, self, player, loc_idx)
                            end
                        end
                    end
                end
            end
        end
    end
end


function Game:scoring_phase_procedure()
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

function Game:check_win_condition_procedure()
  local p1_met_score = self.players[1].score >= self.winning_score
  local p2_met_score = self.players[2].score >= self.winning_score

  if p1_met_score and p2_met_score then
    if self.players[1].score > self.players[2].score then self.winner = self.players[1]
    elseif self.players[2].score > self.players[1].score then self.winner = self.players[2]
    else print("Game ends in a SCORE TIE! (Both >= " .. self.winning_score .. " with same score)") -- Or specific tie-break
    end
  elseif p1_met_score then self.winner = self.players[1]
  elseif p2_met_score then self.winner = self.players[2]
  end

  if self.winner then
    self.game_over = true
    print("\nGAME OVER! " .. self.winner.name .. " wins with " .. self.winner.score .. " points!")
  elseif self.current_turn >= 20 then -- Arbitrary turn limit
      self.game_over = true; print("\nGAME OVER! Turn limit (20) reached.")
      if self.players[1].score > self.players[2].score then self.winner = self.players[1]; print(self.players[1].name .. " wins.")
      elseif self.players[2].score > self.players[1].score then self.winner = self.players[2]; print(self.players[2].name .. " wins.")
      else print("It's a draw on turn limit score!") end
  end
  return self.game_over
end

function Game:discard_card_from_play(card_instance, player_who_owns_card, location_idx_card_is_at, slot_idx_card_is_in)
    local location = self.locations[location_idx_card_is_at]
    if not (location and location.slots[player_who_owns_card.id] and location.slots[player_who_owns_card.id][slot_idx_card_is_in] == card_instance.unique_id_in_game) then
        print("  Warning: Card " .. card_instance.name .. " not found at specified slot (Loc " .. location_idx_card_is_at .. ", Slot " .. slot_idx_card_is_in .. ") for " .. player_who_owns_card.name .. " to discard.")
        return false
    end

    location.slots[player_who_owns_card.id][slot_idx_card_is_in] = nil -- Remove from slot
    table.insert(player_who_owns_card.discard_pile, card_instance)
    card_instance.is_revealed = false -- Reset state
    card_instance.location_idx = nil
    card_instance.slot_idx = nil
    print("  " .. card_instance.name .. " moved from play (Loc " .. location_idx_card_is_at .. ", Slot " .. slot_idx_card_is_in .. ") to " .. player_who_owns_card.name .. "'s discard pile.")

    if card_instance.ability_on_discard then
        card_instance:ability_on_discard(card_instance, self, player_who_owns_card)
    end
    return true
end


function Game:get_simple_board_state_text()
    local lines = {}
    table.insert(lines, "--- Board State (End of Turn " .. self.current_turn .. ") ---")
    for i, player in ipairs(self.players) do
        table.insert(lines, string.format("%s (P%d) - Score: %d, Mana: %d, Hand: %d, Deck: %d, Discard: %d",
            player.name, i, player.score, player.mana, #player.hand, #player.deck, #player.discard_pile))
    end
    for _, loc in ipairs(self.locations) do
        local p1_cards_str = ""
        if loc.slots[self.players[1].id] then
            for i=1, loc.max_slots_per_player do
                local c_id = loc.slots[self.players[1].id][i]
                if c_id then local c = self:get_card_instance_by_id(c_id); p1_cards_str = p1_cards_str .. string.format("%s(%d) ", c.name, c:get_display_power()) else p1_cards_str = p1_cards_str .. "[E] " end
            end
        end
        local p2_cards_str = ""
         if loc.slots[self.players[2].id] then
            for i=1, loc.max_slots_per_player do
                local c_id = loc.slots[self.players[2].id][i]
                if c_id then local c = self:get_card_instance_by_id(c_id); p2_cards_str = p2_cards_str .. string.format("%s(%d) ", c.name, c:get_display_power()) else p2_cards_str = p2_cards_str .. "[E] " end
            end
        end
        table.insert(lines, string.format("  Loc %d (%s): P1> %s | P2> %s", loc.id, loc.name, p1_cards_str, p2_cards_str))
    end
    return table.concat(lines, "\n")
end


return Game