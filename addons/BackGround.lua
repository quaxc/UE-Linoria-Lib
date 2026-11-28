--[[
    BackGround.lua
    Linoria ThemeManager-style background manager.

    Example:
        local Background = loadstring(readfile("addons/BackGround.lua"))()

        Background:SetLibrary(Library)
        Background:Attach(Window, {
            Transparency = 0.10,
            OverlayTransparency = 0.45,
            PanelTransparency = 0.25,
            ScaleType = "Crop"
        })

        -- Put this in your Settings tab:
        Background:ApplyToTab(Tabs.Settings)

        -- Or use an existing groupbox:
        -- Background:ApplyToGroupbox(SettingsGroup)

    Controls are created using the same Linoria Groupbox API style as ThemeManager.
]]

local Background = {} do
    Background.Folder = "LinoriaLibSettings"
    Background.Library = nil
    Background.Controller = nil

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

    local function clamp01(value, fallback)
        value = tonumber(value)
        if value == nil then value = fallback end
        return math.clamp(value, 0, 1)
    end

    local function getAsset(url)
        if type(url) ~= "string" or url == "" then
            return ""
        end

        local assetLoader = getcustomasset or getsynasset
        if not assetLoader or not writefile or not isfile then
            return url
        end

        local extension = url:match("%.([%w]+)[%?#]?.*$") or "png"
        local baseName = url:match("/([^/?#]+)%.") or "background"
        baseName = baseName:gsub("[^%w_%-]", "_")
        local fileName = "UE_Linoria_Background_" .. baseName .. "." .. extension

        local ok, asset = pcall(function()
            if not isfile(fileName) then
                local data = game:HttpGet(url)
                assert(type(data) == "string" and #data > 0, "empty image response")
                writefile(fileName, data)
            end
            return assetLoader(fileName)
        end)

        if ok and asset then
            return asset
        end

        warn("[BackGround] Asset download failed; trying URL directly: " .. tostring(asset))
        return url
    end

    function Background:SetLibrary(lib)
        self.Library = lib
    end

    function Background:Attach(window, config)
        config = config or {}

        assert(self.Library, "[BackGround] Call Background:SetLibrary(Library) first.")
        assert(window and window.Holder, "[BackGround] Pass the Window returned by Library:CreateWindow().")

        local inner = window.Holder:FindFirstChild("Inner")
        assert(inner, "[BackGround] Could not find Window.Holder.Inner.")

        if self.Controller then
            self.Controller:Destroy()
            self.Controller = nil
        end

        local state = {
            Image = config.Image or self.Presets[1].Image,
            ImageTransparency = clamp01(config.Transparency, 0.10),
            OverlayTransparency = clamp01(config.OverlayTransparency, 0.45),
            PanelTransparency = clamp01(config.PanelTransparency, 0.25),
            Enabled = config.Enabled ~= false,
            ScaleType = config.ScaleType or "Crop",
        }

        local scaleTypes = {
            Crop = Enum.ScaleType.Crop,
            Fit = Enum.ScaleType.Fit,
            Stretch = Enum.ScaleType.Stretch,
            Tile = Enum.ScaleType.Tile,
        }

        assert(scaleTypes[state.ScaleType], "[BackGround] Invalid ScaleType.")

        local oldInnerTransparency = inner.BackgroundTransparency
        local oldPanelTransparency = {}
        inner.ClipsDescendants = true
        inner.BackgroundTransparency = 1

        local image = Instance.new("ImageLabel")
        image.Name = "UE_Linoria_Background"
        image.BackgroundTransparency = 1
        image.BorderSizePixel = 0
        image.Position = UDim2.fromScale(0, 0)
        image.Size = UDim2.fromScale(1, 1)
        image.ZIndex = 0
        image.ScaleType = scaleTypes[state.ScaleType]
        image.ImageTransparency = state.ImageTransparency
        image.Image = getAsset(state.Image)
        image.Visible = state.Enabled
        image.Parent = inner

        local overlay = Instance.new("Frame")
        overlay.Name = "UE_Linoria_Background_Overlay"
        overlay.BackgroundColor3 = Color3.new(0, 0, 0)
        overlay.BackgroundTransparency = state.OverlayTransparency
        overlay.BorderSizePixel = 0
        overlay.Position = UDim2.fromScale(0, 0)
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.ZIndex = 0
        overlay.Visible = state.Enabled
        overlay.Parent = inner

        -- Preserve the panel fills so Destroy() can restore them.
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

        local controller = {}
        controller.State = state
        controller.ImageLabel = image
        controller.Overlay = overlay

        function controller:SetImage(url)
            assert(type(url) == "string", "SetImage expects a URL string.")
            state.Image = url
            image.Image = getAsset(url)
        end

        function controller:SetTransparency(value)
            state.ImageTransparency = clamp01(value, state.ImageTransparency)
            image.ImageTransparency = state.ImageTransparency
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
            assert(scaleTypes[value], "ScaleType must be Crop, Fit, Stretch, or Tile.")
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
        assert(self.Library, "[BackGround] Must call Background:SetLibrary(Library) first.")
        return tab:AddLeftGroupbox("Background")
    end

    function Background:CreateBackgroundManager(groupbox)
        assert(self.Library, "[BackGround] Must call Background:SetLibrary(Library) first.")
        assert(self.Controller, "[BackGround] Must call Background:Attach(Window, config) first.")
        assert(groupbox, "[BackGround] A Settings groupbox is required.")
        assert(Options, "[BackGround] Global Options table was not found.")

        local controller = self.Controller
        local presetNames = {}
        local selectedIndex = 1

        for index, preset in ipairs(self.Presets) do
            presetNames[index] = preset.Name
            if preset.Image == controller.State.Image then
                selectedIndex = index
            end
        end

        groupbox:AddToggle("Background_Enabled", {
            Text = "Enable background",
            Default = controller.State.Enabled,
        })

        groupbox:AddDropdown("Background_Image", {
            Text = "Background image",
            Values = presetNames,
            Default = selectedIndex,
        })

        groupbox:AddSlider("Background_ImageTransparency", {
            Text = "Image transparency",
            Default = math.floor(controller.State.ImageTransparency * 100 + 0.5),
            Min = 0,
            Max = 100,
            Rounding = 0,
            Suffix = "%",
        })

        groupbox:AddSlider("Background_OverlayTransparency", {
            Text = "Dark overlay",
            Default = math.floor(controller.State.OverlayTransparency * 100 + 0.5),
            Min = 0,
            Max = 100,
            Rounding = 0,
            Suffix = "%",
        })

        groupbox:AddSlider("Background_PanelTransparency", {
            Text = "Panel transparency",
            Default = math.floor(controller.State.PanelTransparency * 100 + 0.5),
            Min = 0,
            Max = 100,
            Rounding = 0,
            Suffix = "%",
        })

        groupbox:AddDropdown("Background_ScaleType", {
            Text = "Image scaling",
            Values = { "Crop", "Fit", "Stretch", "Tile" },
            Default = table.find({ "Crop", "Fit", "Stretch", "Tile" }, controller.State.ScaleType) or 1,
        })

        -- Match ThemeManager's Options.<name>:OnChanged(callback) pattern.
        Options.Background_Enabled:OnChanged(function()
            controller:SetEnabled(Options.Background_Enabled.Value)
        end)

        Options.Background_Image:OnChanged(function()
            local value = Options.Background_Image.Value
            for _, preset in ipairs(self.Presets) do
                if preset.Name == value then
                    controller:SetImage(preset.Image)
                    break
                end
            end
        end)

        Options.Background_ImageTransparency:OnChanged(function()
            controller:SetTransparency(Options.Background_ImageTransparency.Value / 100)
        end)

        Options.Background_OverlayTransparency:OnChanged(function()
            controller:SetOverlayTransparency(Options.Background_OverlayTransparency.Value / 100)
        end)

        Options.Background_PanelTransparency:OnChanged(function()
            controller:SetPanelTransparency(Options.Background_PanelTransparency.Value / 100)
        end)

        Options.Background_ScaleType:OnChanged(function()
            controller:SetScaleType(Options.Background_ScaleType.Value)
        end)
    end

    function Background:ApplyToTab(tab)
        assert(self.Library, "[BackGround] Must call Background:SetLibrary(Library) first.")
        local groupbox = self:CreateGroupBox(tab)
        self:CreateBackgroundManager(groupbox)
    end

    function Background:ApplyToGroupbox(groupbox)
        assert(self.Library, "[BackGround] Must call Background:SetLibrary(Library) first.")
        self:CreateBackgroundManager(groupbox)
    end
end

return Background
