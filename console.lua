--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Console version 1.2.2 (26.7.2013)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- A fairly simple in-game console implementation in Love2D. Contains support
-- for input history, scrolling text, and basic interpretation at run-time.
--------------------------------------------------------------------------------
-- Notes:
-- Since the console is mainly used for debugging there isn't much optimization,
-- though it doesn't seem to be very taxing.
--
-- I would like to use the loveframes gui, but as of now the text object is 
-- total shit once its buffer starts to fill and FPS drops like crazy.
--
-- Weird issue when the display mode is changed...love seems to lose the key
-- repeat setting. Don't know of an easy way to fix it...nvm, guess it is a bug
-- in 0.8; is fixed in 0.9.
--------------------------------------------------------------------------------
-- Useage:
-- Simply require("lovebug.console") to get the console module. Next, be sure to 
-- call console.load() in love.love(), console.draw() in love.draw(), and
-- console.keypressed() in love.keypressed(). Edit the settings below to taste.
-- I thought about hooking into love's draw/load functions automagically, but
-- that isn't always desired.
-- Oh, and make sure you have the ttf file for the font you wish to use.
--------------------------------------------------------------------------------
-- The MIT License (MIT)
--
-- Copyright (c) 2013 Nicholas Campbell
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Module definition / settings
--------------------------------------------------------------------------------
local console = {}

console.fontFile = "lovebug/fonts/dejavu-fonts-ttf-2.33/ttf/DejaVuSansMono.ttf"
console.fontSize = 12
console.textColor = {255, 255, 255, 190}
console.lineSpacing = 1
console.font = love.graphics.getFont()

console.backgroundColor = {0, 0, 0, 50}

console.optionBar = true
console.optionBarBGColor = { 255, 0, 255, 90 }
console.optionBarTextColor = { 255, 255, 255, 255 }

console.inputBorderSize = 3
console.inputBorderColor = {255, 0, 255, 90}
console.prompt = "> "
console.promptIndent = 5
console.inputColor = {255, 0, 255, 50}
console.inputBuffer = ""
console.keyRepeatDelay = 0.20
console.keyRepeatInterval = 0.05
console.echoInput = true

console.historyBuffer = {}
console.historyPosition = 0

console.cursorColor = {255, 0, 255, 255}
console.cursorBlinkRate = 0.6
console.cursorPosition = 0

console.buffer = {}
console.lines = 20
console.linePosition = 0
console.textboxBB = {["x"] = 0, ["y"] = 0, ["w"] = 0, ["h"] = 0}

console.activateKey = "`"
console.vsyncKey = "f1"
console.fullscreenKey = "f2"

console.active = false

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------
local console_utils = require("lovebug.console_util")

local show = console_utils.show
local pack = console_utils.pack
local modulo = console_utils.modulo
local round = console_utils.round
local insert_char = console_utils.insert_char
local replace_char = console_utils.replace_char
local split = console_utils.split

--------------------------------------------------------------------------------
-- Local functions
--------------------------------------------------------------------------------
local function addText(str, newline, scroll)
    local t = {}
    
    if str == nil then str = "nil" end
    if newline == nil then newline = true end
    if scroll == nil then scroll = true end
    
    if newline then    
        -- Split on newline; our buffer is a table list of strings and each index is a line
        t = split(str, '\n')
        
        -- Merge text
        for i = 1, #t do
            console.buffer[#console.buffer + 1] = t[i]
        end
    else
        -- Simply concat to the last line
        console.buffer[#console.buffer] = console.buffer[#console.buffer] .. str
    end
    
    -- Optionally scroll to bottom
    local lineCount = #t or 1
    if #t == 0 then lineCount = 1 end
    if scroll or (#console.buffer - console.linePosition) == lineCount then
        console.linePosition = #console.buffer
    end
end

local function drawOptionBar(x, y, w, h)
    -- The optional text to output; change to taste
    local mode = {love.graphics.getMode() }
    local optionText = "FPS: " .. round(love.timer.getFPS(), 4) .. " | dt: " .. round(love.timer.getDelta(), 5)
    optionText = optionText .. " | (" .. console.vsyncKey .. ") vsync: " .. tostring(mode[4])
    optionText = optionText .. " | (" .. console.fullscreenKey .. ") fullscreen: " .. tostring(mode[3])
    
    -- Draw option bar background
    love.graphics.setColor(console.optionBarBGColor)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Draw optional info
    love.graphics.setColor(console.optionBarTextColor)
    love.graphics.print(optionText, x + 2, y)
end

local function drawVisibleText()
    if console.linePosition == 0 then return end
    
    local buff = console.buffer
    
    local lineHeight = console.lineSpacing + console.font:getHeight()
    local y = console.textboxBB.h -  lineHeight
    
    -- Determine endpoint; ie., how "low" into the buffer we might possibly need
    -- to go to fill the textbox using console.lines as the number of lines
    local endpoint = console.linePosition - console.lines
    if endpoint < 1 then endpoint = 1 end
    
    -- Draw each line in the buffer inside the range created by console.lines
    for line = console.linePosition, endpoint, -1 do
        if console.font:getWidth(buff[line]) <= love.graphics.getWidth() then
            -- Not going to be wrapped; simply print it at the current Y position
            love.graphics.print(buff[line], 0, y)
        else
            -- Text is gonna wrap; figure out how many lines and draw at that position
            local wrapWidth, wrapCount = console.font:getWrap(buff[line], love.graphics.getWidth())
            y = y - (lineHeight * (wrapCount - 1))
            love.graphics.printf(buff[line], 0, y, love.graphics.getWidth())           
        end
                    
        -- Increment Y
        y = y - lineHeight
    end
end

local function calculateTextboxBB()
    -- The bounding box for the text area. Height is simply the number of lines times the
    -- height of the font, plus any line spacing.
    console.textboxBB.x = 0
    console.textboxBB.y = 0
    console.textboxBB.w = love.graphics.getWidth()
    console.textboxBB.h = (console.lines * console.font:getHeight()) + (console.lines * console.lineSpacing)
end

local function drawTextbox()
    -- Recalc dimensions of textbox
    calculateTextboxBB()
    local bb = console.textboxBB
    
    -- Draw bg
    love.graphics.setColor(console.backgroundColor)
    love.graphics.rectangle("fill", bb.x, bb.y, bb.w, bb.h)
    
    -- Draw text
    love.graphics.setColor(console.textColor)
    drawVisibleText()
end

local function drawBorder(y, w, borderSize)
    -- Draw the line based on the border width
    -- https://love2d.org/forums/viewtopic.php?f=4&t=10464&p=63090
    love.graphics.setLineWidth(borderSize)
    love.graphics.setColor(console.inputBorderColor)
    love.graphics.line(0, y + (borderSize / 2), w, y + (borderSize / 2))
    love.graphics.setLineWidth(1)
end

local function drawInputArea()
    -- Info used for drawing calls. Width is always the width of the window and y is
    -- set to the height of the console's textbox area (right after where we want to draw
    -- the borders and input area).
    local y, w = console.textboxBB.h, love.graphics.getWidth()
    local borderSize = console.inputBorderSize
    local lineSpacing = console.lineSpacing

    -- Draw top border after the textbox area
    drawBorder(y, w, borderSize)
    
    -- Draw input background; height is the height of the font plus the padding
    -- from the line spacing
    local bgHeight = console.font:getHeight() + lineSpacing
    love.graphics.setColor(console.backgroundColor)
    love.graphics.rectangle("fill", 0, y + borderSize, w, bgHeight)
    
    -- Draw prompt
    local promptWidth = console.promptIndent + console.font:getWidth(console.prompt) 
    love.graphics.setColor(console.inputBorderColor)
    love.graphics.print(console.prompt, 0 + console.promptIndent, y + borderSize + lineSpacing)
    
    -- Prepare to draw input text; special case when it starts to flow offscreen
    love.graphics.setColor(console.textColor)
    local txt = console.inputBuffer
    if (promptWidth + console.font:getWidth(console.inputBuffer)) > w then
        -- Input text has to scroll; shrink the text until we get a string that will fit
        -- TODO: this is inefficient but simple. I noticed when you input large lines of
        -- text there is significant slowdown...but you probably shouldn't be doing that
        -- anyways so this isn't much of a priority.
        local pos = 1
        while (promptWidth + console.font:getWidth(txt)) > w do
            txt = string.sub(console.inputBuffer, pos)
            pos = pos + 1
        end
    end
    
    -- Draw input text
    love.graphics.print(txt, 0 + promptWidth, y + borderSize + lineSpacing)
    
    -- First, a quick and dirty hack to handle cursor blinking: basically, taking the modulus
    -- of the microtimer and the blink rate will return a float in the range of ~0 to ~blinkrate.
    -- So, if the float returned is on the bottom half of the blink rate we draw it, else not :)
    if modulo(love.timer.getTime(), console.cursorBlinkRate) <= (console.cursorBlinkRate / 2) then
        -- Draw cursor; x position is calculated using the cursor's position and the width of the
        -- string up until this position. Then the prompt width is added because of its offset.
        love.graphics.setColor(console.cursorColor)
        local cursorX = console.font:getWidth(string.sub(txt, 1, console.cursorPosition))
        local cursorY = y + borderSize + lineSpacing
        cursorX = promptWidth + cursorX
        love.graphics.line(cursorX, cursorY, cursorX, cursorY + console.font:getHeight())
    end
    
    -- Draw bottom border after input area; y set past the top border and input area
    drawBorder(y + borderSize + bgHeight, w, borderSize)
end

local function updateCursorPosition(pos)
    -- Prevent going past input text
    if pos > 0 then
        if console.cursorPosition == string.len(console.inputBuffer) then return end
    end
    
    -- Prevent negative cursor position
    if pos < 0 then
        if console.cursorPosition == 0 then return end
    end

    console.cursorPosition = console.cursorPosition + pos
end

local function updateHistoryPosition(pos)
    if (console.historyPosition + pos) < 1 then return end
    if (console.historyPosition + pos) > #console.historyBuffer then return end
    
    console.historyPosition = console.historyPosition + pos
end

local function clearInputBuffer()
    console.inputBuffer = ""
    console.cursorPosition = 0
end

local function processInputEntry()
    -- Save cmd to history and return history position to +1 past the last;
    -- may seem weird to keep an index out of bounds, but when you think about
    -- it only once you push the "up" key to scroll through the history
    -- does the indexing start.
    console.historyBuffer[#console.historyBuffer + 1] = console.inputBuffer
    console.historyPosition = #console.historyBuffer + 1
    
    -- Echo input
    if console.echoInput == true then
        addText("> " .. console.inputBuffer)
    end
    
    -- Do shit based on cmd eventually; for now, just eval simple expressions
    -- TODO: add more functionality
    -- First, try it as though it were an expression (with return)
    local func, err = loadstring("return " .. console.inputBuffer)
    
    -- If that didn't work, try as a statement on its own
    local statement = false
    if func == nil then 
        func, err = loadstring(console.inputBuffer) 
        statement = true
    end
    
    -- Function is constructed, use pcall if its valid or catch any errors
    if func ~= nil then
        local result = { pcall(func) }

        -- For statements, we acknowledge the statement; anything else display result
        if statement then
            addText("Ok.")
        else
            -- Echo any results (result[1] should always be true at this point)
            -- When certain shit is passed to pcall it'll still return true but have no results
            -- so, we just make sure we at least got something, otherwise it was just garbage input
            if #result < 2 then addText("Unable to process: " .. console.inputBuffer) end
            for i = 2, #result do
                if result[i] ~= nil then
                    addText(show(result[i]))
                end
            end
        end
    else
        addText(err)
    end
    
    -- Clear input buffer
    clearInputBuffer()
end

local function scrollText(dir)
    console.linePosition = console.linePosition + (dir * console.lines)
  
    if console.linePosition < console.lines then console.linePosition = console.lines end
    if console.linePosition > #console.buffer then console.linePosition = #console.buffer end
end

--------------------------------------------------------------------------------
-- Module functions
--------------------------------------------------------------------------------
function console.load()
    console.font = love.graphics.newFont(console.fontFile, console.fontSize)
    
    love.keyboard.setKeyRepeat(console.keyRepeatDelay, console.keyRepeatInterval)
    
    -- init the buffer to prevent nil indexing
    console.buffer[1] = ""
end

function console.draw()
    if not console.active and not console.optionBar then return end
    
    -- Preserve old font and color; enable console's
    local oldFont = love.graphics.getFont()
    love.graphics.setFont(console.font)
    local oldColor = pack(love.graphics.getColor())
    
    -- Draw option bar
    if console.optionBar and console.active then
        -- We want to draw it past the text box, then the 2 borders from the input box
        -- then, finally, the size of the text/spacing of the input box; ie., directly
        -- below all of the other shit
        local y = console.textboxBB.h + (2 * console.inputBorderSize) + (console.font:getHeight() + console.lineSpacing)
        drawOptionBar(0, y, love.graphics.getWidth(), console.font:getHeight() + console.lineSpacing)
    elseif console.optionBar and not console.active then
        -- Draw it at the top of the screen
        drawOptionBar(0, 0, love.graphics.getWidth(), console.font:getHeight() + console.lineSpacing)
    end
    
    -- Draw the actual console
    if console.active then
        drawTextbox()
        drawInputArea()
    end
    
    -- Return to previous font/color state
    if oldFont then love.graphics.setFont(oldFont) end
    love.graphics.setColor(oldColor)
end

function console.keypressed(key, unicode)
    local inputBuffer = console.inputBuffer
    local cursorPos = console.cursorPosition
    
    -- Check for activation key
    if key == console.activateKey then
        console.active = not console.active
        return
    end
    
    -- Option bar keys
    -- Note: there is a bug where the key repeat disappears after love.setMode() in <0.9.0
    if key == console.vsyncKey then
        local mode = { love.graphics.getMode() }
        mode[4] = not mode[4]
        love.graphics.setMode(unpack(mode))
        love.keyboard.setKeyRepeat(console.keyRepeatDelay, console.keyRepeatInterval)
    end
    if key == console.fullscreenKey then
        love.graphics.toggleFullscreen()
        love.keyboard.setKeyRepeat(console.keyRepeatDelay, console.keyRepeatInterval)
    end
    
    -- We only want to process these key presses if the console is active
    if console.active == false then return end

    -- Deleting input text
    if key == "backspace" and console.cursorPosition ~= 0 then
        console.inputBuffer = replace_char(inputBuffer, cursorPos, "")
        updateCursorPosition(-1)
    elseif key == "delete" then
        console.inputBuffer = replace_char(inputBuffer, cursorPos + 1, "")   
    end
    
    -- Manipulating the cursor
    if key == "right" then
        updateCursorPosition(1)
    elseif key == "left" then
        updateCursorPosition(-1)
    elseif key == "home" then
        console.cursorPosition = 0
    elseif key == "end" then
        console.cursorPosition = string.len(console.inputBuffer)
    end
    
    -- Submitting input text
    if key == "return" then
        processInputEntry()
    end
    
    -- Scrolling through history
    if key == "up" or key == "down" then
        if key == "up" then updateHistoryPosition(-1) end
        if key == "down" then updateHistoryPosition(1) end
        
        clearInputBuffer()
        
        -- Display the command in history (if available)
        if console.historyPosition <= #console.historyBuffer and
           #console.historyBuffer > 0 then
            console.inputBuffer = console.historyBuffer[console.historyPosition]
            console.cursorPosition = #console.inputBuffer
        end
    end
    
    -- Page scrolling
    if key == "pageup" then
        scrollText(-1)
    elseif key == "pagedown" then
        scrollText(1)
    end
    
    -- Handle remaining unicode strings
    if unicode then
        -- 0.9.0
        if love._version >= "0.9.0" then
            -- Convert to bytecode (integer)
            unicode = string.byte(unicode, 1)
        end
        
        -- Took this from the love.keypressed wiki entry...seems to work for English
        -- YMMV with other languages / crazy unicodeness
        if unicode > 31 and unicode < 127 then
            console.inputBuffer = insert_char(inputBuffer, cursorPos, string.char(unicode))
            updateCursorPosition(1)
        end
    end
end

-- Adds text to the console
-- newline/scroll are optional and default to true so each log of text is \n'd
-- and the console is scrolled to the bottom whenever text is added.
function console.log(str, newline, scroll)
    addText(str, newline, scroll)
end

return console