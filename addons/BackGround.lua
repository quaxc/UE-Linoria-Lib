--[[
    BackGround.lua

    Usage:
        local Background = loadstring(readfile("addons/BackGround.lua"))()
        local bg = Background.Attach(Window, {
            Image = Background.Presets[1].Image,
            Transparency = 0.15,       -- image transparency: 0 = opaque, 1 = invisible
            OverlayTransparency = 0.35, -- dark overlay: 0 = opaque, 1 = invisible
            PanelTransparency = 0.18,   -- transparency for the main menu panels
            ScaleType = "Crop",         -- "Crop", "Fit", "Stretch", "Tile"
        })

        bg:SetImage("https://raw.githubusercontent.com/USER/REPO/BRANCH/path/image.png")
        bg:SetTransparency(0.2)
        bg:SetOverlayTransparency(0.4)
        bg:SetPanelTransparency(0.25)
        bg:SetEnabled(true)
        bg:Destroy()

    IMPORTANT:
      - Replace the example GitHub URLs in Presets with direct image URLs
        (usually https://raw.githubusercontent.com/.../file.png).
      - Roblox must be able to load the image URL as an ImageLabel asset.
      - This addon expects Window to be returned by Library:CreateWindow(...).
]]

local Background = {}

-- Put your own direct GitHub raw image links here.
-- Keep the entries as direct links to .png / .jpg images.
Background.Presets = {
    {
        Name = "Konata Izumi",
        Image = "https://github.com/quaxc/konata_fun/blob/main/resources/background/konataizumi.png?raw=true",
    },
    {
        Name = "Konata Izumi 2",
        Image = "https://github.com/quaxc/konata_fun/blob/main/resources/background/konataizumi2.png?raw=true",
    },
    {
        Name = "Astolfo",
        Image = "https://github.com/quaxc/konata_fun/blob/main/resources/background/Astolfo.png?raw=true",
    },
    {
        Name = "rat",
        Image = "https://github.com/quaxc/konata_fun/blob/main/resources/background/njrat.png?raw=true",
    },
}

local function clamp01(value, default)
    value = tonumber(value)
    if value == nil then
        return default
    end
    return math.clamp(value, 0, 1)
end

local function resolveImage(source)
    if type(source) ~= "string" or source == "" then
        return ""
    end

    -- Executors commonly provide getcustomasset/getsynasset. Downloading a
    -- raw GitHub image and converting it to a local asset is more reliable
    -- than assigning an https URL directly to ImageLabel.Image.
    local assetLoader = getcustomasset or getsynasset
    if assetLoader and writefile then
        local extension = source:match("%.(%w+)[%?#]?.*$") or "png"
        local fileName = "LinoriaBackground." .. extension
        local downloaded, data = pcall(function()
            return game:HttpGet(source)
        end)

        if downloaded and type(data) == "string" and #data > 0 then
            local saved = pcall(writefile, fileName, data)
            if saved then
                local loaded, asset = pcall(assetLoader, fileName)
                if loaded and asset then
                    return asset
                end
            end
        end
    end

    -- Fallback for environments that accept direct content URLs.
    return source
end

local function getScaleType(name)
    local values = {
        Crop = Enum.ScaleType.Crop,
        Fit = Enum.ScaleType.Fit,
        Stretch = Enum.ScaleType.Stretch,
        Tile = Enum.ScaleType.Tile,
    }
    return values[name] or Enum.ScaleType.Crop
end

function Background.Attach(Window, Config)
    Config = Config or {}

    assert(type(Window) == "table" and Window.Holder, 
        "BackGround.Attach: pass the Window returned by Library:CreateWindow()")

    local Library = (getgenv and getgenv().Library) or _G.Library
    assert(Library and Library.Create, "BackGround: Linoria Library was not found")

    local Holder = Window.Holder
    local Inner = Holder:FindFirstChild("Inner")
    assert(Inner, "BackGround: Window.Holder has no child named 'Inner'")

    local State = {
        Image = Config.Image or "",
        Transparency = clamp01(Config.Transparency, 0),
        OverlayTransparency = clamp01(Config.OverlayTransparency, 0.35),
        PanelTransparency = clamp01(Config.PanelTransparency, 0.15),
        Enabled = Config.Enabled ~= false,
        ScaleType = Config.ScaleType or "Crop",
        Tint = Config.Tint or Color3.new(1, 1, 1),
    }

    -- The image is placed inside Inner at ZIndex 0, behind the menu content.
    Inner.ClipsDescendants = true

    local Image = Library:Create("ImageLabel", {
        Name = "LinoriaBackgroundImage",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        Image = resolveImage(State.Image),
        ImageTransparency = State.Transparency,
        ImageColor3 = State.Tint,
        ScaleType = getScaleType(State.ScaleType),
        ZIndex = 0,
        Visible = State.Enabled,
        Parent = Inner,
    })

    local Overlay = Library:Create("Frame", {
        Name = "LinoriaBackgroundOverlay",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = State.OverlayTransparency,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 0,
        Visible = State.Enabled,
        Parent = Inner,
    })

    -- Make the window's base fill transparent so the image can be seen.
    local OriginalInnerTransparency = Inner.BackgroundTransparency
    Inner.BackgroundTransparency = 1

    -- The supplied Library version does not assign names to every panel.
    -- Detect broad background Frames by their area, avoiding small controls.
    local OriginalPanelTransparency = {}
    local function applyPanelTransparency()
        local innerSize = Inner.AbsoluteSize
        local innerArea = math.max(1, innerSize.X * innerSize.Y)

        for _, object in ipairs(Inner:GetDescendants()) do
            if object:IsA("Frame") and object ~= Overlay then
                local size = object.AbsoluteSize
                local areaRatio = (size.X * size.Y) / innerArea

                if areaRatio >= 0.15 then
                    if OriginalPanelTransparency[object] == nil then
                        OriginalPanelTransparency[object] = object.BackgroundTransparency
                    end
                    object.BackgroundTransparency = State.PanelTransparency
                end
            end
        end
    end

    applyPanelTransparency()
    task.defer(applyPanelTransparency)

    local Controller = {}
    Controller.State = State
    Controller.ImageLabel = Image
    Controller.Overlay = Overlay

    function Controller:SetImage(url)
        assert(type(url) == "string", "SetImage expects a URL string")
        State.Image = url
        Image.Image = resolveImage(url)
    end

    function Controller:SetTransparency(value)
        State.Transparency = clamp01(value, State.Transparency)
        Image.ImageTransparency = State.Transparency
    end

    function Controller:SetOverlayTransparency(value)
        State.OverlayTransparency = clamp01(value, State.OverlayTransparency)
        Overlay.BackgroundTransparency = State.OverlayTransparency
    end

    function Controller:SetPanelTransparency(value)
        State.PanelTransparency = clamp01(value, State.PanelTransparency)
        applyPanelTransparency()
    end

    function Controller:SetScaleType(value)
        State.ScaleType = value
        Image.ScaleType = getScaleType(value)
    end

    function Controller:SetTint(color)
        assert(typeof(color) == "Color3", "SetTint expects Color3")
        State.Tint = color
        Image.ImageColor3 = color
    end

    function Controller:SetEnabled(value)
        State.Enabled = not not value
        Image.Visible = State.Enabled
        Overlay.Visible = State.Enabled
    end

    function Controller:Destroy()
        if Image then Image:Destroy() end
        if Overlay then Overlay:Destroy() end

        if Inner and Inner.Parent then
            Inner.BackgroundTransparency = OriginalInnerTransparency
        end

        for object, transparency in pairs(OriginalPanelTransparency) do
            if object and object.Parent then
                object.BackgroundTransparency = transparency
            end
        end
    end

    return Controller
end

return Background
