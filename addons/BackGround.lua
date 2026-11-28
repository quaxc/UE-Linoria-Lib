-- BackGround.lua
-- Linoria background manager with Settings controls.
-- Load this module, then call:
-- Background:SetLibrary(Library)
-- local bg = Background:Attach(Window, {...})
-- Background:ApplyToTab(Tabs.Settings)

local Background = {
    Library = nil,
    Controller = nil,
    Folder = "LinoriaBackgrounds",

    Presets = {
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
}

local function clamp01(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    return math.clamp(value, 0, 1)
end

local function safeFileName(url)
    local name = url:match("/([^/?#]+)$") or "background.png"
    return name:gsub("[^%w_.-]", "_")
end

local function loadImageAsset(url)
    assert(type(url) == "string" and url ~= "", "[BackGround] Empty image URL")

    local assetFunction = getcustomasset or getsynasset
    if not (assetFunction and writefile and isfile) then
        warn("[BackGround] Executor needs getcustomasset/getsynasset + writefile + isfile to load GitHub images.")
        return nil
    end

    local fileName = "LinoriaBackgrounds/" .. safeFileName(url)

    local ok, result = pcall(function()
        if makefolder and isfolder and not isfolder("LinoriaBackgrounds") then
            makefolder("LinoriaBackgrounds")
        end

        if not isfile(fileName) then
            local response = game:HttpGet(url)
            assert(type(response) == "string" and #response > 100, "GitHub returned an empty/invalid response")
            writefile(fileName, response)
        end

        return assetFunction(fileName)
    end)

    if not ok then
        warn("[BackGround] Failed to load " .. url .. " : " .. tostring(result))
        return nil
    end

    return result
end

function Background:SetLibrary(library)
    self.Library = library
end

function Background:Attach(window, config)
    config = config or {}

    assert(self.Library, "[BackGround] Call Background:SetLibrary(Library) first")
    assert(window and window.Holder, "[BackGround] Invalid Window")

    local inner = window.Holder:FindFirstChild("Inner")
    assert(inner, "[BackGround] Window.Holder.Inner was not found")

    if self.Controller then
        self.Controller:Destroy()
    end

    local scaleTypes = {
        Crop = Enum.ScaleType.Crop,
        Fit = Enum.ScaleType.Fit,
        Stretch = Enum.ScaleType.Stretch,
        Tile = Enum.ScaleType.Tile,
    }

    local state = {
        Image = config.Image or self.Presets[1].Image,
        Transparency = clamp01(config.Transparency, 0.1),
        OverlayTransparency = clamp01(config.OverlayTransparency, 0.45),
        PanelTransparency = clamp01(config.PanelTransparency, 0.25),
        Enabled = config.Enabled ~= false,
        ScaleType = config.ScaleType or "Crop",
    }

    assert(scaleTypes[state.ScaleType], "[BackGround] Invalid ScaleType")

    local oldInnerTransparency = inner.BackgroundTransparency
    local oldPanelTransparency = {}

    inner.ClipsDescendants = true
    inner.BackgroundTransparency = 1

    local image = Instance.new("ImageLabel")
    image.Name = "LinoriaBackgroundImage"
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.Position = UDim2.fromScale(0, 0)
    image.Size = UDim2.fromScale(1, 1)
    image.ScaleType = scaleTypes[state.ScaleType]
    image.ImageTransparency = state.Transparency
    image.ZIndex = 0
    image.Visible = state.Enabled
    image.Parent = inner

    local overlay = Instance.new("Frame")
    overlay.Name = "LinoriaBackgroundOverlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = state.OverlayTransparency
    overlay.BorderSizePixel = 0
    overlay.Position = UDim2.fromScale(0, 0)
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = 0
    overlay.Visible = state.Enabled
    overlay.Parent = inner

    -- Apply first image after the ImageLabel exists.
    local function setImage(url)
        state.Image = url
        local asset = loadImageAsset(url)
        if asset then
            image.Image = asset
            image.Visible = state.Enabled
            return true
        end

        image.Image = ""
        warn("[BackGround] Image was not changed. Check executor asset functions and URL.")
        return false
    end

    setImage(state.Image)

    -- Keep the major Linoria panels translucent so the background is visible.
    local panelNames = {
        "TabBarOuter",
        "TabBarInner",
        "MainSectionOuter",
        "MainSectionInner",
        "TabContainer",
    }

    for _, name in ipairs(panelNames) do
        local panel = inner:FindFirstChild(name, true)
        if panel and panel:IsA("GuiObject") then
            oldPanelTransparency[panel] = panel.BackgroundTransparency
            panel.BackgroundTransparency = state.PanelTransparency
        end
    end

    local controller = {
        State = state,
        ImageLabel = image,
        Overlay = overlay,
    }

    function controller:SetImage(url)
        assert(type(url) == "string", "SetImage expects a URL string")
        return setImage(url)
    end

    function controller:SetTransparency(value)
        state.Transparency = clamp01(value, state.Transparency)
        image.ImageTransparency = state.Transparency
    end

    function controller:SetOverlayTransparency(value)
        state.OverlayTransparency = clamp01(value, state.OverlayTransparency)
        overlay.BackgroundTransparency = state.OverlayTransparency
    end

    function controller:SetPanelTransparency(value)
        state.PanelTransparency = clamp01(value, state.PanelTransparency)
        for panel in pairs(oldPanelTransparency) do
            if panel and panel.Parent then
                panel.BackgroundTransparency = state.PanelTransparency
            end
        end
    end

    function controller:SetScaleType(value)
        assert(scaleTypes[value], "ScaleType must be Crop, Fit, Stretch, or Tile")
        state.ScaleType = value
        image.ScaleType = scaleTypes[value]
    end

    function controller:SetEnabled(value)
        state.Enabled = value == true
        image.Visible = state.Enabled
        overlay.Visible = state.Enabled
    end

    function controller:Destroy()
        if image then image:Destroy() end
        if overlay then overlay:Destroy() end

        if inner and inner.Parent then
            inner.BackgroundTransparency = oldInnerTransparency
        end

        for panel, transparency in pairs(oldPanelTransparency) do
            if panel and panel.Parent then
                panel.BackgroundTransparency = transparency
            end
        end
    end

    self.Controller = controller
    return controller
end

function Background:CreateGroupBox(tab)
    assert(self.Library, "[BackGround] Call SetLibrary first")
    return tab:AddLeftGroupbox("Background")
end

function Background:CreateBackgroundManager(groupbox)
    assert(self.Library, "[BackGround] Call SetLibrary first")
    assert(self.Controller, "[BackGround] Call Attach(Window, config) before creating Settings controls")
    assert(groupbox, "[BackGround] Settings groupbox is missing")

    local controller = self.Controller
    local names = {}
    local currentIndex = 1

    for index, preset in ipairs(self.Presets) do
        names[index] = preset.Name
        if preset.Image == controller.State.Image then
            currentIndex = index
        end
    end

    groupbox:AddToggle("Background_Enabled", {
        Text = "Enable background",
        Default = controller.State.Enabled,
        Callback = function(value)
            controller:SetEnabled(value)
        end,
    })

    groupbox:AddDropdown("Background_Image", {
        Text = "Background image",
        Values = names,
        Default = currentIndex,
        Callback = function(value)
            for _, preset in ipairs(self.Presets) do
                if preset.Name == value then
                    controller:SetImage(preset.Image)
                    break
                end
            end
        end,
    })

    groupbox:AddSlider("Background_Transparency", {
        Text = "Image transparency",
        Default = math.floor(controller.State.Transparency * 100 + 0.5),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(value)
            controller:SetTransparency(value / 100)
        end,
    })

    groupbox:AddSlider("Background_Overlay", {
        Text = "Dark overlay",
        Default = math.floor(controller.State.OverlayTransparency * 100 + 0.5),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(value)
            controller:SetOverlayTransparency(value / 100)
        end,
    })

    groupbox:AddSlider("Background_Panels", {
        Text = "Panel transparency",
        Default = math.floor(controller.State.PanelTransparency * 100 + 0.5),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(value)
            controller:SetPanelTransparency(value / 100)
        end,
    })

    groupbox:AddDropdown("Background_ScaleType", {
        Text = "Image scaling",
        Values = { "Crop", "Fit", "Stretch", "Tile" },
        Default = controller.State.ScaleType,
        Callback = function(value)
            controller:SetScaleType(value)
        end,
    })
end

function Background:ApplyToTab(tab)
    local groupbox = self:CreateGroupBox(tab)
    self:CreateBackgroundManager(groupbox)
end

function Background:ApplyToGroupbox(groupbox)
    self:CreateBackgroundManager(groupbox)
end

return Background
