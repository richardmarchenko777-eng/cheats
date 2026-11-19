-- Наземная станция наведения ПВО (Create Radar -> CC: Tweaked)

local CONFIG = {
    MODEM_SIDE = "back",   -- Сторона, где стоит модем на наземном компе
    RADAR_SIDE = "right",  -- Сторона, где стоит блок радара/контроллера[cite: 6, 7]
    CHANNEL = 42,          -- Канал связи с ракетой
    INTERVAL = 0.1         -- Период отправки координат (сек)
}

rednet.open(CONFIG.MODEM_SIDE)
local radar = peripheral.wrap(CONFIG.RADAR_SIDE)

if not radar or not radar.getSelectedTrack then
    error("На стороне '" .. CONFIG.RADAR_SIDE .. "' не найден getSelectedTrack")
end

-- Превращаем строковый ответ getSelectedTrack() в таблицу Lua[cite: 7]
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

print("Пост ПВО запущен. Канал: " .. CONFIG.CHANNEL)

while true do
    local ok, raw = pcall(radar.getSelectedTrack)
    local track = ok and parseTrack(raw) or nil
    local pos = track and track.position
    local vel = track and track.velocity

    term.setCursorPos(1, 3)
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

        rednet.broadcast(payload, CONFIG.CHANNEL)
        write(string.format("Цель: %.0f, %.0f, %.0f", pos.x, pos.y, pos.z))
    else
        write("Цель не выбрана на радаре...")
    end

    sleep(CONFIG.INTERVAL)
end
