local UniqueCharData = {}

UniqueCharData[1] = {
    name = "Ryu",
    display_name = "隆",
    timers = {
        {
            id = "timer_0_001",
            name = "Denjin Charge",
            display_name = "电刃蓄力",
            -- if install, then we have a timerMaxValue, otherwise no. Also determines the descriptors
            install = false
            -- for timers, we only have values descriptors of
            --[[
            0 = "Standard",
            1 = "Maximum" (and "Activated" for Ryu only),
            2 = "Infinite"

            No reason to bother inserting it here, just do it programmatically later
        ]]
        }
    }
}

UniqueCharData[21] = {
    name = "Jamie",
    display_name = "杰米",
    timers = {
        {
            id = "timer_0_021",
            name = "The Devil's Song",
            display_name = "魔身",
            install = true,
            timerMaxValue = 900
        }
    },
    stocks = {
        {
            id = "stock_0_021",
            name = "Drink Level",
            display_name = "醉酒等级",
            maxValue = 4,
            minValue = 0,
            allowInfinite = false,
            correspond = true,
            descriptors = {
                "0",
                "1",
                "2",
                "3",
                "4"
            }
        }
    }
}

UniqueCharData[3] = {
    name = "Kimberly",
    display_name = "金伯莉",
    stocks = {
        {
            id = "stock_0_003",
            name = "Shuriken Bomb Stocks",
            display_name = "手里剑炸弹库存",
            maxValue = 2,
            minValue = 0,
            allowInfinite = true,
            correspond = false,
            descriptors = {
                "2",
                "1",
                "0"
            }
        }
    }
}

UniqueCharData[12] = {
    name = "Lily",
    display_name = "莉莉",
    stocks = {
        {
            id = "stock_0_012",
            name = "Windclad Stocks",
            display_name = "风缠库存",
            maxValue = 3,
            minValue = 0,
            allowInfinite = true,
            correspond = true,
            descriptors = {
                "0",
                "1",
                "2",
                "3"
            }
        }
    }
}

UniqueCharData[16] = {
    name = "Juri",
    display_name = "蛛俐",
    timers = {
        {
            id = "timer_0_016",
            name = "Feng Shui Engine",
            display_name = "风水引擎",
            install = true,
            timerMaxValue = 600
        }
    },
    stocks = {
        {
            id = "stock_0_016",
            name = "Fuha Stocks",
            display_name = "风破库存",
            maxValue = 3,
            minValue = 0,
            allowInfinite = true,
            correspond = true,
            descriptors = {
                "0",
                "1",
                "2",
                "3"
            }
        }
    }
}

UniqueCharData[20] = {
    name = "E.Honda",
    display_name = "本田",
    stocks = {
        {
            id = "stock_0_020",
            name = "Sumo Spirit",
            display_name = "相扑魂",
            maxValue = 1,
            minValue = 0,
            allowInfinite = true,
            correspond = false,
            descriptors = {
                "标准",
                "已发动"
            }
        }
    }
}

UniqueCharData[15] = {
    name = "Blanka",
    display_name = "布兰卡",
    timers = {
        {
            id = "timer_0_015",
            name = "Lightning Beast",
            display_name = "雷兽",
            install = true,
            timerMaxValue = 1500
        }
    },
    stocks = {
        {
            id = "stock_0_015",
            name = "Blanka-Chan Bomb",
            display_name = "小布兰卡炸弹",
            maxValue = 3,
            minValue = 0,
            allowInfinite = true,
            correspond = false,
            descriptors = {
                "3",
                "2",
                "1",
                "0"
            }
        }
    }
}

UniqueCharData[18] = {
    name = "Guile",
    display_name = "古烈",
    timers = {
        {
            id = "timer_0_018",
            name = "Solid Puncher",
            display_name = "坚实打击者",
            install = true,
            timerMaxValue = 1500
        }
    }
}

UniqueCharData[28] = {
    name = "Mai",
    display_name = "不知火舞",
    stocks = {
        {
            id = "stock_0_028",
            name = "Flame Stocks",
            display_name = "火焰库存",
            maxValue = 5,
            minValue = 0,
            allowInfinite = true,
            correspond = true,
            descriptors = {
                "0",
                "1",
                "2",
                "3",
                "4",
                "5"
            }
        }
    }
}

UniqueCharData[30] = {
    name = "C.Viper",
    display_name = "C.毒蛇",
    timers = {
        {
            id = "timer_0_030",
            name = "Limit Decoupler",
            display_name = "限制解除",
            install = true,
            timerMaxValue = 700
        }
    }
}

UniqueCharData[32] = {
    name = "Ingrid",
    display_name = "英格丽德",
    stocks = {
        {
            id = "stock_0_032",
            name = "Sun Crests",
            display_name = "太阳纹章",
            maxValue = 4,
            minValue = 0,
            allowInfinite = true,
            correspond = true,
            descriptors = {
                "0",
                "1",
                "2",
                "3",
                "4"
            }
        }
    }
}

UniqueCharData[5] = {
    name = "Manon",
    display_name = "玛侬",
    stocks = {
        {
            id = "stock_0_005",
            name = "Medal Level",
            display_name = "奖牌等级",
            maxValue = 4,
            minValue = 0,
            allowInfinite = false,
            correspond = false,
            descriptors = {
                "1",
                "2",
                "3",
                "4",
                "5"
            }
        }
    }
}

-- iterate through the char data and add timer descriptors
for _, charData in pairs(UniqueCharData) do
    if charData.timers then
        for _, timerData in pairs(charData.timers) do
            if not timerData.install then
                timerData.descriptors = {
                    "标准",
                    "已发动",
                    "无限"
                }
            else
                timerData.descriptors = {
                    "标准",
                    "最大",
                    "无限"
                }
            end
        end
    end
end

return UniqueCharData
