local timer = require("timer")
local SS13 = require("SS13") 


-- event Clown Category --
local outfit = SS13.new("/datum/outfit/job/clown") 
local slot_shoes = 128
local all_resistance_flags = 511
local locSpawnClown = {107, 120, 2}
local turfClown = dm.global_procs.coords2turf(locSpawnClown) 

-- Outline -- 
local outlineValue = {["type"] = "outline", ["color"] = "red", ["size"] = 1} -- значение, больше можно узнать в коде фильтров.

-- Event Master --
local admin = "zagovori" -- input your Ckey
local user = dm.global_vars.GLOB.directory[admin].mob


local locRawSpawnRunner = { -- Metastation
    {79, 114, 2},
    {65, 134, 2},
    {51, 122, 2},
    {89, 147, 2},
    {68, 152, 2},
    {89, 155, 2},
    {114, 150, 2},
    {122, 149, 2},
    {134, 153, 2},
    {142, 172, 2},
    {143, 152, 2},
    {131, 141, 2},
    {134, 132, 2},
    {153, 133, 2},
    {135, 112, 2},
    {125, 103, 2},
    {73, 102, 2},
    {82, 110, 2},
    {84, 80, 2},
    {92, 62, 2}
}

local locSpawnsRunner = {}
for _, cord in ipairs(locRawSpawnRunner) do
    table.insert(locSpawnsRunner, dm.global_procs.coords2turf(cord))
end

-- Создаем копию для безопасной модификации
local randomRunnerTeleport = {}
local currentIndexes = {}

-- Функция для обновления доступных точек
local function refresh_teleports()
    -- Создаем новую таблицу индексов
    currentIndexes = {}
    for i = 1, #locSpawnsRunner do
        currentIndexes[i] = i
    end
    
    -- Перемешиваем индексы алгоритмом Фишера-Йетса
    for i = #currentIndexes, 2, -1 do
        local j = math.random(i)
        currentIndexes[i], currentIndexes[j] = currentIndexes[j], currentIndexes[i]
    end
end

-- Первоначальная инициализация
refresh_teleports()

local function getRandomClown(data)
    -- Собираем все ключи в массив
    local keys = {}
    for k in pairs(data) do
        table.insert(keys, k)
    end
    
    -- Проверяем, что есть игроки
    if #keys == 0 then
        return nil 
    end
    
    -- Выбираем случайный ключ
    local random_key = keys[math.random(#keys)]
    
    -- Возвращаем игрока и ключ (если нужно)
    return data[random_key]
end

local function REF(obj)
	return dm.global_procs.REF(obj)
end

local function getRandomRunner(data) 
    -- Собираем все ключи в массив
    local keys = {}
    for k in pairs(data) do
        if data[k].mob and not data[k].is_clown then
            table.insert(keys, k)
        end     
    end
    
    -- Проверяем, что есть игроки
    if #keys == 0 then
        return nil 
    end
    
    -- Выбираем случайный ключ
    local random_key = keys[math.random(#keys)]
    
    -- Возвращаем игрока и ключ (если нужно)
    return data[random_key]
end

-- функции --
local cooldowns = setmetatable({}, { __mode = "k" }) -- weak-keys таблица -- если делать с умом. По сути не забиваем память.bit

local function canActivate(mob, action, cooldown_time)
    local ref = REF(mob)
    local current_time = dm.world.time
    
    -- Инициализация структуры для моба
    cooldowns[ref] = cooldowns[ref] or {}
    
    -- Получаем время последней активации для действия
    local last_time = cooldowns[ref][action]
    
    -- Если действие можно активировать
    if not last_time or (current_time - last_time) >= cooldown_time then
        cooldowns[ref][action] = current_time
        return true
    end
    
    return false
end

local function countPly(players)
    local count = 0
    local clownCount = 0
    for _ , data in pairs(players) do 
        if data.mob then
            count = count + 1 
        end
        if data.mob and data.is_clown then
            clownCount = clownCount + 1
        end
    end
    return count, clownCount
end

local function notifyPlayer(ply, msg)
	ply:balloon_alert(ply, msg)
end

local function do_teleport(target, destination, forced) 
    dm.global_procs.do_teleport(
        target,
        destination,
        precision,
        effectIn,
        effectOut,
        soundIn,
        soundOut,
        no_effects,
        channel,
        forced
    )
end

local function announce(command_name, title, text, sound)
    dm.global_procs.priority_announce(
        text,
        title,
        sound,
        ANNOUNCEMENT_TYPE_PRIORITY,
        command_name,
        false,
        dm.global_vars.GLOB.player_list,
        true,
        true,
        "red"
    )
end

-- Основная функция телепортации
function teleport_player(data)
    if #currentIndexes == 0 then
        refresh_teleports()  -- Перезаполняем когда закончились
    end
    
    -- Берем последний индекс из перемешанного списка
    local idx = table.remove(currentIndexes)
    local target = locSpawnsRunner[idx]
    do_teleport(data.mob, target, true)
    --return target -- онли для дебага
end

local function messageRules(data)
    -- о регистрации в ивенте и о правилах.
    dm.global_procs.to_chat(data.mob, "<span class='yellowteamradio'>🔔 Вы зарегистрированы в ивенте!</span>")
    dm.global_procs.playsound(data.mob, "sound/misc/asay_ping.ogg", 10)
    dm.global_procs.to_chat(data.mob, "<span class='yellowteamradio'>Основные правила:</span> <br/><span class='alert'>1. Не выходить в космос и покидать территорию станции. Шаттлы территорией станции, не являются. <br/>2. Запрещается связывать других игроков. <br/>3. Объятья или удар по игроку превращают в клоуна, даже своих! Но не себя.<br/>4. Если снять ботинки с клоуна он аннигилируется. <br/>5. Если игрок будет очень долго стоять, он аннигилируется.<br/>6. Вы можете попробовать. Но не рекомендуется залезать в мусорки, меха и т.д из-за правила 1.</span>")
end

local function updateVisualData(data)
	data.image:vv_edit_var(
		"maptext",
		string.format(
			"<span class='maptext' style='color: %s'>Timer: %s<br />Clowns: %s<br/>Your location: %s<br/> %s</span>",
			data.color,
			data.timerOut,
			data.playersCount,
            data.playerLocation,
			data.is_clown == true and "<br />Clown Radar: "..data.runnerLoc or ""
		)
	)
	if data.is_clown then
        data.button:vv_edit_var("maptext", "<span class='maptext'>Track Random Target</span>")
	end
end

local function turnIntoClown(data) -- то есть передаем уже внутрению инфу players[ref]
    do_teleport(data.mob, turfClown, true)
    if not data.is_clown then 
        data.is_clown = true
        if data.afkTimer then
            SS13.end_loop(data.afkTimer.timerID)
            data.afkTimer = nil
        end
        data.mob:delete_equipment()
        data.mob:equipOutfit(outfit)

        local shoes = data.mob:get_item_by_slot(slot_shoes)
        data.mob:add_or_update_variable_movespeed_modifier(dm.global_procs._text2path("/datum/movespeed_modifier/admin_varedit"), true, -1)
        data.mob:add_filter("haunt_glow", 2, outlineValue)
        data.color = "#be2548"
        updateVisualData(data)
        shoes:vv_edit_var("resistance_flags", all_resistance_flags)  
        SS13.register_signal(shoes, "item_pre_unequip", function()
            dm.global_procs.playsound(data.mob, "sound/misc/sadtrombone.ogg", 20, true)
            data.mob:gib() -- один из вариантов убить клоуна, забрать его ботинки.
        end)
    end
end

local function applySignals(data)
    SS13.register_signal(data.mob, "movable_moved", function(owner, old_step, dir) -- c old_step не получится, потому что можно себя запульнуть, на лаву, и не двигаться.
        -- logic
        -- 2 set_timeout Первый проверка правил, второй на афк.
        SS13.set_timeout(0, function()
            if SS13.istype(data.mob.loc.loc, "/area/station") and data.mob.z == 2 then return end
            turnIntoClown(data)
        end)
        SS13.set_timeout(0, function() -- в теории мы должны были сначала её запустить. Но похер. Мы дадим сигналы и только потом их тпшним.  Там задержка 00.1 секунда.
            if data.is_clown then return end
            
            if data.afkTimer then -- перезапускаем.
                SS13.end_loop(data.afkTimer.timerID)
            end
            
            data.afkTimer = {
                timerID = SS13.start_loop(1, -1, function()
                    data.afkTimer.repeated_amount += 1
                    if data.afkTimer.repeated_amount == 10 then
                       -- dm.global_procs.to_chat(dm.world, "AFK MOB!: " .. mob.name) -- debug
                        announce("Camper Detector", "CODE 47: STATIC TARGET", "Camper: " .. data.mob.name .. " Detected. \nThey location: " .. data.mob.loc.loc.name, "sound/effects/quack.ogg", "red")
                    elseif data.afkTimer.repeated_amount == 20 then
                        announce("Camper Detector", "Замечено продолжительное бездействие, если вы не умерли за компьютером, пожалуйста подвигайтесь.", "Camper: " .. data.mob.name .. " Detected. \nThey location: " .. data.mob.loc.loc.name .. " \nThey gps coordinate: " .. "x:" .. data.mob.loc.x .. " y:".. data.mob.loc.y .. " z:" ..data.mob.loc.z, "sound/effects/quack.ogg", "red")
                    elseif data.afkTimer.repeated_amount == 30 then
                        announce("Camper Detector", "Новый рекорд бездействия!. У тебя 5 секунд, чтобы начать двигаться иначе твоя кукла расщепится на липовый мед", "Camper: " .. data.mob.name .. " Detected. \nThey location: " .. data.mob.loc.loc.name .. " \nThey gps coordinate: " .. "x:" .. data.mob.loc.x .. " y:".. data.mob.loc.y .. " z:" ..data.mob.loc.z .. "\n5 seconds for Gib", "sound/effects/quack.ogg", "red")
                    elseif data.afkTimer.repeated_amount >= 35 then
                        announce("Camper Detector", "Рецепт дня: Жаркое из кемпера", "Camper: " .. data.mob.name .. "\nThey character Gib", "sound/effects/explosion/explosion_distant.ogg", "red")
                        data.mob:gib() -- исправил ошибку, когда срабатывал гиб, удалял таймер, и тут еще срабатывал и была ошибка. В теории не важно. Просто хочу избавиться от всех проблем.
                    end
                end),
                repeated_amount = 0
            }

        end)
	end)
    SS13.register_signal(data.mob, "atom_attack_hand", function(owner, target) --  target это кто применяет на куклу с сигналом, удар/hug. А не носитель к кому-то.
        -- logic
        if owner == target then -- запрещаем себя заруинить.
            return
        end
        -- 
        turnIntoClown(data)
        
    end)
    SS13.register_signal(data.mob, "carbon_attempt_cuff", function(owner, target) -- target это кто применяет на куклу с сигналом, наручники. А не носитель к кому-то.
        -- logic
        target:Paralyze(69) -- станит тот кто это сделал.
        target:apply_status_effect("/datum/status_effect/speech/stutter", 60) -- слова растягиваются, как при стане.
	end)
    SS13.register_signal(data.mob, "living_death", function(owner, gib)
        -- logic
        if not gib then -- есть какая-та ошибка со щрамами. Скорее всего из-за того что мы сразу ахилим в тот же момент.
            data.mob:revive(-1)
            dm.global_procs.playsound(data.mob, 'sound/effects/pray.ogg', 60, true)
        end
	end)
    SS13.register_signal(data.mob, "living_gibbed", function()
        -- logic
        data.mob = nil 
        if data.afkTimer then -- убираем если все же таймер остался.
            SS13.end_loop(data.afkTimer.timerID)
            data.afkTimer = nil
        end
	end)
     SS13.register_signal(data.mob, "human_suicide_act", function(owner) -- только когда в поле чата, снизу пишет suicide его мнгновенно убивает и отцепляет от тела. А стрельба в голову с гана, это не суицид.
        -- logic
        local ref = REF(data.mob)
        local refSuicide = list.to_table(owner._status_traits .committed_suicide)
        for _, oldMobRef in ipairs(refSuicide) do  -- это было сделано на всякий случай, поскольку там лист, и если он все же будет пополняться, то все не сломалось.
            if oldMobRef == ref then
                data.mob:gib() -- киляем моментально чела, если он так хочет.
            end
        end
     end)
end


local players = {}

local function setupPlayer(mob)
    local ref = REF(mob)
    players[ref] = {
        name = mob.real_name,
        mob = mob,
        color = "#189BCC",
        image = SS13.new("/atom/movable/screen/text", dm.usr), -- не знаю почему dm.usr пока оставлю.
		button = SS13.new("/atom/movable/screen/text", dm.usr),
        timerOut = "Round not Started",
        playersCount = "Round Not Started",
        playerLocation = "unknown",
        runnerLoc = "please press ability button",
        afkTimer = nil,
        is_clown = false
    }

    local playerData = players[ref]
	playerData.button:vv_edit_var("screen_loc", "WEST:4,CENTER-0:0")
	playerData.button:vv_edit_var("maptext_width", 92)
	playerData.button:vv_edit_var("maptext_height", 15)
	playerData.image:vv_edit_var("screen_loc", "WEST:4,CENTER-0:17")
	playerData.button:vv_edit_var("mouse_opacity", 2)
	local hud = dm.get_var(mob, "hud_used")
	local hudElements = dm.get_var(hud, "static_inventory")
	list.add(hudElements, playerData.image)
	list.add(hudElements, playerData.button)
	playerData.image:vv_edit_var("loc", nil)
	playerData.button:vv_edit_var("loc", nil)
	hud:show_hud(dm.get_var(hud, "hud_version"))
	updateVisualData(playerData)
    -- тут будут сигналы
    applySignals(playerData)
    -- тут телепорты.
    teleport_player(playerData)
    -- Сообщение игроку.
    messageRules(playerData)
    
    
    SS13.register_signal(players[ref].button, "screen_element_click", function()
        print("Click before!")
        if not canActivate(mob, "screen_element_click", 120) or not playerData.is_clown then -- Work properly!
            notifyPlayer(players[ref].mob, "Ability in cooldown")
			return
		end
        -- logic find runner
        local randomRunner = getRandomRunner(players)
        playerData.runnerLoc = "x:"..randomRunner.mob.x.." y:"..randomRunner.mob.y.." z:"..randomRunner.mob.z

        print("Click!")
        updateVisualData(playerData)
    end)
end

local function endRound()
    SS13.stop_all_loops() -- заканчиваем раунд очищая память от всех возможных циклов.
    for _, data in players do
        if data.mob then
            local client = data.mob.client -- заплатка. Потому что мы удаляем юзера. Значит и моб изменился. Получаем клиент, которые не изменится.|
            --local slot = dm.get_var(client.prefs.default_slot)
            --client.prefs:vv_edit_var("default_slot", slot+1) -- чтобы можно было заходить
            SS13.qdel(data.mob) 
            local new_player = SS13.new("/mob/dead/new_player") -- тайп нам не подходит. Он нас отправляет в ничто. А не в лобби.
            client.mob = new_player
        end
    end
    for _, mob in ipairs(list.to_table(dm.global_vars.GLOB.dead_player_list)) do
        local client = mob.client 
      --  local slot = dm.get_var(client.prefs.default_slot)
        --client.prefs:vv_edit_var("default_slot", slot+1) 
        local new_player = SS13.new("/mob/dead/new_player") 
        client.mob = new_player -- назначаем это значение, игроку. И его отправляет смотреть на лобби скрин: хрррр ммммиии
    end
end

SS13.start_loop(1, 300, function(currentCycle)
    local countPly, countClw = countPly(players)
    local time_remaining = 300 - currentCycle
    local mins = math.floor(time_remaining / 60)
    local secs = time_remaining % 60

    if currentCycle == 300 or countClw == 0 then
        local winners = {}
        for _, data in players do
            if data.mob and not data.is_clown then
                table.insert(winners, data.name)
            end
        end
        dm.global_procs.to_chat(dm.world, "<span class='yellowteamradio'>Победители: </span>" .. table.concat(winners, ", ")) -- Добавить эмодзи
        dm.global_procs.alert_sound_to_playing('sound/effects/achievement/tada_fanfare.ogg', 10, true)
        endRound()
    elseif countPly == countClw then
        print("contPly: ", countPly, " countClw: ", countClw)
        dm.global_procs.to_chat(dm.world, "<span class='yellowteamradio'>Победители: Никто. их: </span>" .. countPly - countClw)  -- Добавить эмодзи
        dm.global_procs.alert_sound_to_playing('sound/effects/achievement/tada_fanfare.ogg', 10, true)
        endRound()
    end

    -- update all players interface
    for _, data in players do
        if data.mob then
            data.playersCount = countClw.."/"..countPly
            data.timerOut = string.format("%02d:%02d", mins, secs)
            data.playerLocation = "x:"..data.mob.x.." y:"..data.mob.y.." z:"..data.mob.z
            updateVisualData(data)
        end
    end
    
end)

--[[ 
local function debugHud()
    for _, data in players do
        if data.mob then
            local hud = dm.get_var(data.mob, "hud_used") -- удаление интерфейса
            local hudElements = dm.get_var(hud, "static_inventory")
            dm.global_procs._list_remove(hudElements, data.image)
            dm.global_procs._list_remove(hudElements, data.button)
            dm.global_procs.qdel(data.image)
            dm.global_procs.qdel(data.button)
            SS13.unregister_signal(data.mob, "movable_moved") -- блять оно же тригерит новый. Сначала убираем, а потом уже снимаем таймер.
            SS13.set_timeout(0.5, function() -- потому что все равно успевает накинуться еще один таймер. При гибе такого не должно быть, потому что персонаж встанет.
                if data.afkTimer then
                    SS13.end_loop(data.afkTimer.timerID)
                    data.afkTimer = nil
                end
            end)
            SS13.unregister_signal(data.mob, "atom_attack_hand")
            SS13.unregister_signal(data.mob, "carbon_attempt_cuff")
            SS13.unregister_signal(data.mob, "living_death")
            SS13.unregister_signal(data.mob, "living_gibbed")
            SS13.unregister_signal(data.mob, "human_suicide_act")
        end
    end
end

]]
local mobPlyList = list.to_table(dm.global_vars.GLOB.alive_player_list) 
for _, mobPly in ipairs(mobPlyList) do
    setupPlayer(mobPly)
end


local clownData = getRandomClown(players)
turnIntoClown(clownData)
dm.global_procs.to_chat(dm.world,  "<span class='aiprivradio'>🔴 Первым клоуном будет: </span>" .. clownData.name)

--[[ 
SS13.set_timeout(15, function()
    debugHud()
    print("RESTARTED")
end)

]]

--[[
timer.wait(10)  

debugHud()



 local SS13 = require("SS13") 
 local function REF(obj)
	return dm.global_procs.REF(obj)
end
local mobUser = REF(dm.usr)
local mobOld = dm.usr

 SS13.register_signal(dm.usr, "living_death", function(owner, gib, _)
    -- logic 
    print("owner: ", owner)
    print("gib: ", gib)
    print("underscore: ", _)
end)
 ]]
-- apply_status_effect(/datum/status_effect/speech/stutter/anxiety, INFINITY)

--dm.usr:apply_status_effect("/datum/status_effect/speech/stutter", 60)

-- в основном таймере я буду проходиться по игрокам, и обновлять им интерфейсы, таймер, их позицию и т.д.