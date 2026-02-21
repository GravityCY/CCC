local Helper = require("Helper");

local Graphics = {};

local _term = term;

local tx, ty = 0, 0;
local tpx, tpy = 0, 0;

local pixelMode = false;
local pixels = {};

local function getLowHigh(a, b)
    if (a < b) then return a, b;
    else return b, a; end
end

local function valid(x, y)
    return x >= 1 and x <= tpx and y >= 1 and y <= tpy;
end

--- Sets the background color.
---@param color any
local function setBackgroundColor(color)
    local prev = _term.getBackgroundColor();
    _term.setBackgroundColor(color);
    return prev;
end

local function setTextColor(color)
    local prev = _term.getTextColor();
    _term.setTextColor(color);
    return prev;
end

local function setCursorPos(x, y)
    local px, py = _term.getCursorPos();
    _term.setCursorPos(x, y);
    return px, py;
end

local function getLetter(binary)
    local flip = bit.band(binary, 32) ~= 0;
    binary = bit.band(binary, 31);
    if (flip) then binary = 159 - binary;
    else binary = 128 + binary; end

    return string.char(binary), flip
end

local function getPixel(px, py)
    if (valid(px, py)) then return false; end
    return pixels[px][py] or false;
end

local function getGrid(x, y)
    local px, py = (x - 1) * 2 + 1, (y - 1) * 3 + 1;
    local num = 0;
    local i = 0;
    for iy = py, py + 2 do
        for ix = px, px + 1 do
            if (pixels[ix][iy]) then
                num = bit.bor(num, 2 ^ i);
            end
            i = i + 1;
        end
    end
    return num;
end

function Graphics.getSize()
    if (pixelMode) then return tpx, tpy;
    else return tx, ty; end
end

function Graphics.clear()
    pixels = Helper._arr(tpx);
    _term.clear();
    _term.setCursorPos(1, 1);
end

function Graphics.setTerm(t)
    _term = t;
    tx, ty = _term.getSize();
    tpx, tpy = tx * 2, ty * 3;

    pixels = Helper._arr(tpx);
end

function Graphics.setPixelMode(on)
    pixelMode = on;
end

function Graphics.getPixelMode()
    return pixelMode;
end

function Graphics.setPixel(px, py, on)
    local x, y = math.ceil(px / 2), math.ceil(py / 3);
    if (not valid(px, py)) then return end
    if (getPixel(px, py) == on) then return end
    pixels[px][py] = on;

    local grid = getGrid(x, y);
    local letter, flip = getLetter(grid);

    local tc, bc = _term.getTextColor(), _term.getBackgroundColor();
    local ptc = setTextColor(flip and bc or tc);
    local pbc = setBackgroundColor(flip and tc or bc);
    local pvx, pvy = setCursorPos(x, y);
    _term.write(letter);
    setCursorPos(pvx, pvy);
    setTextColor(ptc);
    setBackgroundColor(pbc);
end

function Graphics.drawPixel(x, y, color)
    if (color == nil) then color = _term.getTextColor(); end

    if (pixelMode) then
        local on = color ~= _term.getBackgroundColor();
        Graphics.setPixel(x, y, on);
    else
        local pb = setBackgroundColor(color);
        local px, py = setCursorPos(x, y);
        _term.write("\160");
        setBackgroundColor(pb);
        setCursorPos(px, py);
    end
end

function Graphics.drawThickPixel(x, y, thickness, setPixel)
    local r = math.floor(thickness / 2)
    for dx = -r, r do
        for dy = -r, r do
            Graphics.setPixel(x + dx, y + dy)
        end
    end
end

function Graphics.drawLine(x1, y1, x2, y2, thickness, color)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local error = dx - dy

    while true do
        Graphics.drawThickPixel(x1, y1, thickness, color)

        if x1 == x2 and y1 == y2 then break end

        local e2 = 2 * error
        if e2 > -dy then
            error = error - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            error = error + dx
            y1 = y1 + sy
        end
    end

end

function Graphics.drawOutline(cx, cy, xs, ys, thickness, color)
    if (thickness == nil or thickness < 1) then thickness = 1; end

    local nx, px = cx - xs, cx + xs;
    local ny, py = cy - ys, cy + ys;

    for ix = nx, px do
        for i = 0, thickness - 1 do
            Graphics.drawPixel(ix, ny - i, color);
            Graphics.drawPixel(ix, py + i, color);
        end
    end

    for iy = ny, py do
        for i = 0, thickness - 1 do
            Graphics.drawPixel(nx - i, iy, color);
            Graphics.drawPixel(px + i, iy, color);
        end
    end
end

function Graphics.drawBox(cx, cy, sx, sy, color)
    local nx, px = cx - sx, cx + sx;
    local ny, py = cy - sy, cy + sy;
    for y = ny, py do
        for x = nx, px do
            Graphics.drawPixel(x, y, color);
        end
    end
end

function Graphics.drawCircle(centerX, centerY, radius, color)
    local scalar = 1.5;
    if (pixelMode) then scalar = 1; end

    for i = 1, 360, 1 do
        local angle = i * math.pi / 180;
        local ptx = math.floor(centerX + (radius * scalar * math.cos(angle)));
        local pty = math.floor(centerY + radius * math.sin(angle));

        Graphics.drawPixel(ptx, pty, color);
    end
end

--- <b>Writes a string to the screen at the specified position.</b> <br>
--- Resets the cursor position to the previous position after the string is written.
---@param str string
---@param x integer
---@param y integer
---@param compensate boolean? **Default: True** - Whether to compensate for the terminal size.
function Graphics.writeAt(str, x, y, compensate)
    compensate = Helper._def(compensate, true);

    if (compensate) then
        if (#str <= tx) then
            if (#str + x >= tx) then x = tx - #str; end
            if (y > ty) then y = ty; end
        end
    end

    local pvx, pvy = setCursorPos(x, y);
    _term.write(str);
    setCursorPos(pvx, pvy);
end

--- <b>Writes a string to the screen and accounts for it's size.</b>
---@param str string
---@param px number A number from 0 - 1, where 0 is left and 1 is right
---@param py number A number from 0 - 1, where 0 is top and 1 is bottom
function Graphics.writePercent(str, px, py)
    local x, y = math.floor(tx * px), math.floor(ty * py);
    Graphics.writeAt(str, x, y);
end

Graphics.setTerm(term);
return Graphics;