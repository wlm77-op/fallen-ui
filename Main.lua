local Library = {
    Configuration = {
        Background   = Color3.fromRGB(25, 25, 25),
        Accent       = Color3.fromRGB(44, 44, 44),
        Inner        = Color3.fromRGB(17, 17, 17),
        TopBar       = Color3.fromRGB(13, 13, 13),
        TabActive    = Color3.fromRGB(35, 35, 35),
        TabInactive  = Color3.fromRGB(13, 13, 13),
        TabText      = Color3.fromRGB(255, 255, 255),
        TabTextDim   = Color3.fromRGB(120, 120, 120),
        ActiveToggle = Color3.fromRGB(120, 120, 120),
    },
    Tabs         = {},
    _connections = {},
    _configItems = {},
}

local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local CONFIG_FOLDER = "Configs"

local function ensureFolder()
    if not isfolder(CONFIG_FOLDER) then
        makefolder(CONFIG_FOLDER)
    end
end

local function listConfigs()
    ensureFolder()
    local files = listfiles(CONFIG_FOLDER)
    local names = {}
    for _, path in ipairs(files) do
        local name = path:match("([^/\\]+)%.json$")
        if name then
            table.insert(names, name)
        end
    end
    return names
end

local function saveConfig(name, data)
    ensureFolder()
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if ok then
        writefile(path, encoded)
        return true
    end
    return false
end

local function loadConfig(name)
    ensureFolder()
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if not isfile(path) then
        return nil
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    return ok and decoded or nil
end

local function deleteConfig(name)
    ensureFolder()
    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    if isfile(path) then
        delfile(path)
        return true
    end
    return false
end

local function trackConn(conn)
    table.insert(Library._connections, conn)
    return conn
end

local function getFont()
    local ttfName        = "UIFont.ttf"
    local fontConfigName = "UIFont.font"
    local fontUrl        = "https://raw.githubusercontent.com/wlm77-op/fallen-ui/refs/heads/main/Assets/Font.ttf"

    if writefile and readfile and isfile and getcustomasset then
        if isfile(ttfName)        then delfile(ttfName)        end
        if isfile(fontConfigName) then delfile(fontConfigName) end

        local success, content = pcall(function()
            return game:HttpGet(fontUrl)
        end)

        if not success or not content or content == "" then
            return Font.fromEnum(Enum.Font.Code)
        end

        writefile(ttfName, content)
        local ttfAsset = getcustomasset(ttfName)

        local fontStructure = {
            name  = "UIFont",
            faces = {
                {
                    name    = "Regular",
                    weight  = 400,
                    style   = "normal",
                    assetId = ttfAsset,
                },
            },
            fallbacks = {},
        }

        writefile(fontConfigName, HttpService:JSONEncode(fontStructure))
        local fontAsset = getcustomasset(fontConfigName)
        return Font.new(fontAsset, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
    end

    return Font.fromEnum(Enum.Font.Code)
end

local function getImage(Url)
    local Name = "photo.jpg"
    if writefile and isfile and getcustomasset then
        if isfile(Name) then delfile(Name) end
        local success, content = pcall(function()
            return game:HttpGet(Url)
        end)
        if not success or not content or content == "" then
            return ""
        end
        writefile(Name, content)
        return getcustomasset(Name)
    end
    return ""
end

local UIFont = getFont()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent         = CoreGui
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local NotifGui = Instance.new("ScreenGui")
NotifGui.Name            = "Notfications"
NotifGui.Parent          = CoreGui
NotifGui.ResetOnSpawn    = false
NotifGui.IgnoreGuiInset  = true
NotifGui.ZIndexBehavior  = Enum.ZIndexBehavior.Global

local function CreateObj(ClassName, Params)
    local Obj = Instance.new(ClassName)
    for i, v in pairs(Params) do
        Obj[i] = v
    end
    return Obj
end

local NotifContainer = CreateObj("Frame", {
    Parent                 = NotifGui,
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    AnchorPoint            = Vector2.new(0, 0),
    Position               = UDim2.new(0, 12, 0, 12),
    Size                   = UDim2.new(0, 260, 1, -24),
})

CreateObj("UIListLayout", {
    Parent              = NotifContainer,
    FillDirection       = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment   = Enum.VerticalAlignment.Top,
    Padding             = UDim.new(0, 6),
    SortOrder           = Enum.SortOrder.LayoutOrder,
})

local TAG_COLORS = {
    red    = "ff4444",
    green  = "44ff88",
    yellow = "ffdd44",
    blue   = "44aaff",
    orange = "ff8833",
    white  = "ffffff",
    gray   = "aaaaaa",
    purple = "aa66ff",
    cyan   = "44ffee",
}

local function parseRichTags(str)
    str = str:gsub("{(%a+)}(.-)({/%1})", function(tag, content)
        local hex = TAG_COLORS[tag:lower()]
        if hex then
            return ('<font color="#' .. hex .. '">' .. content .. "</font>")
        end
        return content
    end)
    str = str:gsub("{(#%x%x%x%x%x%x)}(.-)({/%1})", function(hex, content)
        return ('<font color="' .. hex .. '">' .. content .. "</font>")
    end)
    return str
end

local notifCount = 0
local ANIM_IN    = 0.18
local ANIM_OUT   = 0.22
local HOLD_DEF   = 4.5

local function spawnNotif(rawText, duration)
    duration   = tonumber(duration) or HOLD_DEF
    notifCount = notifCount + 1

    local Wrapper = CreateObj("Frame", {
        Parent                 = NotifContainer,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        ClipsDescendants       = false,
        LayoutOrder            = notifCount,
    })

    local Card = CreateObj("Frame", {
        Parent                 = Wrapper,
        BackgroundColor3       = Library.Configuration.Background,
        BorderSizePixel        = 0,
        AnchorPoint            = Vector2.new(0, 0),
        Position               = UDim2.new(0, -300, 0, 0),
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        ClipsDescendants       = false,
    })

    CreateObj("UIStroke", {
        Parent          = Card,
        Color           = Library.Configuration.Accent,
        Thickness       = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    CreateObj("Frame", {
        Parent           = Card,
        BackgroundColor3 = Library.Configuration.ActiveToggle,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 0, 0, 0),
        Size             = UDim2.new(0, 2, 1, 0),
    })

    local Inner = CreateObj("Frame", {
        Parent           = Card,
        BackgroundColor3 = Library.Configuration.Inner,
        BorderSizePixel  = 0,
        Position         = UDim2.new(0, 2, 0, 0),
        Size             = UDim2.new(1, -2, 0, 0),
        AutomaticSize    = Enum.AutomaticSize.Y,
        ClipsDescendants = false,
    })

    CreateObj("UIPadding", {
        Parent        = Inner,
        PaddingLeft   = UDim.new(0, 8),
        PaddingRight  = UDim.new(0, 8),
        PaddingTop    = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
    })

    CreateObj("TextLabel", {
        Parent                 = Inner,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 0),
        AutomaticSize          = Enum.AutomaticSize.Y,
        Text                   = parseRichTags(tostring(rawText)),
        TextColor3             = Color3.fromRGB(200, 200, 200),
        TextSize               = 12,
        FontFace               = UIFont,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextYAlignment         = Enum.TextYAlignment.Top,
        TextWrapped            = true,
        RichText               = true,
    })

    local BarTrack = CreateObj("Frame", {
        Parent           = Card,
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0, 1),
        Position         = UDim2.new(0, 2, 1, 0),
        Size             = UDim2.new(1, -2, 0, 2),
    })

    local BarFill = CreateObj("Frame", {
        Parent           = BarTrack,
        BackgroundColor3 = Library.Configuration.ActiveToggle,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 1, 0),
    })

    TweenService:Create(
        Card,
        TweenInfo.new(ANIM_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, 0) }
    ):Play()

    TweenService:Create(
        BarFill,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 1, 0) }
    ):Play()

    task.delay(duration, function()
        if not Card or not Card.Parent then return end
        local slideOut = TweenService:Create(
            Card,
            TweenInfo.new(ANIM_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0, -300, 0, 0) }
        )
        slideOut:Play()
        slideOut.Completed:Connect(function()
            if Wrapper and Wrapper.Parent then
                Wrapper:Destroy()
            end
        end)
    end)
end

function Library:Notify(text, duration)
    spawnNotif(text, duration)
end

local function hsvToRgb(h, s, v)
    if s == 0 then return v, v, v end
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

local function rgbToHsv(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local v   = max
    local s   = max == 0 and 0 or (max - min) / max
    local h   = 0
    if max ~= min then
        local d = max - min
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end
    return h, s, v
end

local function applyBackground(color)
    Library.Configuration.Background = color
    for _, f in ipairs(ScreenGui:GetDescendants()) do
        if f:IsA("Frame") and f.Name == "MainFrame" then
            f.BackgroundColor3 = color
        end
        if f:IsA("Frame") and (f.Name == "SideFrame" or f.Name == "SideFrame2") then
            f.BackgroundColor3 = color
        end
    end
end

local function applyInner(color)
    Library.Configuration.Inner = color
    for _, f in ipairs(ScreenGui:GetDescendants()) do
        if f:IsA("Frame") and f.Name == "InnerFrame" then
            f.BackgroundColor3 = color
        end
        if f:IsA("Frame") and (f.Name == "SideInnerFrame" or f.Name == "SideInnerFrame2") then
            f.BackgroundColor3 = color
        end
    end
end

local function applyTopBar(color)
    Library.Configuration.TopBar = color
    for _, f in ipairs(ScreenGui:GetDescendants()) do
        if f:IsA("Frame") and f.Name == "TopBar" then
            f.BackgroundColor3 = color
        end
    end
end

local function applyAccent(color)
    Library.Configuration.Accent = color
    for _, s in ipairs(ScreenGui:GetDescendants()) do
        if s:IsA("UIStroke") then
            s.Color = color
        end
        if s:IsA("ScrollingFrame") then
            s.ScrollBarImageColor3 = color
        end
    end
end

local function applyTabActive(color)
    Library.Configuration.TabActive = color
end

local function applyTabInactive(color)
    Library.Configuration.TabInactive = color
end

local function applyActiveToggle(color)
    Library.Configuration.ActiveToggle = color
    for _, f in ipairs(ScreenGui:GetDescendants()) do
        if f:IsA("Frame") and f.Name == "Fill" then
            f.BackgroundColor3 = color
        end
        if f:IsA("Frame") and f.Name == "SliderFill" then
            f.BackgroundColor3 = color
        end
    end
end

function Library:RegisterConfigItem(id, getFn, setFn)
    self._configItems[id] = { get = getFn, set = setFn }
end

function Library:CollectConfig()
    local data = {}
    for id, item in pairs(self._configItems) do
        local ok, val = pcall(item.get)
        if ok then
            if typeof(val) == "Color3" then
                data[id] = { __type = "Color3", r = val.R, g = val.G, b = val.B }
            elseif typeof(val) == "EnumItem" then
                data[id] = { __type = "EnumItem", name = tostring(val) }
            else
                data[id] = val
            end
        end
    end
    return data
end

function Library:ApplyConfig(data)
    for id, val in pairs(data) do
        local item = self._configItems[id]
        if item then
            local decoded = val
            if type(val) == "table" and val.__type == "Color3" then
                decoded = Color3.new(val.r, val.g, val.b)
            elseif type(val) == "table" and val.__type == "EnumItem" then
                local ok, ei = pcall(function()
                    local parts = val.name:split(".")
                    return Enum[parts[2]][parts[3]]
                end)
                decoded = ok and ei or val
            end
            pcall(item.set, decoded)
        end
    end
end

function Library:CreateWindow(Params)
    local Clogs       = Params.Changelogs or {}
    local tabButtons  = {}
    local tabContents = {}
    local activeTab   = nil

    local MainFrame = CreateObj("Frame", {
        Name             = "MainFrame",
        Parent           = ScreenGui,
        BackgroundColor3 = Library.Configuration.Background,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = UDim2.new(0, 600, 0, 650),
    })

    CreateObj("UIStroke", {
        Parent          = MainFrame,
        Color           = Library.Configuration.Accent,
        Thickness       = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    local InnerFrame = CreateObj("Frame", {
        Name             = "InnerFrame",
        Parent           = MainFrame,
        BackgroundColor3 = Library.Configuration.Inner,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = UDim2.new(1, -50, 1, -50),
    })

    CreateObj("UIStroke", {
        Parent          = InnerFrame,
        Color           = Library.Configuration.Accent,
        Thickness       = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    local TopBar = CreateObj("Frame", {
        Name             = "TopBar",
        Parent           = InnerFrame,
        BackgroundColor3 = Library.Configuration.TopBar,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0.5, 0),
        Position         = UDim2.new(0.5, 0, 0, 0),
        Size             = UDim2.new(1, 0, 0, 28),
    })

    CreateObj("UIStroke", {
        Parent          = TopBar,
        Color           = Library.Configuration.Accent,
        Thickness       = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    local dragging       = false
    local dragStartMouse = Vector2.new()
    local dragStartPos   = UDim2.new()

    trackConn(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local mouse = Vector2.new(input.Position.X, input.Position.Y)
        local abs   = TopBar.AbsolutePosition
        local size  = TopBar.AbsoluteSize
        if mouse.X >= abs.X and mouse.X <= abs.X + size.X
        and mouse.Y >= abs.Y and mouse.Y <= abs.Y + size.Y then
            dragging       = true
            dragStartMouse = mouse
            dragStartPos   = MainFrame.Position
        end
    end))

    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta      = Vector2.new(input.Position.X, input.Position.Y) - dragStartMouse
        local screenSize = ScreenGui.AbsoluteSize
        local frameSize  = MainFrame.AbsoluteSize
        local originX    = dragStartPos.X.Scale * screenSize.X + dragStartPos.X.Offset
        local originY    = dragStartPos.Y.Scale * screenSize.Y + dragStartPos.Y.Offset
        local newX       = math.clamp(originX + delta.X, frameSize.X / 2, screenSize.X - frameSize.X / 2)
        local newY       = math.clamp(originY + delta.Y, frameSize.Y / 2, screenSize.Y - frameSize.Y / 2)
        MainFrame.Position = UDim2.new(0, newX, 0, newY)
    end))

    local TabScrollFrame = CreateObj("ScrollingFrame", {
        Parent                 = TopBar,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 0, 0, 0),
        Size                   = UDim2.new(1, 0, 1, 0),
        ScrollBarThickness     = 0,
        ScrollingDirection     = Enum.ScrollingDirection.X,
        CanvasSize             = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize    = Enum.AutomaticSize.X,
        ClipsDescendants       = true,
    })

    local TabButtonContainer = CreateObj("Frame", {
        Parent                 = TabScrollFrame,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 0, 0, 0),
        Size                   = UDim2.new(1, 0, 1, 0),
        AutomaticSize          = Enum.AutomaticSize.X,
    })

    CreateObj("UIPadding", {
        Parent        = TabButtonContainer,
        PaddingLeft   = UDim.new(0, 4),
        PaddingRight  = UDim.new(0, 4),
        PaddingTop    = UDim.new(0, 0),
        PaddingBottom = UDim.new(0, 0),
    })

    CreateObj("UIListLayout", {
        Parent              = TabButtonContainer,
        FillDirection       = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment   = Enum.VerticalAlignment.Center,
        Padding             = UDim.new(0, 4),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    })

    local ContentArea = CreateObj("Frame", {
        Parent                 = InnerFrame,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 0, 0, 28),
        Size                   = UDim2.new(1, 0, 1, -28),
    })

    CreateObj("TextLabel", {
        Parent                 = InnerFrame,
        BackgroundTransparency = 1,
        AnchorPoint            = Vector2.new(0.5, 0),
        Position               = UDim2.new(0.5, 0, 0, -21.5),
        Size                   = UDim2.new(1, -10, 0, 18),
        Text                   = Params.Title or "Untitled",
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 12,
        FontFace               = UIFont,
        TextXAlignment         = Enum.TextXAlignment.Center,
        TextYAlignment         = Enum.TextYAlignment.Center,
        RichText               = false,
    })

    local SideFrame = CreateObj("Frame", {
        Name             = "SideFrame",
        Parent           = MainFrame,
        BackgroundColor3 = Library.Configuration.Background,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0, 0),
        Position         = UDim2.new(1, 8, 0, 0),
        Size             = UDim2.new(0, 200, 0.5, -4),
    })

    CreateObj("UIStroke", {
        Parent          = SideFrame,
        Color           = Library.Configuration.Accent,
        Thickness       = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    local SideInnerFrame = CreateObj("Frame", {
        Name             = "SideInnerFrame",
        Parent           = SideFrame,
        BackgroundColor3 = Library.Configuration.Inner,
        BorderSizePixel  = 0,
        AnchorPoint      = Vector2.new(0.5, 1),
        Position         = UDim2.new(0.5, 0, 1, -10),
        Size             = UDim2.new(1, -20, 1, -35),
    })

    CreateObj("UIStroke", {
        Parent          = SideInnerFrame,
        Color           = Library.Configuration.Accent,
        Thickness       = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    CreateObj("TextLabel", {
        Parent                 = SideInnerFrame,
        BackgroundTransparency = 1,
        AnchorPoint            = Vector2.new(0.5, 0),
        Position               = UDim2.new(0.5, 0, 0, -21.5),
        Size                   = UDim2.new(1, -10, 0, 18),
        Text                   = "Changelogs",
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextSize               = 12,
        FontFace               = UIFont,
        TextXAlignment         = Enum.TextXAlignment.Center,
        TextYAlignment         = Enum.TextYAlignment.Center,
        RichText               = false,
    })

    local Scroll = CreateObj("ScrollingFrame", {
        Parent                 = SideInnerFrame,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Position               = UDim2.new(0, 5, 0, 5),
        Size                   = UDim2.new(1, -10, 1, -10),
        ScrollBarThickness     = 2,
        ScrollBarImageColor3   = Library.Configuration.Accent,
        CanvasSize             = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize    = Enum.AutomaticSize.Y,
    })

    CreateObj("UIListLayout", {
        Parent              = Scroll,
        FillDirection       = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment   = Enum.VerticalAlignment.Top,
        Padding             = UDim.new(0, 3),
        SortOrder           = Enum.SortOrder.LayoutOrder,
    })

    for i = 1, #Clogs do
        CreateObj("TextLabel", {
            Parent                 = Scroll,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 0, 14),
            Text                   = Clogs[i],
            TextColor3             = Color3.fromRGB(160, 160, 160),
            TextSize               = 12,
            FontFace               = UIFont,
            TextXAlignment         = Enum.TextXAlignment.Left,
            TextYAlignment         = Enum.TextYAlignment.Center,
            TextWrapped            = false,
            RichText               = false,
            LayoutOrder            = i,
        })
    end

    local function setActiveTab(tabName)
        if activeTab == tabName then return end
        activeTab = tabName
        for name, btn in pairs(tabButtons) do
            local isActive = (name == tabName)
            btn.BackgroundColor3 = isActive
                and Library.Configuration.TabActive
                or  Library.Configuration.TabInactive
            btn.TextColor3 = isActive
                and Library.Configuration.TabText
                or  Library.Configuration.TabTextDim
        end
        for name, frame in pairs(tabContents) do
            frame.Visible = (name == tabName)
        end
    end

    local guiVisible = true
    local Window     = {}
    Window.ToggleKeybind = Enum.KeyCode.K

    function Window:Unload()
        for _, conn in ipairs(Library._connections) do
            pcall(function() conn:Disconnect() end)
        end
        Library._connections = {}
        ScreenGui:Destroy()
        NotifGui:Destroy()
    end

    trackConn(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Keyboard
        and input.KeyCode == Window.ToggleKeybind then
            guiVisible        = not guiVisible
            ScreenGui.Enabled = guiVisible
        end
    end))

    function Window:AddTab(name)
        local textService = game:GetService("TextService")
        local textSize    = textService:GetTextSize(name, 12, Enum.Font.Code, Vector2.new(1000, 28))
        local btnWidth    = math.max(textSize.X + 16, 40)

        local TabBtn = CreateObj("TextButton", {
            Parent           = TabButtonContainer,
            BackgroundColor3 = Library.Configuration.TabInactive,
            BorderSizePixel  = 0,
            Size             = UDim2.new(0, btnWidth, 0, 20),
            Text             = name,
            TextColor3       = Library.Configuration.TabTextDim,
            TextSize         = 12,
            FontFace         = UIFont,
            AutoButtonColor  = false,
            LayoutOrder      = #tabButtons + 1,
        })

        CreateObj("UIStroke", {
            Parent          = TabBtn,
            Color           = Library.Configuration.Accent,
            Thickness       = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })

        local ColumnsFrame = CreateObj("Frame", {
            Parent                 = ContentArea,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Position               = UDim2.new(0, 8, 0, 8),
            Size                   = UDim2.new(1, -16, 1, -16),
            Visible                = false,
        })

        local LeftColumn = CreateObj("ScrollingFrame", {
            Parent                 = ColumnsFrame,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Position               = UDim2.new(0, 0, 0, 0),
            Size                   = UDim2.new(0.5, -3, 1, 0),
            ScrollBarThickness     = 2,
            ScrollBarImageColor3   = Library.Configuration.Accent,
            CanvasSize             = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        })

        CreateObj("UIListLayout", {
            Parent              = LeftColumn,
            FillDirection       = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment   = Enum.VerticalAlignment.Top,
            Padding             = UDim.new(0, 4),
            SortOrder           = Enum.SortOrder.LayoutOrder,
        })

        local RightColumn = CreateObj("ScrollingFrame", {
            Parent                 = ColumnsFrame,
            BackgroundTransparency = 1,
            BorderSizePixel        = 0,
            Position               = UDim2.new(0.5, 3, 0, 0),
            Size                   = UDim2.new(0.5, -3, 1, 0),
            ScrollBarThickness     = 2,
            ScrollBarImageColor3   = Library.Configuration.Accent,
            CanvasSize             = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize    = Enum.AutomaticSize.Y,
        })

        CreateObj("UIListLayout", {
            Parent              = RightColumn,
            FillDirection       = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment   = Enum.VerticalAlignment.Top,
            Padding             = UDim.new(0, 4),
            SortOrder           = Enum.SortOrder.LayoutOrder,
        })

        tabButtons[name]  = TabBtn
        tabContents[name] = ColumnsFrame

        if activeTab == nil then
            setActiveTab(name)
        end

        TabBtn.MouseButton1Click:Connect(function()
            setActiveTab(name)
        end)

        local boxCountLeft  = 0
        local boxCountRight = 0
        local itemIdCounter = 0

        local function nextId(prefix)
            itemIdCounter = itemIdCounter + 1
            return name .. "_" .. prefix .. "_" .. tostring(itemIdCounter)
        end

        local function BuildBox(parent, counter, label)
            counter = counter + 1

            local WrapperFrame = CreateObj("Frame", {
                Parent           = parent,
                BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                BorderSizePixel  = 0,
                Size             = UDim2.new(1, 0, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                LayoutOrder      = counter,
                ClipsDescendants = false,
            })

            CreateObj("UIStroke", {
                Parent          = WrapperFrame,
                Color           = Library.Configuration.Accent,
                Thickness       = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            })

            local BoxFrame = CreateObj("Frame", {
                Parent           = WrapperFrame,
                BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                BorderSizePixel  = 0,
                Position         = UDim2.new(0, 1, 0, 1),
                Size             = UDim2.new(1, -2, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                ClipsDescendants = false,
            })

            CreateObj("UIPadding", {
                Parent        = BoxFrame,
                PaddingLeft   = UDim.new(0, 6),
                PaddingRight  = UDim.new(0, 6),
                PaddingTop    = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 6),
            })

            CreateObj("UIListLayout", {
                Parent              = BoxFrame,
                FillDirection       = Enum.FillDirection.Vertical,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment   = Enum.VerticalAlignment.Top,
                Padding             = UDim.new(0, 4),
                SortOrder           = Enum.SortOrder.LayoutOrder,
            })

            if label and label ~= "" then
                CreateObj("TextLabel", {
                    Parent                 = BoxFrame,
                    BackgroundTransparency = 1,
                    Size                   = UDim2.new(1, 0, 0, 14),
                    Text                   = label,
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                    LayoutOrder            = 0,
                })
            end

            local ContentList = CreateObj("Frame", {
                Parent                 = BoxFrame,
                BackgroundTransparency = 1,
                BorderSizePixel        = 0,
                Size                   = UDim2.new(1, 0, 0, 0),
                AutomaticSize          = Enum.AutomaticSize.Y,
                LayoutOrder            = 1,
            })

            CreateObj("UIListLayout", {
                Parent              = ContentList,
                FillDirection       = Enum.FillDirection.Vertical,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                VerticalAlignment   = Enum.VerticalAlignment.Top,
                Padding             = UDim.new(0, 5),
                SortOrder           = Enum.SortOrder.LayoutOrder,
            })

            local Box   = {}
            Box.Content = ContentList

            function Box:AddTitle(text)
                local Row = CreateObj("Frame", {
                    Parent                 = self.Content,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 16),
                    LayoutOrder            = #self.Content:GetChildren(),
                    ClipsDescendants       = false,
                })

                local TitleLabel = CreateObj("TextLabel", {
                    Parent                 = Row,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 0, 0, 0),
                    Size                   = UDim2.new(1, 0, 1, 0),
                    Text                   = text or "",
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                })

                local rightOffset = 0
                local function shrinkTitle(px)
                    rightOffset     = rightOffset + px
                    TitleLabel.Size = UDim2.new(1, -rightOffset, 1, 0)
                end

                local TitleObj = {}

                function TitleObj:SetText(str)
                    TitleLabel.Text = tostring(str)
                end

                function TitleObj:SetColor(color)
                    TitleLabel.TextColor3 = color
                end

                function TitleObj:AddKeyPicker(KParams)
                    local DefaultKey = KParams.Key      or Enum.KeyCode.E
                    local KCallback  = KParams.Function or function() end
                    local CurrentKey = DefaultKey
                    local Listening  = false
                    local kpCfgId    = nextId("keypicker_title")

                    shrinkTitle(36)

                    local KBox = CreateObj("Frame", {
                        Parent           = Row,
                        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                        BorderSizePixel  = 0,
                        AnchorPoint      = Vector2.new(1, 0.5),
                        Position         = UDim2.new(1, 0, 0.5, 0),
                        Size             = UDim2.new(0, 32, 0, 12),
                        ZIndex           = 6,
                    })

                    CreateObj("UIStroke", {
                        Parent          = KBox,
                        Color           = Library.Configuration.Accent,
                        Thickness       = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    })

                    local KLabel = CreateObj("TextLabel", {
                        Parent                 = KBox,
                        BackgroundTransparency = 1,
                        Size                   = UDim2.new(1, 0, 1, 0),
                        Text                   = DefaultKey.Name,
                        TextColor3             = Color3.fromRGB(160, 160, 160),
                        TextSize               = 9,
                        FontFace               = UIFont,
                        TextXAlignment         = Enum.TextXAlignment.Center,
                        TextYAlignment         = Enum.TextYAlignment.Center,
                        ClipsDescendants       = true,
                        ZIndex                 = 7,
                    })

                    local KBtn = CreateObj("TextButton", {
                        Parent                 = KBox,
                        BackgroundTransparency = 1,
                        BorderSizePixel        = 0,
                        Size                   = UDim2.new(1, 0, 1, 0),
                        Text                   = "",
                        ZIndex                 = 8,
                    })

                    local function startListen()
                        if Listening then return end
                        Listening         = true
                        KLabel.Text       = "..."
                        KLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                        local conn
                        conn = UserInputService.InputBegan:Connect(function(input, processed)
                            if processed then return end
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                CurrentKey        = input.KeyCode
                                KLabel.Text       = input.KeyCode.Name
                                KLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
                                Listening         = false
                                conn:Disconnect()
                            end
                        end)
                    end

                    KBtn.MouseButton1Click:Connect(startListen)

                    trackConn(UserInputService.InputBegan:Connect(function(input, processed)
                        if processed or Listening then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard
                        and input.KeyCode == CurrentKey then
                            KCallback(input.KeyCode)
                        end
                    end))

                    local KP = {}
                    function KP:Set(key)
                        CurrentKey    = key
                        KLabel.Text   = key.Name
                    end
                    function KP:Get() return CurrentKey end

                    Library:RegisterConfigItem(kpCfgId,
                        function() return CurrentKey end,
                        function(val)
                            if typeof(val) == "EnumItem" then
                                KP:Set(val)
                            end
                        end
                    )

                    return KP
                end

                function TitleObj:AddColorPicker(CParams)
                    local DefaultColor = CParams.Default or CParams.Defualt or Color3.fromRGB(200, 200, 200)
                    local CCallback    = CParams.Function or function() end
                    local ch, cs, cv   = rgbToHsv(DefaultColor.R, DefaultColor.G, DefaultColor.B)
                    local CurrentColor = DefaultColor
                    local popupOpen    = false
                    local popupFrame   = nil
                    local cpCfgId      = nextId("colorpicker_title")

                    shrinkTitle(18)

                    local colorSwatch = CreateObj("Frame", {
                        Parent           = Row,
                        BackgroundColor3 = DefaultColor,
                        BorderSizePixel  = 0,
                        AnchorPoint      = Vector2.new(1, 0.5),
                        Position         = UDim2.new(1, -rightOffset + 18, 0.5, 0),
                        Size             = UDim2.new(0, 14, 0, 12),
                        ZIndex           = 6,
                    })

                    CreateObj("UIStroke", {
                        Parent          = colorSwatch,
                        Color           = Library.Configuration.Accent,
                        Thickness       = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    })

                    local SwatchBtn = CreateObj("TextButton", {
                        Parent                 = colorSwatch,
                        BackgroundTransparency = 1,
                        BorderSizePixel        = 0,
                        Size                   = UDim2.new(1, 0, 1, 0),
                        Text                   = "",
                        ZIndex                 = 8,
                    })

                    local PW, PH   = 160, 160
                    local HH       = 12
                    local POPUP_H  = PH + HH + 12 + 6

                    local function buildPopup()
                        popupFrame = CreateObj("Frame", {
                            Parent           = ScreenGui,
                            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
                            BorderSizePixel  = 0,
                            Size             = UDim2.new(0, PW + 16, 0, POPUP_H),
                            Position         = UDim2.new(0, 0, 0, 0),
                            ZIndex           = 50,
                            ClipsDescendants = false,
                        })

                        CreateObj("UIStroke", {
                            Parent          = popupFrame,
                            Color           = Library.Configuration.Accent,
                            Thickness       = 1,
                            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        })

                        local svArea = CreateObj("Frame", {
                            Parent           = popupFrame,
                            BackgroundColor3 = Color3.fromHSV(ch, 1, 1),
                            BorderSizePixel  = 0,
                            Position         = UDim2.new(0, 8, 0, 8),
                            Size             = UDim2.new(0, PW, 0, PH),
                            ZIndex           = 51,
                            ClipsDescendants = true,
                        })

                        local svWhite = CreateObj("Frame", {
                            Parent          = svArea,
                            Size            = UDim2.new(1, 0, 1, 0),
                            BorderSizePixel = 0,
                            ZIndex          = 52,
                        })

                        CreateObj("UIGradient", {
                            Parent       = svWhite,
                            Color        = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
                            }),
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0),
                                NumberSequenceKeypoint.new(1, 1),
                            }),
                            Rotation = 0,
                        })

                        local svBlack = CreateObj("Frame", {
                            Parent          = svArea,
                            Size            = UDim2.new(1, 0, 1, 0),
                            BorderSizePixel = 0,
                            ZIndex          = 53,
                        })

                        CreateObj("UIGradient", {
                            Parent       = svBlack,
                            Color        = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
                            }),
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 1),
                                NumberSequenceKeypoint.new(1, 0),
                            }),
                            Rotation = 90,
                        })

                        local svCursor = CreateObj("Frame", {
                            Parent           = svArea,
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BorderSizePixel  = 0,
                            AnchorPoint      = Vector2.new(0.5, 0.5),
                            Position         = UDim2.new(cs, 0, 1 - cv, 0),
                            Size             = UDim2.new(0, 6, 0, 6),
                            ZIndex           = 55,
                        })

                        CreateObj("UICorner", {
                            Parent       = svCursor,
                            CornerRadius = UDim.new(1, 0),
                        })

                        CreateObj("UIStroke", {
                            Parent    = svCursor,
                            Color     = Color3.fromRGB(0, 0, 0),
                            Thickness = 1,
                        })

                        local hueBar = CreateObj("Frame", {
                            Parent           = popupFrame,
                            BorderSizePixel  = 0,
                            Position         = UDim2.new(0, 8, 0, PH + 12),
                            Size             = UDim2.new(0, PW, 0, HH),
                            ZIndex           = 51,
                            ClipsDescendants = true,
                        })

                        CreateObj("UIGradient", {
                            Parent = hueBar,
                            Color  = ColorSequence.new({
                                ColorSequenceKeypoint.new(0 / 6, Color3.fromHSV(0 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(6 / 6, Color3.fromHSV(0,     1, 1)),
                            }),
                            Rotation = 0,
                        })

                        CreateObj("UIStroke", {
                            Parent          = hueBar,
                            Color           = Library.Configuration.Accent,
                            Thickness       = 1,
                            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        })

                        local hueCursor = CreateObj("Frame", {
                            Parent           = hueBar,
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BorderSizePixel  = 0,
                            AnchorPoint      = Vector2.new(0.5, 0.5),
                            Position         = UDim2.new(ch, 0, 0.5, 0),
                            Size             = UDim2.new(0, 4, 1, 0),
                            ZIndex           = 55,
                        })

                        CreateObj("UIStroke", {
                            Parent    = hueCursor,
                            Color     = Color3.fromRGB(0, 0, 0),
                            Thickness = 1,
                        })

                        local function applyColor()
                            local r, g, b        = hsvToRgb(ch, cs, cv)
                            CurrentColor         = Color3.new(r, g, b)
                            colorSwatch.BackgroundColor3 = CurrentColor
                            svArea.BackgroundColor3      = Color3.fromHSV(ch, 1, 1)
                            svCursor.Position  = UDim2.new(cs, 0, 1 - cv, 0)
                            hueCursor.Position = UDim2.new(ch, 0, 0.5, 0)
                            CCallback(CurrentColor)
                        end

                        local svDragging  = false
                        local hueDragging = false

                        local svHit = CreateObj("TextButton", {
                            Parent                 = svArea,
                            BackgroundTransparency = 1,
                            BorderSizePixel        = 0,
                            Size                   = UDim2.new(1, 0, 1, 0),
                            Text                   = "",
                            ZIndex                 = 56,
                        })

                        local function updateSV(inputX, inputY)
                            local abs  = svArea.AbsolutePosition
                            local size = svArea.AbsoluteSize
                            cs = math.clamp((inputX - abs.X) / size.X, 0, 1)
                            cv = math.clamp(1 - (inputY - abs.Y) / size.Y, 0, 1)
                            applyColor()
                        end

                        svHit.MouseButton1Down:Connect(function()
                            svDragging = true
                            local m = game.Players.LocalPlayer:GetMouse()
                            updateSV(m.X, m.Y)
                        end)

                        local hueHit = CreateObj("TextButton", {
                            Parent                 = hueBar,
                            BackgroundTransparency = 1,
                            BorderSizePixel        = 0,
                            Size                   = UDim2.new(1, 0, 1, 0),
                            Text                   = "",
                            ZIndex                 = 56,
                        })

                        local function updateHue(inputX)
                            local abs  = hueBar.AbsolutePosition
                            local size = hueBar.AbsoluteSize
                            ch = math.clamp((inputX - abs.X) / size.X, 0, 1)
                            applyColor()
                        end

                        hueHit.MouseButton1Down:Connect(function()
                            hueDragging = true
                            local m = game.Players.LocalPlayer:GetMouse()
                            updateHue(m.X)
                        end)

                        UserInputService.InputEnded:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                svDragging  = false
                                hueDragging = false
                            end
                        end)

                        UserInputService.InputChanged:Connect(function(input)
                            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                            if svDragging  then updateSV(input.Position.X, input.Position.Y) end
                            if hueDragging then updateHue(input.Position.X) end
                        end)

                        local function repositionPopup()
                            local abs = colorSwatch.AbsolutePosition
                            local pw  = popupFrame.AbsoluteSize.X
                            local sx  = ScreenGui.AbsoluteSize.X
                            local px  = math.clamp(abs.X - pw / 2, 4, sx - pw - 4)
                            popupFrame.Position = UDim2.new(0, px, 0, abs.Y + 16)
                        end

                        task.defer(repositionPopup)

                        local closeConn
                        closeConn = UserInputService.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                task.defer(function()
                                    local m    = game.Players.LocalPlayer:GetMouse()
                                    local abs  = popupFrame and popupFrame.AbsolutePosition
                                    local size = popupFrame and popupFrame.AbsoluteSize
                                    if not abs then return end
                                    local inside = m.X >= abs.X and m.X <= abs.X + size.X
                                               and m.Y >= abs.Y and m.Y <= abs.Y + size.Y
                                    if not inside then
                                        popupOpen = false
                                        popupFrame:Destroy()
                                        popupFrame = nil
                                        closeConn:Disconnect()
                                    end
                                end)
                            end
                        end)
                    end

                    SwatchBtn.MouseButton1Click:Connect(function()
                        if popupOpen then
                            popupOpen = false
                            if popupFrame then
                                popupFrame:Destroy()
                                popupFrame = nil
                            end
                        else
                            popupOpen = true
                            buildPopup()
                        end
                    end)

                    local CP2 = {}
                    function CP2:Set(color)
                        if typeof(color) ~= "Color3" then return end
                        ch, cs, cv   = rgbToHsv(color.R, color.G, color.B)
                        CurrentColor = color
                        colorSwatch.BackgroundColor3 = color
                        CCallback(color)
                    end
                    function CP2:Get() return CurrentColor end

                    Library:RegisterConfigItem(cpCfgId,
                        function() return CurrentColor end,
                        function(val) CP2:Set(val) end
                    )

                    return CP2
                end

                return TitleObj
            end

            function Box:AddButton(Params)
                local Title    = Params.Title    or "Button"
                local Callback = Params.Function or function() end

                local Row = CreateObj("Frame", {
                    Parent                 = self.Content,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 16),
                    LayoutOrder            = #self.Content:GetChildren(),
                })

                local Btn = CreateObj("TextButton", {
                    Parent           = Row,
                    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                    BorderSizePixel  = 0,
                    Size             = UDim2.new(1, 0, 1, 0),
                    Text             = Title,
                    TextColor3       = Color3.fromRGB(200, 200, 200),
                    TextSize         = 12,
                    FontFace         = UIFont,
                    TextXAlignment   = Enum.TextXAlignment.Center,
                    TextYAlignment   = Enum.TextYAlignment.Center,
                    AutoButtonColor  = false,
                    ZIndex           = 5,
                })

                CreateObj("UIStroke", {
                    Parent          = Btn,
                    Color           = Library.Configuration.Accent,
                    Thickness       = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                })

                Btn.MouseButton1Click:Connect(function()
                    Callback()
                end)

                local Button = {}
                function Button:SetTitle(text)
                    Btn.Text = tostring(text)
                end
                return Button
            end

            function Box:AddToggle(Params)
                local Title    = Params.Title    or "Toggle"
                local Default  = Params.Default  or false
                local Callback = Params.Function or function() end
                local State    = Default
                local cfgId    = nextId("toggle_" .. Title)

                local Wrapper = CreateObj("Frame", {
                    Parent                 = self.Content,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 16),
                    LayoutOrder            = #self.Content:GetChildren(),
                    ClipsDescendants       = false,
                })

                local Row = CreateObj("Frame", {
                    Parent                 = Wrapper,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 16),
                    ClipsDescendants       = false,
                })

                local CheckBox = CreateObj("Frame", {
                    Parent           = Row,
                    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                    BorderSizePixel  = 0,
                    AnchorPoint      = Vector2.new(0, 0.5),
                    Position         = UDim2.new(0, 0, 0.5, 0),
                    Size             = UDim2.new(0, 12, 0, 12),
                })

                CreateObj("UIStroke", {
                    Parent          = CheckBox,
                    Color           = Library.Configuration.Accent,
                    Thickness       = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                })

                local Fill = CreateObj("Frame", {
                    Name             = "Fill",
                    Parent           = CheckBox,
                    BackgroundColor3 = Library.Configuration.ActiveToggle,
                    BorderSizePixel  = 0,
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    Position         = UDim2.new(0.5, 0, 0.5, 0),
                    Size             = UDim2.new(1, 0, 1, 0),
                    Visible          = Default,
                })

                local TitleLabel = CreateObj("TextLabel", {
                    Parent                 = Row,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 18, 0, 0),
                    Size                   = UDim2.new(1, -18, 1, 0),
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                })

                local HitBtn = CreateObj("TextButton", {
                    Parent                 = Row,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Position               = UDim2.new(0, 0, 0, 0),
                    Size                   = UDim2.new(1, 0, 1, 0),
                    Text                   = "",
                    ZIndex                 = 5,
                })

                local rightOffset = 0
                local function shrinkTitle(px)
                    rightOffset     = rightOffset + px
                    TitleLabel.Size = UDim2.new(1, -(18 + rightOffset), 1, 0)
                    HitBtn.Size     = UDim2.new(1, -rightOffset, 1, 0)
                end

                local Toggle = {}

                local function applyState(value, fireCallback)
                    State        = value
                    Fill.Visible = State
                    if fireCallback then Callback(State) end
                end

                HitBtn.MouseButton1Click:Connect(function()
                    applyState(not State, true)
                end)

                function Toggle:Set(value)
                    if type(value) ~= "boolean" then return end
                    applyState(value, true)
                end

                function Toggle:Get()
                    return State
                end

                Library:RegisterConfigItem(cfgId,
                    function() return State end,
                    function(val) applyState(val == true, true) end
                )

                function Toggle:AddKeyPicker(KParams)
                    local DefaultKey = KParams.Key      or Enum.KeyCode.E
                    local KCallback  = KParams.Function or function() end
                    local CurrentKey = DefaultKey
                    local Listening  = false
                    local kpCfgId    = nextId("keypicker_toggle_" .. Title)

                    shrinkTitle(36)

                    local KBox = CreateObj("Frame", {
                        Parent           = Row,
                        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                        BorderSizePixel  = 0,
                        AnchorPoint      = Vector2.new(1, 0.5),
                        Position         = UDim2.new(1, -(rightOffset - 36), 0.5, 0),
                        Size             = UDim2.new(0, 32, 0, 12),
                        ZIndex           = 6,
                    })

                    CreateObj("UIStroke", {
                        Parent          = KBox,
                        Color           = Library.Configuration.Accent,
                        Thickness       = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    })

                    local KLabel = CreateObj("TextLabel", {
                        Parent                 = KBox,
                        BackgroundTransparency = 1,
                        Size                   = UDim2.new(1, 0, 1, 0),
                        Text                   = DefaultKey.Name,
                        TextColor3             = Color3.fromRGB(160, 160, 160),
                        TextSize               = 9,
                        FontFace               = UIFont,
                        TextXAlignment         = Enum.TextXAlignment.Center,
                        TextYAlignment         = Enum.TextYAlignment.Center,
                        ClipsDescendants       = true,
                        ZIndex                 = 7,
                    })

                    local KBtn = CreateObj("TextButton", {
                        Parent                 = KBox,
                        BackgroundTransparency = 1,
                        BorderSizePixel        = 0,
                        Size                   = UDim2.new(1, 0, 1, 0),
                        Text                   = "",
                        ZIndex                 = 8,
                    })

                    local function startListen()
                        if Listening then return end
                        Listening         = true
                        KLabel.Text       = "..."
                        KLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                        local conn
                        conn = UserInputService.InputBegan:Connect(function(input, processed)
                            if processed then return end
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                CurrentKey        = input.KeyCode
                                KLabel.Text       = input.KeyCode.Name
                                KLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
                                Listening         = false
                                conn:Disconnect()
                            end
                        end)
                    end

                    KBtn.MouseButton1Click:Connect(startListen)

                    trackConn(UserInputService.InputBegan:Connect(function(input, processed)
                        if processed or Listening then return end
                        if input.UserInputType == Enum.UserInputType.Keyboard
                        and input.KeyCode == CurrentKey then
                            KCallback(not State)
                        end
                    end))

                    local KP = {}
                    function KP:Set(key)
                        CurrentKey  = key
                        KLabel.Text = key.Name
                    end
                    function KP:Get() return CurrentKey end

                    Library:RegisterConfigItem(kpCfgId,
                        function() return CurrentKey end,
                        function(val)
                            if typeof(val) == "EnumItem" then
                                KP:Set(val)
                            end
                        end
                    )

                    return KP
                end

                function Toggle:AddColorPicker(CParams)
                    local DefaultColor = CParams.Defualt or CParams.Default or Color3.fromRGB(255, 255, 255)
                    local CCallback    = CParams.Function or function() end
                    local h, s, v      = rgbToHsv(DefaultColor.R, DefaultColor.G, DefaultColor.B)
                    local CurrentColor = DefaultColor
                    local popupOpen    = false
                    local popupFrame   = nil
                    local cpCfgId      = nextId("colorpicker_toggle_" .. Title)

                    shrinkTitle(18)

                    local colorSwatch = CreateObj("Frame", {
                        Parent           = Row,
                        BackgroundColor3 = DefaultColor,
                        BorderSizePixel  = 0,
                        AnchorPoint      = Vector2.new(1, 0.5),
                        Position         = UDim2.new(1, -(rightOffset - 18), 0.5, 0),
                        Size             = UDim2.new(0, 14, 0, 12),
                        ZIndex           = 6,
                    })

                    CreateObj("UIStroke", {
                        Parent          = colorSwatch,
                        Color           = Library.Configuration.Accent,
                        Thickness       = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    })

                    local SwatchBtn = CreateObj("TextButton", {
                        Parent                 = colorSwatch,
                        BackgroundTransparency = 1,
                        BorderSizePixel        = 0,
                        Size                   = UDim2.new(1, 0, 1, 0),
                        Text                   = "",
                        ZIndex                 = 8,
                    })

                    local PW, PH  = 160, 160
                    local HW, HH  = 160, 12
                    local POPUP_H = PH + HH + 12 + 6

                    local function buildPopup()
                        popupFrame = CreateObj("Frame", {
                            Parent           = ScreenGui,
                            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
                            BorderSizePixel  = 0,
                            Size             = UDim2.new(0, PW + 16, 0, POPUP_H),
                            Position         = UDim2.new(0, 0, 0, 0),
                            ZIndex           = 50,
                            ClipsDescendants = false,
                        })

                        CreateObj("UIStroke", {
                            Parent          = popupFrame,
                            Color           = Library.Configuration.Accent,
                            Thickness       = 1,
                            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        })

                        local svArea = CreateObj("Frame", {
                            Parent           = popupFrame,
                            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                            BorderSizePixel  = 0,
                            Position         = UDim2.new(0, 8, 0, 8),
                            Size             = UDim2.new(0, PW, 0, PH),
                            ZIndex           = 51,
                            ClipsDescendants = true,
                        })

                        local svWhite = CreateObj("Frame", {
                            Parent          = svArea,
                            Size            = UDim2.new(1, 0, 1, 0),
                            BorderSizePixel = 0,
                            ZIndex          = 52,
                        })

                        CreateObj("UIGradient", {
                            Parent       = svWhite,
                            Color        = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
                            }),
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0),
                                NumberSequenceKeypoint.new(1, 1),
                            }),
                            Rotation = 0,
                        })

                        local svBlack = CreateObj("Frame", {
                            Parent          = svArea,
                            Size            = UDim2.new(1, 0, 1, 0),
                            BorderSizePixel = 0,
                            ZIndex          = 53,
                        })

                        CreateObj("UIGradient", {
                            Parent       = svBlack,
                            Color        = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
                            }),
                            Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 1),
                                NumberSequenceKeypoint.new(1, 0),
                            }),
                            Rotation = 90,
                        })

                        local svCursor = CreateObj("Frame", {
                            Parent           = svArea,
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BorderSizePixel  = 0,
                            AnchorPoint      = Vector2.new(0.5, 0.5),
                            Position         = UDim2.new(s, 0, 1 - v, 0),
                            Size             = UDim2.new(0, 6, 0, 6),
                            ZIndex           = 55,
                        })

                        CreateObj("UICorner", {
                            Parent       = svCursor,
                            CornerRadius = UDim.new(1, 0),
                        })

                        CreateObj("UIStroke", {
                            Parent    = svCursor,
                            Color     = Color3.fromRGB(0, 0, 0),
                            Thickness = 1,
                        })

                        local hueBar = CreateObj("Frame", {
                            Parent           = popupFrame,
                            BorderSizePixel  = 0,
                            Position         = UDim2.new(0, 8, 0, PH + 12),
                            Size             = UDim2.new(0, HW, 0, HH),
                            ZIndex           = 51,
                            ClipsDescendants = true,
                        })

                        CreateObj("UIGradient", {
                            Parent = hueBar,
                            Color  = ColorSequence.new({
                                ColorSequenceKeypoint.new(0 / 6, Color3.fromHSV(0 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
                                ColorSequenceKeypoint.new(6 / 6, Color3.fromHSV(0,     1, 1)),
                            }),
                            Rotation = 0,
                        })

                        CreateObj("UIStroke", {
                            Parent          = hueBar,
                            Color           = Library.Configuration.Accent,
                            Thickness       = 1,
                            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                        })

                        local hueCursor = CreateObj("Frame", {
                            Parent           = hueBar,
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BorderSizePixel  = 0,
                            AnchorPoint      = Vector2.new(0.5, 0.5),
                            Position         = UDim2.new(h, 0, 0.5, 0),
                            Size             = UDim2.new(0, 4, 1, 0),
                            ZIndex           = 55,
                        })

                        CreateObj("UIStroke", {
                            Parent    = hueCursor,
                            Color     = Color3.fromRGB(0, 0, 0),
                            Thickness = 1,
                        })

                        local function applyColor()
                            local r, g, b        = hsvToRgb(h, s, v)
                            CurrentColor         = Color3.new(r, g, b)
                            colorSwatch.BackgroundColor3 = CurrentColor
                            svArea.BackgroundColor3      = Color3.fromHSV(h, 1, 1)
                            svCursor.Position  = UDim2.new(s, 0, 1 - v, 0)
                            hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                            CCallback(CurrentColor)
                        end

                        local svDragging  = false
                        local hueDragging = false

                        local svHit = CreateObj("TextButton", {
                            Parent                 = svArea,
                            BackgroundTransparency = 1,
                            BorderSizePixel        = 0,
                            Size                   = UDim2.new(1, 0, 1, 0),
                            Text                   = "",
                            ZIndex                 = 56,
                        })

                        local function updateSV(inputX, inputY)
                            local abs  = svArea.AbsolutePosition
                            local size = svArea.AbsoluteSize
                            s = math.clamp((inputX - abs.X) / size.X, 0, 1)
                            v = math.clamp(1 - (inputY - abs.Y) / size.Y, 0, 1)
                            applyColor()
                        end

                        svHit.MouseButton1Down:Connect(function()
                            svDragging = true
                            local m = game.Players.LocalPlayer:GetMouse()
                            updateSV(m.X, m.Y)
                        end)

                        local hueHit = CreateObj("TextButton", {
                            Parent                 = hueBar,
                            BackgroundTransparency = 1,
                            BorderSizePixel        = 0,
                            Size                   = UDim2.new(1, 0, 1, 0),
                            Text                   = "",
                            ZIndex                 = 56,
                        })

                        local function updateHue(inputX)
                            local abs  = hueBar.AbsolutePosition
                            local size = hueBar.AbsoluteSize
                            h = math.clamp((inputX - abs.X) / size.X, 0, 1)
                            applyColor()
                        end

                        hueHit.MouseButton1Down:Connect(function()
                            hueDragging = true
                            local m = game.Players.LocalPlayer:GetMouse()
                            updateHue(m.X)
                        end)

                        UserInputService.InputEnded:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                svDragging  = false
                                hueDragging = false
                            end
                        end)

                        UserInputService.InputChanged:Connect(function(input)
                            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                            if svDragging  then updateSV(input.Position.X, input.Position.Y) end
                            if hueDragging then updateHue(input.Position.X) end
                        end)

                        local function repositionPopup()
                            local abs = colorSwatch.AbsolutePosition
                            local pw  = popupFrame.AbsoluteSize.X
                            local sx  = ScreenGui.AbsoluteSize.X
                            local px  = math.clamp(abs.X - pw / 2, 4, sx - pw - 4)
                            popupFrame.Position = UDim2.new(0, px, 0, abs.Y + 16)
                        end

                        task.defer(repositionPopup)

                        local closeConn
                        closeConn = UserInputService.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                                task.defer(function()
                                    local m    = game.Players.LocalPlayer:GetMouse()
                                    local abs  = popupFrame and popupFrame.AbsolutePosition
                                    local size = popupFrame and popupFrame.AbsoluteSize
                                    if not abs then return end
                                    local inside = m.X >= abs.X and m.X <= abs.X + size.X
                                               and m.Y >= abs.Y and m.Y <= abs.Y + size.Y
                                    if not inside then
                                        popupOpen = false
                                        popupFrame:Destroy()
                                        popupFrame = nil
                                        closeConn:Disconnect()
                                    end
                                end)
                            end
                        end)
                    end

                    SwatchBtn.MouseButton1Click:Connect(function()
                        if popupOpen then
                            popupOpen = false
                            if popupFrame then
                                popupFrame:Destroy()
                                popupFrame = nil
                            end
                        else
                            popupOpen = true
                            buildPopup()
                        end
                    end)

                    local CP = {}
                    function CP:Set(color)
                        if typeof(color) ~= "Color3" then return end
                        h, s, v      = rgbToHsv(color.R, color.G, color.B)
                        CurrentColor = color
                        colorSwatch.BackgroundColor3 = color
                        CCallback(color)
                    end
                    function CP:Get() return CurrentColor end

                    Library:RegisterConfigItem(cpCfgId,
                        function() return CurrentColor end,
                        function(val) CP:Set(val) end
                    )

                    return CP
                end

                return Toggle
            end

            function Box:AddSlider(Params)
                local Title    = Params.Title                        or "Slider"
                local Default  = Params.Default or Params.Defualt   or 0
                local Min      = Params.Min                          or 0
                local Max      = Params.Max                          or 100
                local Callback = Params.Function                     or function() end
                local Value    = math.clamp(Default, Min, Max)
                local Dragging = false
                local cfgId    = nextId("slider_" .. Title)

                local Row = CreateObj("Frame", {
                    Parent                 = self.Content,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 32),
                    LayoutOrder            = #self.Content:GetChildren(),
                })

                local Header = CreateObj("Frame", {
                    Parent                 = Row,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Position               = UDim2.new(0, 0, 0, 0),
                    Size                   = UDim2.new(1, 0, 0, 14),
                })

                CreateObj("TextLabel", {
                    Parent                 = Header,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 0, 0, 0),
                    Size                   = UDim2.new(0.6, 0, 1, 0),
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                })

                local ValueLabel = CreateObj("TextLabel", {
                    Parent                 = Header,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0.6, 0, 0, 0),
                    Size                   = UDim2.new(0.4, 0, 1, 0),
                    Text                   = tostring(Value) .. "/" .. tostring(Max),
                    TextColor3             = Color3.fromRGB(160, 160, 160),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Right,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                })

                local Track = CreateObj("Frame", {
                    Parent           = Row,
                    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(0, 0, 0, 18),
                    Size             = UDim2.new(1, 0, 0, 12),
                })

                CreateObj("UIStroke", {
                    Parent          = Track,
                    Color           = Library.Configuration.Accent,
                    Thickness       = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                })

                local function pctFor(val)
                    return (val - Min) / (Max - Min)
                end

                local SliderFill = CreateObj("Frame", {
                    Name             = "SliderFill",
                    Parent           = Track,
                    BackgroundColor3 = Library.Configuration.ActiveToggle,
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(0, 0, 0, 0),
                    Size             = UDim2.new(pctFor(Value), 0, 1, 0),
                })

                local HitBox = CreateObj("TextButton", {
                    Parent                 = Track,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 1, 0),
                    Text                   = "",
                    ZIndex                 = 5,
                })

                local function updateFromX(inputX)
                    local abs    = Track.AbsolutePosition.X
                    local size   = Track.AbsoluteSize.X
                    local rel    = math.clamp((inputX - abs) / size, 0, 1)
                    local newVal = math.clamp(math.floor(Min + (Max - Min) * rel + 0.5), Min, Max)
                    if newVal ~= Value then
                        Value           = newVal
                        SliderFill.Size = UDim2.new(pctFor(Value), 0, 1, 0)
                        ValueLabel.Text = tostring(Value) .. "/" .. tostring(Max)
                        Callback(Value)
                    end
                end

                HitBox.MouseButton1Down:Connect(function()
                    Dragging = true
                end)

                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Dragging = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(input)
                    if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        updateFromX(input.Position.X)
                    end
                end)

                HitBox.MouseButton1Click:Connect(function()
                    local mouse = game.Players.LocalPlayer:GetMouse()
                    updateFromX(mouse.X)
                end)

                local Slider = {}

                function Slider:Set(value)
                    if type(value) ~= "number" then return end
                    value           = math.clamp(value, Min, Max)
                    Value           = value
                    SliderFill.Size = UDim2.new(pctFor(Value), 0, 1, 0)
                    ValueLabel.Text = tostring(Value) .. "/" .. tostring(Max)
                    Callback(Value)
                end

                function Slider:Get()
                    return Value
                end

                Library:RegisterConfigItem(cfgId,
                    function() return Value end,
                    function(val) Slider:Set(tonumber(val) or Value) end
                )

                return Slider
            end

            function Box:AddTextBox(Params)
                local Title     = Params.Title                          or "TextBox"
                local InputText = Params.InputText                      or "Type here..."
                local Default   = Params.Defualt or Params.Default      or ""
                local Callback  = Params.Function                       or function() end
                local cfgId     = nextId("textbox_" .. Title)

                local Row = CreateObj("Frame", {
                    Parent                 = self.Content,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 0),
                    AutomaticSize          = Enum.AutomaticSize.Y,
                    LayoutOrder            = #self.Content:GetChildren(),
                    ClipsDescendants       = false,
                })

                CreateObj("TextLabel", {
                    Parent                 = Row,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 0, 0, 0),
                    Size                   = UDim2.new(1, 0, 0, 14),
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                })

                local InputFrame = CreateObj("Frame", {
                    Parent           = Row,
                    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(0, 0, 0, 18),
                    Size             = UDim2.new(1, 0, 0, 16),
                })

                CreateObj("UIStroke", {
                    Parent          = InputFrame,
                    Color           = Library.Configuration.Accent,
                    Thickness       = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                })

                local InputBox = CreateObj("TextBox", {
                    Parent                 = InputFrame,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Position               = UDim2.new(0, 6, 0, 0),
                    Size                   = UDim2.new(1, -12, 1, 0),
                    Text                   = Default,
                    PlaceholderText        = InputText,
                    PlaceholderColor3      = Color3.fromRGB(80, 80, 80),
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    ClearTextOnFocus       = false,
                    ClipsDescendants       = true,
                    ZIndex                 = 5,
                })

                InputBox.FocusLost:Connect(function()
                    Callback(InputBox.Text)
                end)

                local TextBox = {}

                function TextBox:Set(value)
                    InputBox.Text = tostring(value)
                    Callback(InputBox.Text)
                end

                function TextBox:Get()
                    return InputBox.Text
                end

                function TextBox:SetPlaceholder(text)
                    InputBox.PlaceholderText = tostring(text)
                end

                Library:RegisterConfigItem(cfgId,
                    function() return InputBox.Text end,
                    function(val)
                        InputBox.Text = tostring(val or "")
                        Callback(InputBox.Text)
                    end
                )

                return TextBox
            end

            function Box:AddDropdown(Params)
                local Title    = Params.Title                          or "Dropdown"
                local Default  = Params.Default or Params.Defualt      or nil
                local Values   = Params.Values                         or {}
                local Multi    = Params.Multi                          or false
                local Callback = Params.Function                       or function() end
                local cfgId    = nextId("dropdown_" .. Title)

                local Open          = false
                local optionButtons = {}
                local selectedSet   = {}
                local CurrentValue

                if Multi then
                    if type(Default) == "table" then
                        for _, v in ipairs(Default) do
                            selectedSet[v] = true
                        end
                    end
                else
                    CurrentValue = (type(Default) == "string" and Default) or Values[1]
                end

                local function buildHeaderText()
                    if not Multi then
                        return tostring(CurrentValue)
                    end
                    local parts = {}
                    for _, v in ipairs(Values) do
                        if selectedSet[v] then
                            parts[#parts + 1] = v
                        end
                    end
                    return #parts > 0 and table.concat(parts, ", ") or "None"
                end

                local Row = CreateObj("Frame", {
                    Parent                 = self.Content,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 0, 38),
                    LayoutOrder            = #self.Content:GetChildren(),
                    ClipsDescendants       = false,
                    ZIndex                 = 1,
                })

                CreateObj("TextLabel", {
                    Parent                 = Row,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 0, 0, 0),
                    Size                   = UDim2.new(1, 0, 0, 14),
                    Text                   = Title,
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                })

                local Head = CreateObj("Frame", {
                    Parent           = Row,
                    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(0, 0, 0, 18),
                    Size             = UDim2.new(1, 0, 0, 16),
                    ZIndex           = 2,
                })

                CreateObj("UIStroke", {
                    Parent          = Head,
                    Color           = Library.Configuration.Accent,
                    Thickness       = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                })

                local ValueLabel = CreateObj("TextLabel", {
                    Parent                 = Head,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 6, 0, 0),
                    Size                   = UDim2.new(1, -20, 1, 0),
                    Text                   = buildHeaderText(),
                    TextColor3             = Color3.fromRGB(200, 200, 200),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                    ClipsDescendants       = true,
                    ZIndex                 = 3,
                })

                local Arrow = CreateObj("TextLabel", {
                    Parent                 = Head,
                    BackgroundTransparency = 1,
                    AnchorPoint            = Vector2.new(1, 0.5),
                    Position               = UDim2.new(1, -6, 0.5, 0),
                    Size                   = UDim2.new(0, 12, 1, 0),
                    Text                   = "+",
                    TextColor3             = Color3.fromRGB(160, 160, 160),
                    TextSize               = 12,
                    FontFace               = UIFont,
                    TextXAlignment         = Enum.TextXAlignment.Right,
                    TextYAlignment         = Enum.TextYAlignment.Center,
                    RichText               = false,
                    ZIndex                 = 3,
                })

                local HeadButton = CreateObj("TextButton", {
                    Parent                 = Head,
                    BackgroundTransparency = 1,
                    BorderSizePixel        = 0,
                    Size                   = UDim2.new(1, 0, 1, 0),
                    Text                   = "",
                    ZIndex                 = 4,
                })

                local ListFrame = CreateObj("Frame", {
                    Parent           = Row,
                    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                    BorderSizePixel  = 0,
                    Position         = UDim2.new(0, 0, 0, 38),
                    Size             = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    Visible          = false,
                    ZIndex           = 5,
                })

                CreateObj("UIStroke", {
                    Parent          = ListFrame,
                    Color           = Library.Configuration.Accent,
                    Thickness       = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                })

                CreateObj("UIListLayout", {
                    Parent              = ListFrame,
                    FillDirection       = Enum.FillDirection.Vertical,
                    HorizontalAlignment = Enum.HorizontalAlignment.Left,
                    VerticalAlignment   = Enum.VerticalAlignment.Top,
                    Padding             = UDim.new(0, 0),
                    SortOrder           = Enum.SortOrder.LayoutOrder,
                })

                local function closeList()
                    Open              = false
                    ListFrame.Visible = false
                    ListFrame.Size    = UDim2.new(1, 0, 0, 0)
                    Arrow.Text        = "+"
                    Row.Size          = UDim2.new(1, 0, 0, 37)
                end

                local function openList()
                    Open              = true
                    ListFrame.Visible = true
                    local h2          = #Values * 16
                    ListFrame.Size    = UDim2.new(1, 0, 0, h2)
                    Arrow.Text        = "-"
                    Row.Size          = UDim2.new(1, 0, 0, 37 + h2 + 1)
                end

                local function selectSingle(val)
                    CurrentValue    = val
                    ValueLabel.Text = tostring(val)
                    for k, btn in pairs(optionButtons) do
                        btn.TextColor3 = (k == val)
                            and Color3.fromRGB(255, 255, 255)
                            or  Color3.fromRGB(160, 160, 160)
                    end
                    Callback(val)
                    closeList()
                end

                local function toggleMulti(val)
                    selectedSet[val] = not selectedSet[val] or nil
                    local btn = optionButtons[val]
                    if btn then
                        btn.TextColor3 = selectedSet[val]
                            and Color3.fromRGB(255, 255, 255)
                            or  Color3.fromRGB(160, 160, 160)
                    end
                    ValueLabel.Text = buildHeaderText()
                    local out = {}
                    for _, v in ipairs(Values) do
                        if selectedSet[v] then
                            out[#out + 1] = v
                        end
                    end
                    Callback(out)
                end

                local function buildOptionButtons()
                    for i, val in ipairs(Values) do
                        local isActive = Multi and (selectedSet[val] == true) or (val == CurrentValue)

                        local OptBtn = CreateObj("TextButton", {
                            Parent           = ListFrame,
                            BackgroundColor3 = Color3.fromRGB(10, 10, 10),
                            BorderSizePixel  = 0,
                            Size             = UDim2.new(1, 0, 0, 16),
                            Text             = tostring(val),
                            TextColor3       = isActive
                                and Color3.fromRGB(255, 255, 255)
                                or  Color3.fromRGB(160, 160, 160),
                            TextSize         = 12,
                            FontFace         = UIFont,
                            TextXAlignment   = Enum.TextXAlignment.Left,
                            AutoButtonColor  = false,
                            ZIndex           = 6,
                            LayoutOrder      = i,
                        })

                        CreateObj("UIPadding", {
                            Parent      = OptBtn,
                            PaddingLeft = UDim.new(0, 6),
                        })

                        optionButtons[val] = OptBtn

                        OptBtn.MouseButton1Click:Connect(function()
                            if Multi then
                                toggleMulti(val)
                            else
                                selectSingle(val)
                            end
                        end)
                    end
                end

                buildOptionButtons()

                HeadButton.MouseButton1Click:Connect(function()
                    if Open then closeList() else openList() end
                end)

                local Dropdown = {}

                function Dropdown:Set(value)
                    if Multi then
                        if type(value) ~= "table" then return end
                        selectedSet = {}
                        for _, v in ipairs(value) do
                            selectedSet[v] = true
                        end
                        for k, btn in pairs(optionButtons) do
                            btn.TextColor3 = selectedSet[k]
                                and Color3.fromRGB(255, 255, 255)
                                or  Color3.fromRGB(160, 160, 160)
                        end
                        ValueLabel.Text = buildHeaderText()
                        local out = {}
                        for _, v in ipairs(Values) do
                            if selectedSet[v] then
                                out[#out + 1] = v
                            end
                        end
                        Callback(out)
                    else
                        for _, v in ipairs(Values) do
                            if v == value then
                                selectSingle(value)
                                return
                            end
                        end
                    end
                end

                function Dropdown:Get()
                    if Multi then
                        local out = {}
                        for _, v in ipairs(Values) do
                            if selectedSet[v] then
                                out[#out + 1] = v
                            end
                        end
                        return out
                    end
                    return CurrentValue
                end

                function Dropdown:Refresh(newValues)
                    Values = newValues
                    for _, btn in pairs(optionButtons) do
                        btn:Destroy()
                    end
                    optionButtons = {}
                    if not Multi then
                        local found = false
                        for _, v in ipairs(Values) do
                            if v == CurrentValue then
                                found = true
                                break
                            end
                        end
                        if not found then
                            CurrentValue = Values[1]
                        end
                        ValueLabel.Text = buildHeaderText()
                    else
                        local validSet = {}
                        for _, v in ipairs(Values) do
                            validSet[v] = true
                        end
                        for k in pairs(selectedSet) do
                            if not validSet[k] then
                                selectedSet[k] = nil
                            end
                        end
                        ValueLabel.Text = buildHeaderText()
                    end
                    buildOptionButtons()
                end

                Library:RegisterConfigItem(cfgId,
                    function()
                        if Multi then
                            local out = {}
                            for _, v in ipairs(Values) do
                                if selectedSet[v] then
                                    out[#out + 1] = v
                                end
                            end
                            return out
                        else
                            return CurrentValue
                        end
                    end,
                    function(val)
                        if Multi then
                            if type(val) == "table" then Dropdown:Set(val) end
                        else
                            if type(val) == "string" then Dropdown:Set(val) end
                        end
                    end
                )

                return Dropdown
            end

            return Box, counter
        end

        local Tab = {}

        function Tab:AddLeftBox(label)
            local box
            box, boxCountLeft = BuildBox(LeftColumn, boxCountLeft, label)
            return box
        end

        function Tab:AddRightBox(label)
            local box
            box, boxCountRight = BuildBox(RightColumn, boxCountRight, label)
            return box
        end

        return Tab
    end

    function Window:BuildUITab(tabName, isThemeCustomizable)
        local UITab = self:AddTab(tabName or "UI")

        local MenuBox = UITab:AddRightBox("Menu")

        MenuBox:AddButton({
            Title    = "Unload",
            Function = function()
                self:Unload()
            end,
        })

        local MenuToggle = MenuBox:AddToggle({
            Title    = "Menu Key",
            Default  = true,
            Function = function(val)
                guiVisible        = val
                ScreenGui.Enabled = val
            end,
        })

        MenuToggle:AddKeyPicker({
            Key      = Window.ToggleKeybind,
            Function = function(val)
                MenuToggle:Set(val)
            end,
        })

        local ConfigBox      = UITab:AddRightBox("Configs")
        local currentConfigs = listConfigs()
        local selectedConfig = currentConfigs[1] or nil

        local ConfigDropdown = ConfigBox:AddDropdown({
            Title    = "Saved Configs",
            Values   = currentConfigs,
            Default  = selectedConfig,
            Function = function(val)
                selectedConfig = val
            end,
        })

        local ConfigNameBox = ConfigBox:AddTextBox({
            Title     = "Config Name",
            InputText = "Enter name...",
            Default   = "",
            Function  = function(val) end,
        })

        ConfigBox:AddButton({
            Title    = "Save Config",
            Function = function()
                local name = ConfigNameBox:Get():match("^%s*(.-)%s*$")
                if name == "" then
                    Library:Notify("{yellow}Config name cannot be empty.{/yellow}", 3)
                    return
                end
                local data  = Library:CollectConfig()
                local saved = saveConfig(name, data)
                if saved then
                    local fresh = listConfigs()
                    ConfigDropdown:Refresh(fresh)
                    ConfigDropdown:Set(name)
                    selectedConfig = name
                    Library:Notify("{green}Config saved: " .. name .. "{/green}", 3)
                else
                    Library:Notify("{red}Failed to save config.{/red}", 3)
                end
            end,
        })

        ConfigBox:AddButton({
            Title    = "Load Config",
            Function = function()
                if not selectedConfig or selectedConfig == "" then
                    Library:Notify("{yellow}No config selected.{/yellow}", 3)
                    return
                end
                local data = loadConfig(selectedConfig)
                if data then
                    Library:ApplyConfig(data)
                    Library:Notify("{green}Config loaded: " .. selectedConfig .. "{/green}", 3)
                else
                    Library:Notify("{red}Config not found: " .. selectedConfig .. "{/red}", 3)
                end
            end,
        })

        ConfigBox:AddButton({
            Title    = "Delete Config",
            Function = function()
                if not selectedConfig or selectedConfig == "" then
                    Library:Notify("{yellow}No config selected.{/yellow}", 3)
                    return
                end
                local name = selectedConfig
                if deleteConfig(name) then
                    local fresh = listConfigs()
                    selectedConfig = fresh[1] or nil
                    ConfigDropdown:Refresh(fresh)
                    if selectedConfig then
                        ConfigDropdown:Set(selectedConfig)
                    end
                    Library:Notify("{red}Config deleted: " .. name .. "{/red}", 3)
                else
                    Library:Notify("{red}Failed to delete config.{/red}", 3)
                end
            end,
        })

        if isThemeCustomizable then
            local ThemeBox = UITab:AddLeftBox("Theme")

            local entries = {
                { label = "Background",   key = "Background",   apply = applyBackground   },
                { label = "Inner",        key = "Inner",        apply = applyInner        },
                { label = "TopBar",       key = "TopBar",       apply = applyTopBar       },
                { label = "Accent",       key = "Accent",       apply = applyAccent       },
                { label = "Tab Active",   key = "TabActive",    apply = applyTabActive    },
                { label = "Tab Inactive", key = "TabInactive",  apply = applyTabInactive  },
                { label = "Fill Color",   key = "ActiveToggle", apply = applyActiveToggle },
            }

            for _, entry in ipairs(entries) do
                local titleRow = ThemeBox:AddTitle(entry.label)
                titleRow:AddColorPicker({
                    Default  = Library.Configuration[entry.key],
                    Function = function(color)
                        entry.apply(color)
                    end,
                })
            end
        end

        return UITab
    end

    function Window:BuildUserTab(tabName)
    local UITab = self:AddTab(tabName or "Account")

    local USER_FILE = "UserData.json"

    local function loadUserData()
        if not isfile(USER_FILE) then return nil end
        local ok, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(USER_FILE))
        end)
        return ok and decoded or nil
    end

    local function saveUserData(data)
        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if ok then
            writefile(USER_FILE, encoded)
            return true
        end
        return false
    end

    local function hashPassword(password)
        local hash = 0
        for i = 1, #password do
            hash = (hash * 31 + string.byte(password, i)) % 2147483647
        end
        return tostring(hash)
    end

    local function generateUID()
        local t = os.time()
        local r = math.random(1000, 9999)
        return tostring(t):sub(-6) .. tostring(r)
    end

    local function downloadAvatar(url)
        if not url or url == "" then return "" end
        local ok, content = pcall(function()
            return game:HttpGet(url)
        end)
        if not ok or not content or content == "" then return "" end
        local ext = url:match("%.(%a+)%??") or "jpg"
        local filename = "UserAvatar." .. ext
        if writefile and getcustomasset then
            pcall(function() writefile(filename, content) end)
            local asset = ""
            pcall(function() asset = getcustomasset(filename) end)
            return asset
        end
        return ""
    end

    local existingData = loadUserData()
    local isLoggedIn   = false

    local LeftBox   = UITab:AddLeftBox("Account")
    local RightBox  = UITab:AddRightBox("Profile")

    local AvatarFrame = CreateObj("Frame", {
        Parent           = RightBox.Content,
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 80),
        LayoutOrder      = 0,
        ClipsDescendants = true,
    })

    CreateObj("UIStroke", {
        Parent          = AvatarFrame,
        Color           = Library.Configuration.Accent,
        Thickness       = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })

    local AvatarImage = CreateObj("ImageLabel", {
        Parent                 = AvatarFrame,
        BackgroundTransparency = 1,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, 0),
        Size                   = UDim2.new(1, 0, 1, 0),
        Image                  = "",
        ScaleType              = Enum.ScaleType.Fit,
    })

    local AvatarPlaceholder = CreateObj("TextLabel", {
        Parent                 = AvatarFrame,
        BackgroundTransparency = 1,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, 0),
        Size                   = UDim2.new(1, 0, 1, 0),
        Text                   = "No Avatar",
        TextColor3             = Color3.fromRGB(80, 80, 80),
        TextSize               = 12,
        FontFace               = UIFont,
        TextXAlignment         = Enum.TextXAlignment.Center,
        TextYAlignment         = Enum.TextYAlignment.Center,
    })

    local function setAvatarImage(asset)
        if asset and asset ~= "" then
            AvatarImage.Image        = asset
            AvatarPlaceholder.Visible = false
        else
            AvatarImage.Image        = ""
            AvatarPlaceholder.Visible = true
        end
    end

    local StatusTitle   = RightBox:AddTitle("Status: Not logged in")
    local UIDTitle      = RightBox:AddTitle("")
    local UsernameTitle = RightBox:AddTitle("")

    local function setStatus(text, color)
        StatusTitle:SetText("Status: " .. text)
        if color then
            StatusTitle:SetColor(color)
        end
    end

    local function showUserInfo(data)
        UIDTitle:SetText("UID: " .. tostring(data.uid))
        UsernameTitle:SetText("User: " .. tostring(data.username))
        setStatus("Logged in", Color3.fromRGB(68, 255, 136))
        if data.avatar_asset and data.avatar_asset ~= "" then
            setAvatarImage(data.avatar_asset)
        else
            setAvatarImage("")
        end
    end

    if existingData then
        isLoggedIn = true
        showUserInfo(existingData)
    end

    local NickBox = LeftBox:AddTextBox({
        Title     = "Username",
        InputText = "Enter username...",
        Default   = "",
        Function  = function() end,
    })

    local PassBox = LeftBox:AddTextBox({
        Title     = "Password",
        InputText = "Enter password...",
        Default   = "",
        Function  = function() end,
    })

    LeftBox:AddButton({
        Title    = "Register",
        Function = function()
            if isLoggedIn then
                Library:Notify("{yellow}Already logged in. Logout first.{/yellow}", 3)
                return
            end

            local username = NickBox:Get():match("^%s*(.-)%s*$")
            local password = PassBox:Get():match("^%s*(.-)%s*$")

            if username == "" then
                Library:Notify("{red}Username cannot be empty.{/red}", 3)
                return
            end

            if #username < 3 then
                Library:Notify("{red}Username must be at least 3 characters.{/red}", 3)
                return
            end

            if password == "" then
                Library:Notify("{red}Password cannot be empty.{/red}", 3)
                return
            end

            if #password < 6 then
                Library:Notify("{red}Password must be at least 6 characters.{/red}", 3)
                return
            end

            local existing = loadUserData()
            if existing then
                Library:Notify("{yellow}Account already exists. Use Login.{/yellow}", 3)
                return
            end

            local uid  = generateUID()
            local data = {
                uid           = uid,
                username      = username,
                password      = hashPassword(password),
                avatar_url    = "",
                avatar_asset  = "",
                registered_at = os.time(),
                last_login    = os.time(),
            }

            if saveUserData(data) then
                isLoggedIn = true
                showUserInfo(data)
                Library:Notify("{green}Registered! UID: " .. uid .. "{/green}", 5)
            else
                Library:Notify("{red}Failed to save user data.{/red}", 3)
            end
        end,
    })

    LeftBox:AddButton({
        Title    = "Login",
        Function = function()
            if isLoggedIn then
                Library:Notify("{yellow}Already logged in.{/yellow}", 3)
                return
            end

            local username = NickBox:Get():match("^%s*(.-)%s*$")
            local password = PassBox:Get():match("^%s*(.-)%s*$")

            if username == "" or password == "" then
                Library:Notify("{red}Fill in both fields.{/red}", 3)
                return
            end

            local data = loadUserData()

            if not data then
                Library:Notify("{red}No account found. Register first.{/red}", 3)
                return
            end

            if data.username ~= username then
                Library:Notify("{red}Wrong username.{/red}", 3)
                return
            end

            if data.password ~= hashPassword(password) then
                Library:Notify("{red}Wrong password.{/red}", 3)
                return
            end

            data.last_login = os.time()
            saveUserData(data)

            isLoggedIn = true
            showUserInfo(data)
            Library:Notify("{green}Welcome back, " .. username .. "!{/green}", 4)
        end,
    })

    LeftBox:AddButton({
        Title    = "Logout",
        Function = function()
            if not isLoggedIn then
                Library:Notify("{yellow}Not logged in.{/yellow}", 3)
                return
            end

            isLoggedIn = false
            setStatus("Not logged in", Color3.fromRGB(200, 200, 200))
            UIDTitle:SetText("")
            UsernameTitle:SetText("")
            setAvatarImage("")
            Library:Notify("{gray}Logged out.{/gray}", 3)
        end,
    })

    LeftBox:AddButton({
        Title    = "Delete Account",
        Function = function()
            if not isLoggedIn then
                Library:Notify("{yellow}Not logged in.{/yellow}", 3)
                return
            end

            if isfile(USER_FILE) then
                delfile(USER_FILE)
            end

            local avatarFiles = { "UserAvatar.jpg", "UserAvatar.png", "UserAvatar.jpeg", "UserAvatar.webp" }
            for _, f in ipairs(avatarFiles) do
                if isfile(f) then
                    pcall(function() delfile(f) end)
                end
            end

            isLoggedIn = false
            setStatus("Not logged in", Color3.fromRGB(200, 200, 200))
            UIDTitle:SetText("")
            UsernameTitle:SetText("")
            setAvatarImage("")
            Library:Notify("{red}Account deleted.{/red}", 4)
        end,
    })

    local AvatarBox = LeftBox:AddTextBox({
        Title     = "Avatar URL",
        InputText = "Paste image URL...",
        Default   = existingData and existingData.avatar_url or "",
        Function  = function() end,
    })

    LeftBox:AddButton({
        Title    = "Set Avatar",
        Function = function()
            if not isLoggedIn then
                Library:Notify("{yellow}Login first.{/yellow}", 3)
                return
            end

            local url = AvatarBox:Get():match("^%s*(.-)%s*$")

            if url == "" then
                Library:Notify("{red}URL cannot be empty.{/red}", 3)
                return
            end

            local validExts = { "jpg", "jpeg", "png", "webp" }
            local ext       = url:match("%.(%a+)%??") or ""
            local valid     = false
            for _, e in ipairs(validExts) do
                if ext:lower() == e then
                    valid = true
                    break
                end
            end

            if not valid then
                Library:Notify("{yellow}URL should point to jpg/png/webp image.{/yellow}", 4)
            end

            Library:Notify("{gray}Downloading avatar...{/gray}", 2)

            task.spawn(function()
                local asset = downloadAvatar(url)

                if asset == "" then
                    Library:Notify("{red}Failed to download avatar. Check the URL.{/red}", 4)
                    return
                end

                local data = loadUserData()
                if not data then return end

                data.avatar_url   = url
                data.avatar_asset = asset
                saveUserData(data)

                setAvatarImage(asset)
                Library:Notify("{green}Avatar updated!{/green}", 3)
            end)
        end,
    })

    LeftBox:AddButton({
        Title    = "Clear Avatar",
        Function = function()
            if not isLoggedIn then
                Library:Notify("{yellow}Login first.{/yellow}", 3)
                return
            end

            local data = loadUserData()
            if not data then return end

            data.avatar_url  = ""
            data.avatar_asset = ""
            saveUserData(data)

            setAvatarImage("")
            AvatarBox:Set("")
            Library:Notify("{gray}Avatar cleared.{/gray}", 3)
        end,
    })

    return UITab
end

    return Window
end

return Library
