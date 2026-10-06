// Quickshell dispatches IPC strings; Lua expressions only work in Lua sessions.
function workspace(id, usingLua) {
    return usingLua
        ? `hl.dsp.focus({ workspace = ${JSON.stringify(String(id))} })`
        : `workspace ${id}`;
}

function moveWindow(workspaceId, address, usingLua) {
    return usingLua
        ? `hl.dsp.window.move({ workspace = ${JSON.stringify(String(workspaceId))}, window = ${JSON.stringify(`address:${address}`)}, follow = false })`
        : `movetoworkspacesilent ${workspaceId}, address:${address}`;
}

function focusWindow(address, usingLua) {
    return usingLua
        ? `hl.dsp.focus({ window = ${JSON.stringify(`address:${address}`)} })`
        : `focuswindow address:${address}`;
}

function closeWindow(address, usingLua) {
    return usingLua
        ? `hl.dsp.window.close({ window = ${JSON.stringify(`address:${address}`)} })`
        : `closewindow address:${address}`;
}
