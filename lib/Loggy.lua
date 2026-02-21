local Files = require("Files")
local Path = require("Path")
local Helper = require("Helper");

local Loggy = {};

local loggerMap = {};

local LogHandlerList = {};
local PrintLogHandler = {};
local FileLogHandler = {};

function LogHandlerList.new(...)
    local self = {};
    local handlers = {...};

    function self.add(...)
        for _, handler in ipairs({...}) do
            table.insert(handlers, handler);
        end
        return self;
    end

    function self.print(message)
        for _, handler in ipairs(handlers) do
            handler.print(message);
        end
    end
    return self;
end

function PrintLogHandler.new()
    local self = {};

    function self.print(message)
        print(message);
    end

    return self;
end

function FileLogHandler.new(dest, keepOld)
    local self = {};
    local f = nil;

    --- <b>Sets the path of the log file</b>
    ---@param path string
    function self.setPath(path)
        dest = path;
        if (f ~= nil) then f.close(); end
        f = fs.open(dest, "w");
        return self;
    end

    function self.print(message)
        if (f == nil) then return end

        f.writeLine(message);
        f.flush();
    end

    if (keepOld and fs.exists(dest)) then
        local path = Path.getFilePath(dest);
        local name = Path.getFileName(dest);
        local ext = Path.getFileExtension(dest);
        local date = os.date("%d-%m-%Y");
        local new = Path.join(path, date.."-"..name.."{-%d}."..ext);
        Files.rename(dest, new);
    end

    self.setPath(dest);
    return self;
end

Loggy.LogHandlerList = LogHandlerList;
Loggy.PrintLogHandler = PrintLogHandler;
Loggy.FileLogHandler = FileLogHandler;

local HANDLER = PrintLogHandler.new();
local MESSAGE_FORMATTER = function(level, namespace, message, ...)
    return ("(%s) %s: %s"):format(level, namespace, message:format(...));
end;
local IS_DEBUG = false;

function Loggy.setHandler(handler)
    HANDLER = handler;
    return Loggy;
end

function Loggy.setDebug(debug)
    IS_DEBUG = debug;
    return Loggy;
end

function Loggy.setDebugTo(namespace, debug)
    if (loggerMap[namespace] ~= nil) then loggerMap[namespace].setDebug(debug); end
    return Loggy;
end

function Loggy.setFormatter(format)
    MESSAGE_FORMATTER = format;
    return Loggy;
end

function Loggy.get(namespace)
    if (loggerMap[namespace] ~= nil) then return loggerMap[namespace]; end

    local self = {};

    local isDebug = IS_DEBUG;

    function self.setDebug(debug)
        isDebug = debug;
        return self;
    end

    function self.log(level, message, ...)
        if (level == nil) then level = "NORMAL"; end
        HANDLER.print(MESSAGE_FORMATTER(level, namespace, message, ...));
    end

    function self.info(message, ...)
        self.log("INFO", message, ...);
    end

    function self.debug(message, ...)
        if (not isDebug) then return end
        self.log("DEBUG", message, ...);
    end

    loggerMap[namespace] = self;
    return self;
end

return Loggy;