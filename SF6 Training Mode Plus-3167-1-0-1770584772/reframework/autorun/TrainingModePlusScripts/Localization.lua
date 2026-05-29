local Localization = {}

Localization.font_file = "TrainingModePlusCN.ttf"

local font = nil
local font_checked = false

local function file_exists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

function Localization.load_font()
    if font_checked then
        return font
    end
    font_checked = true

    if not imgui or not imgui.load_font then
        return nil
    end

    if not file_exists("reframework/fonts/" .. Localization.font_file) then
        return nil
    end

    local font_size = 18
    if imgui.get_default_font_size then
        local ok, default_size = pcall(imgui.get_default_font_size)
        if ok and default_size then
            font_size = default_size
        end
    end

    local glyph_ranges = {
        0x0020,
        0x00FF,
        0x2000,
        0x206F,
        0x3000,
        0x30FF,
        0x31F0,
        0x31FF,
        0x4E00,
        0x9FFF,
        0xFF00,
        0xFFEF,
        0
    }

    local ok, loaded_font = pcall(imgui.load_font, Localization.font_file, font_size, glyph_ranges)
    if ok then
        font = loaded_font
    end

    return font
end

function Localization.push_font()
    local loaded_font = Localization.load_font()
    if loaded_font and imgui.push_font then
        local ok = pcall(imgui.push_font, loaded_font)
        return ok
    end
    return false
end

function Localization.pop_font(font_pushed)
    if font_pushed and imgui.pop_font then
        pcall(imgui.pop_font)
    end
end

function Localization.player_label(player_index)
    return player_index == "p1" and "玩家1" or "玩家2"
end

function Localization.character_name(character_data)
    return character_data.display_name or character_data.name
end

function Localization.resource_name(resource_data)
    return resource_data.display_name or resource_data.name
end

local hotkey_text = {
    ["Clear"] = "清除",
    ["Reset to Default"] = "重置为默认",
    ["Enable Modifier"] = "启用组合键",
    ["Disable Modifier"] = "禁用组合键",
    ["Set Hotkey"] = "设置热键",
    ["Right click for options"] = "右键打开选项"
}

local function translate_hotkey_text(text)
    return hotkey_text[text] or text
end

function Localization.with_hotkey_text_translation(callback)
    local patched_functions = {
        "text",
        "text_colored",
        "button",
        "small_button",
        "checkbox",
        "menu_item",
        "selectable",
        "radio_button",
        "set_tooltip",
        "tooltip",
        "tree_node",
        "collapsing_header"
    }
    local originals = {}

    for _, function_name in ipairs(patched_functions) do
        local original = imgui[function_name]
        if original then
            local ok =
                pcall(
                function()
                    imgui[function_name] = function(label, ...)
                        if type(label) == "string" then
                            label = translate_hotkey_text(label)
                        end
                        return original(label, ...)
                    end
                end
            )
            if ok then
                originals[function_name] = original
            end
        end
    end

    local ok, result = pcall(callback)

    for function_name, original in pairs(originals) do
        imgui[function_name] = original
    end

    if not ok then
        error(result)
    end

    return result
end

return Localization
