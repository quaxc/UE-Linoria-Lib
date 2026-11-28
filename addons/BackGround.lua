-- BackGround.lua
-- Two independent image layers:
-- 1) GameBackground: fullscreen image behind the Linoria window, over the game view.
-- 2) MenuBackground: image inside the Linoria window, behind its controls.
-- Also includes a Blur toggle using the Library.BlurEffect already defined in Library.lua.

local Background = {
    Library = nil,
    Window = nil,
    GameController = nil,
    MenuController = nil,
    VisibilityConnection = nil,

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
    },
}

local function clamp01(value, fallback)
    value = tonumber(value)
    if value == nil then value = fallback end
    return math.clamp(value, 0, 1)
end

local function scaleType(name)
    local types = {
        Crop = Enum.ScaleType.Crop,
        Fit = Enum.ScaleType.Fit,
        Stretch = Enum.ScaleType.Stretch,
        Tile = Enum.ScaleType.Tile,
    }
    return types[name] or Enum.ScaleType.Crop
end

local function assetFromUrl(url)
    assert(type(url) == "string" and url ~= "", "[BackGround] Invalid image URL")

    local getAsset = getcustomasset or getsynasset
    if not (getAsset and writefile and isfile) then
        warn("[BackGround] This executor needs getcustomasset/getsynasset, writefile and isfile for GitHub images.")
        return nil
    end

    local filename = url:match("/([^/?#]+)$") or "background.png"
    filename = filename:gsub("[^%w_.-]", "_")
    local folder = "UE_Linoria_Backgrounds"
    local path = folder .. "/" .. filename

    local ok, result = pcall(function()
        if makefolder and isfolder and not isfolder(folder) then
            makefolder(folder)
        end

        if not isfile(path) then
            local response = game:HttpGet(url)
            assert(type(response) == "string" and #response > 100, "GitHub image response was empty")
            writefile(path, response)
        end

        return getAsset(path)
    end)

    if not ok then
        warn("[BackGround] Image download failed: " .. tostring(result))
        return nil
    end

    return result
end

local function newImageLayer(parent, name, zIndex, url, transparency, enabled, scale)
    local image = Instance.new("ImageLabel")
    image.Name = name
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.Position = UDim2.fromScale(0, 0)
    image.Size = UDim2.fromScale(1, 1)
    image.ZIndex = zIndex
    image.ScaleType = scaleType(scale)
    image.ImageTransparency = transparency
    image.Visible = enabled
    image.Parent = parent

    local function setImage(imageUrl)
        local asset = assetFromUrl(imageUrl)
        if not asset then
            image.Image = ""
            return false
        end
        image.Image = asset
        return true
    end

    setImage(url)
    return image, setImage
end

local function makeController(image, overlay, state, setImageFn, panelObjects, inner, oldInnerTransparency)
    local controller = {
        State = state,
        ImageLabel = image,
        Overlay = overlay,
    }

    local function refreshVisibility()
        local visible = state.Enabled == true and state.MenuOpen ~= false
        if image then image.Visible = visible end
        if overlay then overlay.Visible = visible end
    end

    function controller:SetMenuOpen(open)
        state.MenuOpen = open == true
        refreshVisibility()
    end

    function controller:SetImage(url)
        assert(type(url) == "string", "SetImage expects a URL string")
        state.Image = url
        return setImageFn(url)
    end

    function controller:SetTransparency(value)
        state.Transparency = clamp01(value, state.Transparency)
        image.ImageTransparency = state.Transparency
    end

    function controller:SetOverlayTransparency(value)
        state.OverlayTransparency = clamp01(value, state.OverlayTransparency)
        if overlay then
            overlay.BackgroundTransparency = state.OverlayTransparency
        end
    end

    function controller:SetPanelTransparency(value)
        state.PanelTransparency = clamp01(value, state.PanelTransparency)
        for panel in pairs(panelObjects or {}) do
            if panel and panel.Parent then
                panel.BackgroundTransparency = state.PanelTransparency
            end
        end
    end

    function controller:SetScaleType(value)
        assert(value == "Crop" or value == "Fit" or value == "Stretch" or value == "Tile", "Invalid scale type")
        state.ScaleType = value
        image.ScaleType = scaleType(value)
    end

    function controller:SetEnabled(value)
        state.Enabled = value == true
        refreshVisibility()
    end

    function controller:Destroy()
        if image then image:Destroy() end
        if overlay then overlay:Destroy() end
        if inner and inner.Parent and oldInnerTransparency ~= nil then
            inner.BackgroundTransparency = oldInnerTransparency
        end
        for panel, oldTransparency in pairs(panelObjects or {}) do
            if panel and panel.Parent then
                panel.BackgroundTransparency = oldTransparency
            end
        end
    end

    return controller
end

function Background:SetLibrary(library)
    self.Library = library
end

-- Create the fullscreen image behind the menu (ZIndex 0, menu window is ZIndex 1).
function Background:AttachGameBackground(config)
    assert(self.Library and self.Library.ScreenGui, "[BackGround] Call SetLibrary(Library) first")
    config = config or {}

    if self.GameController then
        self.GameController:Destroy()
        self.GameController = nil
    end
    if self.VisibilityConnection then
        self.VisibilityConnection:Disconnect()
        self.VisibilityConnection = nil
    end

    local state = {
        Image = config.Image or self.Presets[1].Image,
        Transparency = clamp01(config.Transparency, 0.15),
        OverlayTransparency = clamp01(config.OverlayTransparency, 1),
        Enabled = config.Enabled ~= false,
        MenuOpen = self.Library.Toggled == true,
        ScaleType = config.ScaleType or "Crop",
    }

    local image, setImage = newImageLayer(
        self.Library.ScreenGui,
        "LinoriaGameBackground",
        0,
        state.Image,
        state.Transparency,
        state.Enabled,
        state.ScaleType
    )

    local overlay
    if config.UseOverlay then
        overlay = Instance.new("Frame")
        overlay.Name = "LinoriaGameBackgroundOverlay"
        overlay.BackgroundColor3 = Color3.new(0, 0, 0)
        overlay.BackgroundTransparency = state.OverlayTransparency
        overlay.BorderSizePixel = 0
        overlay.Size = UDim2.fromScale(1, 1)
        overlay.Position = UDim2.fromScale(0, 0)
        overlay.ZIndex = 0
        overlay.Visible = state.Enabled
        overlay.Parent = self.Library.ScreenGui
    end

    self.GameController = makeController(image, overlay, state, setImage)
    self.GameController:SetMenuOpen(self.Library.Toggled == true)

    -- The fullscreen game wallpaper must only be visible while the Linoria
    -- window is open. Library.Toggle() updates Library.Toggled.
    if self.VisibilityConnection then
        self.VisibilityConnection:Disconnect()
        self.VisibilityConnection = nil
    end

    local RunService = game:GetService("RunService")
    self.VisibilityConnection = RunService.RenderStepped:Connect(function()
        if not self.Library or not self.GameController then
            return
        end

        local isOpen = self.Library.Toggled == true
        if self.GameController.State.MenuOpen ~= isOpen then
            self.GameController:SetMenuOpen(isOpen)
        end
    end)

    return self.GameController
end

-- Create the image inside the Linoria window, behind its controls.
function Background:AttachMenuBackground(window, config)
    assert(self.Library, "[BackGround] Call SetLibrary(Library) first")
    assert(window and window.Holder, "[BackGround] Pass the Window returned by Library:CreateWindow()")
    config = config or {}

    if self.MenuController then
        self.MenuController:Destroy()
        self.MenuController = nil
    end

    local inner = window.Holder:FindFirstChild("Inner")
    assert(inner, "[BackGround] Window.Holder.Inner was not found")

    local state = {
        Image = config.Image or self.Presets[1].Image,
        Transparency = clamp01(config.Transparency, 0.12),
        OverlayTransparency = clamp01(config.OverlayTransparency, 0.45),
        PanelTransparency = clamp01(config.PanelTransparency, 0.2),
        Enabled = config.Enabled ~= false,
        ScaleType = config.ScaleType or "Crop",
    }

    local oldInnerTransparency = inner.BackgroundTransparency
    inner.ClipsDescendants = true
    inner.BackgroundTransparency = 1

    -- The window's controls use ZIndex 1+, so ZIndex 0 stays behind them.
    local image, setImage = newImageLayer(
        inner,
        "LinoriaMenuBackground",
        0,
        state.Image,
        state.Transparency,
        state.Enabled,
        state.ScaleType
    )

    local overlay = Instance.new("Frame")
    overlay.Name = "LinoriaMenuBackgroundOverlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = state.OverlayTransparency
    overlay.BorderSizePixel = 0
    overlay.Position = UDim2.fromScale(0, 0)
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = 0
    overlay.Visible = state.Enabled
    overlay.Parent = inner

    local panelObjects = {}
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
            panelObjects[panel] = panel.BackgroundTransparency
            panel.BackgroundTransparency = state.PanelTransparency
        end
    end

    self.MenuController = makeController(
        image, overlay, state, setImage, panelObjects, inner, oldInnerTransparency
    )
    self.Window = window
    return self.MenuController
end

-- Backwards-compatible alias: Attach means attach the menu background.
function Background:Attach(window, config)
    return self:AttachMenuBackground(window, config)
end

function Background:SetBlurEnabled(enabled)
    assert(self.Library, "[BackGround] Call SetLibrary(Library) first")
    local library = self.Library
    library.UseBlur = enabled == true

    if library.BlurEffect then
        if library.UseBlur and library.Toggled then
            library.BlurEffect.Enabled = true
            library.BlurEffect.Size = library.BlurSize or 15
        else
            library.BlurEffect.Size = 0
            library.BlurEffect.Enabled = false
        end
    elseif library.UpdateBlur then
        library:UpdateBlur()
    end
end

function Background:SetBlurSize(size)
    assert(self.Library, "[BackGround] Call SetLibrary(Library) first")
    self.Library.BlurSize = math.clamp(tonumber(size) or 15, 0, 56)
    if self.Library.UseBlur and self.Library.Toggled and self.Library.BlurEffect then
        self.Library.BlurEffect.Enabled = true
        self.Library.BlurEffect.Size = self.Library.BlurSize
    end
end

local function presetNames(self)
    local names = {}
    for _, preset in ipairs(self.Presets) do
        table.insert(names, preset.Name)
    end
    return names
end

local function findPreset(self, name)
    for _, preset in ipairs(self.Presets) do
        if preset.Name == name then
            return preset
        end
    end
end

function Background:ApplyToTab(tab)
    assert(self.Library, "[BackGround] Call SetLibrary(Library) first")
    assert(tab, "[BackGround] Settings tab is missing")
    assert(self.MenuController, "[BackGround] Call Attach(Window, config) first")

    -- Auto-balanced two-column Settings layout:
    -- left: Menu background + Blur; right: Game background.
    -- Linoria's Groupbox Resize() automatically stacks and resizes each column.
    local menuBox = tab:AddLeftGroupbox("Menu background")
    local gameBox = tab:AddRightGroupbox("Game background")
    local blurBox = tab:AddLeftGroupbox("Blur")

    local menu = self.MenuController
    local game = self.GameController
    local names = presetNames(self)
    local menuDefault, gameDefault = 1, 1

    for index, preset in ipairs(self.Presets) do
        if preset.Image == menu.State.Image then menuDefault = index end
        if game and preset.Image == game.State.Image then gameDefault = index end
    end

    menuBox:AddToggle("BG_MenuEnabled", {
        Text = "Enable menu image",
        Default = menu.State.Enabled,
        Callback = function(value) menu:SetEnabled(value) end,
    })

    menuBox:AddDropdown("BG_MenuImage", {
        Text = "Menu image",
        Values = names,
        Default = menuDefault,
        Callback = function(value)
            local preset = findPreset(self, value)
            if preset then menu:SetImage(preset.Image) end
        end,
    })

    menuBox:AddSlider("BG_MenuOpacity", {
        Text = "Menu image opacity",
        Default = math.floor((1 - menu.State.Transparency) * 100 + 0.5),
        Min = 0, Max = 100, Rounding = 0, Suffix = "%",
        Callback = function(value) menu:SetTransparency(1 - value / 100) end,
    })

    menuBox:AddSlider("BG_MenuOverlay", {
        Text = "Menu dark overlay",
        Default = math.floor((1 - menu.State.OverlayTransparency) * 100 + 0.5),
        Min = 0, Max = 100, Rounding = 0, Suffix = "%",
        Callback = function(value) menu:SetOverlayTransparency(1 - value / 100) end,
    })

    menuBox:AddSlider("BG_MenuPanels", {
        Text = "Menu panels opacity",
        Default = math.floor((1 - menu.State.PanelTransparency) * 100 + 0.5),
        Min = 0, Max = 100, Rounding = 0, Suffix = "%",
        Callback = function(value) menu:SetPanelTransparency(1 - value / 100) end,
    })

    menuBox:AddDropdown("BG_MenuScale", {
        Text = "Menu image scaling",
        Values = { "Crop", "Fit", "Stretch", "Tile" },
        Default = menu.State.ScaleType,
        Callback = function(value) menu:SetScaleType(value) end,
    })

    gameBox:AddToggle("BG_GameEnabled", {
        Text = "Enable game background",
        Default = game and game.State.Enabled or false,
        Callback = function(value)
            if game then game:SetEnabled(value) end
        end,
    })

    gameBox:AddDropdown("BG_GameImage", {
        Text = "Game background image",
        Values = names,
        Default = gameDefault,
        Callback = function(value)
            local preset = findPreset(self, value)
            if preset and self.GameController then
                self.GameController:SetImage(preset.Image)
            end
        end,
    })

    gameBox:AddSlider("BG_GameOpacity", {
        Text = "Game image opacity",
        Default = game and math.floor((1 - game.State.Transparency) * 100 + 0.5) or 85,
        Min = 0, Max = 100, Rounding = 0, Suffix = "%",
        Callback = function(value)
            if self.GameController then
                self.GameController:SetTransparency(1 - value / 100)
            end
        end,
    })

    gameBox:AddDropdown("BG_GameScale", {
        Text = "Game image scaling",
        Values = { "Crop", "Fit", "Stretch", "Tile" },
        Default = game and game.State.ScaleType or "Crop",
        Callback = function(value)
            if self.GameController then self.GameController:SetScaleType(value) end
        end,
    })

    blurBox:AddToggle("BG_BlurEnabled", {
        Text = "Blur game when menu is open",
        Default = self.Library.UseBlur == true,
        Callback = function(value)
            self:SetBlurEnabled(value)
        end,
    })

    blurBox:AddSlider("BG_BlurSize", {
        Text = "Blur strength",
        Default = self.Library.BlurSize or 15,
        Min = 0, Max = 56, Rounding = 0,
        Callback = function(value)
            self:SetBlurSize(value)
        end,
    })

    return {
        Menu = menuBox,
        Game = gameBox,
        Blur = blurBox,
    }
end

return Background
