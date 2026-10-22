-- BALEREOT KEY MANAGER  (khusus owner, JANGAN dibagikan bareng script utama)
-- Membuat baris key untuk BalereotCommunity.lua:
--     isi USERNAME + LAMA PAKAI  ->  GENERATE  ->  salin baris  ->  tempel ke keys.txt di GitHub
--
-- Format baris yang dihasilkan (dibaca script utama):
--     BLR-XXXX-XXXX-XXXX-XXXX|username|waktu_unix # username | 30 Hari | sampai 2026-11-22 02:30 WIB
--   username  = akun Roblox pemilik key (* = siapa saja)
--   waktu_unix = kapan key habis (dihitung dari saat GENERATE), atau "perm" = permanen
--
-- Masa aktif dihitung dari saat key dibuat, jadi buat key saat key itu dibeli / diberikan.
-- Bulan = 30 hari. Semua key yang dibuat juga tersimpan di workspace/balereot_keys_generated.txt

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local lp = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- PENGATURAN
local KEY_PREFIX = "BLR"
local OUT_FILE = "balereot_keys_generated.txt"
local KEYS_EDIT_URL = "https://github.com/dancok1238/VoiceRedirectorPro/edit/main/keys.txt"  -- halaman edit keys.txt
local WIB = 7 * 3600
local MAX_HISTORY = 40
local UNITS = {   -- {nama, singkatan tombol, detik (0 = permanen)}
    {"Jam", "Jam", 3600},
    {"Hari", "Hari", 86400},
    {"Minggu", "Mgg", 604800},
    {"Bulan", "Bulan", 2592000},
    {"Permanen", "Perm", 0},
}

local C = {
    bg = Color3.fromRGB(8, 4, 16), panel = Color3.fromRGB(22, 12, 40), header = Color3.fromRGB(16, 8, 30),
    input = Color3.fromRGB(28, 16, 50), stroke = Color3.fromRGB(95, 45, 160), accent = Color3.fromRGB(150, 60, 235),
    cyan = Color3.fromRGB(190, 120, 255), text = Color3.fromRGB(238, 232, 250), sub = Color3.fromRGB(165, 145, 200),
    dim = Color3.fromRGB(100, 80, 135), green = Color3.fromRGB(80, 230, 140), red = Color3.fromRGB(255, 90, 90),
    yellow = Color3.fromRGB(255, 196, 60), white = Color3.new(1, 1, 1),
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function round(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end
local function stroke(o, color, thick, transp)
    return new("UIStroke", {Color = color, Thickness = thick or 1, Transparency = transp or 0}, o)
end
local function trim(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end

local function nowTs()
    local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and type(t) == "number" and t > 1600000000 then return math.floor(t) end
    return os.time()
end
local function fmtDate(ts)
    return os.date("!%Y-%m-%d %H:%M", ts + WIB) .. " WIB"
end
local function fmtNum(n)
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return tostring(math.floor(n * 100 + 0.5) / 100)
end

-- ============ Pembuat key ============
local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   -- tanpa 0/O/1/I agar mudah dibaca
local rng = Random.new(math.floor(os.clock() * 1000000) + nowTs())
local function randomBytes(n)
    local hex = (HttpService:GenerateGUID(false) .. HttpService:GenerateGUID(false)):gsub("[^%x]", "")
    local out = {}
    for i = 1, n do
        out[i] = (tonumber(hex:sub(i * 2 - 1, i * 2), 16) or 0)
    end
    return out
end
local function makeKey()
    local bytes = randomBytes(16)
    local chars = {}
    for i = 1, 16 do
        local idx = (bytes[i] + rng:NextInteger(0, 255)) % #ALPHABET + 1
        chars[i] = ALPHABET:sub(idx, idx)
    end
    local s = table.concat(chars)
    return ("%s-%s-%s-%s-%s"):format(KEY_PREFIX, s:sub(1, 4), s:sub(5, 8), s:sub(9, 12), s:sub(13, 16))
end

-- ============ Riwayat (file lokal) ============
local history = {}   -- terbaru di akhir: {key, user, info, line}
local function parseLine(line)
    line = trim(line)
    if line == "" or line:sub(1, 1) == "#" then return nil end
    local body, comment = line:match("^(.-)%s+#%s*(.*)$")
    body = body or line
    local key, user = body:match("^([^|]+)|([^|]*)")
    if not key then return nil end
    return {key = trim(key), user = trim(user), info = comment or "", line = line}
end
local function loadHistory()
    if not (readfile and isfile and isfile(OUT_FILE)) then return end
    local ok, data = pcall(readfile, OUT_FILE)
    if not ok or type(data) ~= "string" then return end
    for l in data:gmatch("[^\r\n]+") do
        local e = parseLine(l)
        if e then history[#history + 1] = e end
    end
    while #history > MAX_HISTORY do table.remove(history, 1) end
end
local function appendFile(line)
    if not writefile then return false end
    if appendfile then return (pcall(appendfile, OUT_FILE, line .. "\n")) end
    local old = ""
    if isfile and readfile and isfile(OUT_FILE) then
        local ok, d = pcall(readfile, OUT_FILE)
        if ok and type(d) == "string" then old = d end
    end
    return (pcall(writefile, OUT_FILE, old .. line .. "\n"))
end
local function copy(text)
    if setclipboard then return (pcall(setclipboard, text)) end
    return false
end

-- ============ UI ============
local function getParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then return ui end
    return lp:WaitForChild("PlayerGui")
end
local oldGui = getParent():FindFirstChild("BalereotKeyManager")
if oldGui then oldGui:Destroy() end

local gui = new("ScreenGui", {Name = "BalereotKeyManager", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000}, getParent())
local main = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.bg,
    BorderSizePixel = 0, Active = true, Draggable = true, ClipsDescendants = true,
}, gui)
round(main, 14)
stroke(main, C.stroke, 2.5)
new("UISizeConstraint", {MaxSize = Vector2.new(380, 9999), MinSize = Vector2.new(260, 300)}, main)
local function fit()
    local v = (camera and camera.ViewportSize) or Vector2.new(800, 600)
    main.Size = UDim2.new(0.92, 0, 0, math.clamp(v.Y - 40, 300, 600))
end
fit()
if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end

local header = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.header, BorderSizePixel = 0}, main)
round(header, 14)
new("TextLabel", {
    Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
    Text = "BALEREOT KEY MANAGER", Font = Enum.Font.Arcade, TextSize = 13, TextColor3 = C.white,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local closeBtn = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(26, 24),
    BackgroundColor3 = C.red, Text = "X", TextColor3 = C.white, TextSize = 11, Font = Enum.Font.GothamBold, BorderSizePixel = 0,
}, header)
round(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local scroll = new("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -48), Position = UDim2.fromOffset(8, 44), BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)
new("UIPadding", {PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8)}, scroll)

local order = 0
local function section(height, auto)
    order += 1
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = order}, scroll)
    if auto then f.AutomaticSize = Enum.AutomaticSize.Y end
    return f
end
local function smallLabel(parent, text, y)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, y or 0), BackgroundTransparency = 1, Text = text,
        Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end
local function inputBox(parent, y, w, placeholder, text)
    local fr = new("Frame", {Size = w, Position = UDim2.fromOffset(0, y), BackgroundColor3 = C.input, BorderSizePixel = 0}, parent)
    round(fr, 8)
    stroke(fr, C.stroke, 1.2, 0.3)
    local tb = new("TextBox", {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1, Text = text or "",
        PlaceholderText = placeholder, TextColor3 = C.text, PlaceholderColor3 = C.dim, Font = Enum.Font.Code, TextSize = 12,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
    }, fr)
    return tb, fr
end
local function button(parent, text, pos, size, color)
    local b = new("TextButton", {
        Size = size, Position = pos, BackgroundColor3 = color or C.accent, Text = text, TextColor3 = C.white,
        Font = Enum.Font.GothamBold, TextSize = 11, BorderSizePixel = 0, AutoButtonColor = true,
    }, parent)
    round(b, 8)
    return b
end

-- 1) username
local secUser = section(74)
smallLabel(secUser, "USERNAME ROBLOX PEMILIK KEY  (* = siapa saja)")
local userBox = inputBox(secUser, 16, UDim2.new(1, 0, 0, 34), "contoh: Budi123")
local acctLbl = new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 54), BackgroundTransparency = 1, Text = "",
    Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left,
}, secUser)

-- 2) lama pakai
local secDur = section(78)
smallLabel(secDur, "LAMA PAKAI")
local amountBox = inputBox(secDur, 16, UDim2.fromOffset(64, 34), "1", "1")
amountBox.TextXAlignment = Enum.TextXAlignment.Center
local unitRow = new("Frame", {Size = UDim2.new(1, -72, 0, 34), Position = UDim2.fromOffset(72, 16), BackgroundTransparency = 1}, secDur)
new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, unitRow)
local expLbl = new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 58), BackgroundTransparency = 1, Text = "",
    Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.yellow, TextXAlignment = Enum.TextXAlignment.Left,
}, secDur)

local unitIdx = 2
local unitButtons = {}
local function durationInfo()
    -- return: detik (0 = permanen), label  |  nil, pesan error
    local unit = UNITS[unitIdx]
    if unit[3] == 0 then return 0, "Permanen" end
    local n = tonumber(trim(amountBox.Text))
    if not n or n <= 0 then return nil, "Isi angka lama pakai (lebih dari 0)" end
    local secs = math.floor(n * unit[3])
    if secs > 10 * 365 * 86400 then return nil, "Maksimal 10 tahun" end
    return secs, fmtNum(n) .. " " .. unit[1]
end
local function refreshExpiry()
    for i, b in ipairs(unitButtons) do
        b.BackgroundColor3 = (i == unitIdx) and C.accent or C.input
        b.TextColor3 = (i == unitIdx) and C.white or C.sub
    end
    amountBox.TextEditable = UNITS[unitIdx][3] ~= 0
    local secs, label = durationInfo()
    if not secs then
        expLbl.TextColor3 = C.red
        expLbl.Text = label
    elseif secs == 0 then
        expLbl.TextColor3 = C.yellow
        expLbl.Text = "Key permanen (tidak pernah habis)"
    else
        expLbl.TextColor3 = C.yellow
        expLbl.Text = "Berlaku sampai " .. fmtDate(nowTs() + secs)
    end
end
for i, u in ipairs(UNITS) do
    local b = new("TextButton", {
        LayoutOrder = i, Size = UDim2.new(1 / #UNITS, -3, 1, 0), BackgroundColor3 = C.input, Text = u[2],
        TextColor3 = C.sub, TextSize = 10, Font = Enum.Font.GothamBold, BorderSizePixel = 0,
    }, unitRow)
    round(b, 8)
    unitButtons[i] = b
    b.MouseButton1Click:Connect(function() unitIdx = i; refreshExpiry() end)
end
amountBox:GetPropertyChangedSignal("Text"):Connect(refreshExpiry)

-- 3) tombol generate + pesan
local secGen = section(38)
local genBtn = button(secGen, "GENERATE KEY", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 1, 0), C.accent)
genBtn.TextSize = 13
local secToast = section(16)
local toast = new("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamMedium, TextSize = 10,
    TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, secToast)
local function say(text, color)
    toast.Text = text
    toast.TextColor3 = color or C.sub
end

-- 4) hasil
local secRes = section(112)
local resBox = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.panel, BorderSizePixel = 0}, secRes)
round(resBox, 10)
stroke(resBox, C.stroke, 1, 0.4)
local resKey = new("TextLabel", {
    Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1, Text = "(belum ada key)",
    Font = Enum.Font.Code, TextSize = 14, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Left,
}, resBox)
local resLine = new("TextBox", {
    Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 28), BackgroundColor3 = C.input, BorderSizePixel = 0,
    Text = "", PlaceholderText = "baris key untuk keys.txt muncul di sini", PlaceholderColor3 = C.dim,
    TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 9, TextWrapped = true, MultiLine = true, ClearTextOnFocus = false,
    TextEditable = false, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, resBox)
round(resLine, 6)
new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)}, resLine)
local copyBtn = button(resBox, "SALIN BARIS KEY", UDim2.fromOffset(10, 80), UDim2.new(1, -20, 0, 26), C.input)
stroke(copyBtn, C.accent, 1, 0.3)
local lastLine = nil

-- 5) alat: salin semua, buka keys.txt
local secTools = section(30)
local copyAllBtn = button(secTools, "SALIN SEMUA RIWAYAT", UDim2.fromOffset(0, 0), UDim2.new(0.5, -3, 1, 0), C.input)
local openBtn = button(secTools, "BUKA keys.txt", UDim2.new(0.5, 3, 0, 0), UDim2.new(0.5, -3, 1, 0), C.input)
stroke(copyAllBtn, C.stroke, 1, 0.3)
stroke(openBtn, C.stroke, 1, 0.3)
copyAllBtn.TextSize = 9
openBtn.TextSize = 9

-- 6) riwayat
local secHistTitle = section(16)
smallLabel(secHistTitle, "RIWAYAT KEY  (ketuk = salin barisnya)")
local secHist = section(0, true)
new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, secHist)
local histNodes = {}
local function renderHistory()
    for _, n in ipairs(histNodes) do n:Destroy() end
    table.clear(histNodes)
    for i = #history, 1, -1 do
        local e = history[i]
        local b = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = C.panel, Text = "", AutoButtonColor = true,
            BorderSizePixel = 0, LayoutOrder = #history - i,
        }, secHist)
        round(b, 8)
        stroke(b, C.stroke, 1, 0.6)
        new("TextLabel", {
            Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 3), BackgroundTransparency = 1, Text = e.key,
            Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        }, b)
        new("TextLabel", {
            Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 21), BackgroundTransparency = 1,
            Text = (e.info ~= "" and e.info) or e.user, Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.sub,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, b)
        b.MouseButton1Click:Connect(function()
            if copy(e.line) then say("Baris untuk " .. e.key .. " disalin", C.green) else say("Executor tanpa setclipboard", C.yellow) end
        end)
        histNodes[#histNodes + 1] = b
    end
end

-- ============ Cek akun (opsional, hanya peringatan salah ketik) ============
local acctToken = 0
local function setAcct(text, color)
    acctLbl.Text = text
    acctLbl.TextColor3 = color or C.sub
end
local function runAccountCheck(token)
    local name = trim(userBox.Text)
    if name == "" then return setAcct("") end
    if name == "*" then return setAcct("* = key ini bisa dipakai siapa saja", C.yellow) end
    if #name < 3 or not name:match("^[%w_]+$") then
        return setAcct("Username hanya huruf / angka / _ (min. 3 karakter)", C.red)
    end
    setAcct("Memeriksa akun...", C.sub)
    local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
    if token ~= acctToken then return end
    if ok and id then
        setAcct("Akun ditemukan (ID " .. id .. ")", C.green)
    else
        setAcct("Akun tidak ditemukan, cek ejaan", C.yellow)
    end
end
userBox:GetPropertyChangedSignal("Text"):Connect(function()
    acctToken += 1
    local mine = acctToken
    task.delay(0.6, function()
        if mine == acctToken then task.spawn(runAccountCheck, mine) end
    end)
end)

-- ============ Generate ============
local function keyExists(k)
    for _, e in ipairs(history) do
        if e.key == k then return true end
    end
    return false
end

local function generate()
    local name = trim(userBox.Text)
    if name == "" then return say("Isi username dulu (atau * untuk siapa saja)", C.red) end
    if name ~= "*" and (#name < 3 or not name:match("^[%w_]+$")) then
        return say("Username tidak valid", C.red)
    end
    local secs, label = durationInfo()
    if not secs then return say(label, C.red) end

    local now = nowTs()
    local expField, expText
    if secs == 0 then
        expField, expText = "perm", "permanen"
    else
        expField, expText = tostring(now + secs), "sampai " .. fmtDate(now + secs)
    end

    local key = makeKey()
    local tries = 0
    while keyExists(key) and tries < 20 do key = makeKey(); tries += 1 end

    local line = ("%s|%s|%s # %s | %s | %s | dibuat %s"):format(key, name, expField, name, label, expText, fmtDate(now))
    history[#history + 1] = {key = key, user = name, info = ("%s | %s | %s"):format(name, label, expText), line = line}
    while #history > MAX_HISTORY do table.remove(history, 1) end
    lastLine = line

    resKey.Text = key
    resLine.Text = line
    renderHistory()

    local saved = appendFile(line)
    local copied = copy(line)
    if copied then
        say("Key dibuat & baris disalin" .. (saved and ", tersimpan di file" or "") .. ". Tempel ke keys.txt", C.green)
    else
        say("Key dibuat. Tekan lama kotak baris untuk menyalin manual", C.yellow)
    end
end
genBtn.MouseButton1Click:Connect(generate)

copyBtn.MouseButton1Click:Connect(function()
    if not lastLine then return say("Belum ada key yang dibuat", C.yellow) end
    if copy(lastLine) then say("Baris key disalin", C.green) else say("Executor tanpa setclipboard", C.yellow) end
end)
copyAllBtn.MouseButton1Click:Connect(function()
    if #history == 0 then return say("Riwayat masih kosong", C.yellow) end
    local lines = {}
    for _, e in ipairs(history) do lines[#lines + 1] = e.line end
    if copy(table.concat(lines, "\n")) then
        say(#lines .. " baris disalin", C.green)
    else
        say("Executor tanpa setclipboard", C.yellow)
    end
end)
openBtn.MouseButton1Click:Connect(function()
    copy(KEYS_EDIT_URL)
    pcall(function() GuiService:OpenBrowserWindow(KEYS_EDIT_URL) end)
    say("Link keys.txt disalin / dibuka. Tempel baris key lalu Commit", C.sub)
end)

loadHistory()
renderHistory()
refreshExpiry()
say("Isi username + lama pakai, lalu GENERATE", C.sub)
