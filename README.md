Card Clash of the Gods 3CG Card Game
Created by Sean Massa

A LUA/LÖVE 2D implementation of a Casual Collectible Card Game (3CG) with a Greek Mythology theme. Players deploy cards to three locations, aiming to achieve a higher total power at each location to score points and win the game.

Core Gameplay
Players simultaneously play cards to their side of 3 locations (4 card slots per location per player).
Cards have a Mana cost, Power, and Text describing abilities. Mana equals the current turn number.
After players stage cards, they submit their play. Cards are revealed (priority player's cards first).
At the end of each turn, the player with more total power at a location earns points based on the difference.
The first player to reach 20 points wins.
Decks are 20 cards, max 2 copies of any card. The starting hand is 3 cards, 1 drawn each turn (including turn 1). Max hand size is 7.

1. Programming Patterns Used

Several programming patterns and principles were utilized in the development of this game's Lua codebase:

Modular Design:
 Description: The codebase is broken down into separate Lua files (modules) like `main.lua`, `game.lua`, `player.lua`, `card.lua`, `location.lua`, `renderer.lua`, and `utils.lua`. These modules are loaded using Lua's `require()` function.
 Why: This approach enhances organization, making the code easier to read, navigate, and maintain. It allows for separation of concerns (e.g., game logic vs. rendering vs. utility functions) and simplifies debugging.

Object-Oriented Principles (via Lua Tables & Metatables):
 Description: Core game entities like `Card`, `Player`, `Game`, and `Location` are implemented as Lua tables that function like classes, using metatables with `__index` to simulate inheritance or shared methods. For example, `Card.new()` acts as a constructor.
 Why: This helps encapsulate data (attributes like power, cost, hand, deck) and behavior (methods like `player:draw_card()`, `game:reveal_phase_procedure()`) related to each entity, leading to a more structured and manageable design for complex game objects.

State Pattern (Implicit for Game Phases):
 Description: The `currentPhase` variable in `main.lua` (e.g., "PLAYER_ACTION", "REVEAL", "SCORE") dictates the game's current state. The `love.update()` function and input handlers change behavior based on this variable, effectively transitioning the game through different states within a turn.
Why: This manages the complexity of the turn-based game flow, ensuring that actions and logic appropriate for the current part of the turn are executed in the correct order.

Observer Pattern (Basic for Card Abilities):
 Description: Card abilities like `ability_on_reveal` or `ability_on_end_of_turn` are essentially callback functions associated with card instances. The game logic (e.g., in `Game:reveal_phase_procedure()`) "notifies" or calls these functions when specific game events occur (like a card being revealed or the turn ending).
Why: This decouples the core game event processing from the specific logic of individual card abilities, making it easier to add new cards and abilities without modifying the central game loop extensively.

Singleton (Implicit for `gameState`):
Description: The `gameState` variable in `main.lua`, which holds the instance of the `Game` class, acts as a global access point for the current game session's state.
Why: Provides easy and consistent access to the overall game state (players, locations, current turn, etc.) from various parts of the LÖVE 2D application, particularly in `love.update()`, `love.draw()`, and input handling functions.

Factory Method (Basic for Card Creation):**
 Description: The `Card.new()` function acts as a constructor or a simple factory method. The `Player:create_deck()` method uses `Card.new()` to produce card instances based on definitions stored in `_G.CARD_DATABASE`.
 Why: Centralizes the logic for creating and initializing card objects, ensuring consistency.

2. Feedback 

Source 1: Ashton Gallistel
Feedback Provided: "In an early version of the game I had the controls set via keyboard bindings, Ashton mentioned that the initial keyboard controls for selecting and playing cards felt a bit unintuitive for a card game, and drag-and-drop would feel more natural."
Adjustments Made: This feedback was a strong motivator to prioritize the mouse-driven interface. I focused on implementing the `love.mousepressed`, `love.mousemoved`, and `love.mousereleased` callbacks in `main.lua` to allow players to visually drag cards from their hand to location slots, significantly improving the game's interactivity as per the rubric.

Source 2: Kenshin Chao
Feedback Provided:
Initial game logic was monolithic; suggested refactoring into separate Lua modules for better organization (ex., `card.lua`, `player.lua`, `game.lua`).
Pointed out issues with `require` paths when transitioning to a flat file structure.
Provided an idea for the mouse-driven input (drag-and-drop) to replace initial keyboard-based simulation.
Adjustments Made:
The entire codebase was refactored into the suggested modular structure, significantly improving readability and maintainability. 
`main.lua` was extensively updated to incorporate LÖVE 2D's mouse event callbacks for card interaction.
Card ability functions in `card.lua` and deck creation logic in `player.lua` were implemented/revised based on the guidance.

Source 3: Tommy Nguyen
Feedback Provided: After early playtest , it was clear that understanding what was happening each turn was difficult. Scores weren't changing as expected, and it wasn't obvious if cards were being played or revealed correctly.
Adjustments Made:Implemented a more robust on-screen logging system by overriding `print()` in `main.lua` to display game events. Also improved the text-based board state display in `game.lua` (within `get_simple_board_state_text()`) to show card reveal status (`is_revealed`) and handle nil card data more gracefully. This was crucial for debugging why scores weren't updating and identifying that cards weren't being revealed correctly in earlier iterations.

3. Postmortem

What Went Well:
The core game logic for turns, mana progression, playing cards from hand, and basic scoring was successfully established in Lua.
Refactoring the code into Lua modules early on (based on feedback) made development much more manageable, especially when debugging or adding new features like mouse controls.
The state-based phase management (`currentPhase` in `main.lua`) provided a clear and effective structure for controlling the flow of each turn.
The foundation for card abilities (using functions within `_G.CARD_DATABASE`) is in place and allows for relatively straightforward expansion with new card effects.
Successfully transitioned from placeholder keyboard inputs to a more user-friendly mouse-driven drag-and-drop interface.

What I Would Do Differently Next Time:
 Earlier Visual UI Prototyping: I would set up basic visual representations for cards and UI interactions (even with simple rectangles) much earlier in the LÖVE 2D development process. Relying heavily on console logs and text-based board states for debugging UI-heavy interactions like drag-and-drop was less efficient than it could have been.
More Robust UI State Management: For features like card dragging, a more formal approach to managing UI state (perhaps a small UI state machine or dedicated UI components) could have made the `main.lua` cleaner than using several global-like variables (e.g., `draggedCardInfo`).
Incremental Testing of Card Abilities: While some abilities were tested, a more rigorous approach of testing each new card ability in isolation or with specific test cases could have caught subtle bugs faster than full game playthroughs.
Component-Based Approach for Card Abilities: While the current function-based abilities work, a more component-based approach for card abilities (where abilities are attachable components to a base card entity) could offer greater flexibility and reusability for very complex cards in a larger game. For this project's scale, the current method is adequate.

4. Assets List

I created the card art for the back of the cards using Piskel. Stretch goal to make the face art for the rest of the cards

UI Elements (Buttons, Backgrounds, etc.)
Currently drawn with basic `love.graphics` shapes. Custom images would enhance the UI.

Sound Effects (SFX) & Music:
Stretch Goal to add music



