-- Ground SAM Radar Station (Create Radar -> CC: Tweaked)

local CONFIG = {
    MODEM_SIDE = "back",       -- Modem side
    RADAR_SIDE = "right",      -- Radar / Network Controller side
    PROTOCOL = "sam_pvo",      -- String protocol name (must match missile.lua)
    INTERVAL = 0.1             -- Broadcast interval (sec)
}

rednet.open(CONFIG.MODEM_SIDE)
local radar = peripheral.wrap(CONFIG.RADAR_SIDE)

if not radar or not radar.getSelectedTrack then
    error("No getSelectedTrack on side: " .. CONFIG.RADAR_SIDE)
end

local function parseTrack(raw)
    if type(raw) == "table" then
        return raw
    end
    if type(raw) ~= "string" or raw == "" or raw == "{}" then
        return nil
    end

    local tbl = textutils.unserialize(raw)
    if type(tbl) == "table" then
        return tbl
    end

    local fn = load("return " .. raw)
    if fn then
        local ok, res = pcall(fn)
        if ok and type(res) == "table" then
            return res
        end
    end

    return nil
end

term.clear()
term.setCursorPos(1, 1)
print("SAM Ground Station ACTIVE")
print("Protocol: " .. CONFIG.PROTOCOL)

while true do
    local ok, raw = pcall(radar.getSelectedTrack)
    local track = ok and parseTrack(raw) or nil
    local pos = track and track.position
    local vel = track and track.velocity

    term.setCursorPos(1, 4)
    term.clearLine()

    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" and type(pos.z) == "number" then
        local payload = {
            x = pos.x,
            y = pos.y,
            z = pos.z,
            vx = (type(vel) == "table" and vel.x) or 0,
            vy = (type(vel) == "table" and vel.y) or 0,
            vz = (type(vel) == "table" and vel.z) or 0,
            id = track.id,
            category = track.category
        }

        rednet.broadcast(payload, CONFIG.PROTOCOL)
        write(string.format("LOCK: X=%.1f Y=%.1f Z=%.1f", pos.x, pos.y, pos.z))
    else
        write("SEARCHING: Select target on radar...")
    end

    sleep(CONFIG.INTERVAL)
end
