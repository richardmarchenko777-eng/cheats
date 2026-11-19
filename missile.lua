-- Автопилот ПВО для CC: Tweaked (Create: Aeronautics / Propulsion)

local CONFIG = {
    MODEM_SIDE = "front",      -- Эндер-модем стоит спереди компьютера
    CHANNEL = 42,              -- Канал связи с радаром
    THRUST_FWD = "right",      -- Маршевый двигатель (справа)
    THRUST_UP = "top",         -- Руль вверх (сверху)
    THRUST_DOWN = "bottom",    -- Руль вниз (снизу)
    THRUST_LEFT = "left",      -- Руль влево (слева)
    THRUST_RIGHT = "back",     -- Руль вправо (сзади, т.к. спереди модем)
    PULSE_TIME = 0.08,         -- Длительность импульса рулей в секундах
    DEADZONE = 2.0,            -- Допустимое отклонение в блоках перед коррекцией
    TEST_MODE = true           -- true = тест двигателей и рулей без радара, false = полёт к цели
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
    print("=== ТЕСТ ДВИГАТЕЛЕЙ И РУЛЕЙ ===")
    print("Модем спереди: " .. tostring(CONFIG.MODEM_SIDE))
    print("Маршевый двигатель: " .. tostring(CONFIG.THRUST_FWD))
    if CONFIG.THRUST_FWD then
        rs.setOutput(CONFIG.THRUST_FWD, true)
        sleep(1.5)
        rs.setOutput(CONFIG.THRUST_FWD, false)
    end

    local rudders = {
        {name = "ВВЕРХ", side = CONFIG.THRUST_UP},
        {name = "ВНИЗ", side = CONFIG.THRUST_DOWN},
        {name = "ВЛЕВО", side = CONFIG.THRUST_LEFT},
        {name = "ВПРАВО", side = CONFIG.THRUST_RIGHT}
    }

    for _, item in ipairs(rudders) do
        if item.side then
            print("Импульс руля [" .. item.name .. "] -> " .. item.side)
            pulse(item.side, CONFIG.PULSE_TIME)
            sleep(0.5)
        end
    end

    resetOutputs()
    print("Тест завершён. Чтобы включить наведение, поставь TEST_MODE = false.")
end

local function steerToTarget(targetX, targetY, targetZ)
    local x, y, z = gps.locate(0.5)
    if not x then
        print("Нет GPS-сигнала! Проверь GPS-хосты или поставь TEST_MODE = true.")
        return
    end

    local dx = targetX - x
    local dy = targetY - y
    local dz = targetZ - z

    -- Коррекция по вертикали (Y)
    if dy > CONFIG.DEADZONE then
        pulse(CONFIG.THRUST_UP, CONFIG.PULSE_TIME)
    elseif dy < -CONFIG.DEADZONE then
        pulse(CONFIG.THRUST_DOWN, CONFIG.PULSE_TIME)
    end

    -- Коррекция по горизонтали (X / Z)
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

    print("ПВО активно. Модем спереди, канал: " .. CONFIG.CHANNEL)

    while true do
        local _, msg = rednet.receive(CONFIG.CHANNEL, 0.2)
        if type(msg) == "table" and msg.x and msg.y and msg.z then
            steerToTarget(msg.x, msg.y, msg.z)
        end
    end
end)

resetOutputs()
if not ok and err then
    print("Остановка: " .. tostring(err))
end
