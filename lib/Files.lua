--- Title: Files
--- Description: A library for working with files.
--- Version: 0.1.0

local Path = require("Path");
local Logger = package.loaded["Logger"];
local Helper = require("Helper");

local NAMESPACE = "files";
-- local LOGGER = Logger.get(NAMESPACE);

local Files = {};

--- <b>Rename a file to a new name</b> <br>
--- `to` can be in a special format in order to create a new name if a file at `to` already exists. <br>
--- For example: `to` can be like so; `"hello{-%s}.txt"` which will iteratively check for `hello.txt`, `hello-1.txt`, `hello-2.txt`, etc.
---@param from string
---@param to string
function Files.rename(from, to)
    local isFormat = to:find("{.+}");
    if (isFormat ~= nil) then
        -- LOGGER.debug("User specified format: '%s'", to);
        local formatString = to:match("{(.+)}");

        local first, last = Helper.splitPattern(to, "{.+}");
        local newPath = first .. last;
        if (fs.exists(newPath)) then
            local i = 1;
            while true do
                newPath = first..formatString:format(i)..last;
                if (fs.exists(newPath)) then i = i + 1;
                else break; end
            end
        end
        -- LOGGER.debug("Renaming '%s' to '%s'", from, newPath);
        fs.move(from, newPath);
    else
        local newPath = to;
        if (fs.exists(newPath)) then
            local dotIndex = Helper.lastIndexOf(".", to);
            local first, last = Helper.splitIndex(to, dotIndex);
            local i = 1;
            while true do
                newPath = first.."-"..i.."."..last;
                if (fs.exists(newPath)) then i = i + 1;
                else break; end
            end
        end
        -- LOGGER.debug("Renaming '%s' to '%s'", from, newPath);
        fs.move(from, newPath);
    end
end

--- <b>Copy a file</b> <br>
--- Overwrites existing file
---@param fromPath string
---@param toPath string
---@return boolean
function Files.copy(fromPath, toPath)
    if (not fs.exists(fromPath)) then return false; end
    if (fs.exists(toPath)) then fs.delete(toPath); end
    fs.copy(fromPath, toPath);
    return true;
end

--- <b>Copy all files in a list to a path</b> <br>
--- Example: `Files.copyAll({"path/to/file1", "path/to/file2"}, "path/to/output")` <br>
--- Output: `/path/to/output/file1`, `/path/to/output/file2`
---@param fromPathList table
---@param toPath string
function Files.copyAll(fromPathList, toPath)
    for _, path in ipairs(fromPathList) do
        local file = Path.getFile(path);
        local outPath = Path.join(toPath, file);
        Files.copy(path, outPath);
    end
end

function Files.copyAllS(fromPathList, toPathList)
    local fit = Helper.ipairs(fromPathList);
    local tit = Helper.ipairs(toPathList);
    while (true) do
        local fromPath = fit();
        local toPath = tit();
        if (toPath == nil) then break end
        Files.copy(fromPath, toPath);
    end
end

--- <b>Read lines from a file</b>
---@param pathString string
---@return table|nil
function Files.readLines(pathString)
    if (not fs.exists(pathString)) then return nil; end
    local lines = {};
    local f = fs.open(pathString, "r");
    while true do
        local line = f.readLine();
        if (line == nil) then break end
        table.insert(lines, line);
    end
    return lines;
end

return Files;