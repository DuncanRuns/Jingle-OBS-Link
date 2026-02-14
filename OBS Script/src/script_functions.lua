obs = obslua

-- TODO: Add loop that checks jingle state for walling vs playing and also open projector requests

function script_description()
    return
    [[
    <h1>Jingle OBS Link</h1>
    <p>Links OBS to Jingle.</p>
    <p>Do not remove this script if you want automatic scene switching and projector opening.</p>
    <h2>Press "Regenerate with 'Game Capture'" if you use Minecraft's built-in fullscreen. Otherwise use Window Capture.</h2>
    ]]
end

function script_properties()
    local props = obs.obs_properties_create()

    obs.obs_properties_add_button(
        props, "regenerate_gc_button", "Regenerate With 'Game Capture'", regenerate_gc)
    obs.obs_properties_add_button(
        props, "regenerate_wc_button", "Regenerate With 'Window Capture'", regenerate_wc)

    return props
end

function script_load()
    update_scene_size()
    last_state = get_state_file_string()
end

function script_update(settings)
    if timers_activated then
        return
    end

    timers_activated = true
    obs.timer_add(loop, 20)
    obs.timer_add(update_scene_size, 5000)
end

function update_scene_size()
    local video_info = get_video_info()

    if total_width ~= video_info.base_width or total_height ~= video_info.base_height then
        total_width = video_info.base_width
        total_height = video_info.base_height
    end
end

function regenerate_gc()
    using_win_cap = false
    mc_cap_name = "Jingle MC Capture"
    regenerate()
end

function regenerate_wc()
    using_win_cap = true
    mc_cap_name = "Jingle MC Capture W"
    regenerate()
end

function regenerate()
    local mc_cap = get_or_create_mc_capture()
    local audio_cap = get_or_create_audio_capture()
    local mc_cap_pos = obs.vec2()
    mc_cap_pos.x = total_width / 2
    mc_cap_pos.y = total_height / 2

    setup_recording_scene("Walling", mc_cap, audio_cap, mc_cap_pos)
    setup_recording_scene("Playing", mc_cap, audio_cap, mc_cap_pos)

    release_source(mc_cap)
    release_source(audio_cap)
    set_item_visible("Playing", "Jingle MC Capture", not using_win_cap)
    set_item_visible("Walling", "Jingle MC Capture", not using_win_cap)
    set_item_visible("Playing", "Jingle MC Capture W", using_win_cap)
    set_item_visible("Walling", "Jingle MC Capture W", using_win_cap)
    set_item_visible("Playing", "Minecraft Capture 1", false)
    set_item_visible("Walling", "Minecraft Capture 1", false)
    set_item_visible("Playing", "Julti", false)
    set_item_visible("Walling", "Julti", false)
    set_item_visible("Sound", "Minecraft Audio 1", false)
end

function setup_recording_scene(scene_name, mc_cap, audio_cap, mc_pos)
    if (ensure_scene_exists(scene_name)) then
        local scene = get_scene(scene_name)
        local item = obs.obs_scene_add(scene, mc_cap)
        obs.obs_sceneitem_set_alignment(item, 0)
        obs.obs_sceneitem_set_pos(item, mc_pos)
        obs.obs_scene_add(scene, audio_cap)
        local sound_source = get_source("Sound")
        if sound_source then
            bring_to_bottom(obs.obs_scene_add(scene, sound_source))
            release_source(sound_source)
        end
        return
    end
    local scene = get_scene(scene_name)
    if obs.obs_scene_find_source_recursive(scene, "Sound") == nil then
        local sound_source = get_source("Sound")
        if sound_source then
            bring_to_bottom(obs.obs_scene_add(scene, sound_source))
            release_source(sound_source)
        end
    end
    if obs.obs_scene_find_source_recursive(scene, mc_cap_name) == nil then
        local item = bring_to_bottom(obs.obs_scene_add(scene, mc_cap))
        obs.obs_sceneitem_set_alignment(item, 0)
        obs.obs_sceneitem_set_pos(item, mc_pos)
    end
    if obs.obs_scene_find_source_recursive(scene, "Jingle MC Audio") == nil then
        bring_to_bottom(obs.obs_scene_add(scene, audio_cap))
    end
end

--- Make sure to use release_source() on it afterwards
function get_or_create_mc_capture()
    local source = get_source(mc_cap_name)
    if (source ~= nil) then
        return source
    end

    local settings = nil
    if using_win_cap then
        settings = obs.obs_data_create_from_json('{"priority": 1, "window": "Minecraft* - Instance 1:GLFW30:javaw.exe"}')
    else
        settings = obs.obs_data_create_from_json(
            '{"capture_mode": "window","priority": 1,"window": "Minecraft* - Instance 1:GLFW30:javaw.exe"}')
    end

    if using_win_cap then
        source = obs.obs_source_create("window_capture", mc_cap_name, settings, nil)
    else
        source = obs.obs_source_create("game_capture", mc_cap_name, settings, nil)
    end
    obs.obs_data_release(settings)

    return source
end

--- Make sure to use release_source() on it afterwards
function get_or_create_audio_capture()
    local source = get_source("Jingle MC Audio")
    if (source ~= nil) then
        return source
    end

    local settings = obs.obs_data_create_from_json(
        '{"priority": 1,"window": "Minecraft* - Instance 1:GLFW30:javaw.exe"}')

    source = obs.obs_source_create("wasapi_process_output_capture", "Jingle MC Audio", settings, nil)
    obs.obs_data_release(settings)

    return source
end

function loop()
    local state = get_state_file_string()

    if (state == last_state or state == nil) then
        return
    end

    last_state = state

    local state_args = split_string(state, '|')

    local current_scene_name = get_active_scene_name()

    if (#state_args == 0) then
        return;
    end

    local desired_scene = state_args[1]
    if desired_scene == 'P' and (current_scene_name == "Walling" or current_scene_name == "Jingle Mag") then
        switch_to_scene("Playing")
    end
    if desired_scene == 'W' and (current_scene_name == "Playing" or current_scene_name == "Jingle Mag") then
        switch_to_scene("Walling")
    end

    if #state_args == 1 then
        return;
    end
end
