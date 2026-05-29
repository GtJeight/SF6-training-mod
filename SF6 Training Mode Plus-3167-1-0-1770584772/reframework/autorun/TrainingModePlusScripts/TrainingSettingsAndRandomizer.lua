-- intellinsense
local re = re
local sdk = sdk
local reframework = reframework
local imgui = imgui
local json = json
local l10n = require("TrainingModePlusScripts/Localization")

local module = {
    data = {},
    ui_active = false,
    request_refresh = false,
    request_randomizer = false,
    -- this is the default value, once you override it the config will save the new value
    hotkeys = {
        ["request_randomizer"] = "Select",
        ["request_randomizer_$"] = "L3"
    }
}

local Hotkey = require("Hotkeys/Hotkeys")

local hotkeys_available = Hotkey ~= nil

module.name = "训练设置 + 随机化"
module.description = "用于调整并随机化训练模式设置。可修改体力、斗气、超必杀槽、位置和角色专属资源。"

--[[
    We use the MVC pattern to separate data, logic, and UI.
    The module is what ties all the separate MVC compoenents together.

    The model contains the live game data.
    The controller has variables for logic and states that get saved to memory to reload during different insteances of training sessions.
    The view has variables for UI that can be freely discarted between sessions.
]]
--[[
    player specific parameters (grouped into one since they have very similar and simple logic)
]]
local PlayerParam = {
    model = {
        p1 = {},
        p2 = {}
    },
    view = {
        p1 = {},
        p2 = {}
    },
    controller = {
        p1 = {},
        p2 = {}
    }
}

local function begin_health_config_indent()
    if imgui.indent then
        imgui.indent()
    end
end

local function end_health_config_indent()
    if imgui.unindent then
        imgui.unindent()
    end
end

local function ensure_health_randomizer_defaults(health_randomizer)
    if health_randomizer.enabled == nil then
        health_randomizer.enabled = false
    end
    if health_randomizer.bounds_enabled == nil then
        health_randomizer.bounds_enabled = false
    end
    health_randomizer.lower_bound = health_randomizer.lower_bound or 0
    health_randomizer.upper_bound = health_randomizer.upper_bound or 100

    health_randomizer.mode = "custom"

    if health_randomizer.custom_equal_frequency == nil then
        health_randomizer.custom_equal_frequency = false
    end

    health_randomizer.custom_configs = health_randomizer.custom_configs or {
        {
            enabled = true,
            lower_bound = 100,
            upper_bound = 100,
            frequency = 1
        }
    }

    if #health_randomizer.custom_configs == 0 then
        table.insert(
            health_randomizer.custom_configs,
            {
                enabled = true,
                lower_bound = 100,
                upper_bound = 100,
                frequency = 1
            }
        )
    end

    for _, config in ipairs(health_randomizer.custom_configs) do
        if config.enabled == nil then
            config.enabled = true
        end
        config.lower_bound = math.max(1, math.min(config.lower_bound or 1, 100))
        config.upper_bound = math.max(config.lower_bound, math.min(config.upper_bound or 100, 100))
        config.frequency = math.max(1, math.min(config.frequency or 1, 10))
    end
end

local function ensure_player_health_randomizer_defaults(PlayerController)
    PlayerController.health_randomizer = PlayerController.health_randomizer or {}
    ensure_health_randomizer_defaults(PlayerController.health_randomizer)
end

local function begin_drive_config_indent()
    if imgui.indent then
        imgui.indent()
    end
end

local function end_drive_config_indent()
    if imgui.unindent then
        imgui.unindent()
    end
end

local function ensure_drive_randomizer_defaults(drive_randomizer)
    if drive_randomizer.enabled == nil then
        drive_randomizer.enabled = false
    end
    if drive_randomizer.bounds_enabled == nil then
        drive_randomizer.bounds_enabled = false
    end
    drive_randomizer.lower_bound_stock = drive_randomizer.lower_bound_stock or 0
    drive_randomizer.upper_bound_stock = drive_randomizer.upper_bound_stock or 6
    drive_randomizer.lower_bound_points = drive_randomizer.lower_bound_points or 0
    drive_randomizer.upper_bound_points = drive_randomizer.upper_bound_points or 60000

    drive_randomizer.mode = "custom"

    if drive_randomizer.custom_equal_frequency == nil then
        drive_randomizer.custom_equal_frequency = false
    end

    drive_randomizer.custom_configs = drive_randomizer.custom_configs or {
        {
            enabled = true,
            value = 0,
            frequency = 1
        }
    }

    if #drive_randomizer.custom_configs == 0 then
        table.insert(
            drive_randomizer.custom_configs,
            {
                enabled = true,
                value = 0,
                frequency = 1
            }
        )
    end

    for _, config in ipairs(drive_randomizer.custom_configs) do
        if config.enabled == nil then
            config.enabled = true
        end
        config.value = math.max(-6, math.min(config.value or 0, 6))
        config.frequency = math.max(1, math.min(config.frequency or 1, 10))
    end
end

local function ensure_player_drive_randomizer_defaults(PlayerController)
    PlayerController.drive_randomizer = PlayerController.drive_randomizer or {}
    ensure_drive_randomizer_defaults(PlayerController.drive_randomizer)
end

local function apply_randomized_drive_value(PlayerModel, randomized_value, points_mode)
    if randomized_value < 0 then
        randomized_value = -randomized_value
        PlayerModel.Is_DG_Break = true
    else
        PlayerModel.Is_DG_Break = false
    end

    if points_mode then
        PlayerModel.DG_Point = math.max(0, randomized_value)
        PlayerModel.DG_Stock = math.floor((PlayerModel.DG_Point + 5000) / 10000)
    else
        PlayerModel.DG_Stock = math.max(0, randomized_value)
        PlayerModel.DG_Point = PlayerModel.DG_Stock * 10000
    end
end

function PlayerParam:init_player(PlayerIndex, PlayerParams)
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]

    -- copy the model
    self.model[PlayerIndex] = PlayerParams
    PlayerView.original_drive_type = PlayerParams.DG_Type
    PlayerView.original_drive_point_lock = PlayerParams.Is_DG_Point_Lock
    if PlayerParams.DG_Type ~= 1 then
        PlayerParams.Is_DG_Point_Lock = true
    end

    --[[
        Health parameter initialization
    ]]
    -- define the controller variables
    PlayerController.health_randomizer = {}
    PlayerController.health_randomizer.enabled = false -- health randomizer enabled flag
    PlayerController.health_randomizer.bounds_enabled = false -- health randomizer bounds enabled flag
    PlayerController.health_randomizer.mode = "custom"
    PlayerController.health_randomizer.lower_bound = 0 -- health randomizer lower bound
    PlayerController.health_randomizer.upper_bound = 100 -- health randomizer upper bound
    PlayerController.health_randomizer.custom_equal_frequency = false
    PlayerController.health_randomizer.custom_configs = {
        {
            enabled = true,
            lower_bound = 100,
            upper_bound = 100,
            frequency = 1
        }
    }

    -- define the view variables
    PlayerView.health = PlayerParams.Vital_Point -- current health value
    PlayerView.health_changed = false -- slider changed flag

    --[[ 
    Drive parameter initialization 
    ]]
    -- define the controller variables

    PlayerController.drive_randomizer = {}
    PlayerController.drive_randomizer.enabled = false -- drive randomizer enabled flag
    PlayerController.drive_randomizer.bounds_enabled = false -- drive randomizer bounds enabled flag
    PlayerController.drive_randomizer.mode = "custom"
    PlayerController.drive_randomizer.lower_bound_stock = 0 -- drive randomizer lower bound
    PlayerController.drive_randomizer.upper_bound_stock = 6 -- drive randomizer upper bound
    PlayerController.drive_randomizer.lower_bound_points = 0 -- drive randomizer lower bound
    PlayerController.drive_randomizer.upper_bound_points = 60000 -- drive randomizer upper bound
    PlayerController.drive_randomizer.custom_configs = {
        {
            enabled = true,
            value = 0,
            frequency = 1
        }
    }
    PlayerController.drive_randomizer.custom_equal_frequency = false

    -- define the view variables
    PlayerView.burnout = PlayerParams.Is_DG_Break
    PlayerView.burnout_changed = false

    -- drive type, true == stock, false == custom
    PlayerView.drive_type = true
    PlayerView.drive_type_changed = false

    -- drive stocks
    PlayerView.drive_stocks = PlayerParams.DG_Stock
    PlayerView.drive_stocks_changed = false

    --[[
        Super parameter initialization
    ]]
    PlayerController.super_randomizer = {}
    PlayerController.super_randomizer.enabled = false -- super randomizer enabled flag
    PlayerController.super_randomizer.bounds_enabled = false -- super randomizer bounds enabled flag
    PlayerController.super_randomizer.lower_bound_stock = 0 -- super randomizer lower bound
    PlayerController.super_randomizer.upper_bound_stock = 3 -- super randomizer upper bound
    PlayerController.super_randomizer.lower_bound_points = 0 -- super randomizer lower bound
    PlayerController.super_randomizer.upper_bound_points = 30000 -- super randomizer upper bound

    -- super points type
    PlayerController.super_points_type = false

    -- define the view variables

    -- super type, true == stock, false == custom
    PlayerView.super_type = PlayerParams.SA_Type == 1
    PlayerView.super_type_changed = false

    -- super stocks
    PlayerView.super_stocks = PlayerParams.SA_Stock
    PlayerView.super_stocks_changed = false

    -- super points
    PlayerView.super_points = PlayerParams.SA_Point
    PlayerView.super_points_changed = false
end

function PlayerParam:update_player_parameters(PlayerIndex)
    local PlayerModel = self.model[PlayerIndex]
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]

    local need_apply = false

    -- update health logic
    if not PlayerController.health_randomizer.enabled then
        -- if the randomizer is disabled, use the slider value
        if PlayerView.health_changed then
            PlayerModel.Vital_Point = PlayerView.health
            need_apply = true
        end
    else
        PlayerView.health_changed = false
    end

    -- update drive logic

    if PlayerModel.DG_Type ~= 1 then
        PlayerModel.DG_Type = 1
        PlayerModel.Is_DG_Point_Lock = PlayerView.original_drive_point_lock or false
        need_apply = true
    end

    -- burnout
    if PlayerView.burnout_changed then
        PlayerModel.Is_DG_Break = PlayerView.burnout
        need_apply = true
    end

    if not PlayerController.drive_randomizer.enabled then
        -- if the randomizer is disabled, use the slider value

        if PlayerView.drive_stocks_changed then
            -- stock type
            PlayerModel.DG_Stock = PlayerView.drive_stocks
            PlayerModel.DG_Point = PlayerView.drive_stocks * 10000
            need_apply = true
        end
    else
        PlayerView.drive_stocks_changed = false
    end

    -- update super logic
    if PlayerView.super_type_changed then
        if PlayerView.super_type then
            -- stock type
            PlayerModel.SA_Type = 1
        else
            -- custom type
            PlayerModel.SA_Type = 3
            PlayerModel.Is_SA_Point_Lock = true
        end
        need_apply = true
    end

    if not PlayerController.super_randomizer.enabled then
        -- if the randomizer is disabled, use the slider value

        if PlayerView.super_points_changed then
            -- custom type
            PlayerModel.SA_Point = PlayerView.super_points
            PlayerModel.SA_Stock = math.floor((PlayerView.super_points + 5000) / 10000)
            need_apply = true
        end

        if PlayerView.super_stocks_changed then
            -- stock type
            PlayerModel.SA_Stock = PlayerView.super_stocks
            PlayerModel.SA_Point = PlayerView.super_stocks * 10000
            need_apply = true
        end
    else
        PlayerView.super_points_changed = false
        PlayerView.super_stocks_changed = false
    end

    return need_apply
end

function PlayerParam:randomize_player_health(PlayerIndex)
    if not self.controller[PlayerIndex].health_randomizer.enabled then
        return false
    end

    local PlayerModel = self.model[PlayerIndex]
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]
    local HealthRandomizer = PlayerController.health_randomizer

    ensure_health_randomizer_defaults(HealthRandomizer)

    local total_frequency = 0
    for _, config in ipairs(HealthRandomizer.custom_configs) do
        if config.enabled then
            if HealthRandomizer.custom_equal_frequency then
                total_frequency = total_frequency + 1
            else
                total_frequency = total_frequency + config.frequency
            end
        end
    end

    if total_frequency <= 0 then
        return false
    end

    local random_frequency = math.random(1, total_frequency)
    local accumulated_frequency = 0

    for _, config in ipairs(HealthRandomizer.custom_configs) do
        if config.enabled then
            if HealthRandomizer.custom_equal_frequency then
                accumulated_frequency = accumulated_frequency + 1
            else
                accumulated_frequency = accumulated_frequency + config.frequency
            end

            if random_frequency <= accumulated_frequency then
                PlayerModel.Vital_Point = math.random(config.lower_bound, config.upper_bound)
                return true
            end
        end
    end

    return false
end

function PlayerParam:randomize_player_drive(PlayerIndex)
    if not self.controller[PlayerIndex].drive_randomizer.enabled then
        return false
    end

    local PlayerModel = self.model[PlayerIndex]
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]
    local DriveRandomizer = PlayerController.drive_randomizer

    ensure_drive_randomizer_defaults(DriveRandomizer)

    local total_frequency = 0
    for _, config in ipairs(DriveRandomizer.custom_configs) do
        if config.enabled then
            if DriveRandomizer.custom_equal_frequency then
                total_frequency = total_frequency + 1
            else
                total_frequency = total_frequency + config.frequency
            end
        end
    end

    if total_frequency <= 0 then
        return false
    end

    local random_frequency = math.random(1, total_frequency)
    local accumulated_frequency = 0
    local randomized_stocks = 0

    for _, config in ipairs(DriveRandomizer.custom_configs) do
        if config.enabled then
            if DriveRandomizer.custom_equal_frequency then
                accumulated_frequency = accumulated_frequency + 1
            else
                accumulated_frequency = accumulated_frequency + config.frequency
            end

            if random_frequency <= accumulated_frequency then
                randomized_stocks = config.value
                break
            end
        end
    end

    PlayerModel.DG_Type = 1
    PlayerModel.Is_DG_Point_Lock = PlayerView.original_drive_point_lock or false
    apply_randomized_drive_value(PlayerModel, randomized_stocks, false)
    return true
end

function PlayerParam:randomize_player_super(PlayerIndex)
    if not self.controller[PlayerIndex].super_randomizer.enabled then
        return false
    end

    local PlayerModel = self.model[PlayerIndex]
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]

    -- randomize super logic
    if PlayerView.super_type then
        -- stock type
        local lower_bound = 0
        local upper_bound = 3
        if PlayerController.super_randomizer.bounds_enabled then
            lower_bound = PlayerController.super_randomizer.lower_bound_stock
            upper_bound = PlayerController.super_randomizer.upper_bound_stock
        end
        local randomized_stocks = math.random(lower_bound, upper_bound)
        PlayerModel.SA_Stock = randomized_stocks
        PlayerModel.SA_Point = PlayerModel.SA_Stock * 10000
    else
        -- point type
        local lower_bound = 0
        local upper_bound = 30000
        if PlayerController.super_randomizer.bounds_enabled then
            lower_bound = PlayerController.super_randomizer.lower_bound_points
            upper_bound = PlayerController.super_randomizer.upper_bound_points
        end
        local randomized_points = math.random(lower_bound, upper_bound)
        PlayerModel.SA_Point = randomized_points
        PlayerModel.SA_Stock = math.floor((PlayerModel.SA_Point + 5000) / 10000)
    end

    return true
end

function PlayerParam:draw_health_ui(PlayerIndex)
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]
    local PlayerModel = self.model[PlayerIndex]

    -- draw the health UI

    -- health slider
    if PlayerController.health_randomizer.enabled then
        -- disable the slider if the randomizer is enabled
        imgui.begin_disabled()
    end
    PlayerView.health_changed, PlayerView.health =
        imgui.slider_int("体力百分比", PlayerModel.Vital_Point, 0, 100)

    imgui.separator()

    if PlayerController.health_randomizer.enabled then
        -- stop the health slider disabled section
        imgui.end_disabled()
    end

    -- randomizer checkbox
    _, PlayerController.health_randomizer.enabled =
        imgui.checkbox("启用体力随机化", PlayerController.health_randomizer.enabled)

    if PlayerController.health_randomizer.enabled then
        ensure_health_randomizer_defaults(PlayerController.health_randomizer)

        imgui.separator()
        imgui.text("自定义体力配置")

        _, PlayerController.health_randomizer.custom_equal_frequency =
            imgui.checkbox(
            "统一触发频率",
            PlayerController.health_randomizer.custom_equal_frequency
        )

        local remove_index = nil
        for index, config in ipairs(PlayerController.health_randomizer.custom_configs) do
            imgui.separator()

            _, config.enabled = imgui.checkbox("体力配置 " .. tostring(index), config.enabled)
            begin_health_config_indent()

            if not config.enabled then
                imgui.begin_disabled()
            end

            _, config.lower_bound =
                imgui.drag_int(
                "配置 " .. tostring(index) .. " 体力下限",
                config.lower_bound,
                0.3,
                1,
                config.upper_bound
            )
            _, config.upper_bound =
                imgui.drag_int(
                "配置 " .. tostring(index) .. " 体力上限",
                config.upper_bound,
                0.3,
                config.lower_bound,
                100
            )
            if PlayerController.health_randomizer.custom_equal_frequency then
                imgui.begin_disabled()
            end
            _, config.frequency =
                imgui.slider_int(
                "配置 " .. tostring(index) .. " 权重（1到10）",
                config.frequency,
                1,
                10
            )
            if PlayerController.health_randomizer.custom_equal_frequency then
                imgui.end_disabled()
            end

            if not config.enabled then
                imgui.end_disabled()
            end

            if
                #PlayerController.health_randomizer.custom_configs > 1 and
                    imgui.button("删除体力配置 " .. tostring(index))
             then
                remove_index = index
            end
            end_health_config_indent()
        end

        if remove_index ~= nil then
            table.remove(PlayerController.health_randomizer.custom_configs, remove_index)
        end

        imgui.separator()
        if imgui.button("添加体力配置") then
            table.insert(
                PlayerController.health_randomizer.custom_configs,
                {
                    enabled = true,
                    lower_bound = 100,
                    upper_bound = 100,
                    frequency = 1
                }
            )
        end
    end
end

function PlayerParam:draw_drive_ui(PlayerIndex)
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]
    local PlayerModel = self.model[PlayerIndex]

    -- drive slider(s)

    if PlayerController.drive_randomizer.enabled then
        -- disable the slider if the randomizer is enabled
        imgui.begin_disabled()
    end

    PlayerView.drive_stocks_changed, PlayerView.drive_stocks =
        imgui.slider_int("斗气库存", PlayerModel.DG_Stock, 0, 6)

    -- burnout toggle
    PlayerView.burnout_changed, PlayerView.burnout =
        imgui.checkbox("斗气枯竭", PlayerModel.Is_DG_Break)

    imgui.separator()

    if PlayerController.drive_randomizer.enabled then
        -- stop the drive slider disabled section
        imgui.end_disabled()
    end

    -- randomizer checkbox
    _, PlayerController.drive_randomizer.enabled =
        imgui.checkbox("启用斗气随机化", PlayerController.drive_randomizer.enabled)

    if PlayerController.drive_randomizer.enabled then
        ensure_drive_randomizer_defaults(PlayerController.drive_randomizer)

        imgui.separator()
        imgui.text("自定义斗气配置")

        _, PlayerController.drive_randomizer.custom_equal_frequency =
            imgui.checkbox(
            "统一触发频率",
            PlayerController.drive_randomizer.custom_equal_frequency
        )

        local remove_index = nil
        for index, config in ipairs(PlayerController.drive_randomizer.custom_configs) do
            imgui.separator()

            _, config.enabled = imgui.checkbox("斗气配置 " .. tostring(index), config.enabled)
            begin_drive_config_indent()

            if not config.enabled then
                imgui.begin_disabled()
            end
            _, config.value =
                imgui.slider_int("配置 " .. tostring(index) .. " 斗气值（-6到6）", config.value, -6, 6)

            if PlayerController.drive_randomizer.custom_equal_frequency then
                imgui.begin_disabled()
            end
            _, config.frequency =
                imgui.slider_int("配置 " .. tostring(index) .. " 权重（1到10）", config.frequency, 1, 10)
            if PlayerController.drive_randomizer.custom_equal_frequency then
                imgui.end_disabled()
            end

            if not config.enabled then
                imgui.end_disabled()
            end

            if
                #PlayerController.drive_randomizer.custom_configs > 1 and
                    imgui.button("删除配置 " .. tostring(index))
             then
                remove_index = index
            end
            end_drive_config_indent()
        end

        if remove_index ~= nil then
            table.remove(PlayerController.drive_randomizer.custom_configs, remove_index)
        end

        imgui.separator()
        if imgui.button("添加斗气配置") then
            table.insert(
                PlayerController.drive_randomizer.custom_configs,
                {
                    enabled = true,
                    value = 0,
                    frequency = 1
                }
            )
        end
    end
end

function PlayerParam:draw_super_ui(PlayerIndex)
    local PlayerView = self.view[PlayerIndex]
    local PlayerController = self.controller[PlayerIndex]
    local PlayerModel = self.model[PlayerIndex]

    -- super slider(s)
    if PlayerController.super_randomizer.enabled then
        -- disable the slider if the randomizer is enabled
        imgui.begin_disabled()
    end

    -- super sliders based on type
    if PlayerView.super_type then
        -- stock type
        PlayerView.super_stocks_changed, PlayerView.super_stocks =
            imgui.slider_int("超必杀库存", PlayerModel.SA_Stock, 0, 3)
    else
        -- custom type
        if PlayerController.super_points_type then
            -- absolute type
            PlayerView.super_points_changed, PlayerView.super_points =
                imgui.drag_int("超必杀点数", PlayerModel.SA_Point, 1, 0, 30000)
        else
            -- percentage type
            local points_increments = 0
            local current_points = PlayerModel.SA_Point / 10000
            PlayerView.super_points_changed, points_increments =
                imgui.slider_float(
                "超必杀点数（按10%库存递增）",
                current_points,
                0,
                3,
                "%.1f"
            )
            -- convert to points
            PlayerView.super_points = math.floor(points_increments * 10000)
        end
    end

    imgui.separator()

    if PlayerController.super_randomizer.enabled then
        imgui.end_disabled()
    end

    -- stock vs points checkbox
    local type_value = PlayerModel.SA_Type == 1
    PlayerView.super_type_changed, PlayerView.super_type =
        imgui.checkbox("切换超必杀类型（库存 / 点数）", type_value)

    -- on points, show percentage vs absolute toggle
    if not PlayerView.super_type then
        imgui.same_line()
        _, PlayerController.super_points_type =
            imgui.checkbox(
            "切换超必杀点数类型（绝对值 / 百分比）",
            PlayerController.super_points_type
        )
    end

    -- randomizer checkbox
    _, PlayerController.super_randomizer.enabled =
        imgui.checkbox("启用超必杀槽随机化", PlayerController.super_randomizer.enabled)
    -- if randomizer bounds enable checkbox
    if PlayerController.super_randomizer.enabled then
        -- show the bounds enable checkbox

        _, PlayerController.super_randomizer.bounds_enabled =
            imgui.checkbox(
            "统一设定超必杀槽随机化范围",
            PlayerController.super_randomizer.bounds_enabled
        )

        if PlayerController.super_randomizer.bounds_enabled then
            -- show the bounds sliders based on type

            if PlayerView.super_type then
                -- stock type
                _, PlayerController.super_randomizer.lower_bound_stock =
                    imgui.drag_int(
                    "超必杀库存随机下限",
                    PlayerController.super_randomizer.lower_bound_stock,
                    0.3,
                    0,
                    PlayerController.super_randomizer.upper_bound_stock
                )
                _, PlayerController.super_randomizer.upper_bound_stock =
                    imgui.drag_int(
                    "超必杀库存随机上限",
                    PlayerController.super_randomizer.upper_bound_stock,
                    0.3,
                    PlayerController.super_randomizer.lower_bound_stock,
                    3
                )
            else
                -- point type
                if PlayerController.super_points_type then
                    -- absolute type
                    _, PlayerController.super_randomizer.lower_bound_points =
                        imgui.drag_int(
                        "超必杀点数随机下限",
                        PlayerController.super_randomizer.lower_bound_points,
                        1,
                        0,
                        PlayerController.super_randomizer.upper_bound_points
                    )
                    _, PlayerController.super_randomizer.upper_bound_points =
                        imgui.drag_int(
                        "超必杀点数随机上限",
                        PlayerController.super_randomizer.upper_bound_points,
                        1,
                        PlayerController.super_randomizer.lower_bound_points,
                        30000
                    )
                else
                    -- percentage type
                    local points_increments_lb = 0
                    local current_points_lb = PlayerController.super_randomizer.lower_bound_points / 10000

                    local points_increments_ub = 0
                    local current_points_ub = PlayerController.super_randomizer.upper_bound_points / 10000

                    _, points_increments_lb =
                        imgui.drag_float(
                        "超必杀点数随机下限（按10%库存递增）",
                        current_points_lb,
                        0.1,
                        0,
                        current_points_ub,
                        "%.1f"
                    )
                    PlayerController.super_randomizer.lower_bound_points = math.floor(points_increments_lb * 10000)
                    _, points_increments_ub =
                        imgui.drag_float(
                        "超必杀点数随机上限（按10%库存递增）",
                        current_points_ub,
                        0.1,
                        points_increments_lb,
                        3,
                        "%.1f"
                    )
                    PlayerController.super_randomizer.upper_bound_points = math.floor(points_increments_ub * 10000)
                end
            end
        end
    end
end

function PlayerParam:init(ParameterSettingsData)
    self:init_player("p1", ParameterSettingsData.PlayerDatas[0])
    self:init_player("p2", ParameterSettingsData.PlayerDatas[1])
end

function PlayerParam:draw_ui()
    if imgui.tree_node("体力") then
        if imgui.tree_node("玩家1 体力") then
            self:draw_health_ui("p1")
            imgui.tree_pop()
        end
        if imgui.tree_node("玩家2 体力") then
            self:draw_health_ui("p2")
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end
    if imgui.tree_node("斗气") then
        if imgui.tree_node("玩家1 斗气") then
            self:draw_drive_ui("p1")
            imgui.tree_pop()
        end
        if imgui.tree_node("玩家2 斗气") then
            self:draw_drive_ui("p2")
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end
    if imgui.tree_node("超必杀槽") then
        if imgui.tree_node("玩家1 超必杀槽") then
            self:draw_super_ui("p1")
            imgui.tree_pop()
        end
        if imgui.tree_node("玩家2 超必杀槽") then
            self:draw_super_ui("p2")
            imgui.tree_pop()
        end
        imgui.tree_pop()
    end
end

function PlayerParam:update()
    -- update logic for player parameters

    local need_apply = false

    need_apply = self:update_player_parameters("p1") or need_apply
    need_apply = self:update_player_parameters("p2") or need_apply

    return need_apply
end

function PlayerParam:randomize()
    -- randomization logic for player parameters
    local need_apply = false

    need_apply = self:randomize_player_health("p1") or need_apply
    need_apply = self:randomize_player_health("p2") or need_apply
    need_apply = self:randomize_player_drive("p1") or need_apply
    need_apply = self:randomize_player_drive("p2") or need_apply
    need_apply = self:randomize_player_super("p1") or need_apply
    need_apply = self:randomize_player_super("p2") or need_apply

    return need_apply
end

--[[
    Unique character gauges
]]
module.data.UniqueCharData = require("TrainingModePlusScripts/UniqueCharacterParametersData")

local UniqueGaugeParam = {
    model = {},
    view = {},
    controller = {}
}

function UniqueGaugeParam:init(ParameterSettingsData)
    -- unique gauge parameter initialization
    self.model = ParameterSettingsData

    for _, charData in pairs(module.data.UniqueCharData) do
        self.view[charData.name] = {}
        self.controller[charData.name] = {}
        -- initialize timers ui data
        if charData.timers then
            for _, timerData in pairs(charData.timers) do
                self.view[charData.name][timerData.id] = {}
                self.controller[charData.name][timerData.id] = {}

                self.view[charData.name][timerData.id].timer_combo_value = 1
                self.view[charData.name][timerData.id].timer_combo_changed = false

                -- randomizer settings
                self.controller[charData.name][timerData.id].randomizer_enabled = false

                if timerData.install == true then
                    -- this is the only case we need to store the start value
                    self.controller[charData.name][timerData.id].installed_start_value = timerData.timerMaxValue
                    self.view[charData.name][timerData.id].installed_start_value_changed = false

                    -- randomizer for install timers

                    -- probability of it being disabled when randomized, default is 50%
                    self.controller[charData.name][timerData.id].disabled_prob_percentage = 50

                    self.controller[charData.name][timerData.id].bounds_enabled = false
                    self.controller[charData.name][timerData.id].lower_bound = 0
                    self.controller[charData.name][timerData.id].upper_bound = timerData.timerMaxValue
                end
            end
        end
        -- initialize stocks ui data
        if charData.stocks then
            for _, stockData in pairs(charData.stocks) do
                self.view[charData.name][stockData.id] = {}
                self.controller[charData.name][stockData.id] = {}

                self.view[charData.name][stockData.id].stock_slider = 0
                self.view[charData.name][stockData.id].stock_slider_changed = false
                self.view[charData.name][stockData.id].infinite_checkbox = false
                self.view[charData.name][stockData.id].infinite_checkbox_changed = false

                -- randomizer settings
                self.controller[charData.name][stockData.id].randomizer_enabled = false
                self.controller[charData.name][stockData.id].bounds_enabled = false
                self.controller[charData.name][stockData.id].lower_bound = stockData.minValue
                self.controller[charData.name][stockData.id].upper_bound = stockData.maxValue
            end
        end
    end
end

function UniqueGaugeParam:ensure_controller_defaults()
    for _, charData in pairs(module.data.UniqueCharData) do
        self.controller[charData.name] = self.controller[charData.name] or {}

        if charData.timers then
            for _, timerData in pairs(charData.timers) do
                self.controller[charData.name][timerData.id] = self.controller[charData.name][timerData.id] or {}
                local controller = self.controller[charData.name][timerData.id]

                if controller.randomizer_enabled == nil then
                    controller.randomizer_enabled = false
                end

                if timerData.install == true then
                    controller.installed_start_value = controller.installed_start_value or timerData.timerMaxValue
                    if controller.disabled_prob_percentage == nil then
                        controller.disabled_prob_percentage = 50
                    end
                    if controller.bounds_enabled == nil then
                        controller.bounds_enabled = false
                    end
                    controller.lower_bound = controller.lower_bound or 0
                    controller.upper_bound = controller.upper_bound or timerData.timerMaxValue
                end
            end
        end

        if charData.stocks then
            for _, stockData in pairs(charData.stocks) do
                self.controller[charData.name][stockData.id] = self.controller[charData.name][stockData.id] or {}
                local controller = self.controller[charData.name][stockData.id]

                if controller.randomizer_enabled == nil then
                    controller.randomizer_enabled = false
                end
                if controller.bounds_enabled == nil then
                    controller.bounds_enabled = false
                end
                controller.lower_bound = controller.lower_bound or stockData.minValue
                controller.upper_bound = controller.upper_bound or stockData.maxValue
            end
        end
    end
end

function UniqueGaugeParam:update()
    local char_id1 = module.data.SelectMenu.PlayerDatas[0].FighterID
    local char_id2 = module.data.SelectMenu.PlayerDatas[1].FighterID
    local char_datas
    if char_id1 == char_id2 then
        char_datas = {module.data.UniqueCharData[char_id1]}
    else
        char_datas = {module.data.UniqueCharData[char_id1], module.data.UniqueCharData[char_id2]}
    end

    local need_refresh = false
    -- unique gauge parameter update logic
    for index, char_data in pairs(char_datas) do
        if char_data then
            -- update timers
            if char_data.timers then
                for _, timerData in pairs(char_data.timers) do
                    local ui_timer = self.view[char_data.name][timerData.id]
                    if ui_timer.timer_combo_changed then
                        -- set the unique gauge data based on the selected value
                        self.model[timerData.id] = ui_timer.timer_combo_value - 1
                        need_refresh = true
                    end
                    -- add logic for the timer later
                    if timerData.install == true and ui_timer.timer_combo_value == 2 then
                        -- set the installed start value somewhere
                        local liveData = nil
                        if index == 1 then
                            liveData = module.data.live_P1
                        else
                            liveData = module.data.live_P2
                        end
                        if module.data.sGame.stage_timer == 1 then
                            liveData.style_timer = self.controller[char_data.name][timerData.id].installed_start_value
                        end
                    end
                    if ui_timer.installed_start_value_changed then
                        need_refresh = true
                    end
                end
            end

            -- update stocks
            if char_data.stocks then
                for _, stockData in pairs(char_data.stocks) do
                    local ui_stock = self.view[char_data.name][stockData.id]
                    if ui_stock.infinite_checkbox_changed then
                        if ui_stock.infinite_checkbox then
                            self.model[stockData.id] = 7
                        else
                            self.model[stockData.id] = ui_stock.stock_slider
                        end
                        need_refresh = true
                    end
                    if ui_stock.stock_slider_changed then
                        self.model[stockData.id] = ui_stock.stock_slider
                        need_refresh = true
                    end
                end
            end
        end
    end
    return need_refresh
end

function UniqueGaugeParam:randomize()
    local char_id1 = module.data.SelectMenu.PlayerDatas[0].FighterID
    local char_id2 = module.data.SelectMenu.PlayerDatas[1].FighterID
    local char_datas
    if char_id1 == char_id2 then
        char_datas = {module.data.UniqueCharData[char_id1]}
    else
        char_datas = {module.data.UniqueCharData[char_id1], module.data.UniqueCharData[char_id2]}
    end

    -- unique gauge parameter randomization logic
    for _, char_data in pairs(char_datas) do
        if char_data then
            -- randomize timers
            if char_data.timers then
                for _, timerData in pairs(char_data.timers) do
                    local controller = self.controller[char_data.name][timerData.id]
                    if controller.randomizer_enabled then
                        -- first calculate the disabled probability
                        local rand_percentage = math.random(0, 100)
                        if timerData.install == true and rand_percentage < controller.disabled_prob_percentage then
                            -- set to disabled
                            self.model[timerData.id] = 0
                        else
                            if timerData.install == true then
                                -- enable it
                                self.model[timerData.id] = 1
                            else
                                self.model[timerData.id] = math.random(0, 1)
                            end

                            -- if it's an install timer, set the start value
                            if timerData.install == true then
                                -- randomize the timer starting value
                                local lower_bound = 0
                                local upper_bound = timerData.timerMaxValue
                                if controller.bounds_enabled then
                                    lower_bound = controller.lower_bound
                                    upper_bound = controller.upper_bound
                                end

                                self.controller[char_data.name][timerData.id].installed_start_value =
                                    math.random(lower_bound, upper_bound)
                            end
                        end
                    end
                end
            end

            -- randomize stocks
            if char_data.stocks then
                for _, stockData in pairs(char_data.stocks) do
                    local controller = self.controller[char_data.name][stockData.id]
                    if controller.randomizer_enabled then
                        local lower_bound = stockData.minValue
                        local upper_bound = stockData.maxValue
                        if controller.bounds_enabled then
                            lower_bound = controller.lower_bound
                            upper_bound = controller.upper_bound
                        end
                        local random_value = math.random(lower_bound, upper_bound)
                        self.model[stockData.id] = random_value
                    end
                end
            end
        end
    end
end

function UniqueGaugeParam:draw_ui()
    local char_id1 = module.data.SelectMenu.PlayerDatas[0].FighterID
    local char_id2 = module.data.SelectMenu.PlayerDatas[1].FighterID
    local char_datas
    if char_id1 == char_id2 then
        char_datas = {module.data.UniqueCharData[char_id1]}
    else
        char_datas = {module.data.UniqueCharData[char_id1], module.data.UniqueCharData[char_id2]}
    end

    local any_installed_timer = false

    for _, char_data in pairs(char_datas) do
        if char_data then
            imgui.text("角色：" .. l10n.character_name(char_data))
            -- draw timers
            if char_data.timers then
                for _, timerData in pairs(char_data.timers) do
                    if any_installed_timer then
                        imgui.separator()
                    end
                    any_installed_timer = true

                    local current_value = self.model[timerData.id]
                    -- use stored timer ui values
                    local ui_timer = self.view[char_data.name][timerData.id]
                    local descriptor = timerData.descriptors[current_value + 1]
                    local timer_label = l10n.resource_name(timerData)
                    imgui.text(timer_label .. "：" .. descriptor)

                    local controller = self.controller[char_data.name][timerData.id]

                    if controller.randomizer_enabled then
                        imgui.begin_disabled()
                    end

                    -- use stored slider value as current so it persists
                    ui_timer.timer_combo_changed, ui_timer.timer_combo_value =
                        imgui.combo(timer_label .. " 数值", current_value + 1, timerData.descriptors)
                    if timerData.install == true and current_value == 1 then
                        -- installed timer UI elements
                        ui_timer.installed_start_value_changed,
                            self.controller[char_data.name][timerData.id].installed_start_value =
                            imgui.slider_int(
                            timer_label .. " 起始发动值",
                            self.controller[char_data.name][timerData.id].installed_start_value,
                            0,
                            timerData.timerMaxValue
                        )
                        if imgui.is_item_active() then
                            module.ui_active = true
                        end
                    end

                    if controller.randomizer_enabled then
                        imgui.end_disabled()
                    end

                    if current_value ~= 2 then
                        -- randomizer checkbox
                        _, controller.randomizer_enabled =
                            imgui.checkbox(
                            "启用" .. timer_label .. "随机化",
                            controller.randomizer_enabled
                        )

                        if controller.randomizer_enabled and timerData.install == true then
                            -- randomizer disabled probability
                            _, controller.disabled_prob_percentage =
                                imgui.slider_int(
                                timer_label .. "随机后禁用概率（%）",
                                controller.disabled_prob_percentage,
                                0,
                                100
                            )

                            -- bounds only enabled for installs with timer, no reason to have them otherwise
                            if timerData.install == true then
                                -- bounds enable checkbox
                                _, controller.bounds_enabled =
                                    imgui.checkbox(
                                    "启用" .. timer_label .. "随机化范围",
                                    controller.bounds_enabled
                                )
                                if controller.bounds_enabled then
                                    -- show the bounds sliders
                                    _, controller.lower_bound =
                                        imgui.drag_int(
                                        timer_label .. "随机下限",
                                        controller.lower_bound,
                                        0.3,
                                        0,
                                        controller.upper_bound
                                    )
                                    _, controller.upper_bound =
                                        imgui.drag_int(
                                        timer_label .. "随机上限",
                                        controller.upper_bound,
                                        0.3,
                                        controller.lower_bound,
                                        timerData.timerMaxValue
                                    )
                                end
                            end
                        end
                    end
                end
            end

            -- draw stocks
            if char_data.stocks then
                for _, stockData in pairs(char_data.stocks) do
                    if any_installed_timer then
                        imgui.separator()
                    end
                    any_installed_timer = true

                    local current_value = self.model[stockData.id]
                    -- check for value == 7 (infinite)
                    local descriptor
                    if current_value == 7 then
                        descriptor = "无限"
                    else
                        descriptor = stockData.descriptors[current_value + 1]
                    end
                    -- use stored stock ui values
                    local ui_stock = self.view[char_data.name][stockData.id]
                    local stock_label = l10n.resource_name(stockData)
                    imgui.text(stock_label .. "：" .. descriptor)

                    local controller = self.controller[char_data.name][stockData.id]

                    if controller.randomizer_enabled then
                        imgui.begin_disabled()
                    end

                    if stockData.allowInfinite then
                        ui_stock.infinite_checkbox_changed, ui_stock.infinite_checkbox =
                            imgui.checkbox("启用无限" .. stock_label, current_value == 7)
                    end
                    -- if infinite is enabled, don't show the slider
                    if current_value ~= 7 then
                        ui_stock.stock_slider_changed, ui_stock.stock_slider =
                            imgui.slider_int(
                            stock_label .. " 数值",
                            current_value,
                            stockData.minValue,
                            stockData.maxValue
                        )
                        if not stockData.correspond then
                            imgui.text_colored(
                                "警告：滑条数值与游戏内显示不完全对应，请以“" .. stock_label .. "：#”显示为准。",
                                0xFF00A9F9
                            )
                        end

                        imgui.separator()
                    end

                    if controller.randomizer_enabled then
                        imgui.end_disabled()
                    end

                    if current_value ~= 7 then
                        -- randomizer checkbox
                        _, controller.randomizer_enabled =
                            imgui.checkbox(
                            "启用" .. stock_label .. "随机化",
                            controller.randomizer_enabled
                        )

                        if controller.randomizer_enabled then
                            _, controller.bounds_enabled =
                                imgui.checkbox(
                                "启用" .. stock_label .. "随机化范围",
                                controller.bounds_enabled
                            )
                            if controller.bounds_enabled then
                                -- show the bounds sliders
                                _, controller.lower_bound =
                                    imgui.drag_int(
                                    stock_label .. "随机下限",
                                    controller.lower_bound,
                                    0.3,
                                    stockData.minValue,
                                    controller.upper_bound
                                )
                                _, controller.upper_bound =
                                    imgui.drag_int(
                                    stock_label .. "随机上限",
                                    controller.upper_bound,
                                    0.3,
                                    controller.lower_bound,
                                    stockData.maxValue
                                )
                            end
                        end
                    end
                end
            end
        end
    end
    if not any_installed_timer then
        imgui.text_colored("这些角色没有可用的专属资源设置。", 0xFF00A9F9)
    end
end

--[[
    Position parameters 
]]
module.data.PositionParametersData = require("TrainingModePlusScripts/PositionParametersData")

local PositionalParam = {
    model = {},
    view = {},
    controller = {},
    hooks_initialized = false
}

local POSITION_ADJUSTMENT_MODE_CUSTOM = 2

local CUSTOM_POSITION_SIDE_RANDOM = 1
local CUSTOM_POSITION_SIDE_PLAYER_LEFT = 2
local CUSTOM_POSITION_SIDE_PLAYER_RIGHT = 3
local CUSTOM_POSITION_SIDE_NAMES = {
    "随机",
    "玩家在左侧",
    "玩家在右侧"
}

local function begin_position_config_indent()
    if imgui.indent then
        imgui.indent()
    end
end

local function end_position_config_indent()
    if imgui.unindent then
        imgui.unindent()
    end
end

local function clamp_position_value(value)
    return math.max(
        module.data.PositionParametersData.default_screen_position.min,
        math.min(value or 0.0, module.data.PositionParametersData.default_screen_position.max)
    )
end

local function clamp_discrete_position_value(value)
    return math.max(-6, math.min(value or 0, 6))
end

local function discrete_position_to_absolute(discrete_value)
    local min_pos = module.data.PositionParametersData.default_screen_position.min
    local max_pos = module.data.PositionParametersData.default_screen_position.max
    return min_pos + ((clamp_discrete_position_value(discrete_value) + 6) / 12) * (max_pos - min_pos)
end

local function absolute_position_to_discrete(position)
    local min_pos = module.data.PositionParametersData.default_screen_position.min
    local max_pos = module.data.PositionParametersData.default_screen_position.max
    return clamp_discrete_position_value(math.floor(((clamp_position_value(position) - min_pos) / (max_pos - min_pos)) * 12 + 0.5) - 6)
end

local function clamp_relative_distance_preset_index(index)
    local max_index = #module.data.PositionParametersData.preset_relative_distance_offsets.names
    return math.max(1, math.min(index or 1, max_index))
end

local function relative_distance_preset_to_value(index, min_distance, max_distance)
    if index ~= #module.data.PositionParametersData.preset_relative_distance_offsets.values + 1 then
        return min_distance + module.data.PositionParametersData.preset_relative_distance_offsets.values[index]
    end

    return max_distance
end

local function relative_distance_to_preset_index(distance, min_distance, max_distance)
    local closest_index = 1
    local closest_distance = math.abs(distance - relative_distance_preset_to_value(1, min_distance, max_distance))

    for index = 2, #module.data.PositionParametersData.preset_relative_distance_offsets.names do
        local candidate_distance = relative_distance_preset_to_value(index, min_distance, max_distance)
        local distance_delta = math.abs(distance - candidate_distance)
        if distance_delta < closest_distance then
            closest_distance = distance_delta
            closest_index = index
        end
    end

    return closest_index
end

local function clamp_custom_position_side(side_index)
    if
        side_index ~= CUSTOM_POSITION_SIDE_RANDOM and side_index ~= CUSTOM_POSITION_SIDE_PLAYER_LEFT and
            side_index ~= CUSTOM_POSITION_SIDE_PLAYER_RIGHT
     then
        return CUSTOM_POSITION_SIDE_RANDOM
    end

    return side_index
end

local function is_resolved_custom_position_side(side_index)
    return side_index == CUSTOM_POSITION_SIDE_PLAYER_LEFT or side_index == CUSTOM_POSITION_SIDE_PLAYER_RIGHT
end

local function random_custom_position_side()
    if math.random(0, 1) == 0 then
        return CUSTOM_POSITION_SIDE_PLAYER_LEFT
    end

    return CUSTOM_POSITION_SIDE_PLAYER_RIGHT
end

function PositionalParam:ensure_custom_position_defaults()
    self.controller.screen_position = self.controller.screen_position or {}
    self.controller.screen_position.adjustment_mode = POSITION_ADJUSTMENT_MODE_CUSTOM

    self.controller.custom_position = self.controller.custom_position or {}
    local custom_position = self.controller.custom_position

    if custom_position.override_start_position_enabled == nil then
        custom_position.override_start_position_enabled = false
    end
    custom_position.override_start_position = clamp_position_value(custom_position.override_start_position or 0.0)
    custom_position.override_discrete_start_position =
        clamp_discrete_position_value(
        custom_position.override_discrete_start_position or absolute_position_to_discrete(custom_position.override_start_position)
    )

    if custom_position.override_relative_distance_enabled == nil then
        custom_position.override_relative_distance_enabled = false
    end
    custom_position.override_relative_distance =
        math.max(
        self.controller.relative_distance.min,
        math.min(custom_position.override_relative_distance or self.controller.relative_distance.min, self.controller.relative_distance.max)
    )
    custom_position.override_relative_distance_preset_index =
        clamp_relative_distance_preset_index(
        custom_position.override_relative_distance_preset_index or
            relative_distance_to_preset_index(
                custom_position.override_relative_distance,
                self.controller.relative_distance.min,
                self.controller.relative_distance.max
            )
    )

    if custom_position.override_side_enabled == nil then
        custom_position.override_side_enabled = false
    end
    custom_position.override_side_index = clamp_custom_position_side(custom_position.override_side_index)
    if
        custom_position.override_resolved_side_index ~= nil and
            not is_resolved_custom_position_side(custom_position.override_resolved_side_index)
     then
        custom_position.override_resolved_side_index = nil
    end

    if custom_position.equal_frequency == nil then
        custom_position.equal_frequency = false
    end
    if custom_position.discrete_position_enabled == nil then
        custom_position.discrete_position_enabled = true
    end
    if custom_position.discrete_distance_enabled == nil then
        custom_position.discrete_distance_enabled = true
    end

    custom_position.configs = custom_position.configs or {
        {
            enabled = true,
            start_position = 0.0,
            discrete_start_position = 0,
            relative_distance = self.controller.relative_distance.min,
            relative_distance_preset_index = 1,
            side_index = CUSTOM_POSITION_SIDE_RANDOM,
            frequency = 1
        }
    }

    if #custom_position.configs == 0 then
        table.insert(
            custom_position.configs,
            {
                enabled = true,
                start_position = 0.0,
                discrete_start_position = 0,
                relative_distance = self.controller.relative_distance.min,
                relative_distance_preset_index = 1,
                side_index = CUSTOM_POSITION_SIDE_RANDOM,
                frequency = 1
            }
        )
    end

    for _, config in ipairs(custom_position.configs) do
        if config.enabled == nil then
            config.enabled = true
        end
        config.start_position = clamp_position_value(config.start_position or 0.0)
        config.discrete_start_position =
            clamp_discrete_position_value(config.discrete_start_position or absolute_position_to_discrete(config.start_position))
        config.relative_distance =
            math.max(
            self.controller.relative_distance.min,
            math.min(config.relative_distance or self.controller.relative_distance.min, self.controller.relative_distance.max)
        )
        config.relative_distance_preset_index =
            clamp_relative_distance_preset_index(
            config.relative_distance_preset_index or
                relative_distance_to_preset_index(
                    config.relative_distance,
                    self.controller.relative_distance.min,
                    self.controller.relative_distance.max
                )
        )
        config.side_index = clamp_custom_position_side(config.side_index)
        if config.resolved_side_index ~= nil and not is_resolved_custom_position_side(config.resolved_side_index) then
            config.resolved_side_index = nil
        end
        config.frequency = math.max(1, math.min(config.frequency or 1, 10))
    end
end

function PositionalParam:get_active_custom_position_config()
    local custom_position = self.controller.custom_position
    local current_config_index = custom_position.current_config_index
    local current_config = current_config_index and custom_position.configs[current_config_index]

    if current_config and current_config.enabled then
        return current_config
    end

    for index, config in ipairs(custom_position.configs) do
        if config.enabled then
            custom_position.current_config_index = index
            return config
        end
    end

    custom_position.current_config_index = nil
    return nil
end

function PositionalParam:resolve_custom_position_side(config, reroll_random)
    local custom_position = self.controller.custom_position
    local side_index = config.side_index

    if custom_position.override_side_enabled then
        side_index = custom_position.override_side_index
    end

    if side_index ~= CUSTOM_POSITION_SIDE_RANDOM then
        return side_index
    end

    if custom_position.override_side_enabled then
        if reroll_random or not is_resolved_custom_position_side(custom_position.override_resolved_side_index) then
            custom_position.override_resolved_side_index = random_custom_position_side()
        end

        return custom_position.override_resolved_side_index
    end

    if reroll_random or not is_resolved_custom_position_side(config.resolved_side_index) then
        config.resolved_side_index = random_custom_position_side()
    end

    return config.resolved_side_index
end

function PositionalParam:apply_custom_position_config(config)
    local char_id1 = self.model.PlayerDatas[0].FighterID
    local char_id2 = self.model.PlayerDatas[1].FighterID
    local offset1 = module.data.PositionParametersData.character_relative_distance_offsets[char_id1] or 0.0
    local offset2 = module.data.PositionParametersData.character_relative_distance_offsets[char_id2] or 0.0
    local total_offset = offset1 + offset2

    local custom_position = self.controller.custom_position
    local start_position = config.start_position
    if custom_position.discrete_position_enabled then
        start_position = discrete_position_to_absolute(config.discrete_start_position)
    end
    if custom_position.override_start_position_enabled then
        start_position = custom_position.override_start_position
        if custom_position.discrete_position_enabled then
            start_position = discrete_position_to_absolute(custom_position.override_discrete_start_position)
        end
    end

    local relative_distance = config.relative_distance
    if custom_position.discrete_distance_enabled then
        relative_distance =
            relative_distance_preset_to_value(
            config.relative_distance_preset_index,
            self.controller.relative_distance.min,
            self.controller.relative_distance.max
        )
    end
    if custom_position.override_relative_distance_enabled then
        relative_distance = custom_position.override_relative_distance
        if custom_position.discrete_distance_enabled then
            relative_distance =
                relative_distance_preset_to_value(
                custom_position.override_relative_distance_preset_index,
                self.controller.relative_distance.min,
                self.controller.relative_distance.max
            )
        end
    end

    local side_index = self:resolve_custom_position_side(config, false)

    local manual_distance = relative_distance + total_offset
    local left_pos = start_position - (manual_distance / 2.0)
    local right_pos = start_position + (manual_distance / 2.0)
    local screen_min = module.data.PositionParametersData.default_screen_position.min
    local screen_max = module.data.PositionParametersData.default_screen_position.max

    if left_pos < screen_min then
        left_pos = screen_min
        right_pos = screen_min + manual_distance
    elseif right_pos > screen_max then
        right_pos = screen_max
        left_pos = screen_max - manual_distance
    end

    if side_index == CUSTOM_POSITION_SIDE_PLAYER_LEFT then
        self.model.PlayerDatas[0].ManualPosX = left_pos
        self.model.PlayerDatas[1].ManualPosX = right_pos
    else
        self.model.PlayerDatas[0].ManualPosX = right_pos
        self.model.PlayerDatas[1].ManualPosX = left_pos
    end

    self.controller.relative_distance.relative_distance = relative_distance
    self.controller.screen_position.position = start_position
    self.model.StartLocation = 3
end

function PositionalParam:init(SelectMenuData)
    -- positional parameter initialization
    self.model = SelectMenuData

    -- determine current character ids from the passed SelectMenuData
    local char_id1 = SelectMenuData.PlayerDatas[0].FighterID
    local char_id2 = SelectMenuData.PlayerDatas[1].FighterID
    local offset1 = module.data.PositionParametersData.character_relative_distance_offsets[char_id1] or 0.0
    local offset2 = module.data.PositionParametersData.character_relative_distance_offsets[char_id2] or 0.0
    local total_offset = offset1 + offset2

    --[[
        controller variables
    ]]
    -- controller encompasses most settings as they don't translate well to the ingame parameters
    self.controller.relative_distance = {}
    self.controller.screen_position = {}
    self.controller.randomizer = {}

    -- relative distance
    self.controller.relative_distance.min =
        module.data.PositionParametersData.default_relative_distance.min + total_offset
    -- account for character-specific offsets: subtract total_offset from the allowed max
    self.controller.relative_distance.max =
        module.data.PositionParametersData.default_relative_distance.max - total_offset

    if SelectMenuData.StartLocation == 0 then
        -- midscreen start
        self.controller.relative_distance.relative_distance = 300
        self.controller.relative_distance.discrete_relative_distance_preset_index = 6
    else
        -- corner start
        self.controller.relative_distance.relative_distance = self.controller.relative_distance.min
        self.controller.relative_distance.discrete_relative_distance_preset_index = 1
    end

    self.controller.relative_distance.enabled = false

    self.controller.relative_distance.discrete_enabled = true

    -- absolute screen position

    self.controller.screen_position.enabled = false
    self.controller.screen_position.adjustment_mode = POSITION_ADJUSTMENT_MODE_CUSTOM

    self.controller.screen_position.position = 0.0
    self.controller.screen_position.pivot_type_index = 1
    -- discrete vs precise
    self.controller.screen_position.discrete_screen_position = true
    self.controller.screen_position.discrete_screen_position_value = 0
    -- absolute, distance from left/distance from right
    self.controller.screen_position.precise_distance_reference_index = 1

    --[[
        view variables
    ]]
    self.view.relative_distance = {}
    self.view.screen_position = {}
    self.view.randomizer = {}

    -- relative distance

    self.view.relative_distance.relative_distance_enabled_changed = false

    self.view.relative_distance.discrete_relative_distance_enabled_changed = false

    self.view.relative_distance.relative_distance_changed = false
    self.view.relative_distance.discrete_relative_distance_preset_index_changed = false

    self.view.relative_distance.old_starting_position = SelectMenuData.StartLocation

    -- screen position
    self.view.screen_position.enabled_changed = false

    self.view.screen_position.position_changed = false
    self.view.screen_position.pivot_type_index_changed = false
    self.view.screen_position.discrete_screen_position_changed = false
    self.view.screen_position.discrete_screen_position_value_changed = false
    self.view.screen_position.precise_distance_reference_index_changed = false

    self.view.screen_position.show_position_warning = false
    self.view.screen_position.precise_distance_reference_previous_index =
        self.controller.screen_position.precise_distance_reference_index

    --[[
        randomizer variables
    ]]
    self.controller.randomizer.enabled_relative = false
    self.controller.randomizer.relative_bounds_enabled = false
    self.controller.randomizer.relative_lower_bound = self.controller.relative_distance.min
    self.controller.randomizer.relative_upper_bound = self.controller.relative_distance.max
    self.controller.randomizer.relative_lower_bound_discrete_index = 1
    self.controller.randomizer.relative_upper_bound_discrete_index =
        #module.data.PositionParametersData.preset_relative_distance_offsets.names

    self.view.randomizer.relative_discrete_bounds_changed = false

    self.controller.randomizer.enabled_screen = false
    self.controller.randomizer.screen_bounds_enabled = false
    self.controller.randomizer.screen_lower_bound = module.data.PositionParametersData.default_screen_position.min
    self.controller.randomizer.screen_upper_bound = module.data.PositionParametersData.default_screen_position.max
    self.controller.randomizer.screen_lower_bound_discrete = -6
    self.controller.randomizer.screen_upper_bound_discrete = 6

    self.view.randomizer.screen_discrete_bounds_changed = false
    self.view.randomizer.screen_continuous_bounds_changed = false

    self.controller.custom_position = {
        override_start_position_enabled = false,
        override_start_position = 0.0,
        override_discrete_start_position = 0,
        override_relative_distance_enabled = false,
        override_relative_distance = self.controller.relative_distance.min,
        override_relative_distance_preset_index = 1,
        override_side_enabled = false,
        override_side_index = CUSTOM_POSITION_SIDE_RANDOM,
        equal_frequency = false,
        discrete_position_enabled = true,
        discrete_distance_enabled = true,
        configs = {
            {
                enabled = true,
                start_position = 0.0,
                discrete_start_position = 0,
                relative_distance = self.controller.relative_distance.min,
                relative_distance_preset_index = 1,
                side_index = CUSTOM_POSITION_SIDE_RANDOM,
                frequency = 1
            }
        }
    }

    --[[
        HOOKS
    ]]
    local function on_pre(args)
        -- no pre logic needed
    end
    local function on_post(retval)
        if
            self.controller.relative_distance.enabled and
                self.controller.screen_position.adjustment_mode == POSITION_ADJUSTMENT_MODE_CUSTOM
         then
            self:ensure_custom_position_defaults()
            local current_config = self:get_active_custom_position_config()
            if current_config then
                self:apply_custom_position_config(current_config)
                if self.view.relative_distance.old_starting_position == 3 then
                    self.view.relative_distance.old_starting_position = 0
                end
            end
            return
        end

        if not self.controller.relative_distance.enabled then
            -- if its disabled
            return
        end

        -- get the current characters to determine the offset to the relative distances
        local char_id1 = self.model.PlayerDatas[0].FighterID
        local char_id2 = self.model.PlayerDatas[1].FighterID

        local offset1 = module.data.PositionParametersData.character_relative_distance_offsets[char_id1] or 0.0
        local offset2 = module.data.PositionParametersData.character_relative_distance_offsets[char_id2] or 0.0
        local total_offset = offset1 + offset2

        -- if starting position adjustment is enabled, force custom start location
        if self.controller.screen_position.enabled then
            self.model.StartLocation = 3
        else
            if self.model.StartLocation ~= 3 then
                -- if starting position adjustment is disabled, we just use the old starting position
                self.view.relative_distance.old_starting_position = self.model.StartLocation
            else
                -- if starting position adjustment is disabled, we just use the old starting position
                if self.view.relative_distance.old_starting_position == 3 then
                    self.view.relative_distance.old_starting_position = 0
                end
                self.model.StartLocation = self.view.relative_distance.old_starting_position
            end
        end

        if self.model.StartLocation == 0 then
            -- center pivot
            local center_position = (self.controller.relative_distance.relative_distance) / 2.0
            self.model.PlayerDatas[0].ManualPosX = -center_position - (total_offset / 2.0)
            self.model.PlayerDatas[1].ManualPosX = center_position + (total_offset / 2.0)
        elseif self.model.StartLocation == 1 then
            -- right side pivot
            local right_position = module.data.PositionParametersData.default_screen_position.max
            self.model.PlayerDatas[0].ManualPosX =
                right_position - self.controller.relative_distance.relative_distance - total_offset
            self.model.PlayerDatas[1].ManualPosX = right_position
        elseif self.model.StartLocation == 2 then
            -- left side pivot
            local left_position = module.data.PositionParametersData.default_screen_position.min
            self.model.PlayerDatas[0].ManualPosX = left_position
            self.model.PlayerDatas[1].ManualPosX =
                left_position + self.controller.relative_distance.relative_distance + total_offset
        elseif self.model.StartLocation == 3 then
            -- custom position pivot
            local new_pos1
            local new_pos2

            -- first, calculate the position of the fulcrum based on the distance reference
            local fulcrum_position = 0.0
            if self.controller.screen_position.precise_distance_reference_index == 1 then
                -- absolute position
                fulcrum_position = self.controller.screen_position.position
            elseif self.controller.screen_position.precise_distance_reference_index == 2 then
                -- distance from left corner
                fulcrum_position =
                    self.controller.screen_position.position +
                    module.data.PositionParametersData.default_screen_position.min
            elseif self.controller.screen_position.precise_distance_reference_index == 3 then
                -- distance from right corner
                fulcrum_position =
                    module.data.PositionParametersData.default_screen_position.max -
                    self.controller.screen_position.position
            end

            -- calculate the new positions based on the pivot type
            if self.controller.screen_position.pivot_type_index == 1 then
                -- center pivot type
                new_pos1 = fulcrum_position - (self.controller.relative_distance.relative_distance + total_offset) / 2.0
                new_pos2 = fulcrum_position + (self.controller.relative_distance.relative_distance + total_offset) / 2.0
            elseif self.controller.screen_position.pivot_type_index == 2 then
                -- p1 player pivot type
                new_pos1 = fulcrum_position
                new_pos2 = fulcrum_position + self.controller.relative_distance.relative_distance + total_offset
            elseif self.controller.screen_position.pivot_type_index == 3 then
                -- p2 player pivot type
                new_pos1 = fulcrum_position - self.controller.relative_distance.relative_distance - total_offset
                new_pos2 = fulcrum_position
            end

            -- check screen bounds
            local screen_min = module.data.PositionParametersData.default_screen_position.min
            local screen_max = module.data.PositionParametersData.default_screen_position.max
            if new_pos1 < screen_min then
                new_pos1 = screen_min
                new_pos2 = screen_min + self.controller.relative_distance.relative_distance + total_offset
            elseif new_pos2 > screen_max then
                new_pos2 = screen_max
                new_pos1 = screen_max - self.controller.relative_distance.relative_distance - total_offset
            end
            self.model.PlayerDatas[0].ManualPosX = new_pos1
            self.model.PlayerDatas[1].ManualPosX = new_pos2
        end

        self.model.StartLocation = 3
    end

    self.update_positioning_func = on_post

    if not self.hooks_initialized then
        sdk.hook(
            sdk.find_type_definition("app.training.tf_SelectMenu.FuncData"):get_method("ChangeStartLocationType"),
            on_pre,
            on_post
        )
        self.hooks_initialized = true
    end

    self:ensure_custom_position_defaults()
end

function PositionalParam:update()
    -- positional parameter update logic
    local need_refresh = false

    -- get the current characters to determine the offset to the relative distances
    local char_id1 = self.model.PlayerDatas[0].FighterID
    local char_id2 = self.model.PlayerDatas[1].FighterID

    local offset1 = module.data.PositionParametersData.character_relative_distance_offsets[char_id1] or 0.0
    local offset2 = module.data.PositionParametersData.character_relative_distance_offsets[char_id2] or 0.0
    local total_offset = offset1 + offset2

    -- relative distance updates
    self.controller.relative_distance.min =
        module.data.PositionParametersData.default_relative_distance.min + total_offset
    -- keep max within screen-space minus the total character offset
    self.controller.relative_distance.max =
        module.data.PositionParametersData.default_relative_distance.max - total_offset

    self.controller.relative_distance.relative_distance =
        math.max(
        self.controller.relative_distance.min,
        math.min(self.controller.relative_distance.relative_distance, self.controller.relative_distance.max)
    )
    self:ensure_custom_position_defaults()

    -- relative distance changed
    if self.view.relative_distance.relative_distance_enabled_changed then
        need_refresh = true
        if self.controller.relative_distance.enabled then
            -- enable relative distance adjustments
            if self.model.StartLocation ~= 3 then
                self.view.relative_distance.old_starting_position = self.model.StartLocation
            elseif self.view.relative_distance.old_starting_position == 3 then
                self.view.relative_distance.old_starting_position = 0
            end
        else
            -- disable relative distance adjustments
            -- revert to old starting position
            if self.view.relative_distance.old_starting_position == 3 then
                self.view.relative_distance.old_starting_position = 0
            end
            self.model.StartLocation = self.view.relative_distance.old_starting_position
        end
    end

    -- relative distance discrete preset values
    if self.view.relative_distance.discrete_relative_distance_preset_index_changed then
        need_refresh = true

        -- if its the last value, we set the maximum (which we compute dynamically), otherwise we use the preset values in the table
        if
            self.controller.relative_distance.discrete_relative_distance_preset_index ==
                #module.data.PositionParametersData.preset_relative_distance_offsets.values + 1
         then
            self.controller.relative_distance.relative_distance = self.controller.relative_distance.max
        else
            -- preset values are offsets from the minimum, add the min to get the absolute relative distance
            self.controller.relative_distance.relative_distance =
                self.controller.relative_distance.min +
                module.data.PositionParametersData.preset_relative_distance_offsets.values[
                    self.controller.relative_distance.discrete_relative_distance_preset_index
                ]
        end
    end

    if self.view.screen_position.enabled_changed then
        need_refresh = true

        if self.view.screen_position.enabled then
            -- if we disabled starting position adjustment, restore the old starting position
            self.view.relative_distance.old_starting_position = 3
        else
            -- when we disable starting position, we just default back to the middle of the screen, cuz it don't matter
            self.view.relative_distance.old_starting_position = 0
        end
    end

    -- for the screen position, when we change the reference type, we need to adjust the position value to match the new reference
    if self.view.screen_position.precise_distance_reference_index_changed then
        local previous_index = self.view.screen_position.precise_distance_reference_previous_index
        local current_value = self.controller.screen_position.position

        local fulcrum_position = 0.0
        -- first, get the fulcrum position based on the previous reference
        if previous_index == 1 then
            -- absolute position
            fulcrum_position = current_value
        elseif previous_index == 2 then
            -- distance from left corner
            fulcrum_position = current_value + module.data.PositionParametersData.default_screen_position.min
        elseif previous_index == 3 then
            -- distance from right corner
            fulcrum_position = module.data.PositionParametersData.default_screen_position.max - current_value
        end

        -- now, calculate the new starting position based on the new reference
        if self.controller.screen_position.precise_distance_reference_index == 1 then
            -- absolute position
            self.controller.screen_position.position = fulcrum_position
        elseif self.controller.screen_position.precise_distance_reference_index == 2 then
            -- distance from left corner
            self.controller.screen_position.position =
                fulcrum_position - module.data.PositionParametersData.default_screen_position.min
        elseif self.controller.screen_position.precise_distance_reference_index == 3 then
            -- distance from right corner
            self.controller.screen_position.position =
                module.data.PositionParametersData.default_screen_position.max - fulcrum_position
        end

        self.view.screen_position.precise_distance_reference_previous_index =
            self.controller.screen_position.precise_distance_reference_index

        -- convert the randomizer bounds as well
        if self.controller.randomizer.screen_bounds_enabled then
            local lower_fulcrum = 0.0
            local upper_fulcrum = 0.0

            -- get fulcrum positions based on previous reference
            if previous_index == 1 then
                -- absolute position
                lower_fulcrum = self.controller.randomizer.screen_lower_bound
                upper_fulcrum = self.controller.randomizer.screen_upper_bound
            elseif previous_index == 2 then
                -- distance from left corner
                lower_fulcrum =
                    self.controller.randomizer.screen_lower_bound +
                    module.data.PositionParametersData.default_screen_position.min
                upper_fulcrum =
                    self.controller.randomizer.screen_upper_bound +
                    module.data.PositionParametersData.default_screen_position.min
            elseif previous_index == 3 then
                -- distance from right corner
                upper_fulcrum =
                    module.data.PositionParametersData.default_screen_position.max -
                    self.controller.randomizer.screen_lower_bound
                lower_fulcrum =
                    module.data.PositionParametersData.default_screen_position.max -
                    self.controller.randomizer.screen_upper_bound
            end

            -- now convert to new reference
            if self.controller.screen_position.precise_distance_reference_index == 1 then
                -- absolute position
                self.controller.randomizer.screen_lower_bound = lower_fulcrum
                self.controller.randomizer.screen_upper_bound = upper_fulcrum
            elseif self.controller.screen_position.precise_distance_reference_index == 2 then
                -- distance from left corner
                self.controller.randomizer.screen_lower_bound =
                    lower_fulcrum - module.data.PositionParametersData.default_screen_position.min
                self.controller.randomizer.screen_upper_bound =
                    upper_fulcrum - module.data.PositionParametersData.default_screen_position.min
            elseif self.controller.screen_position.precise_distance_reference_index == 3 then
                -- distance from right corner
                self.controller.randomizer.screen_upper_bound =
                    module.data.PositionParametersData.default_screen_position.max - lower_fulcrum
                self.controller.randomizer.screen_lower_bound =
                    module.data.PositionParametersData.default_screen_position.max - upper_fulcrum
            end
        end
    end

    -- if the discrete starting-position reference slider changed, convert it to an absolute position value
    if self.view.screen_position.discrete_screen_position_value_changed then
        need_refresh = true
        local min_pos = module.data.PositionParametersData.default_screen_position.min
        local max_pos = module.data.PositionParametersData.default_screen_position.max
        local discrete_value = self.controller.screen_position.discrete_screen_position_value
        -- map -6..6 to min_pos..max_pos (13 steps -> denominator 12)
        local fulcrum_position = min_pos + ((discrete_value + 6) / 12) * (max_pos - min_pos)

        -- store controller.screen_position.position according to the currently selected reference type
        -- 1 = absolute position, 2 = distance from left corner, 3 = distance from right corner
        if self.controller.screen_position.precise_distance_reference_index == 1 then
            -- absolute
            self.controller.screen_position.position = fulcrum_position
        elseif self.controller.screen_position.precise_distance_reference_index == 2 then
            -- distance from left corner
            self.controller.screen_position.position = fulcrum_position - min_pos
        else
            -- distance from right corner
            self.controller.screen_position.position = max_pos - fulcrum_position
        end
    end

    if self.view.screen_position.position_changed then
        need_refresh = true
        -- update the discrete slider value so the UI matches the computed fulcrum position
        local min_pos = module.data.PositionParametersData.default_screen_position.min
        local max_pos = module.data.PositionParametersData.default_screen_position.max

        local fulcrum_position = 0.0
        if self.controller.screen_position.precise_distance_reference_index == 1 then
            -- absolute position
            fulcrum_position = self.controller.screen_position.position
        elseif self.controller.screen_position.precise_distance_reference_index == 2 then
            -- distance from left corner
            fulcrum_position = self.controller.screen_position.position + min_pos
        elseif self.controller.screen_position.precise_distance_reference_index == 3 then
            -- distance from right corner
            fulcrum_position = max_pos - self.controller.screen_position.position
        end

        self.controller.screen_position.discrete_screen_position_value =
            math.floor(((fulcrum_position - min_pos) / (max_pos - min_pos)) * 12 + 0.5) - 6
    end

    if self.view.screen_position.pivot_type_index_changed or self.view.relative_distance.relative_distance_changed then
        need_refresh = true
    end

    -- verify screen position is within bounds
    if
        self.view.screen_position.position_changed or self.view.relative_distance.relative_distance_changed or
            self.view.relative_distance.discrete_relative_distance_preset_index_changed or
            self.view.screen_position.pivot_type_index_changed or
            self.view.screen_position.discrete_screen_position_changed or
            self.view.screen_position.discrete_screen_position_value_changed or
            self.view.screen_position.precise_distance_reference_index_changed
     then
        -- check the calculated positions to see if they are within screen bounds
        local screen_min = module.data.PositionParametersData.default_screen_position.min
        local screen_max = module.data.PositionParametersData.default_screen_position.max

        local new_pos1
        local new_pos2

        -- first, calculate the position of the fulcrum based on the distance reference
        local fulcrum_position = 0.0
        if self.controller.screen_position.precise_distance_reference_index == 1 then
            -- absolute position
            fulcrum_position = self.controller.screen_position.position
        elseif self.controller.screen_position.precise_distance_reference_index == 2 then
            -- distance from left corner
            fulcrum_position =
                self.controller.screen_position.position +
                module.data.PositionParametersData.default_screen_position.min
        elseif self.controller.screen_position.precise_distance_reference_index == 3 then
            -- distance from right corner
            fulcrum_position =
                module.data.PositionParametersData.default_screen_position.max -
                self.controller.screen_position.position
        end

        -- calculate the new positions based on the pivot type
        if self.controller.screen_position.pivot_type_index == 1 then
            -- center pivot type
            new_pos1 = fulcrum_position - (self.controller.relative_distance.relative_distance / 2.0)
            new_pos2 = fulcrum_position + (self.controller.relative_distance.relative_distance / 2.0)
        elseif self.controller.screen_position.pivot_type_index == 2 then
            -- p1 player pivot type
            new_pos1 = fulcrum_position
            new_pos2 = fulcrum_position + self.controller.relative_distance.relative_distance
        elseif self.controller.screen_position.pivot_type_index == 3 then
            -- p2 player pivot type
            new_pos1 = fulcrum_position - self.controller.relative_distance.relative_distance
            new_pos2 = fulcrum_position
        end

        -- update the discrete slider value so the UI matches the computed fulcrum position
        local min_pos = module.data.PositionParametersData.default_screen_position.min
        local max_pos = module.data.PositionParametersData.default_screen_position.max
        local fulcrum_relative_position = fulcrum_position - min_pos
        local relative_range = max_pos - min_pos
        local discrete_value = math.floor((fulcrum_relative_position / relative_range) * 12 + 0.5) - 6
        self.controller.screen_position.discrete_screen_position_value = discrete_value

        -- check screen bounds
        if new_pos1 < screen_min or new_pos2 > screen_max then
            self.view.screen_position.show_position_warning = true
        else
            self.view.screen_position.show_position_warning = false
        end
    end

    -- randomizer synchronize bounds
    if self.view.randomizer.relative_discrete_bounds_changed == true then
        -- synchronize precise bounds to discrete bounds
        local lower_index = self.controller.randomizer.relative_lower_bound_discrete_index
        local upper_index = self.controller.randomizer.relative_upper_bound_discrete_index

        -- if either index is == max range, then we don't add by the minimum value, just just use the max

        local lower_value
        local upper_value

        if lower_index ~= #module.data.PositionParametersData.preset_relative_distance_offsets.values + 1 then
            lower_value = module.data.PositionParametersData.preset_relative_distance_offsets.values[lower_index]
        else
            lower_value = self.controller.relative_distance.max - self.controller.relative_distance.min
        end

        if upper_index ~= #module.data.PositionParametersData.preset_relative_distance_offsets.values + 1 then
            upper_value = module.data.PositionParametersData.preset_relative_distance_offsets.values[upper_index]
        else
            upper_value = self.controller.relative_distance.max - self.controller.relative_distance.min
        end

        self.controller.randomizer.relative_lower_bound = self.controller.relative_distance.min + lower_value
        self.controller.randomizer.relative_upper_bound = self.controller.relative_distance.min + upper_value
    end

    -- screen position bounds updating to match discrete/precise mode
    if self.view.randomizer.screen_discrete_bounds_changed == true then
        -- synchronize precise bounds to discrete bounds
        local lower_discrete = self.controller.randomizer.screen_lower_bound_discrete
        local upper_discrete = self.controller.randomizer.screen_upper_bound_discrete

        local min_pos = module.data.PositionParametersData.default_screen_position.min
        local max_pos = module.data.PositionParametersData.default_screen_position.max

        -- convert discrete to absolute positions
        local lower_value = min_pos + ((lower_discrete + 6) / 12) * (max_pos - min_pos)
        local upper_value = min_pos + ((upper_discrete + 6) / 12) * (max_pos - min_pos)

        -- based on the current reference type, convert to appropriate stored value
        if self.controller.screen_position.precise_distance_reference_index == 1 then
            -- absolute position
            self.controller.randomizer.screen_lower_bound = lower_value
            self.controller.randomizer.screen_upper_bound = upper_value
        elseif self.controller.screen_position.precise_distance_reference_index == 2 then
            -- distance from left corner
            self.controller.randomizer.screen_lower_bound =
                lower_value - module.data.PositionParametersData.default_screen_position.min
            self.controller.randomizer.screen_upper_bound =
                upper_value - module.data.PositionParametersData.default_screen_position.min
        elseif self.controller.screen_position.precise_distance_reference_index == 3 then
            -- distance from right corner (remember to invert)
            -- distance from right corner
            self.controller.randomizer.screen_upper_bound =
                module.data.PositionParametersData.default_screen_position.max - lower_value
            self.controller.randomizer.screen_lower_bound =
                module.data.PositionParametersData.default_screen_position.max - upper_value
        end
    end

    -- screen position precise bounds changed
    if self.view.randomizer.screen_continuous_bounds_changed == true then
        -- synchronize discrete bounds to precise bounds
        local min_pos = module.data.PositionParametersData.default_screen_position.min
        local max_pos = module.data.PositionParametersData.default_screen_position.max

        local lower_value
        local upper_value

        -- convert from stored value to absolute position
        if self.controller.screen_position.precise_distance_reference_index == 1 then
            -- absolute position
            lower_value = self.controller.randomizer.screen_lower_bound
            upper_value = self.controller.randomizer.screen_upper_bound
        elseif self.controller.screen_position.precise_distance_reference_index == 2 then
            -- distance from left corner
            lower_value =
                self.controller.randomizer.screen_lower_bound +
                module.data.PositionParametersData.default_screen_position.min
            upper_value =
                self.controller.randomizer.screen_upper_bound +
                module.data.PositionParametersData.default_screen_position.min
        elseif self.controller.screen_position.precise_distance_reference_index == 3 then
            -- distance from right corner
            upper_value =
                module.data.PositionParametersData.default_screen_position.max -
                self.controller.randomizer.screen_lower_bound
            lower_value =
                module.data.PositionParametersData.default_screen_position.max -
                self.controller.randomizer.screen_upper_bound
        end

        -- convert absolute positions to discrete values
        self.controller.randomizer.screen_lower_bound_discrete =
            math.floor(((lower_value - min_pos) / (max_pos - min_pos)) * 12 + 0.5) - 6
        self.controller.randomizer.screen_upper_bound_discrete =
            math.floor(((upper_value - min_pos) / (max_pos - min_pos)) * 12 + 0.5) - 6
    end

    return need_refresh
end

function PositionalParam:randomize()
    -- positional parameter randomization logic

    local need_refresh = false

    self:ensure_custom_position_defaults()

    if self.controller.relative_distance.enabled then
        local custom_position = self.controller.custom_position
        local total_frequency = 0

        for _, config in ipairs(custom_position.configs) do
            if config.enabled then
                if custom_position.equal_frequency then
                    total_frequency = total_frequency + 1
                else
                    total_frequency = total_frequency + config.frequency
                end
            end
        end

        if total_frequency <= 0 then
            return false
        end

        local random_frequency = math.random(1, total_frequency)
        local accumulated_frequency = 0

        for index, config in ipairs(custom_position.configs) do
            if config.enabled then
                if custom_position.equal_frequency then
                    accumulated_frequency = accumulated_frequency + 1
                else
                    accumulated_frequency = accumulated_frequency + config.frequency
                end

                if random_frequency <= accumulated_frequency then
                    custom_position.current_config_index = index
                    self:resolve_custom_position_side(config, true)
                    break
                end
            end
        end

        self.model.StartLocation = 3
        return true
    end

    return need_refresh
end

function PositionalParam:draw_custom_position_ui()
    self:ensure_custom_position_defaults()

    local custom_position = self.controller.custom_position
    local screen_min = module.data.PositionParametersData.default_screen_position.min
    local screen_max = module.data.PositionParametersData.default_screen_position.max

    local discrete_position_changed = false
    discrete_position_changed, custom_position.discrete_position_enabled =
        imgui.checkbox("使用离散位置值", custom_position.discrete_position_enabled)
    if discrete_position_changed then
        if custom_position.discrete_position_enabled then
            custom_position.override_discrete_start_position =
                absolute_position_to_discrete(custom_position.override_start_position)
        else
            custom_position.override_start_position =
                discrete_position_to_absolute(custom_position.override_discrete_start_position)
        end

        for _, config in ipairs(custom_position.configs) do
            if custom_position.discrete_position_enabled then
                config.discrete_start_position = absolute_position_to_discrete(config.start_position)
            else
                config.start_position = discrete_position_to_absolute(config.discrete_start_position)
            end
        end
    end

    _, custom_position.override_start_position_enabled =
        imgui.checkbox("统一设定起始位置", custom_position.override_start_position_enabled)
    begin_position_config_indent()
    if not custom_position.override_start_position_enabled then
        imgui.begin_disabled()
    end
    if custom_position.discrete_position_enabled then
        _, custom_position.override_discrete_start_position =
            imgui.slider_int(
            "统一设定起始位置参考值",
            custom_position.override_discrete_start_position,
            -6,
            6
        )
        custom_position.override_start_position = discrete_position_to_absolute(custom_position.override_discrete_start_position)
    else
        _, custom_position.override_start_position =
            imgui.drag_float(
            "统一设定起始位置 X",
            custom_position.override_start_position,
            1.0,
            screen_min,
            screen_max
        )
        custom_position.override_discrete_start_position =
            absolute_position_to_discrete(custom_position.override_start_position)
    end
    if not custom_position.override_start_position_enabled then
        imgui.end_disabled()
    end
    end_position_config_indent()

    imgui.separator()

    local discrete_distance_changed = false
    discrete_distance_changed, custom_position.discrete_distance_enabled =
        imgui.checkbox("使用预设相对距离", custom_position.discrete_distance_enabled)
    if discrete_distance_changed then
        if custom_position.discrete_distance_enabled then
            custom_position.override_relative_distance_preset_index =
                relative_distance_to_preset_index(
                custom_position.override_relative_distance,
                self.controller.relative_distance.min,
                self.controller.relative_distance.max
            )
        else
            custom_position.override_relative_distance =
                relative_distance_preset_to_value(
                custom_position.override_relative_distance_preset_index,
                self.controller.relative_distance.min,
                self.controller.relative_distance.max
            )
        end

        for _, config in ipairs(custom_position.configs) do
            if custom_position.discrete_distance_enabled then
                config.relative_distance_preset_index =
                    relative_distance_to_preset_index(
                    config.relative_distance,
                    self.controller.relative_distance.min,
                    self.controller.relative_distance.max
                )
            else
                config.relative_distance =
                    relative_distance_preset_to_value(
                    config.relative_distance_preset_index,
                    self.controller.relative_distance.min,
                    self.controller.relative_distance.max
                )
            end
        end
    end

    _, custom_position.override_relative_distance_enabled =
        imgui.checkbox("统一设定相对距离", custom_position.override_relative_distance_enabled)
    begin_position_config_indent()
    if not custom_position.override_relative_distance_enabled then
        imgui.begin_disabled()
    end
    if custom_position.discrete_distance_enabled then
        _, custom_position.override_relative_distance_preset_index =
            imgui.combo(
            "统一设定相对距离预设",
            custom_position.override_relative_distance_preset_index,
            module.data.PositionParametersData.preset_relative_distance_offsets.names
        )
        custom_position.override_relative_distance =
            relative_distance_preset_to_value(
            custom_position.override_relative_distance_preset_index,
            self.controller.relative_distance.min,
            self.controller.relative_distance.max
        )
        imgui.text("当前统一设定相对距离：" .. string.format("%.2f", custom_position.override_relative_distance))
    else
        _, custom_position.override_relative_distance =
            imgui.drag_float(
            "统一设定相对距离数值",
            custom_position.override_relative_distance,
            1.0,
            self.controller.relative_distance.min,
            self.controller.relative_distance.max
        )
        custom_position.override_relative_distance_preset_index =
            relative_distance_to_preset_index(
            custom_position.override_relative_distance,
            self.controller.relative_distance.min,
            self.controller.relative_distance.max
        )
    end
    if not custom_position.override_relative_distance_enabled then
        imgui.end_disabled()
    end
    end_position_config_indent()

    local override_side_enabled_changed = false
    override_side_enabled_changed, custom_position.override_side_enabled =
        imgui.checkbox("统一设定玩家站位侧", custom_position.override_side_enabled)
    if override_side_enabled_changed then
        custom_position.override_resolved_side_index = nil
    end
    begin_position_config_indent()
    if not custom_position.override_side_enabled then
        imgui.begin_disabled()
    end
    local override_side_changed = false
    override_side_changed, custom_position.override_side_index =
        imgui.combo("统一设定玩家站位侧数值", custom_position.override_side_index, CUSTOM_POSITION_SIDE_NAMES)
    if override_side_changed then
        custom_position.override_resolved_side_index = nil
    end
    if not custom_position.override_side_enabled then
        imgui.end_disabled()
    end
    end_position_config_indent()

    _, custom_position.equal_frequency =
        imgui.checkbox("统一触发频率", custom_position.equal_frequency)

    imgui.separator()
    imgui.text("自定义位置配置")

    local remove_index = nil
    for index, config in ipairs(custom_position.configs) do
        imgui.separator()

        _, config.enabled = imgui.checkbox("位置配置 " .. tostring(index), config.enabled)
        begin_position_config_indent()

        if not config.enabled then
            imgui.begin_disabled()
        end

        if custom_position.override_start_position_enabled then
            imgui.begin_disabled()
        end
        if custom_position.discrete_position_enabled then
            _, config.discrete_start_position =
                imgui.slider_int(
                "位置配置 " .. tostring(index) .. " 起始位置参考值",
                config.discrete_start_position,
                -6,
                6
            )
            config.start_position = discrete_position_to_absolute(config.discrete_start_position)
        else
            _, config.start_position =
                imgui.drag_float(
                "位置配置 " .. tostring(index) .. " 起始位置 X",
                config.start_position,
                1.0,
                screen_min,
                screen_max
            )
            config.discrete_start_position = absolute_position_to_discrete(config.start_position)
        end
        if custom_position.override_start_position_enabled then
            imgui.end_disabled()
        end

        if custom_position.override_relative_distance_enabled then
            imgui.begin_disabled()
        end
        if custom_position.discrete_distance_enabled then
            _, config.relative_distance_preset_index =
                imgui.combo(
                "位置配置 " .. tostring(index) .. " 相对距离预设",
                config.relative_distance_preset_index,
                module.data.PositionParametersData.preset_relative_distance_offsets.names
            )
            config.relative_distance =
                relative_distance_preset_to_value(
                config.relative_distance_preset_index,
                self.controller.relative_distance.min,
                self.controller.relative_distance.max
            )
            imgui.text("当前相对距离：" .. string.format("%.2f", config.relative_distance))
        else
            _, config.relative_distance =
                imgui.drag_float(
                "位置配置 " .. tostring(index) .. " 相对距离",
                config.relative_distance,
                1.0,
                self.controller.relative_distance.min,
                self.controller.relative_distance.max
            )
            config.relative_distance_preset_index =
                relative_distance_to_preset_index(
                config.relative_distance,
                self.controller.relative_distance.min,
                self.controller.relative_distance.max
            )
        end
        if custom_position.override_relative_distance_enabled then
            imgui.end_disabled()
        end

        if custom_position.override_side_enabled then
            imgui.begin_disabled()
        end
        local config_side_changed = false
        config_side_changed, config.side_index =
            imgui.combo("位置配置 " .. tostring(index) .. " 玩家站位侧", config.side_index, CUSTOM_POSITION_SIDE_NAMES)
        if config_side_changed then
            config.resolved_side_index = nil
        end
        if custom_position.override_side_enabled then
            imgui.end_disabled()
        end

        if custom_position.equal_frequency then
            imgui.begin_disabled()
        end
        _, config.frequency =
            imgui.slider_int("位置配置 " .. tostring(index) .. " 权重（1到10）", config.frequency, 1, 10)
        if custom_position.equal_frequency then
            imgui.end_disabled()
        end

        if not config.enabled then
            imgui.end_disabled()
        end

        if #custom_position.configs > 1 and imgui.button("删除位置配置 " .. tostring(index)) then
            remove_index = index
        end
        end_position_config_indent()
    end

    if remove_index ~= nil then
        table.remove(custom_position.configs, remove_index)
        if custom_position.current_config_index == remove_index then
            custom_position.current_config_index = nil
        elseif custom_position.current_config_index and custom_position.current_config_index > remove_index then
            custom_position.current_config_index = custom_position.current_config_index - 1
        end
    end

    imgui.separator()
    if imgui.button("添加位置配置") then
        table.insert(
            custom_position.configs,
            {
                enabled = true,
                start_position = 0.0,
                discrete_start_position = 0,
                relative_distance = self.controller.relative_distance.min,
                relative_distance_preset_index = 1,
                side_index = CUSTOM_POSITION_SIDE_RANDOM,
                frequency = 1
            }
        )
    end
end

function PositionalParam:draw_ui()
    -- positional parameter UI logic

    self.view.relative_distance.relative_distance_enabled_changed, self.controller.relative_distance.enabled =
        imgui.checkbox("启用起始位置调整", self.controller.relative_distance.enabled)

    imgui.separator()

    if self.controller.relative_distance.enabled then
        self:ensure_custom_position_defaults()
        self.controller.screen_position.adjustment_mode = POSITION_ADJUSTMENT_MODE_CUSTOM
        self:draw_custom_position_ui()
    end
end

--[[
    Module level logic
]]
function module.init()
    -- load the game parameters
    module.data.TrainingManager = sdk.get_managed_singleton("app.training.TrainingManager")
    module.data.TrainingData = module.data.TrainingManager:get_field("_tData")
    module.data.ParameterSetting = module.data.TrainingData:get_field("ParameterSetting")
    module.data.SelectMenu = module.data.TrainingData:get_field("SelectMenu")
    module.data.tf_PS = module.data.TrainingManager._tfFuncs._entries[6]:get_field("value")
    -- module.data.refresh_object =
    --     module.data.TrainingManager._tfFuncs._entries[0]:get_field("value"):get_field("FuncList")
    local gBattle = sdk.find_type_definition("gBattle")
    local sPlayer = gBattle:get_field("Player"):get_data(nil)
    local cPlayer = sPlayer.mcPlayer
    -- use sGame.stage_timer == 1 to check for the refresh (you can apply all the settings you want here and they won't get overwritten by the game at this point)
    module.data.sGame = gBattle:get_field("Game"):get_data(nil)
    module.data.live_P1 = cPlayer[0]
    module.data.live_P2 = cPlayer[1]

    -- initialize player parameters
    PlayerParam:init(module.data.ParameterSetting)
    UniqueGaugeParam:init(module.data.ParameterSetting.UniqueData)
    PositionalParam:init(module.data.SelectMenu)

    -- load config file
    local config_file = json.load_file("TrainingModePlus/TrainingSettingsAndRandomizer_Config.json")
    if config_file ~= nil then
        PlayerParam.controller = config_file.PlayerParam or PlayerParam.controller
        UniqueGaugeParam.controller = config_file.UniqueGaugeParam or UniqueGaugeParam.controller
        PositionalParam.controller = config_file.PositionalParam or PositionalParam.controller
        module.hotkeys = config_file.Hotkeys or module.hotkeys
    end
    ensure_player_health_randomizer_defaults(PlayerParam.controller.p1)
    ensure_player_health_randomizer_defaults(PlayerParam.controller.p2)
    ensure_player_drive_randomizer_defaults(PlayerParam.controller.p1)
    ensure_player_drive_randomizer_defaults(PlayerParam.controller.p2)
    UniqueGaugeParam:ensure_controller_defaults()
    PositionalParam:ensure_custom_position_defaults()

    -- initialize refresh request flag
    module.request_refresh = false
    module.ui_active = false

    if hotkeys_available then
        -- initialize the hotkeys
        Hotkey.setup_hotkeys(module.hotkeys, module.default_hotkeys)
    end
end

function module.on_frame()
    -- module logic goes here
    local need_apply = false
    local need_refresh = false
    local refresh_modules = false

    -- randomization logic
    -- for now just use this, later set this to a bind or something
    if hotkeys_available then
        local hotkey_randomizer_requested = Hotkey.check_hotkey("request_randomizer", nil, true)
        module.request_randomizer = module.request_randomizer or hotkey_randomizer_requested
        refresh_modules = hotkey_randomizer_requested
    end

    if module.request_randomizer then
        -- randomize parameters
        need_apply = PlayerParam:randomize() or need_apply
        UniqueGaugeParam:randomize()
        need_refresh = PositionalParam:randomize() or need_refresh

        need_refresh = true
        module.request_randomizer = false
    end

    need_apply = PlayerParam:update() or need_apply
    need_refresh = UniqueGaugeParam:update() or need_refresh
    need_refresh = PositionalParam:update() or need_refresh

    -- apply the settings if needed
    if need_apply then
        sdk.call_object_func(module.data.tf_PS, "bApply")
    end

    if need_refresh then
        module.request_refresh = true
    end

    if module.request_refresh == true and (module.ui_active == false) then
        module.data.TrainingManager._IsReqRefresh = true
        PositionalParam:update_positioning_func()
        module.request_refresh = false
    end
    module.ui_active = false

    if refresh_modules then
        return {
            refresh_modules = true
        }
    end
end

function module.draw_ui()
    -- module level UI
    if imgui.collapsing_header("训练设置 + 随机化") then
        module.request_randomizer = imgui.button("刷新并随机化")

        if hotkeys_available then
            imgui.same_line()
            local hotkeyChanged =
                l10n.with_hotkey_text_translation(
                function()
                    return Hotkey.hotkey_setter("request_randomizer", nil, "热键")
                end
            )

            if hotkeyChanged then
                Hotkey.update_hotkey_table(module.hotkeys)
            end
        end

        -- player specific UI
        PlayerParam:draw_ui()
        if imgui.tree_node("角色专属资源") then
            UniqueGaugeParam:draw_ui()
            imgui.tree_pop()
        end
        if imgui.tree_node("位置参数") then
            PositionalParam:draw_ui()
            imgui.tree_pop()
        end
    end
end

function module.on_exit_training_mode()
    -- save the config
    config_file = {
        PlayerParam = PlayerParam.controller,
        UniqueGaugeParam = UniqueGaugeParam.controller,
        PositionalParam = PositionalParam.controller,
        Hotkeys = module.hotkeys
    }

    json.dump_file("TrainingModePlus/TrainingSettingsAndRandomizer_Config.json", config_file)
end

return module
