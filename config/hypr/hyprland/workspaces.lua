-- Per-monitor workspace blocks.
--
-- Every connected monitor owns a block of ten workspaces: the built-in panel
-- takes 1-10, the first external output 11-20, the next one 21-30, and so on.
-- Workspaces past the last block stay unbound, so they can be pulled up on
-- whichever monitor happens to be focused.

local M = {}

M.per_monitor = 10

local function is_internal(monitor)
    return monitor.name:match("^eDP") ~= nil
end

-- Stable order, so a block always lands on the same output: the built-in panel
-- first, then the external ones by name.
local function ordered_monitors()
    local monitors = {}
    for _, monitor in ipairs(hl.get_monitors() or {}) do
        monitors[#monitors + 1] = monitor
    end

    table.sort(monitors, function(a, b)
        if is_internal(a) ~= is_internal(b) then
            return is_internal(a)
        end
        return a.name < b.name
    end)

    return monitors
end

-- First workspace of the block the focused monitor is currently showing. That
-- is the monitor's own block, unless it is displaying one of the overflow
-- workspaces past the last block.
local function focused_block_start()
    local monitor = hl.get_active_monitor()
    local workspace = monitor and monitor.active_workspace
    local id = workspace and workspace.id or 1
    if id < 1 then
        id = 1
    end
    return math.floor((id - 1) / M.per_monitor) * M.per_monitor
end

-- Turns a 1..per_monitor key offset into the workspace the focused monitor
-- should switch to. Used by the SUPER+<n> binds.
function M.workspace_for(offset)
    return focused_block_start() + offset
end

local rules = {}

function M.apply()
    for _, rule in ipairs(rules) do
        rule:set_enabled(false)
    end
    rules = {}

    for index, monitor in ipairs(ordered_monitors()) do
        local block = (index - 1) * M.per_monitor
        for offset = 1, M.per_monitor do
            rules[#rules + 1] = hl.workspace_rule({
                workspace = tostring(block + offset),
                monitor = monitor.name,
                persistent = true,
            })
        end
    end
end

-- Monitor events fire while Hyprland is still reshuffling outputs, so let the
-- list settle before rebuilding the blocks.
local pending

local function schedule_apply()
    pending = hl.timer(function()
        pending = nil
        M.apply()
    end, { timeout = 100, type = "oneshot" })
end

M.apply()

hl.on("hyprland.start", M.apply)
hl.on("monitor.added", schedule_apply)
hl.on("monitor.removed", schedule_apply)

return M
