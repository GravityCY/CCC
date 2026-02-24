local Installer = {
    BASE_URL = "https://raw.githubusercontent.com/GravityCY/CCC/refs/heads/master"
}

package.loaded["Installer"] = Installer;

function Installer.getManifest()
    if (Installer.MANIFEST ~= nil) then return Installer.MANIFEST; end
    local f = http.get(Installer.BASE_URL .. "/manifest.json");
    Installer.MANIFEST = textutils.unserializeJSON(f.readAll());
    f.close();
    return Installer.MANIFEST;
end

function Installer.fetchDirectory(repoDir)
    if (http == nil) then
        error("HTTP is disabled in ComputerCraft config!")
    end

    local manifest = Installer.getManifest();
    repoDir = repoDir:gsub("^/", "")
    repoDir = repoDir:gsub("/+$", "") .. "/"

    for _, path in ipairs(manifest.files) do
        if (path:sub(1, #repoDir) == repoDir) then
            Installer.fetch(path);
        end
    end
end

function Installer.fetch(file)
    if (fs.exists(file)) then return end

    if (http == nil) then
        error("HTTP is disabled in ComputerCraft config!")
    end

    local manifest = Installer.getManifest();
    if (manifest.files[file] == nil) then return end

    local url = Installer.BASE_URL .. file

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
    local url = Installer.BASE_URL .. path

    Installer.fetch(url);

    return oldRequire(name)
end

local function isRequired(args)
    return #args == 2 and type(package.loaded[args[1]]) == "table" and not next(package.loaded[args[1]]);
end

if (not isRequired(...)) then
    Installer.fetch(...);
end