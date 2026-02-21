local Loggy = require("Loggy");
local Path = require("Path");
local Identifier = require("Identifier")
local Helper = require("Helper");
local Std = require("Std");

-- TODO: Redesign so that Language is a Global Instance, that anyone can access, without needing to create a language instance per user

local NAMESPACE = "language";
local LOGGER = Loggy.get(NAMESPACE);

local PATH = Std.getAndMakeDirectory("language");
local Language = {};

local current = "en";

---@type table<string, LanguageNamespace>
local cache = {};

function Language.getLanguages(namespace)
    local translationList = {};
    local path = Path.join(PATH, namespace);
    if (not fs.exists(path)) then return translationList; end

    for _, file in ipairs(fs.list(path)) do
        local name = Path.getFileName(file);
        table.insert(translationList, name);
    end
    return translationList;
end

function Language.loadAll(namespace)
    local translationMap = {};
    local translationList = Language.getLanguages(namespace);
    if (translationList == nil) then return translationMap; end

    for _, name in ipairs(translationList) do
        translationMap[name] = Language.load(name);
    end
    return translationMap;
end

function Language.load(namespace, lang)
    local path = Path.join(PATH, namespace, lang .. ".json");
    if (not fs.exists(path)) then return {}; end
    LOGGER.debug("Loading language '%s:%s'", namespace, path);
    return Helper.loadJSON(path);
end

function Language.save(namespace, translations, lang)
    local path = Path.join(PATH, namespace, lang .. ".json");
    LOGGER.debug("Saving language '%s:%s'", namespace, path);
    Helper.saveJSON(path, translations);
end

--- <b>Checks if a language exists for all namespaces.</b>
---@param lang string
---@return boolean
function Language.isValid(lang)
    for namespace, instance in pairs(cache) do
        if (instance.isValid(lang)) then
            return true;
        end
    end
    return false;
end

--- <b>Sets the current language.</b>
---@param lang string
function Language.setLanguage(lang)
    current = lang;
    LOGGER.debug("Language set to '%s'", current);
    for namespace, instance in pairs(cache) do
        instance.setLanguage(current);
    end
end

--- <b>Returns a translated string.</b>
---@param namespace string eg. "music_player"
---@param path string eg. "song_name"
---@param ... string
---@return string
function Language.get(namespace, path, ...)
    LOGGER.debug("Getting '%s:%s'", namespace, path);
    return Language.getNamespace(namespace).get(path, ...);
end

--- <b>Returns a translated string.</b>
---@param key string eg. "music_player:song_name"
---@param ... string
---@return string
function Language.getKey(key, ...)
    local namespace = Identifier.getNamespace(key);
    local path = Identifier.getPath(key);
    return Language.get(namespace, path, ...);
end

--- <b>Returns a translated string.</b>
---@param id Identifier
---@param ... string
---@return string
function Language.getID(id, ...)
    return Language.get(id.namespace, id.path, ...);
end

--#region Utility

--- <b>Prints a translated string.</b>
---@param namespace string
---@param path string
---@param ... string
function Language.print(namespace, path, ...)
    print(Language.get(namespace, path, ...));
end

--- <b>Prints a translated string.</b>
---@param key string
---@param ... string
function Language.printKey(key, ...)
    print(Language.getKey(key, ...));
end

--- <b>Prints a translated string.</b>
---@param id Identifier
---@param ... string
function Language.printID(id, ...)
    print(Language.get(id.namespace, id.path, ...));
end

--- <b>Writes a translated string.</b>
---@param key string
---@param ... string
function Language.write(key, ...)
    write(Language.getKey(key, ...));
end

--- <b>Writes a translated string.</b>
---@param key string
---@param ... string
function Language.writeKey(key, ...)
    write(Language.getKey(key, ...));
end

--- <b>Writes a translated string.</b>
---@param id Identifier
---@param ... string
function Language.writeID(id, ...)
    write(Language.get(id.namespace, id.path, ...));
end

--#endregion

--- <b>Returns a language namespace instance.</b>
---@param namespace string
---@return LanguageNamespace
function Language.getNamespace(namespace)
    if (cache[namespace] ~= nil) then return cache[namespace]; end

    ---@class LanguageNamespace
    local self = {};

    local namespaceMap = {};
    ---@type table<string, string>
    local currentLanguageMap = {};
    local languageList = Language.getLanguages(namespace);

    --- <b>Get translations for a language.</b>
    ---@param lang string
    ---@return table<string, string>
    function self.getLanguage(lang)
        return namespaceMap[lang];
    end

    --- <b>Checks if a language is loaded.</b>
    ---@param lang string
    ---@return boolean
    function self.isLoaded(lang)
        return self.getLanguage(lang) ~= nil;
    end

    --- <b>Checks if a language exists for this namespace.</b>
    ---@param lang string
    ---@return boolean
    function self.isValid(lang)
        for _, name in ipairs(languageList) do
            if (name == lang) then return true; end
        end
        return false;
    end

    --- <b>Sets the current language.</b>
    ---@param lang string
    function self.setLanguage(lang)
        if (not self.isValid(lang)) then currentLanguageMap = {}; return end

        if (not self.isLoaded(lang)) then self.load(lang); end
        currentLanguageMap = self.getLanguage(lang);
    end

    --- <b>Returns the list of available languages.</b>
    ---@return table
    function self.getLanguages()
        return languageList;
    end

    --- <b>Loads a language.</b>
    ---@param lang string
    function self.load(lang)
        namespaceMap[lang] = Language.load(namespace, lang);
    end

    --- <b>Loads all languages.</b>
    function self.loadAll()
        namespaceMap = Language.loadAll(namespace);
    end

    --- <b>Gets a translation.</b>
    ---@param key string
    ---@param ... string
    ---@return string
    function self.get(key, ...)
        if (currentLanguageMap == nil or currentLanguageMap[key] == nil) then return namespace .. ":" .. key; end
        return currentLanguageMap[key]:format(...);
    end

    self.setLanguage(current);
    cache[namespace] = self;
    return self;
end

return Language