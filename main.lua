-- main

local Game = require("game")
local CardRenderer = require("renderer")
local Utils = require("utils")

-- Game state and UI variables
local gameState
local gameMessages = {}
local currentPhase = "SETUP" -- SETUP, PLAYER_ACTION, SUBMITTED_BY_PLAYER, REVEAL, EOT_ABILITIES, SCORE, GAME_OVER

-- Drag and Drop state
local draggedCardInfo = {
    card_instance = nil,
    original_hand_idx = nil,
    offset_x = 0,
    offset_y = 0,
    current_screen_x = 0,
    current_screen_y = 0
}

-- UI Element Definitions
local handCardVisuals = {}
local locationSlotDropZones = {}
local submitButtonRect = {x = 0, y = 0, width = 150, height = 50, text = "Submit Turn"} 

local CARD_WIDTH = 100
local CARD_HEIGHT = 150

-- Helper function to capture print statements for on-screen display
local oldPrint = print
function print(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    local message = table.concat(parts, "\t")
    oldPrint(message)
    table.insert(gameMessages, 1, message)
    if #gameMessages > 15 then table.remove(gameMessages) end
end

local function isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function updatePlayer1HandCardVisuals()
    if not gameState or not gameState.players[1] then
        handCardVisuals = {}
        return
    end
    
    handCardVisuals = {}
    local player1_hand = gameState.players[1].hand
    local hand_y = love.graphics.getHeight() - CARD_HEIGHT - 20
    local card_spacing = 10
    local total_hand_width = (#player1_hand * CARD_WIDTH) + (math.max(0, #player1_hand - 1) * card_spacing)
    local hand_x_start = (love.graphics.getWidth() - total_hand_width) / 2

    for i, card_in_hand_instance in ipairs(player1_hand) do
        table.insert(handCardVisuals, {
            x = hand_x_start + (i - 1) * (CARD_WIDTH + card_spacing),
            y = hand_y,
            width = CARD_WIDTH,
            height = CARD_HEIGHT,
            card_instance = card_in_hand_instance
        })
    end
end

function defineLocationSlotDropZones()
    if not gameState then return end
    locationSlotDropZones = {}
    local loc_visual_width = (CARD_WIDTH * gameState.locations[1].max_slots_per_player) + (10 * (gameState.locations[1].max_slots_per_player -1))
    local total_width_for_all_locs = (loc_visual_width * #gameState.locations) + (40 * (#gameState.locations - 1))
    local loc_start_x_overall = (love.graphics.getWidth() - total_width_for_all_locs) / 2

    local p1_slots_y = love.graphics.getHeight() / 2 + 10 -- Player 1 slots (bottom half of middle)
    local p2_slots_y = love.graphics.getHeight() / 2 - CARD_HEIGHT - 10 -- Player 2 slots (top half of middle)

    for loc_idx = 1, #gameState.locations do
        local current_loc_block_start_x = loc_start_x_overall + (loc_idx - 1) * (loc_visual_width + 40)
        for slot_idx = 1, gameState.locations[loc_idx].max_slots_per_player do
            table.insert(locationSlotDropZones, {
                x = current_loc_block_start_x + (slot_idx - 1) * (CARD_WIDTH + 10),
                y = p1_slots_y, width = CARD_WIDTH, height = CARD_HEIGHT,
                location_idx = loc_idx, slot_idx = slot_idx, player_id = gameState.players[1].id
            })
            table.insert(locationSlotDropZones, {
                x = current_loc_block_start_x + (slot_idx - 1) * (CARD_WIDTH + 10),
                y = p2_slots_y, width = CARD_WIDTH, height = CARD_HEIGHT,
                location_idx = loc_idx, slot_idx = slot_idx, player_id = gameState.players[2].id
            })
        end
    end
end

-- load
function love.load()
    math.randomseed(os.time())
    love.graphics.setFont(love.graphics.newFont(12))
    love.window.setTitle("Card Clash of the Gods") 

    CardRenderer.loadAssets()

    -- submit button position
    submitButtonRect.x = love.graphics.getWidth() - submitButtonRect.width - 20
    submitButtonRect.y = love.graphics.getHeight() - submitButtonRect.height - 20


    gameState = Game.new()
    gameState:setup_game()
    
    defineLocationSlotDropZones() 
    updatePlayer1HandCardVisuals() 

    currentPhase = "START_TURN"
    print("Game Loaded. Current phase: " .. currentPhase)
    if gameState and not gameState.game_over then
        gameState:start_turn_procedure()
        updatePlayer1HandCardVisuals() 
        currentPhase = "PLAYER_ACTION"
        print("First turn (" .. gameState.current_turn .. "). Phase: " .. currentPhase .. ". Player 1 Mana: " .. gameState.players[1].mana)
    end
end

function simulate_ai_player_actions(player, game)
    if not player or not game or game.game_over then return end
    print("\n--- Simulating AI (" .. player.name .. ") Actions for Turn " .. game.current_turn .. " ---")
    local cards_played_by_ai = 0
    local max_ai_plays_per_turn = 4 

    local temp_hand_for_ai = {}
    for _, card_in_hand in ipairs(player.hand) do table.insert(temp_hand_for_ai, card_in_hand) end

    for _, card_to_play in ipairs(temp_hand_for_ai) do
        if cards_played_by_ai >= max_ai_plays_per_turn then break end
        if player.mana == 0 then break end

        if card_to_play:get_display_cost() <= player.mana then
            local played_this_card_successfully = false
            for attempt = 1, #game.locations * 2 do 
                local target_loc_idx = math.random(1, #game.locations)
                if player:play_card_from_hand_by_instance_id(card_to_play.unique_id_in_game, target_loc_idx, game) then
                    print(player.name .. " AI successfully staged " .. card_to_play.name .. " to Loc " .. target_loc_idx)
                    cards_played_by_ai = cards_played_by_ai + 1
                    played_this_card_successfully = true
                    break 
                end
            end
            if not played_this_card_successfully then
                 print(player.name .. " AI failed to find a slot for " .. card_to_play.name .. " after several attempts.")
            end
        end
        if played_this_card_successfully and cards_played_by_ai >= max_ai_plays_per_turn then break end
    end
    if cards_played_by_ai == 0 then
        print(player.name .. " AI did not play any card this turn.")
    end
end

function love.update(dt)
    if not gameState or gameState.game_over then return end

    if currentPhase == "SUBMITTED_BY_PLAYER" then
        simulate_ai_player_actions(gameState.players[2], gameState)
        currentPhase = "REVEAL"
        print("AI actions simulated. Current phase: " .. currentPhase)
    elseif currentPhase == "REVEAL" then
        gameState:reveal_phase_procedure()
        currentPhase = "EOT_ABILITIES"
        print("Reveal phase complete. Current phase: " .. currentPhase)
    elseif currentPhase == "EOT_ABILITIES" then
        gameState:end_of_turn_abilities_procedure()
        currentPhase = "SCORE"
        print("End of Turn abilities complete. Current phase: " .. currentPhase)
    elseif currentPhase == "SCORE" then
        gameState:scoring_phase_procedure()
        if gameState:check_win_condition_procedure() then
            currentPhase = "GAME_OVER"
            print("Win condition met. Current phase: " .. currentPhase)
        else
            currentPhase = "START_TURN"
            print("Scoring complete. Next turn. Current phase: " .. currentPhase)
        end
    elseif currentPhase == "START_TURN" then
         gameState:start_turn_procedure()
         updatePlayer1HandCardVisuals() 
         currentPhase = "PLAYER_ACTION"
         print("New turn (".. gameState.current_turn ..") started. Phase: " .. currentPhase .. ". Player 1 Mana: " .. gameState.players[1].mana)
    end
end

function love.mousepressed(mx, my, button, istouch, presses)
    if not gameState or gameState.game_over then return end

    if button == 1 then 
        if currentPhase == "PLAYER_ACTION" then
            if isPointInRect(mx, my, submitButtonRect.x, submitButtonRect.y, submitButtonRect.width, submitButtonRect.height) then
                print("Player 1 clicked Submit Button.")
                currentPhase = "SUBMITTED_BY_PLAYER"
                draggedCardInfo.card_instance = nil 
                return
            end

            updatePlayer1HandCardVisuals() 
            for i = #handCardVisuals, 1, -1 do 
                local handCardVisual = handCardVisuals[i]
                if isPointInRect(mx, my, handCardVisual.x, handCardVisual.y, handCardVisual.width, handCardVisual.height) then
                    local card_to_drag = handCardVisual.card_instance
                    if card_to_drag:get_display_cost() <= gameState.players[1].mana then
                        draggedCardInfo.card_instance = card_to_drag
                        draggedCardInfo.original_hand_idx = i 
                        draggedCardInfo.offset_x = mx - handCardVisual.x
                        draggedCardInfo.offset_y = my - handCardVisual.y
                        draggedCardInfo.current_screen_x = handCardVisual.x
                        draggedCardInfo.current_screen_y = handCardVisual.y
                        print("Dragging card: " .. draggedCardInfo.card_instance.name)
                        return 
                    else
                        print(card_to_drag.name .. " is too expensive (Cost: " .. card_to_drag:get_display_cost() .. ", Mana: " .. gameState.players[1].mana .. ")")
                    end
                end
            end
        end
    end
end

function love.mousemoved(mx, my, dx, dy, istouch)
    if draggedCardInfo.card_instance then
        draggedCardInfo.current_screen_x = mx - draggedCardInfo.offset_x
        draggedCardInfo.current_screen_y = my - draggedCardInfo.offset_y
    end
end

function love.mousereleased(mx, my, button, istouch)
    if not gameState or gameState.game_over then return end

    if button == 1 and draggedCardInfo.card_instance then
        local card_being_dragged = draggedCardInfo.card_instance
        print("Dropped card: " .. card_being_dragged.name .. " at " .. mx .. "," .. my)
        
        local successfully_placed_on_board = false
        defineLocationSlotDropZones() 

        for _, drop_zone in ipairs(locationSlotDropZones) do
            if drop_zone.player_id == gameState.players[1].id then 
                if isPointInRect(mx, my, drop_zone.x, drop_zone.y, drop_zone.width, drop_zone.height) then
                    if not gameState.locations[drop_zone.location_idx].slots[drop_zone.player_id][drop_zone.slot_idx] then
                        if gameState.players[1]:play_card_from_hand_by_instance_id(card_being_dragged.unique_id_in_game, drop_zone.location_idx, gameState) then
                            print("Successfully played " .. card_being_dragged.name .. " to Loc " .. drop_zone.location_idx .. ", Slot " .. drop_zone.slot_idx)
                            successfully_placed_on_board = true
                            updatePlayer1HandCardVisuals() 
                        else
                            print("Backend: Failed to play " .. card_being_dragged.name)
                        end
                    else
                        print("Slot " .. drop_zone.slot_idx .. " at Loc " .. drop_zone.location_idx .. " is occupied.")
                    end
                    break 
                end
            end
        end

        if not successfully_placed_on_board then
            print(card_being_dragged.name .. " returned to hand (invalid drop/play failed).")
        end
        draggedCardInfo.card_instance = nil 
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    if not gameState or gameState.game_over then return end

    if key == "space" then
        if currentPhase == "PLAYER_ACTION" then
            print("Player 1 submitted turn (SPACEBAR).")
            currentPhase = "SUBMITTED_BY_PLAYER"
            draggedCardInfo.card_instance = nil
        end
    end

    if gameState.game_over and key == "r" then
        print("Resetting game...")
        gameState = Game.new()
        gameState:setup_game()
        defineLocationSlotDropZones()
        updatePlayer1HandCardVisuals()
        currentPhase = "START_TURN"
        if gameState then
            gameState:start_turn_procedure()
            updatePlayer1HandCardVisuals()
            currentPhase = "PLAYER_ACTION"
        end
        gameMessages = {}
        print("New game started! Phase: " .. currentPhase)
    end
end

--draw
function love.draw()
    if not gameState then return end

    love.graphics.setBackgroundColor(0.12, 0.12, 0.18) 

    defineLocationSlotDropZones() 
    for _, zone_info in ipairs(locationSlotDropZones) do
        local is_p1_zone = zone_info.player_id == gameState.players[1].id
        local is_occupied = gameState.locations[zone_info.location_idx].slots[zone_info.player_id][zone_info.slot_idx] ~= nil
        
        if is_p1_zone then 
             if is_occupied then love.graphics.setColor(0.25,0.3,0.25, 0.7) else love.graphics.setColor(0.3,0.3,0.35, 0.7) end
             love.graphics.rectangle("fill", zone_info.x, zone_info.y, zone_info.width, zone_info.height)
             love.graphics.setColor(0.5,0.5,0.6, 0.8)
             love.graphics.rectangle("line", zone_info.x, zone_info.y, zone_info.width, zone_info.height)
        else 
             if is_occupied then love.graphics.setColor(0.3,0.25,0.25, 0.7) else love.graphics.setColor(0.2,0.2,0.2, 0.5) end
             love.graphics.rectangle("fill", zone_info.x, zone_info.y, zone_info.width, zone_info.height)
        end
    end
    love.graphics.setColor(1,1,1) 

    for _, zone_info in ipairs(locationSlotDropZones) do 
        local card_unique_id = gameState.locations[zone_info.location_idx].slots[zone_info.player_id][zone_info.slot_idx]
        if card_unique_id then
            local card_on_board = gameState:get_card_instance_by_id(card_unique_id)
            if card_on_board then
                CardRenderer.draw(card_on_board, zone_info.x, zone_info.y, zone_info.width, zone_info.height)
            end
        end
    end

    -- draw Player 1's Hand
    updatePlayer1HandCardVisuals() 
    for _, handCardVisual in ipairs(handCardVisuals) do
        if not (draggedCardInfo.card_instance and draggedCardInfo.card_instance.unique_id_in_game == handCardVisual.card_instance.unique_id_in_game) then
            CardRenderer.draw(handCardVisual.card_instance, handCardVisual.x, handCardVisual.y, handCardVisual.width, handCardVisual.height)
        end
    end

    -- draw dragged card
    if draggedCardInfo.card_instance then
        love.graphics.setColor(1,1,1,0.85) 
        CardRenderer.draw(draggedCardInfo.card_instance, draggedCardInfo.current_screen_x, draggedCardInfo.current_screen_y, CARD_WIDTH, CARD_HEIGHT)
        love.graphics.setColor(1,1,1,1) 
    end

    -- submit button
    if currentPhase == "PLAYER_ACTION" then
        local sb = submitButtonRect
        local mx_b, my_b = love.mouse.getPosition() -- Renamed to avoid conflict
        if isPointInRect(mx_b,my_b, sb.x, sb.y, sb.width, sb.height) then
            love.graphics.setColor(0.4, 0.8, 0.4, 0.9) else love.graphics.setColor(0.3, 0.7, 0.3, 0.9) end
        love.graphics.rectangle("fill", sb.x, sb.y, sb.width, sb.height)
        love.graphics.setColor(0.1,0.1,0.1) love.graphics.rectangle("line", sb.x, sb.y, sb.width, sb.height)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(sb.text, sb.x, sb.y + sb.height / 2 - (love.graphics.getFont():getHeight()/2) - 2, sb.width, "center")
    end
    love.graphics.setColor(1,1,1)

    -- log messages
    love.graphics.push()
    love.graphics.translate(5,5)
    love.graphics.setColor(0,0,0,0.65) 
    love.graphics.rectangle("fill", 0, 0, math.min(600, love.graphics.getWidth() - 10), (#gameMessages * 14) + 10)
    love.graphics.setColor(1,1,0.7) 
    for i, msg in ipairs(gameMessages) do love.graphics.print(msg, 5, 5 + (i-1) * 14) end
    love.graphics.pop()

    -- status text (Turn, Phase, Scores)
    local status_text_y = love.graphics.getHeight() - 130
    local p1_stat = string.format("%s (P1) - Score: %d, Mana: %d, Hand: %d", gameState.players[1].name, gameState.players[1].score, gameState.players[1].mana, #gameState.players[1].hand)
    local p2_stat = string.format("%s (P2) - Score: %d, Mana: %d, Hand: %d", gameState.players[2].name, gameState.players[2].score, gameState.players[2].mana, #gameState.players[2].hand)
    
    love.graphics.setColor(0.9,0.9,0.9)
    love.graphics.print(p1_stat, 10, status_text_y)
    love.graphics.print(p2_stat, 10, status_text_y + 20)

    local phaseMsg = "Turn: " .. gameState.current_turn .. " | Phase: " .. currentPhase
    if gameState.game_over then
        phaseMsg = phaseMsg .. "\nGAME OVER! Winner: " .. (gameState.winner and gameState.winner.name or "None") .. "\nPress [R] to Play Again."
    elseif currentPhase == "PLAYER_ACTION" then
        phaseMsg = phaseMsg .. "\nDrag cards to play. Click Submit Turn or Press SPACE."
    end
    love.graphics.printf(phaseMsg, 10, status_text_y + 40, love.graphics.getWidth() - 20, "left")
end