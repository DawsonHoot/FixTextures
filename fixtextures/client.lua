local function chat(msg)
    TriggerEvent('chat:addMessage', {
        color = { 0, 200, 255 },
        multiline = true,
        args = { 'worldfix', msg }
    })
end

local function loadWorldAroundPlayer(radius)
    radius = radius or 60.0
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return false end

    local c = GetEntityCoords(ped)
    local x, y, z = c.x, c.y, c.z

    -- Force collision + streaming focus
    RequestCollisionAtCoord(x, y, z)
    RequestAdditionalCollisionAtCoord(x, y, z)

    SetFocusArea(x, y, z, 0.0, 0.0, 0.0)
    NewLoadSceneStart(x, y, z, x, y, z, radius, 0)

    -- Wait for collision around entity (cap so we don't hang)
    local start = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - start) < 4500 do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end

    -- Give scene loader a moment (also capped)
    local start2 = GetGameTimer()
    while not IsNewLoadSceneLoaded() and (GetGameTimer() - start2) < 4500 do
        Wait(50)
    end

    NewLoadSceneStop()
    ClearFocus()

    return HasCollisionLoadedAroundEntity(ped)
end

local function nudgeToGroundIfFalling()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local c = GetEntityCoords(ped)

    -- Try to find ground below-ish (search from above to increase hit rate)
    local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 250.0)
    if found and groundZ and groundZ ~= 0.0 then
        -- If you're clearly below ground / in void, pop up above ground a bit
        if c.z < (groundZ - 3.0) then
            SetEntityCoordsNoOffset(ped, c.x, c.y, groundZ + 2.0, false, false, false)
            Wait(150)
        end
    end
end

-- /fixtextures: lightweight “poke” that often recovers blurry/missing textures
RegisterCommand('fixtextures', function()
    chat('Attempting texture/streaming refresh...')

    -- Toggle perf overlay briefly (streaming “jolt”)
    ExecuteCommand('cl_drawPerf 1')
    Wait(250)
    ExecuteCommand('cl_drawPerf 0')

    -- Force ped components to refresh (can trigger texture reload)
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        SetPedDefaultComponentVariation(ped)
    end

    -- Focus poke
    local c = GetEntityCoords(ped)
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
    Wait(250)
    ClearFocus()

    chat('Done. If textures keep breaking, it’s usually heavy assets/VRAM/streaming—relog is the full reset.')
end, false)

-- /fixworld: stronger, targets falling-through + missing collision/streaming
RegisterCommand('fixworld', function()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    chat('Reloading collision + world streaming around you...')

    -- If you're currently dropping through, pop to ground first (when possible)
    nudgeToGroundIfFalling()

    -- Freeze while we load collision so you don't keep falling
    FreezeEntityPosition(ped, true)
    Wait(50)

    -- Load a bit larger radius to help big city/MLO areas
    local ok = loadWorldAroundPlayer(80.0)

    FreezeEntityPosition(ped, false)

    if ok then
        chat('Collision loaded. You should be solid again.')
    else
        chat('Collision still not fully loaded. Try once more, or relog if you’re in a heavy streamed area.')
    end
end, false)

-- Keybindable commands (FiveM Settings > Key Bindings)
RegisterKeyMapping('fixtextures', 'Fix texture loss (client)', 'keyboard', '')
RegisterKeyMapping('fixworld', 'Fix falling through map / missing collision (client)', 'keyboard', '')
