-- For Lua Editor / auxlua 4/26/2025
local SS13 = require("SS13")
local timer = require("timer")
local confettiTB = {}
local turfCOLOR = {}

-- Создаем маркеры для визуализации
local function create_marker(tile, status)
    -- Таблица соответствия статусов и путей к объектам
    local status_to_path = {
        frontier = "#bfffbf", -- light-green
        visited = "#B0F4FF", -- cyan
        goal = "yellow", -- yellow-green
        error = "red", -- red!
        -- Значение по умолчанию
        default = "#ca56ff" -- purple
    }
    
    -- Выбираем путь по статусу или используем default
    local color = status_to_path[status] or status_to_path.default
    
    -- Создаем маркер
    local marker = tile:add_atom_colour(color, 1)
    
    -- Добавляем маркер в таблицу confettiTB
    table.insert(confettiTB, marker) -- old, for obj
    
    -- Добавляем turf в таблицу turfCOLOR
    table.insert(turfCOLOR, tile)
end

local solidThrough = {
    [SS13.type("/obj/machinery/door/airlock/public/glass")] = true,
    [SS13.type("/obj/machinery/door/airlock")] = true
}

function is_passable(tile)
    -- Проверка плотности тайла
    --  print("Checking tile:", tile.x, tile.y)
    if tile.density == 1 then
        return false
    end

    local tileContents = dm.get_var(tile, "contents")
   -- print("Tile contents:", #tileContents, "objects")

    if #tileContents == 0 then
        return true
    end

    -- Проверка объектов
    for _, obj in tileContents do
      --  print("Object:", obj.type, "Density:", obj.density)
        if obj.density == 1 and not solidThrough[obj.type] then
            return false
        end
    end

    return true
end

-- BFS с визуализацией
local function bfs(start, goal)
    local queue = {start}
    local visited = {[start] = true}
    local parent = {}

    while #queue > 0 do
        local current = table.remove(queue, 1)
        create_marker(current, "visited") -- Маркер посещения

        if current == goal then
            -- Восстановление пути
            local path = {}
            local step = goal
            while parent[step] do
                table.insert(path, 1, step)
                step = parent[step]
            end
            return path
        end

        -- Проверяем соседей (4 направления)
        local dirs = {1, 2, 4, 8} -- South, North, East, West  
       -- local dirs = {1, 2, 4, 5, 6, 8, 9, 10} -- South, North, East, West   --1 = South, 2 = North, 4 = EAST, 5 = SouthEast, 6 = NorthEast, 8 = WEST, 9 = SouthWest, 10 = NorthWest ALL
        for _, dir in ipairs(dirs) do
            local neighbor = dm.global_procs._get_step(current, dir)
            if neighbor and not visited[neighbor] and is_passable(neighbor) then
                visited[neighbor] = true
                parent[neighbor] = current
                table.insert(queue, neighbor)
                create_marker(neighbor, "frontier") -- Маркер границы
            end
        end
        sleep(0.1) -- Задержка для анимации
    end
    return nil
end


local admin = "zagovori"
local user = dm.global_vars.GLOB.directory[admin].mob
local spawn_location = dm.get_var(user, "loc")
local gorilla = SS13.new("/mob/living/basic/gorilla", spawn_location)

local start = gorilla.loc
local goal = dm.global_procs.coords2turf({x = 130, y = 125, z = 2})
create_marker(goal, "goal") -- точка к которой нам нужно
local path = bfs(start, goal)

SS13.set_timeout(2, function()
if path then
    create_marker(goal, "error") -- точка к которой нам нужно
    for _, tile in ipairs(path) do
        SS13.wait(0.1) 
        create_marker(tile, "path") -- Маркер пути
        gorilla:Move(tile)
    end
else
    print("Путь не найден!")
end
end)

SS13.set_timeout(8, function()
    for _, conf in pairs(confettiTB) do
        SS13.qdel(conf) -- for objects
    end
    for _, tile in pairs(turfCOLOR) do
        tile:add_atom_colour("white", 1) -- white по сути ставит цвет на nil то есть сбрасывает его. Пойдет. xnj значит "1" хрен его знает. Работает не трогает.
    end
    SS13.qdel(gorilla)
end)