-- BackGround.lua
-- Executor-compatible background addon for this UE-Linoria-Lib version.
-- Load:
-- local Background = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL"))()
-- local bg = Background.Attach(Window, Library, { Image = "RAW_IMAGE_URL" })

local Background = {}

Background.Presets = {
    {
        Name = "Konata Izumi",
        Image = "https://raw.githubusercontent.com/quaxc/konata_fun/main/resources/background/konataizumi.png",
    },
    {
        Name = "Konata Izumi 2",
        Image = "https://raw.githubusercontent.com/quaxc/konata_fun/main/resources/background/konataizumi2.png",
    },
    {
        Name = "Astolfo",
        Image = "https://raw.githubusercontent.com/quaxc/konata_fun/main/resources/background/Astolfo.png",
    },
    {
        Name = "rat",
        Image = "https://raw.githubusercontent.com/quaxc/konata_fun/main/resources/background/njrat.png",
    },
}

local function clamp(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    return math.clamp(value, 0, 1)
end

local function getAsset(url)
    if type(url) ~= "string" or url == "" then
        return ""
    end

    local getAssetFn = getcustomasset or getsynasset
    if not getAssetFn then
        return url
    end

    if not (writefile and isfile) then
        return url
    end

    local extension = url:match("%.([%w]+)[%?#]?.*$") or "png"
    local baseName = url:match("/([^/?#]+)%.") or "image"
    baseName = baseName:gsub("[^%w_%-]", "_")
    local fileName = "UE_Linoria_Background_" .. baseName .. "." .. extension

    local ok, result = pcall(function()
        if not isfile(fileName) then
            local data = game:HttpGet(url)
            writefile(fileName, data)
        end
        return getAssetFn(fileName)
    end)

    if ok and result then
        return result
    end

    warn("[BackGround] Could not download/load image: " .. tostring(result))
    return url
end

function Background.Attach(Window, Library, Config)
    Config = Config or {}

    assert(Window and Window.Holder, "[BackGround] Invalid Window. Pass the result of Library:CreateWindow().")
    assert(Library and type(Library.Create) == "function", "[BackGround] Pass your local Library as the second argument.")

    local Inner = Window.Holder:FindFirstChild("Inner")
    assert(Inner, "[BackGround] Could not find Window.Holder.Inner")

    local State = {
        Image = Config.Image or Background.Presets[1].Image,
        ImageTransparency = clamp(Config.Transparency, 0.10),
        OverlayTransparency = clamp(Config.OverlayTransparency, 0.45),
        PanelTransparency = clamp(Config.PanelTransparency, 0.25),
        Enabled = Config.Enabled ~= false,
        ScaleType = Config.ScaleType or "Crop",
    }

    local scaleTypes = {
        Crop = Enum.ScaleType.Crop,
        Fit = Enum.ScaleType.Fit,
        Stretch = Enum.ScaleType.Stretch,
        Tile = Enum.ScaleType.Tile,
    }

    local originalInnerTransparency = Inner.BackgroundTransparency
    local originalPanels = {}

    Inner.ClipsDescendants = true
    Inner.BackgroundTransparency = 1

    -- Image and overlay use ZIndex 0; Linoria content uses ZIndex 1 or higher.
    local image = Instance.new("ImageLabel")
    image.Name = "UE_Linoria_Background"
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.Position = UDim2.fromScale(0, 0)
    image.Size = UDim2.fromScale(1, 1)
    image.ZIndex = 0
    image.ScaleType = scaleTypes[State.ScaleType] or Enum.ScaleType.Crop
    image.ImageTransparency = State.ImageTransparency
    image.Image = getAsset(State.Image)
    image.Visible = State.Enabled
    image.Parent = Inner

    local overlay = Instance.new("Frame")
    overlay.Name = "UE_Linoria_Background_Overlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = State.OverlayTransparency
    overlay.BorderSizePixel = 0
    overlay.Position = UDim2.fromScale(0, 0)
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = 0
    overlay.Visible = State.Enabled
    overlay.Parent = Inner

    -- These are the actual large panels created by the supplied Library.lua.
    local panelNames = {
        "TabBarOuter",
        "TabBarInner",
        "MainSectionOuter",
        "MainSectionInner",
        "TabContainer",
    }

    for _, name in ipairs(panelNames) do
        local panel = Inner:FindFirstChild(name, true)
        if panel and panel:IsA("GuiObject") then
            originalPanels[panel] = panel.BackgroundTransparency
            panel.BackgroundTransparency = State.PanelTransparency
        end
    end

    local Controller = {}

    function Controller:SetImage(url)
        assert(type(url) == "string", "SetImage expects an image URL")
        State.Image = url
        image.Image = getAsset(url)
    end

    function Controller:SetTransparency(value)
        State.ImageTransparency = clamp(value, State.ImageTransparency)
        image.ImageTransparency = State.ImageTransparency
    end

    function Controller:SetOverlayTransparency(value)
        State.OverlayTransparency = clamp(value, State.OverlayTransparency)
        overlay.BackgroundTransparency = State.OverlayTransparency
    end

    function Controller:SetPanelTransparency(value)
        State.PanelTransparency = clamp(value, State.PanelTransparency)
        for panel in pairs(originalPanels) do
            if panel and panel.Parent then
                panel.BackgroundTransparency = State.PanelTransparency
            end
        end
    end

    function Controller:SetScaleType(value)
        assert(scaleTypes[value], "ScaleType must be Crop, Fit, Stretch, or Tile")
        State.ScaleType = value
        image.ScaleType = scaleTypes[value]
    end

    function Controller:SetEnabled(value)
        State.Enabled = value == true
        image.Visible = State.Enabled
        overlay.Visible = State.Enabled
    end

    function Controller:Destroy()
        if image then image:Destroy() end
        if overlay then overlay:Destroy() end

        if Inner and Inner.Parent then
            Inner.BackgroundTransparency = originalInnerTransparency
        end

        for panel, transparency in pairs(originalPanels) do
            if panel and panel.Parent then
                panel.BackgroundTransparency = transparency
            end
        end
    end

    Controller.ImageLabel = image
    Controller.Overlay = overlay
    Controller.State = State

    return Controller
end

-- Adds controls to an existing Linoria Groupbox on your Settings tab.
-- Example: Background.AddSettings(SettingsGroup, bg)
function Background.AddSettings(SettingsGroup, Controller)
    assert(SettingsGroup and type(SettingsGroup.AddDropdown) == "function",
        "[BackGround] First argument must be a Linoria Groupbox (for example SettingsGroup).")
    assert(Controller and Controller.State, "[BackGround] Pass the controller returned by Background.Attach().")

    local presetNames = {}
    local currentPreset = Background.Presets[1].Name

    for _, preset in ipairs(Background.Presets) do
        table.insert(presetNames, preset.Name)
        if preset.Image == Controller.State.Image then
            currentPreset = preset.Name
        end
    end

    SettingsGroup:AddToggle("BackgroundEnabled", {
        Text = "enable menu background",
        Default = Controller.State.Enabled,
        Callback = function(value)
            Controller:SetEnabled(value)
        end,
    })

    SettingsGroup:AddDropdown("BackgroundImage", {
        Text = "background image",
        Values = presetNames,
        Default = currentPreset,
        Multi = false,
        Callback = function(value)
            for _, preset in ipairs(Background.Presets) do
                if preset.Name == value then
                    Controller:SetImage(preset.Image)
                    break
                end
            end
        end,
    })

    SettingsGroup:AddSlider("BackgroundImageTransparency", {
        Text = "image transparency",
        Default = math.floor(Controller.State.ImageTransparency * 100 + 0.5),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(value)
            Controller:SetTransparency(value / 100)
        end,
    })

    SettingsGroup:AddSlider("BackgroundOverlayTransparency", {
        Text = "dark overlay transparency",
        Default = math.floor(Controller.State.OverlayTransparency * 100 + 0.5),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(value)
            Controller:SetOverlayTransparency(value / 100)
        end,
    })

    SettingsGroup:AddSlider("BackgroundPanelTransparency", {
        Text = "menu panels transparency",
        Default = math.floor(Controller.State.PanelTransparency * 100 + 0.5),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(value)
            Controller:SetPanelTransparency(value / 100)
        end,
    })

    SettingsGroup:AddDropdown("BackgroundScaleType", {
        Text = "image scaling",
        Values = { "Crop", "Fit", "Stretch", "Tile" },
        Default = Controller.State.ScaleType,
        Multi = false,
        Callback = function(value)
            Controller:SetScaleType(value)
        end,
    })
end

return Background
