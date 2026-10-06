-- Read bindings with inert Hyprland stubs: never run dispatchers or callbacks.
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local path = arg[1] or (config_home .. "/hypr/hyprland/keybinds.lua")
local sections, seen, metadata = { "General" }, { General = true }, {}
local section = "General"
for line in io.lines(path) do
    local heading = line:match("^%s*%-%-#+!%s*(.+)")
    if heading then
        section = heading
        if not seen[section] then
            seen[section] = true
            sections[#sections + 1] = section
        end
    end
    metadata[#metadata + 1] = { section = section, hidden = line:find("%-%-%s*%[hidden%]"),
        description = line:match("%-%-%s*help:%s*(.+)") }
end

local function clean(value)
    return (tostring(value):gsub("[\t\r\n]", " "))
end

local function render(value)
    if type(value) ~= "table" then
        return tostring(value)
    end
    local fields = {}
    for key, item in pairs(value) do
        fields[#fields + 1] = key .. "=" .. render(item)
    end
    table.sort(fields)
    return table.concat(fields, ", ")
end

local function dispatcher(name)
    return setmetatable({}, {
        __index = function(_, key) return dispatcher(name .. "." .. key) end,
        __call = function(_, ...)
            local values = {}
            for _, value in ipairs({...}) do values[#values + 1] = render(value) end
            return name .. "(" .. table.concat(values, ", ") .. ")"
        end,
    })
end

local submap = ""
local stub = { dsp = dispatcher("hl.dsp") }
function stub.bind(shortcut, action, options)
    local info = metadata[debug.getinfo(2, "l").currentline] or { section = "General" }
    if info.hidden then return end
    local description = (options or {}).description or info.description
    if type(action) == "function" then action = description or "Lua callback" end
    description = description or action
    if submap ~= "" then description = description .. " [submap: " .. submap .. "]" end
    print(table.concat({ "ENTRY", clean(info.section), clean(shortcut), clean(description), clean(action) }, "\t"))
end
function stub.define_submap(name, callback)
    local previous = submap
    submap = name
    callback()
    submap = previous
end
function stub.gesture() end

-- Load workspace constants without installing monitor rules or event handlers.
local workspace_env = {
    hl = {
        get_monitors = function() return {} end,
        on = function() end,
    },
    ipairs = ipairs, table = table, math = math, tostring = tostring,
}
local directory = assert(path:match("^(.*)/"), "expected a path with a directory")
local workspaces = assert(loadfile(directory .. "/workspaces.lua", "t", workspace_env))()
local env = {
    hl = stub,
    require = function(name)
        assert(name == "hyprland.workspaces", "unsupported help module: " .. name)
        return workspaces
    end,
}
assert(loadfile(path, "t", env))()
for _, title in ipairs(sections) do print("SECTION\t" .. clean(title)) end
