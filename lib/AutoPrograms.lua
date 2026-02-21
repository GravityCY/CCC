local AutoPrograms = {
    BASE_URL = "https://raw.githubusercontent.com/GravityCY/CCC/refs/heads/master"
}

package.loaded["AutoPrograms"] = AutoPrograms;

function AutoPrograms.getManifest()
    if (AutoPrograms.MANIFEST ~= nil) then return AutoPrograms.MANIFEST; end
    local f = http.get(AutoPrograms.BASE_URL .. "/manifest.json");
    AutoPrograms.MANIFEST = textutils.unserializeJSON(f.readAll());
    f.close();
    return AutoPrograms.MANIFEST;
end

function AutoPrograms.fetchDirectory(repoDir)
    if (http == nil) then
        error("HTTP is disabled in ComputerCraft config!")
    end

    local manifest = AutoPrograms.getManifest();
    repoDir = repoDir:gsub("^/", "")
    repoDir = repoDir:gsub("/+$", "") .. "/"

    for _, path in ipairs(manifest.files) do
        if (path:sub(1, #repoDir) == repoDir) then
            local relative = path:sub(#repoDir + 1);

            local target = fs.combine(repoDir, relative);

            local dir = fs.getDir(target);
            if (dir ~= "" and not fs.exists(dir)) then
                fs.makeDir(dir);
            end
            
            local url = manifest.base .. path;
            print("Downloading: ", path);
            
            shell.run("wget", url, target);
        end
    end
end

function AutoPrograms.fetch(file)
    if (fs.exists(file)) then return end

    if (http == nil) then
        error("HTTP is disabled in ComputerCraft config!")
    end

    local manifest = AutoPrograms.getManifest();
    if (manifest.files[file] == nil) then return end

    local url = AutoPrograms.BASE_URL .. file

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
    local url = AutoPrograms.BASE_URL .. path

    AutoPrograms.fetch(url);

    return oldRequire(name)
end
