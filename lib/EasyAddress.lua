local Identifier = require("lib.Identifier");
local Helper = require("lib.Helper")
local Ask = require("lib.Ask");
local Graphics = require("lib.Graphics")
local Std = require("lib.Std");
local Table = require("lib.Table")

local EasyAddress = {};

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
---@return string?
function EasyAddress.wait(name, description)

    --- <b>Before we block the thread, we need to clear the terminal, and print some info.</b>
    local function ui_waiting()
        term.clear();
        term.setCursorPos(1, 1)
        ---@diagnostic disable-next-line: undefined-field
        print(("Please enable the peripheral '%s'..."):format(name));
        if (description) then
            print("Additional Information is Available:");
        ---@diagnostic disable-next-line: undefined-field
            print(description:format(name));
        end
    end

    --- <b>When we receive the address list of peripherals enabled, we return an address from that list</b>
    ---@param addressList string[]
    ---@return boolean success Whether the user confirmed the address
    ---@return string|nil address The address of the peripheral
    local function ui_received(addressList)
        local addr = addressList[1];
        if (#addressList > 1) then
            write("Select one of the following: ");
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
        ---@diagnostic disable-next-line: undefined-field
        print(("Are you sure you want to set the peripheral '%s' as '%s'? (y/n)"):format(addr, name));
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

--- <b>Given a list adds or removes peripherals</b>
---@param name string
---@param description string|nil
---@param list string[]? addresses
---@return string[]
function EasyAddress.waitList(name, description, list)
    list = list or {};

    local ret = Table.deepCopy(list);
    local pause = false;

    local confirm = true;

    local speaker = peripheral.find("speaker") or {playNote = function() end};

    --- <b>Before we block the thread, we need to clear the terminal, and print some info.</b>
    local function onShowWaiting()
        ---@diagnostic disable-next-line: undefined-field
        print(("Please enable a peripheral in the category of '%s'..."):format(name));
        if (description ~= nil) then
            print("Additional Information is Available:");
        ---@diagnostic disable-next-line: undefined-field
            print(description:format(name));
        end
        Graphics.writePercent("Press Enter when done.", 1, 1);
    end

    --- <b>When we receive the address list of peripherals enabled, we return an address from that list</b>
    ---@param addressList string[]
    ---@return string[] address The address of the peripheral
    local function onShowFilter(isAdd, addressList)
        local key = nil;
        if (isAdd) then key = "Found multiple peripherals, do you want to add them all? (y/n):";
        else key = "Found multiple peripherals, do you want to remove them all? (y/n):"; end

        if (#addressList > 1) then
            if (Ask.ask(key, Ask.yesNo())) then
                return addressList;
            else
                write("Select one of the following: ")
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
                ---@diagnostic disable-next-line: undefined-field
                local event, key = os.pullEvent("key_up");
                if (key == keys.enter) then
                    if (Ask.ask("Are you sure you want to exit? (y/n):", Ask.yesNo())) then
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
                    if (Table.contains(ret, addr)) then
                        Table.add(toRemove, addr);
                    end
                end
                for _, addr in ipairs(toRemove) do
                    Table.remove(addrs, addr);
                end
            else
                local toRemove = {};
                for _, addr in ipairs(addrs) do
                    if (not Table.contains(ret, addr)) then
                        Table.add(toRemove, addr);
                    end
                end
                for _, addr in ipairs(toRemove) do
                    Table.remove(addrs, addr);
                end
            end

            local filteredAddrs = nil;
            if (confirm) then filteredAddrs = onShowFilter(isAdd, addrs);
            else filteredAddrs = addrs; end

            toggleKeyInput();
            if (event == "peripheral") then
                for index, addr in ipairs(filteredAddrs) do
                    if (not Table.contains(ret, addr)) then
                        ---@diagnostic disable-next-line: redundant-parameter
                        speaker.playNote("harp", 1, 1);
                        ---@diagnostic disable-next-line: undefined-field
                        print(("Added '%s' to '%s'"):format(addr, name));
                        Table.add(ret, addr);
                    end
                end
            elseif (event == "peripheral_detach") then
                for index, addr in ipairs(filteredAddrs) do
                    if (Table.contains(ret, addr)) then
                        ---@diagnostic disable-next-line: redundant-parameter
                        speaker.playNote("bass", 1, 12);
                        ---@diagnostic disable-next-line: undefined-field
                        print(("Removed '%s' from '%s'"):format(addr, name));
                        Table.remove(ret, addr);
                    end
                end
            end
        end
    end

    confirm = Ask.ask("Everytime you connect a peripheral do you want to confirm the address? (y/n):", Ask.yesNo());

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
        Table.set(new, prev)
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