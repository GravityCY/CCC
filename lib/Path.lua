--- Title: Path
--- Description: A library for working with paths.
--- Version: 0.2.0

local String = require("lib.String");

local PathLib = {};
local PathInstance = {};

local function instanceof(obj, class)
    return type(obj) == "table" and getmetatable(obj) == class;
end

--- <b>Clean a path string.</b> <br>
--- Examples: `"hello/there/"` → `"hello/there"`.
---@param str string
---@return string
local function clean(str)
    local ret = str:gsub("\\", "/"):gsub("/+", "/");
    local slash = ret:sub(-1) == "/";
    if (slash) then ret = ret:sub(1, -2); end
    return ret;
end

--- <b>Join two or more paths.</b> <br>
--- Examples: `"hello", "there", "world.txt"` → `"hello/there/world.txt"`.
---@param topPath string|Path
---@param ... string
---@return string
function PathLib.join(topPath, ...)
    if (instanceof(topPath, PathLib)) then topPath = topPath.getAbsolutePath(); end

    local subPaths = {...};
    local ret = clean(topPath);
    for _, subPath in ipairs(subPaths) do
        ret = clean(ret .. "/" .. clean(subPath));
    end
    return ret;
end

--- <b>Get the name of a path w/ extension</b> <br>
--- Examples: `"hello/there.txt"` → `"there.txt"`.
---@param path any
---@return string
function PathLib.getFile(path)
    return PathLib.getFileName(path) .. PathLib.getFileExtension(path);
end

--- <b>Get the name of a path.</b> <br>
--- Examples: `"hello/there.txt"` → `"there"`.
---@param path string
---@return string
function PathLib.getFileName(path)
    local i = String.lastIndexOf("/", path);
    local ret = nil;
    if (i == -1) then ret = path;
    else ret = path:sub(i + 1); end

    local j = String.lastIndexOf(".", ret);
    if (j == -1) then return ret;
    else return ret:sub(1, j - 1); end
end

--- <b>Get the file extension of a path.</b> <br>
--- Examples: `"hello/there.txt"` → `"txt"`.
---@param path string
---@return string|nil
function PathLib.getFileExtension(path)
    local i = String.lastIndexOf(".", path);
    if (i == -1) then return nil; end
    return path:sub(i + 1);
end

--- <b>Get the file path of a path.</b> <br>
--- Examples: `"hello/there.txt"` → `"hello/"`.
---@param path string
---@return string
function PathLib.getFilePath(path)
    local i = String.lastIndexOf("/", path);
    if (i == -1) then return "/"; end
    return path:sub(1, i);
end

--- <b>Get the absolute path of a path.</b> <br>
--- Examples: `"hello/there.txt"` → `"disk/something/hello/there.txt"`.
---@param path any
---@return unknown
function PathLib.getAbsolutePath(path)
    return shell.resolve(path);
end

function PathLib.new(path)
    local absolute = PathLib.getAbsolutePath(path);

    ---@class Path
    local self = {
        data = {
            path = path;
            absolutePath = absolute;
            fileName = PathLib.getFileName(absolute);
            fileExtension = PathLib.getFileExtension(absolute);
            filePath = PathLib.getFilePath(absolute);
        }
    };

    self = setmetatable(self, {__index = PathInstance});
    return self;
end

--- <b>Get the absolute path of the path.</b>
---@return string
function PathInstance:getAbsolutePath()
    return self.data.absolutePath;
end

--- <b>Get the path of the path.</b>
---@return string
function PathInstance:getPath()
    return self.data.path;
end

--- <b>Get the name of the path.</b> <br>
--- Examples: `"hello/there.txt"` → `"there"`.
---@return unknown
function PathInstance:getFileName()
    return self.data.fileName;
end

--- <b>Get the file extension of the path.</b> <br>
--- Examples: `"hello/there.txt"` → `"txt"`.
---@return string
function PathInstance:getFileExtension()
    return self.data.fileExtension;
end

--- <b>Get the file path of the path.</b> <br>
--- Examples: `"hello/there.txt"` → `"hello/"`.
---@return string
function PathInstance:getFilePath()
    return self.data.filePath;
end

--- <b>Check if the path exists.</b>
---@return boolean
function PathInstance:exists()
    return fs.exists(self.data.absolutePath);
end

--- <b>Check if the path is a file.</b>
---@return boolean
function PathInstance:isFile()
    return not self:isDir();
end

--- <b>Check if the path is a directory.</b>
---@return boolean
function PathInstance:isDir()
    return fs.isDir(self.data.absolutePath);
end

--- <b>Join the path with another path.</b>
---@param joinPath string
---@return table self
function PathInstance:join(joinPath)
    return PathLib.new(self.data.absolutePath .. "/" .. joinPath);
end

---@param obj Path
---@return boolean
function PathInstance:equals(obj)
    return instanceof(obj, PathLib) and obj:getPath() == self:getPath();
end

return PathLib;