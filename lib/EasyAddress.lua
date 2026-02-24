local Language = require("lib.Language");
local Identifier = require("lib.Identifier");
local Helper = require("lib.Helper")
local Ask = require("lib.Ask");
local Graphics = require("lib.Graphics")
local Std = require("lib.Std");

local EasyAddress = {};

local Installer = package.loaded["Installer"];
if (Installer ~= nil and not fs.exists("/data/language/easy_address")) then
    Installer.fetchDirectory("/data/language/easy_address");
end

--- Everytime you connect a peripheral do you want to confirm the address? (y/n):
local SHOULD_CONFIRM_KEY = "easy_address:message.should_confirm";
--- Select one of the following: 
local SELECT_MULTIPLE_KEY = "easy_address:message.select_multiple";
--- Additional Information is Available:
local DESC_KEY = "easy_address:message.desc_info";
--- '%s'
local DESC_VALUE_KEY = "easy_address:message.desc_value";

--- Please enable the peripheral '%s'...;
local WAIT_KEY = "easy_address:message.wait_one";
--- Are you sure you want to set the peripheral '%s' as '%s'? (y/n):
local CONFIRM_ADDRESS_KEY = "easy_address:message.confirm_address";

--- Please enable a peripheral in the category of '%s'...
local WAIT_LIST_KEY = "easy_address:message.wait_list";
--- Found multiple peripherals, do you want to add them all? (y/n):
local CONFIRM_ADD_ALL_KEY = "easy_address:message.confirm_add_all";
--- Found multiple peripherals, do you want to remove them all? (y/n):
local CONFIRM_REMOVE_ALL_KEY = "easy_address:message.confirm_remove_all";
--- Are you sure you want to add '%s' to '%s'? (y/n):
local CONFIRM_ADD_ADDRESSES_KEY = "easy_address:message.confirm_add_addresses";
--- Are you sure you want to remove '%s' from '%s'? (y/n):
local CONFIRM_REMOVE_ADDRESSES_KEY = "easy_address:message.confirm_remove_addresses";
--- Added '%s' to '%s'
local ADD_KEY = "easy_address:message.added";
--- Removed '%s' from '%s'
local REMOVE_KEY = "easy_address:message.removed";
--- Press Enter when done.
local PRESS_DONE_KEY = "easy_address:message.press_done";
--- Are you sure you want to exit? (y/n):
local CONFIRM_EXIT_KEY = "easy_address:message.confirm_exit";

local PATH = Std.getAndMakeDirectory("easy_address");

local function getArgs(args)
    local addrs = {};
    for i, v in ipairs(args) do
        table.insert(addrs, v[2]);
    end
    return addrs;
end

local function pullMultiple(event)
    local eventArgs = Helper.pullRepeat(event);
    return getArgs(eventArgs);
end

local function pullAny(...)
    local name, eventArgs = Helper.pullMultiple(...);
    return name, getArgs(eventArgs);
end

--- <b>Loads an address translation table.</b>
---@param namespace string
---@return table
function EasyAddress.load(namespace)
    local fpath = PATH .. namespace .. ".luaj";
    if (not fs.exists(fpath)) then return {}; end
    local f = fs.open(fpath, "r");
    local text = f.readAll();
    f.close();
    return textutils.unserialise(text);
end

--- <b>Saves an address translation table.</b>
---@param namespace string
---@param translations table
function EasyAddress.save(namespace, translations)
    local fpath = PATH .. namespace .. ".luaj";
    fs.makeDir(PATH);
    local f = fs.open(fpath, "w");
    f.write(textutils.serialise(translations));
    f.close();
end

--- <b>Waits for an peripheral to be enabled.</b>
---@param name string
---@param description string|nil
---@return string
function EasyAddress.wait(name, description)

    --- <b>Before we block the thread, we need to clear the terminal, and print some info.</b>
    local function ui_waiting()
        term.clear();
        term.setCursorPos(1, 1)
        Language.printKey(WAIT_KEY, name);
        if (description) then
            Language.printKey(DESC_KEY);
            Language.printKey(DESC_VALUE_KEY, description:format(name));
        end
    end

    --- <b>When we receive the address list of peripherals enabled, we return an address from that list</b>
    ---@param addressList string[]
    ---@return boolean success Whether the user confirmed the address
    ---@return string|nil address The address of the peripheral
    local function ui_received(addressList)
        local addr = addressList[1];
        if (#addressList > 1) then
            Language.write(SELECT_MULTIPLE_KEY);
            local x, y = term.getCursorPos();
            local ey;
            print();
            for i, a in ipairs(addressList) do
                print(i .. ": '" .. a .. "'");
                _, ey = term.getCursorPos();
            end
            term.setCursorPos(x, y);
            local index = tonumber(read());
            term.setCursorPos(1, ey);
            addr = addressList[index];
        end
        Language.printKey(CONFIRM_ADDRESS_KEY, addr, name);
        local confirm = read():lower();
        if (confirm == "y") then return true, addr; end
        return false;
    end

    while true do
        ui_waiting();
        local addrs = pullMultiple("peripheral");
        local success, addr = ui_received(addrs);
        if (success) then return addr; end
    end
end

--- <b>Waits for an peripheral to be enabled.</b>
---@param name string
---@param description string|nil
---@return string[]
function EasyAddress.waitList(name, description, list)
    list = list or {};

    local ret = Helper.copy(list);
    local pause = false;

    local confirm = true;

    local speaker = peripheral.find("speaker") or {playNote = function() end};

    --- <b>Before we block the thread, we need to clear the terminal, and print some info.</b>
    local function onShowWaiting()
        Language.printKey(WAIT_LIST_KEY, name);
        if (description ~= nil) then
            Language.printKey(DESC_KEY);
            Language.printKey(DESC_VALUE_KEY, description:format(name));
        end
        Graphics.writePercent(Language.getKey(PRESS_DONE_KEY), 1, 1);
    end

    --- <b>When we receive the address list of peripherals enabled, we return an address from that list</b>
    ---@param addressList string[]
    ---@return string[] address The address of the peripheral
    local function onShowFilter(isAdd, addressList)
        local key = nil;
        if (isAdd) then key = CONFIRM_ADD_ALL_KEY;
        else key = CONFIRM_REMOVE_ALL_KEY; end

        if (#addressList > 1) then
            if (Ask.ask(Language.getKey(key), Ask.yesNo())) then
                return addressList;
            else
                Language.writeKey(SELECT_MULTIPLE_KEY)
                local x, y = term.getCursorPos();
                local ey;
                print();
                for i, a in ipairs(addressList) do
                    print(i .. ": '" .. a .. "'");
                    _, ey = term.getCursorPos();
                end
                term.setCursorPos(x, y);
                local index = tonumber(read());
                term.setCursorPos(1, ey);
                return {addressList[index]};
            end
        else return {addressList[1]}; end
    end

    local function toggleKeyInput()
        pause = not pause;
    end

    local function keyThread()
        while true do
            if (not pause) then
                sleep(0.25);
                local event, key = os.pullEvent("key_up");
                if (key == keys.enter) then
                    if (Ask.ask(Language.getKey(CONFIRM_EXIT_KEY), Ask.yesNo())) then
                        break;
                    end
                end
            end
            sleep(0.25);
        end
    end

    local function peripheralThread()
        term.clear();
        term.setCursorPos(1, 1);
        onShowWaiting();
        while true do
            local event, addrs = pullAny("peripheral", "peripheral_detach");
            local isAdd = nil;
            if (event == "peripheral") then isAdd = true;
            elseif (event == "peripheral_detach") then isAdd = false; end

            toggleKeyInput();
            if (isAdd) then
                local toRemove = {};
                for _, addr in ipairs(addrs) do
                    if (Helper.contains(ret, addr)) then
                        table.insert(toRemove, addr);
                    end
                end
                for _, addr in ipairs(toRemove) do
                    Helper.remove(addrs, addr);
                end
            else
                local toRemove = {};
                for _, addr in ipairs(addrs) do
                    if (not Helper.contains(ret, addr)) then
                        table.insert(toRemove, addr);
                    end
                end
                for _, addr in ipairs(toRemove) do
                    Helper.remove(addrs, addr);
                end
            end

            local filteredAddrs = nil;
            if (confirm) then filteredAddrs = onShowFilter(isAdd, addrs);
            else filteredAddrs = addrs; end

            toggleKeyInput();
            if (event == "peripheral") then
                for index, addr in ipairs(filteredAddrs) do
                    if (not Helper.contains(ret, addr)) then
                        speaker.playNote("harp", 1, 1);
                        Language.printKey(ADD_KEY, addr, name);
                        Helper.add(ret, addr);
                    end
                end
            elseif (event == "peripheral_detach") then
                for index, addr in ipairs(filteredAddrs) do
                    if (Helper.contains(ret, addr)) then
                        speaker.playNote("bass", 1, 12);
                        Language.printKey(REMOVE_KEY, addr, name);
                        Helper.remove(ret, addr);
                    end
                end
            end
        end
    end

    confirm = Ask.ask(Language.getKey(SHOULD_CONFIRM_KEY), Ask.yesNo());

    parallel.waitForAny(keyThread, peripheralThread);
    return ret;
end

--- <b>Creates an address translation table.</b>
---@param namespace string
---@return EasyAddress
function EasyAddress.new(namespace)
    ---@class EasyAddress
    local self = {};

    ---@type any[]
    local translations = {};
    local decriptions = {};

    --- <b>Sets the descriptions.</b>
    ---@param descriptions table A lookup table with address keys and description values.
    function self.setDescriptions(descriptions)
        decriptions = descriptions;
    end

    --- <b>Gets an address translation.</b>
    ---@param name string The name of the address
    ---@param request boolean|nil Whether to request for user input if it doesn't exist
    ---@return string address The translated address.
    function self.get(name, request)
        if (request == nil) then request = true; end

        ---@type string
        local ret = translations[name];
        if (request and ret == nil) then
            self.request(name);
            ret = translations[name];
        end
        return ret;
    end

    --- <b>Gets multiple addresses.</b>
    ---@param name string The name of the address.
    ---@param request boolean? **Default: True** - Whether to request for user input if it doesn't exist.
    ---@return string[] addresses The translated address.
    function self.getList(name, request)
        if (request == nil) then request = true; end

        local ret = translations[name];
        if (ret == nil) then translations[name] = {}; ret = translations[name]; end
        if (request and #ret == 0) then
            self.modifyList(name);
            ret = translations[name];
        end
        return ret;
    end

    --- <b>Requests an address translation from the user.</b> <br>
    --- <b>After the user has entered an address, it will be stored in the translation table.</b>
    ---@param name string
    function self.request(name)
        self.set(name, EasyAddress.wait(name, decriptions[name]));
        self.save();
    end

    --- <b>Requests a list of addresses from the user.</b> <br>
    --- The user will effectively modify a copy of the original list until they are done. This is to allow for deduplication.
    ---@param name string
    function self.modifyList(name)
        local prev = translations[name];
        local new = EasyAddress.waitList(name, decriptions[name], prev);
        Helper.set(new, prev)
        self.save();
    end

    --- <b>Sets an address translation.</b>
    ---@param name string
    ---@param addr string|string[]|nil
    function self.set(name, addr)
        translations[name] = addr;
        self.save();
    end

    function self.remove(name)
        self.set(name, nil);
    end

    function self.save()
        EasyAddress.save(namespace, translations);
    end

    function self.load()
        translations = EasyAddress.load(namespace);
    end

    self.load();
    return self;
end

return EasyAddress;