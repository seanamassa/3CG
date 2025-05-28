-- renderer.lua

local CardRenderer = {}

CardRenderer.assets = {
    card_back_image = nil,
    card_face_image = nil, -- Optional: a template image for the card face
    font_title = nil,
    font_stats = nil,
    font_text = nil,
    loaded = false
}

-- Default card dimensions (you can adjust these)
CardRenderer.defaultWidth = 100
CardRenderer.defaultHeight = 150

function CardRenderer.loadAssets()
    if CardRenderer.assets.loaded then return end

    -- Load fonts (adjust paths and sizes as needed)
    -- Using a default font if specific ones aren't available for simplicity
    pcall(function() CardRenderer.assets.font_title = love.graphics.newFont("assets/fonts/your_title_font.ttf", 16) end)
    if not CardRenderer.assets.font_title then CardRenderer.assets.font_title = love.graphics.newFont(16) end -- Fallback

    pcall(function() CardRenderer.assets.font_stats = love.graphics.newFont("assets/fonts/your_stats_font.ttf", 14) end)
    if not CardRenderer.assets.font_stats then CardRenderer.assets.font_stats = love.graphics.newFont(14) end

    pcall(function() CardRenderer.assets.font_text = love.graphics.newFont("assets/fonts/your_text_font.ttf", 10) end)
    if not CardRenderer.assets.font_text then CardRenderer.assets.font_text = love.graphics.newFont(10) end

    -- Load images (replace with your actual asset paths)
    local success_back, err_back = pcall(function()
        CardRenderer.assets.card_back_image = love.graphics.newImage("assets/images/card_back.png")
    end)
    if not success_back then
        print("Warning: Could not load card_back.png: " .. tostring(err_back))
    end

    local success_face, err_face = pcall(function()
        -- CardRenderer.assets.card_face_image = love.graphics.newImage("assets/images/card_face_template.png")
        -- If you have a template image. If not, we'll just draw colored rectangles.
    end)
    if not success_face and CardRenderer.assets.card_face_image then -- only print error if it was expected
        print("Warning: Could not load card_face_template.png: " .. tostring(err_face))
    end


    CardRenderer.assets.loaded = true
    print("CardRenderer assets loaded.")
end

-- Main drawing function
-- card_obj: The card object from your game logic
-- x, y: Top-left coordinates to draw the card
-- w, h: Optional width and height, defaults to CardRenderer.defaultWidth/Height
function CardRenderer.draw(card_obj, x, y, w, h)
    if not CardRenderer.assets.loaded then
        CardRenderer.loadAssets() -- Ensure assets are loaded
    end

    local width = w or CardRenderer.defaultWidth
    local height = h or CardRenderer.defaultHeight

    love.graphics.push()
    love.graphics.translate(x, y)

    -- Draw card outline/background
    love.graphics.setColor(0.8, 0.8, 0.8) -- Light grey for card background
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setColor(0, 0, 0) -- Black for outline
    love.graphics.rectangle("line", 0, 0, width, height)


    if not card_obj.is_revealed then
        -- Draw Card Back
        if CardRenderer.assets.card_back_image then
            love.graphics.setColor(1, 1, 1) -- White tint for the image
            love.graphics.draw(CardRenderer.assets.card_back_image, 0, 0, 0, width / CardRenderer.assets.card_back_image:getWidth(), height / CardRenderer.assets.card_back_image:getHeight())
        else
            -- Fallback if no image: simple pattern or color
            love.graphics.setColor(0.3, 0.3, 0.7) -- Blueish
            love.graphics.rectangle("fill", 5, 5, width - 10, height - 10)
            love.graphics.setColor(1,1,1)
            love.graphics.setFont(CardRenderer.assets.font_title or love.graphics.getFont())
            love.graphics.printf("CARD BACK", 0, height / 2 - 10, width, "center")
        end
    else
        -- Draw Card Face
        if CardRenderer.assets.card_face_image then
             love.graphics.setColor(1, 1, 1)
            love.graphics.draw(CardRenderer.assets.card_face_image, 0, 0, 0, width / CardRenderer.assets.card_face_image:getWidth(), height / CardRenderer.assets.card_face_image:getHeight())
        else
            -- Simple colored sections if no face template
            love.graphics.setColor(1, 1, 0.9) -- Creamy face
            love.graphics.rectangle("fill", 2, 2, width - 4, height - 4)
        end

        love.graphics.setColor(0, 0, 0) -- Black for text

        -- Card Name
        local currentFont = CardRenderer.assets.font_title or love.graphics.getFont()
        love.graphics.setFont(currentFont)
        love.graphics.printf(card_obj.name or "N/A", 5, 5, width - 10, "center")
        local textHeight = currentFont:getHeight()

        -- Cost
        currentFont = CardRenderer.assets.font_stats or love.graphics.getFont()
        love.graphics.setFont(currentFont)
        love.graphics.print("Cost: " .. (card_obj:get_display_cost() or "N/A"), 5, textHeight + 5)

        -- Power
        love.graphics.print("Pow: " .. (card_obj:get_display_power() or "N/A"), width - 45, textHeight + 5) -- Adjust position
        textHeight = textHeight + currentFont:getHeight() + 5


        -- Placeholder for Card Art (a simple rectangle for now)
        local artX, artY, artW, artH = 5, textHeight + 10, width - 10, (height / 2) - 20
        love.graphics.setColor(0.7, 0.7, 0.7) -- Grey box for art
        love.graphics.rectangle("fill", artX, artY, artW, artH)
        love.graphics.setColor(0,0,0)
        love.graphics.setFont(CardRenderer.assets.font_text or love.graphics.getFont())
        love.graphics.printf("[Card Art]", artX, artY + artH/2 - 5 , artW, "center")
        textHeight = artY + artH

        -- Card Text/Ability Description
        currentFont = CardRenderer.assets.font_text or love.graphics.getFont()
        love.graphics.setFont(currentFont)
        love.graphics.setColor(0,0,0)
        love.graphics.printf(card_obj.text or "", 5, textHeight + 10, width - 10, "left")
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1) -- Reset color
end

return CardRenderer