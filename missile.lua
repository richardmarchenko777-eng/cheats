-- SAM Missile Autopilot (CC: Tweaked + Create Aeronautics / Propulsion)

local CONFIG = {
    MODEM_SIDE = "front",      -- Ender modem on front
    PROTOCOL = "sam_pvo",      -- Must match ground.lua
    THRUST_FWD = "back",       -- Main rear thruster
    THRUST_UP = "top",         -- Up thruster
    THRUST_DOWN = "bottom",    -- Down thruster
    THRUST_LEFT = "left",      -- Left thruster
    THRUST_RIGHT = "right",    -- Right thruster
    TEST_RUDDER_TIME = 1.5,
    PULSE_TIME = 0.08,
    DEADZONE = 2.0,
    TEST_MODE = true           -- Change to false when ready for radar guidance
}

local SIDES = {
    CONFIG.THRUST_FWD,
    CONFIG.THRUST_UP,
    CONFIG.THRUST_DOWN,
    CONFIG.THRUST_LEFT,
    CONFIG.THRUST_RIGHT
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

local function runTest()
    print("=== THRUSTER & RUDDER TEST ===")

    if CONFIG.THRUST_RIGHT then
        print("Testing RIGHT (" .. CONFIG.THRUST_RIGHT .. ") for " .. CONFIG.TEST_RUDDER_TIME .. "s")
        rs.setOutput(CONFIG.THRUST_RIGHT, true)
        sleep(CONFIG.TEST_RUDDER_TIME)
        rs.setOutput(CONFIG.THRUST_RIGHT, false)
        sleep(0.5)
    end

    local rudders = {
        {name = "UP", side = CONFIG.THRUST_UP},
        {name = "DOWN", side = CONFIG.THRUST_DOWN},
        {name = "LEFT", side = CONFIG.THRUST_LEFT}
    }

    for _, item in ipairs(rudders) do
        if item.side then
            print("Pulse [" .. item.name .. "] -> " .. item.side)
            pulse(item.side, CONFIG.PULSE_TIME)
            sleep(0.5)
        end
    end

    if CONFIG.THRUST_FWD then
        print("Testing MAIN (" .. CONFIG.THRUST_FWD .. ")...")
        rs.setOutput(CONFIG.THRUST_FWD, true)
        sleep(1.0)
        rs.setOutput(CONFIG.THRUST_FWD, false)
    end

    resetOutputs()
    print("Test finished.")
end

local function steerToTarget(targetX, targetY, targetZ)
    local x, y, z = gps.locate(0.5)
    if not x then
        print("NO GPS SIGNAL! Check GPS hosts.")
        return
    end

    local dx = targetX - x
    local dy = targetY - y
    local dz = targetZ - z

    if dy > CONFIG.DEADZONE then
        pulse(CONFIG.THRUST_UP, CONFIG.PULSE_TIME)
    elseif dy < -CONFIG.DEADZONE then
        pulse(CONFIG.THRUST_DOWN, CONFIG.PULSE_TIME)
    end

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
end

local ok, err = pcall(function()
    if CONFIG.TEST_MODE then
        runTest()
        return
    end

    if CONFIG.MODEM_SIDE then
        rednet.open(CONFIG.MODEM_SIDE)
    end

    if CONFIG.THRUST_FWD then
        rs.setOutput(CONFIG.THRUST_FWD, true)
    end

    print("SAM GUIDANCE ACTIVE. Protocol: " .. CONFIG.PROTOCOL)

    while true do
        local _, msg = rednet.receive(CONFIG.PROTOCOL, 0.2)
        if type(msg) == "table" and msg.x and msg.y and msg.z then
            steerToTarget(msg.x, msg.y, msg.z)
        end
    end
end)

resetOutputs()
if not ok and err then
    print("Stopped: " .. tostring(err))
end
