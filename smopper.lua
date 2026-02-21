local AutoPrograms = {
    BASE_URL = "https://raw.githubusercontent.com/GravityCY/CCC/refs/heads/master"
}

function AutoPrograms.fetch(file, place)
    if (fs.exists(file)) then return end
    local url = AutoPrograms.BASE_URL .. file

    if (not http) then
        error("HTTP is disabled in ComputerCraft config!")
    end

    local response = http.get(url)
    if (not response) then
        error("Failed to download module from: " .. url)
    end

    local content = response.readAll()
    response.close()

    -- Save file locally
    local dir = fs.getDir(file)
    if (dir ~= "" and not fs.exists(dir)) then
        fs.makeDir(dir)
    end

    local f = fs.open(file, "w")
    f.write(content)
    f.close()

    print("Downloaded '" .. fs.getName(file) .. "' successfully.")
end

package.loaded["AutoPrograms"] = AutoPrograms;

local oldRequire = require

function require(name)
    -- Try normal require first
    local ok, result = pcall(oldRequire, name)
    if ok then
        return result
    end

    -- If it fails, try downloading
    print("Module '" .. name .. "' not found. Attempting download...")

    local path = name:gsub("%.", "/") .. ".lua"
    local url = BASE_URL .. path

    if not http then
        error("HTTP is disabled in ComputerCraft config!")
    end

    local response = http.get(url)
    if not response then
        error("Failed to download module from: " .. url)
    end

    local content = response.readAll()
    response.close()

    -- Save file locally
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local file = fs.open(path, "w")
    file.write(content)
    file.close()

    print("Downloaded '" .. name .. "' successfully.")

    -- Try requiring again
    return oldRequire(name)
end

local EasyAddress = require("lib.EasyAddress");