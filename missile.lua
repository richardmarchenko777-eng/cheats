-- SAM Missile Combat Autopilot (CC: Tweaked + Create Aeronautics / Propulsion)

local CONFIG = {
    MODEM_SIDE = "front",      -- Ender modem on front
    PROTOCOL = "sam_pvo",      -- Must match ground.lua
    THRUST_FWD = "back",       -- Main rear thruster
    THRUST_UP = "top",         -- Up thruster
    THRUST_DOWN = "bottom",    -- Down thruster
    THRUST_LEFT = "left",      -- Left thruster
    THRUST_RIGHT = "right",    -- Right thruster
    WARHEAD_SIDE = nil,        -- Side for detonation signal (e.g. via Redstone Link)
    PULSE_TIME = 0.08,         -- Rudder pulse duration (sec)
    DEADZONE = 1.5,            -- Acceptable error before correction (blocks)
    LEAD_FACTOR = 0.5,         -- Velocity lead multiplier (seconds ahead)
    DETONATE_DIST = 4.0,       -- Proximity fuse radius (blocks)
    TEST_MODE = false          -- Combat guidance mode
}

local SIDES = {
    CONFIG.THRUST_FWD,
    CONFIG.THRUST_UP,
    CONFIG.THRUST_DOWN,
    CONFIG.THRUST_LEFT,
    CONFIG.THRUST_RIGHT,
    CONFIG.WARHEAD_SIDE
}

local function resetOutputs()
    for _, side in ipairs(SIDES) do
        if side then
            rs.setOutput(side, false)
        end
    end
end

local function pulse(side, duration)
    if not side then return end
    rs.setOutput(side, true)
    sleep(duration or CONFIG.PULSE_TIME)
    rs.setOutput(side, false)
end

local function detonate()
    print("!!! PROXIMITY FUSE TRIGGERED - DETONATING !!!")
    if CONFIG.WARHEAD_SIDE then
        rs.setOutput(CONFIG.WARHEAD_SIDE, true)
    end
    resetOutputs()
    if CONFIG.WARHEAD_SIDE then
        rs.setOutput(CONFIG.WARHEAD_SIDE, true)
    end
end

local function steerToTarget(msg)
    local x, y, z = gps.locate(0.2)
    if not x then
        print("NO GPS SIGNAL! Build 4 GPS host computers.")
        return false
    end

    -- Calculate predicted target position using velocity
    local aimX = msg.x + (msg.vx or 0) * CONFIG.LEAD_FACTOR
    local aimY = msg.y + (msg.vy or 0) * CONFIG.LEAD_FACTOR
    local aimZ = msg.z + (msg.vz or 0) * CONFIG.LEAD_FACTOR

    local dx = aimX - x
    local dy = aimY - y
    local dz = aimZ - z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

    term.setCursorPos(1, 4)
    term.clearLine()
    write(string.format("DIST: %.1fm | dX:%.0f dY:%.0f dZ:%.0f", dist, dx, dy, dz))

    -- Proximity detonation check
    if dist <= CONFIG.DETONATE_DIST then
        detonate()
        return true
    end

    -- Vertical correction (Y)
    if dy > CONFIG.DEADZONE then
        pulse(CONFIG.THRUST_UP, CONFIG.PULSE_TIME)
    elseif dy < -CONFIG.DEADZONE then
        pulse(CONFIG.THRUST_DOWN, CONFIG.PULSE_TIME)
    end

    -- Horizontal correction (X / Z)
    if math.abs(dx) >= math.abs(dz) then
        if dx > CONFIG.DEADZONE then
            pulse(CONFIG.THRUST_RIGHT, CONFIG.PULSE_TIME)
        elseif dx < -CONFIG.DEADZONE then
            pulse(CONFIG.THRUST_LEFT, CONFIG.PULSE_TIME)
        end
    else
        if dz > CONFIG.DEADZONE then
            pulse(CONFIG.THRUST_RIGHT, CONFIG.PULSE_TIME)
        elseif dz < -CONFIG.DEADZONE then
            pulse(CONFIG.THRUST_LEFT, CONFIG.PULSE_TIME)
        end
    end

    return false
end

local ok, err = pcall(function()
    rednet.open(CONFIG.MODEM_SIDE)
    term.clear()
    term.setCursorPos(1, 1)
    print("SAM MISSILE ARMED. Waiting for target lock...")

    local launched = false

    while true do
        local _, msg = rednet.receive(CONFIG.PROTOCOL, 0.2)
        if type(msg) == "table" and msg.x and msg.y and msg.z then
            if not launched then
                launched = true
                print("TARGET ACQUIRED - LAUNCHING!")
                if CONFIG.THRUST_FWD then
                    rs.setOutput(CONFIG.THRUST_FWD, true)
                end
            end

            local hit = steerToTarget(msg)
            if hit then
                break
            end
        end
    end
end)

if not ok then
    resetOutputs()
    print("Stopped: " .. tostring(err))
end
