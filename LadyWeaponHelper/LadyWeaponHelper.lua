--------------------------------------------------------------------------------------------------------
-- 2.24: + тестовый скрипт по авто-снятию/одеванию пушек на леди 
--------------------------------------------------------------------------------------------------------
local ADDON_NAME, namespace = ...
local lastEquipTryTime, lastUnequipTryTime, lastEquipOrUnequipTryTime = 0, 0, 0
local tarCD = GetTime()
local MKLastAppliedTime, MKLastUsedTime, playerClass, playerGuid, bossFightStarted, bossFightStartYelled, BossSubZone, disposedForCurrentFight, disposed, bossIsDefeated, maxPlayers, playerDifficulty, firstLoad, spectatorMode, playerEnteredWorld, inCombat, waitIsEquipingSet
local onUpdateTimer, actionTimer = 0, 0.2
local ourSpecWeaponSlots, auto, settings, MKAffectedPlayerGuids, savedSlotAndWeaponLinkInfo, chatFrameDocked = {}, {}, {},
    {}, {}, {}
local weaponUnequipedSlots = {}
local MK_COOLDOWN = 39.5 -- чуть выше нормальной температуры котика
local LANG = GetLocale()
local TMP_SET_NAME = "_lwhtmp"
local THIN_FONT_NAME = "Interface\\addons\\" .. ADDON_NAME .. "\\PTSansNarrow.ttf" or GameFontNormal:GetFont()
local gunpickup2wav = "Interface\\addons\\" .. ADDON_NAME .. "\\gunpickup2.wav"
local weapondrop1wav = "Interface\\addons\\" .. ADDON_NAME .. "\\weapondrop1.wav"

local PlayMusic, PlaySoundFile = PlayMusic, PlaySoundFile
local UnitIsDeadOrGhost, UnitCastingInfo, UnitChannelInfo, UnitThreatSituation = UnitIsDeadOrGhost, UnitCastingInfo, UnitChannelInfo, UnitThreatSituation
local UnitDebuff, GetSpellInfo, GetNumTalentTabs, GetNumTalents = UnitDebuff, GetSpellInfo, GetNumTalentTabs, GetNumTalents
local DeleteEquipmentSet, GetNumEquipmentSets, SaveEquipmentSet, GetEquipmentSetInfoByName = DeleteEquipmentSet, GetNumEquipmentSets, SaveEquipmentSet, GetEquipmentSetInfoByName
local GetChatWindowInfo, GetSubZoneText, GetItemInfom, CreateFrame = GetChatWindowInfo, GetSubZoneText, GetItemInfom, CreateFrame
local RaidNotice_AddMessage, GetAddOnMetadata, GetPlayerMapPosition = RaidNotice_AddMessage, GetAddOnMetadata, GetPlayerMapPosition
local IsInInstance, GetRealNumRaidMembers, UnitInRaid, GetInstanceInfo = IsInInstance, GetRealNumRaidMembers, UnitInRaid, GetInstanceInfo
local UnitClass, UnitName, UnitGUID, UnitIsControlled, UnitIsPossessed, UnitAffectingCombat = UnitClass, UnitName, UnitGUID, UnitIsControlled, UnitIsPossessed, UnitAffectingCombat
local PickupInventoryItem, PutItemInBackpack, GetInventoryItemLink, GetContainerNumFreeSlots = PickupInventoryItem, PutItemInBackpack, GetInventoryItemLink, GetContainerNumFreeSlots

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- тестовый чат лог для отладки, если вкладок чата меньше 10: создаст отдельную, если 10: отправит в первый чат фрейм
------------------------------------------------------------------------------------------------------------------------------------------------------------
local function showAndDockChatWindow(frame, _fontSize)
  if not frame or chatFrameDocked[frame] then return end
  if _fontSize then FCF_SetChatWindowFontSize(nil, frame, _fontSize) end
  FCF_DockFrame(frame)
  --frame:Show()
  --frame:Hide()
  --_G[frame:GetName().."Tab"]:Show()
  --_G[frame:GetName().."Tab"]:Click()
  frame:AddMessage("|ccc55ffaa" ..
  ADDON_NAME ..
  ":|r |cccff3355" ..
  (LANG == "ruRU" and "Похоже, у нас есть свободная вкладка чата: сообщения связанные с отладкой теперь будут выводиться здесь." or "It seems we have a free chat tab, debug messages will now be displayed here.") ..
  "|r")
  chatFrameDocked[frame] = true
end

local function getChatFrameByName(_name)
  local frame, found, _docked
  for i = 1, NUM_CHAT_WINDOWS do
    local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
    if (name == _name) then
      found = true
      frame = _G["ChatFrame" .. i]
      break
    end
  end
  _docked = chatFrameDocked[frame]
  return frame, found, _docked
end

local function func_frameAddMessage(msg, windowName, r, g, b, _fontSize)
  if not playerEnteredWorld or not settings["debugMessagesInSeparateChatWindow"] then
    print(msg)
    return
  end

  if not _fontSize then _fontSize = 12 end

  -- for i = 1, NUM_CHAT_WINDOWS do
  -- local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
  -- if (name == windowName) then
  -- frame = _G["ChatFrame" .. i]
  -- showAndDockChatWindow(frame,_fontSize)
  -- break
  -- end
  -- end

  local frame, _, docked = getChatFrameByName(windowName)

  if frame and not docked then
    showAndDockChatWindow(frame, _fontSize)
    frame:AddMessage("|ccc55ffaa" .. ADDON_NAME .. ":|r |cccff3355" .. frame:GetName() .. " created|r")
  end

  local chatWindowsNum = FCF_GetNumActiveChatFrames()

  if not frame and chatWindowsNum and chatWindowsNum < 10 then
    FCF_OpenNewWindow(windowName)
    frame = _G["ChatFrame" .. chatWindowsNum]

    if frame then
      showAndDockChatWindow(frame, _fontSize)
      frame:AddMessage("|ccc55ffaa" .. ADDON_NAME .. ":|r |cccff3355" .. frame:GetName() .. " created|r")
    else
      frame = DEFAULT_CHAT_FRAME
      frame:AddMessage("|ccc55ffaa" .. ADDON_NAME .. ":|r |cccff3355" .. frame:GetName() .. " not created:(|r")
    end
  end

  if r == nil then r = 1 end
  if g == nil then g = 1 end
  if b == nil then b = 1 end

  if frame then
    frame:AddMessage(msg, r, g, b)
  else
    print(msg)
  end
end

local function testprint(msg, r, g, b)
  if settings["Enabled"] and settings["DebugMessagesEnabled"] then
    --func_frameAddMessage("|ccc777777["..date("%H:%M:%S", time()).."]|r"..msg,ADDON_NAME.."_dbg",r,g,b)
    func_frameAddMessage("" .. msg, ADDON_NAME .. "_dbg", r, g, b)
  end
end

----------------------------------------------------
-- текст по центру
----------------------------------------------------
local function func_alert(text, textcolor, startTextSize, textDuration, flashColor, flashDuration, edgeFlashOnly,
                          enableFlash, enableSound, soundPath, soundPathTwo, maxTextSize)
  if not settings["CenterTextEnabled"] or not settings["Enabled"] then return end

  --if func_Alert then
  --  func_Alert(text,textcolor,startTextSize,textDuration,flashColor,flashDuration,edgeFlashOnly,enableFlash,enableSound,soundPath,soundPathTwo,maxTextSize)
  --else
  RaidNotice_AddMessage(RaidWarningFrame, "|cffffffcc" .. text .. "|r", ChatTypeInfo["RAID_WARNING"])
  --end
end

--[[
--------------------------------------------------------------------------------------------------------
-- фреймы и прочая тестовая хрень для алертов, можно не относить к коду
--------------------------------------------------------------------------------------------------------
local texEdge = "Interface\\addons\\"..ADDON_NAME.."\\white.tga"
local texFull = "Interface\\addons\\"..ADDON_NAME.."\\fullwhite+edge2.tga"
local defaultPosY = 200
local maxTextFrames = 15
local defaultFontStartSize = 1
local defaultTextColor = {0.5,0.3,1}
local defaultFlashColor = {0.5,0.3,1}
local defaultSoundPath = ""
local defaultText = "test! 12345! kdsjksdjfksdjf, ЭТА ТЭСТ"
local defaultTextDuration = 2
local defaultFlashDuration = 1
local defaultFont = "Interface\\addons\\"..ADDON_NAME.."\\PTSansNarrow.ttf"
local defaultFontMaxSize = 35
local busyFrames = {}

do
  -- center text frames
  local f = CreateFrame("frame")
  f:SetPoint("TOPLEFT")
  f:SetPoint("BOTTOMRIGHT")
  f:SetFrameLevel(0)
  f:SetFrameStrata("BACKGROUND")
  f.tex = f:CreateTexture(ADDON_NAME.."_alertFrame_screenEdgeHighlight", "BACKGROUND")
  f.tex:SetAllPoints(f)
  f.tex:Hide()

  for i = 1, maxTextFrames do
    local f = CreateFrame("frame",ADDON_NAME.."_alertFrame"..i)
    f.t=f:CreateFontString(ADDON_NAME.."_alertFrame_text"..i, "overlay")
    f.t:SetShadowOffset(0, 0)
    f.t:SetPoint("BOTTOM", f, "CENTER", 0, 0)
    f.t:SetJustifyH("BOTTOM")
    f.t:SetJustifyV("BOTTOM")
    --f:SetFrameStrata("high")
    f:SetFrameStrata("tooltip")
  end
end

----------------------------------------------------
-- функция для изменения размера фрейма
----------------------------------------------------
local function func_animateFrameSize(startTextSize, maxTextSize, scalingDuration, textRegion)
    busyFrames[textRegion]={maxTextSize=maxTextSize}
    local startTime = GetTime()
    local scalingFactor = maxTextSize/startTextSize

    local function onUpdate()
        local elapsed = GetTime() - startTime
        local progress = elapsed / scalingDuration

        if progress >= 1 then
            textRegion:GetParent():SetScript("OnUpdate", nil)
        else
            local curSize = select(2,textRegion:GetFont())
            local newSize = curSize + (maxTextSize - curSize) * progress
            textRegion:SetFont(defaultFont, newSize, 'OUTLINE')
        end
    end

    if textRegion:GetParent():GetScript("OnUpdate")==nil then
      textRegion:GetParent():SetScript("OnUpdate", onUpdate)
    end
end

local function countNewlines(text)
  if not text then return 0 end
  return select(2, text:gsub("\n", "")) or 0
end

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- тестовая функция для показа текста по центру экрана и засвета краёв типа дбм, не относится к данному аддону почти никак, лишь как побрекушка
------------------------------------------------------------------------------------------------------------------------------------------------------------
local function func_alert(text,textcolor,startTextSize,textDuration,flashColor,flashDuration,edgeFlashOnly,enableFlash,enableSound,soundPath,soundPathTwo,maxTextSize)
    if not settings["CenterTextEnabled"] or not settings["Enabled"] then return end

    if enableFlash==nil then enableFlash = true end
    if text==nil then text = defaultText end
    if soundPath==nil then soundPath = defaultSoundPath end
    if flashColor==nil then flashColor = defaultFlashColor end
    if textcolor==nil then textcolor = defaultTextColor end
    if startTextSize==nil then startTextSize = defaultFontStartSize end
    if textDuration==nil then textDuration = defaultTextDuration end
    if flashDuration==nil then flashDuration = defaultFlashDuration end
    if maxTextSize==nil then maxTextSize = defaultFontMaxSize end
    local tex,screenflash
    if edgeFlashOnly then tex=texEdge screenflash=true else tex=texFull end
    local screenEdge = _G[ADDON_NAME.."_alertFrame_screenEdgeHighlight"]
    screenEdge:SetTexture(tex)

    local textRegion,anchor,prevTextRegion,nextTextRegion,offsetY

    for i = 1, maxTextFrames do
      textRegion = _G[ADDON_NAME.."_alertFrame_text" .. i]
      prevTextRegion = _G[ADDON_NAME.."_alertFrame_text"..(i-1)]
      nextTextRegion = _G[ADDON_NAME.."_alertFrame_text"..(i+1)]
      nextNextTextRegion = _G[ADDON_NAME.."_alertFrame_text"..(i+2)]

      if (not UIFrameIsFlashing(textRegion)) then
        if (prevTextRegion) then
          prevTextRegionNumLines = countNewlines(prevTextRegion:GetText())+1
          prevTextFontSize = math.min(maxTextSize,(select(2,prevTextRegion:GetFont())))
          offsetY = -(busyFrames[prevTextRegion].maxTextSize*(prevTextRegionNumLines+1))
          anchor = prevTextRegion
        else
          prevTextRegion = textRegion
          offsetY = defaultPosY
          anchor = UIParent
        end

        if (nextTextRegion and nextTextRegion:IsVisible()) then
          UIFrameFlashStop(nextTextRegion)
          nextTextRegion:Hide()
        end

        if (nextNextTextRegion and nextNextTextRegion:IsVisible()) then
          UIFrameFlashStop(nextNextTextRegion)
          nextNextTextRegion:Hide()
        end

        textRegion:SetPoint("BOTTOM", anchor, "CENTER", 0, offsetY)
        break
      elseif (i == maxTextFrames) then
        textRegion = _G[ADDON_NAME.."_alertFrame_text"..(1)]
        textRegion:SetPoint("BOTTOM", UIParent, "CENTER", 0, defaultPosY)
      end
    end

    if text then
      textRegion:SetFont(defaultFont, startTextSize, 'OUTLINE')
      textRegion:SetTextColor(unpack(textcolor))
      textRegion:SetText(text)
    end

    func_animateFrameSize(startTextSize, maxTextSize, 0.3, textRegion)

    if (screenflash or enableFlash) then
      UIFrameFlashStop(screenEdge)
      screenEdge:SetVertexColor(unpack(flashColor))
      local fadeInTime=flashDuration/5
      local fadeOutTime=flashDuration/2
      UIFrameFlash(screenEdge, fadeInTime, fadeOutTime, flashDuration, false, flashDuration-fadeInTime-fadeOutTime, 0)
    end

    UIFrameFlashStop(textRegion)
    UIFrameFlash(textRegion, 0.2, 0.8, textDuration, false, textDuration-0.2-0.8, 0)

    if enableSound then PlaySoundFile(soundPath) end
    if soundPathTwo then PlaySoundFile(soundPathTwo) end
end
]]

local function contains(table, element)
  for _, value in pairs(table) do
    if (value == element) then
      return true
    end
  end
  return false
end

local function func_playSound(path, isMusic)
  if settings["Enabled"] and settings["SoundsEnabled"] then
    if isMusic then
      PlayMusic(path)
    else
      PlaySoundFile(path)
    end
  end
end

--------------------------------------------------------------------------------------------------------
-- микро напоминания при первом запуске и на входе в комнату к леди
--------------------------------------------------------------------------------------------------------
local function msgAlmostUnobtrusiveAlert() return "|ccc55ffaa" ..
  GetAddOnMetadata(ADDON_NAME, "Author"):match("^(.-) ") ..
  "'s " ..
  ADDON_NAME ..
  ",|r |cccff3355enabled:|r |ccc55ffaa" ..
  tostring(settings["Enabled"]) ..
  "|r" ..
  (LANG == "ruRU" and "\nПеред контролем: запомнит экипированые пушки, после: наденет их обратно.\nАддон на этапе тестирования, офк может что-то не работать.\nФункции по эквипу из \"нового\" дбм, если тот есть, - находим и отключаем вручную." or "\nBefore mind control, this simple script will remember equipped weapons and then put them back on.\nThe addon is in the early testing stage, so some features may not work properly.\nFunctions related to equipment from the \"new\" DBM, if it exists, find and disable manually.") ..
  "" end
local function msgFirstLoadAlert() return "|ccc55ffaa" ..
  GetAddOnMetadata(ADDON_NAME, "Author"):match("^(.-) ") ..
  "'s " ..
  ADDON_NAME ..
  ":|r |cccff3355first load.|r" ..
  (LANG == "ruRU" and "\nПеред контролем: запомнит экипированые пушки, после: наденет их обратно.\nАддон на этапе тестирования, офк может что-то не работать.\nФункции по эквипу из \"нового\" дбм, если тот есть, - находим и отключаем вручную.\nПринудительно было включено: отображение луа ошибок(Интерфейс->Помощь->Ошибки сценариев Lua).\nВсегда находите и исправляйте ошибки, а не скрывайте их!" or "\nBefore mind control, this simple script will remember equipped weapons and then put them back on.\nThe addon is in the early testing stage, so some features may not work properly.\nFunctions related to equipment from the \"new\" DBM, if it exists, find and disable manually.\nLua error display was forcibly enabled(Interface->Help->Display Lua Errors).\nAlways find and fix errors, don't hide them!") ..
  "" end

--------------------------------------------------------------------------------------------------------
-- а вот теперь +- важная часть кода пошла с этого момента
--------------------------------------------------------------------------------------------------------
local function checkIsBossSubZone(subZone)
  if disposed or not settings["Enabled"] then return end
  _, _, _, _, maxPlayers, playerDifficulty = GetInstanceInfo()
  local _, InstanceType = IsInInstance()
  local InRaidGroup = (GetRealNumRaidMembers() > 0 or UnitInRaid('player'))
  spectatorMode = nil
  if (InstanceType == "raid" and not InRaidGroup) then spectatorMode = true end
  if (subZone and (subZone == "Oratory of the Damned" or subZone == "Молельня Проклятых")) and not (maxPlayers == 10 and playerDifficulty == 0) then -- чек что не 10 об + в комнате боса
    isBossSubZone = true
    local posX, posY = GetPlayerMapPosition('player')
    if settings["TestAlertTime"] < time() and posX <= 0.41 and posX >= 0.37 and posY >= 0.72 and posY <= 0.74 then -- координаты входа в комнату
      settings["TestAlertTime"] = time() + 10000
      func_alert(msgAlmostUnobtrusiveAlert(), { 1, 1, 1 }, nil, 20, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
      print(msgAlmostUnobtrusiveAlert())
      if (settings["SoundsEnabled"] and GetCVar("Sound_EnableMusic") == "1" and tonumber(GetCVar("Sound_MusicVolume")) >= 0.1) then -- немного фана
        func_playSound("Interface\\addons\\" .. ADDON_NAME .. "\\Spooky Scary Skeletons.mp3")
      else
        func_playSound("Interface\\addons\\" .. ADDON_NAME .. "\\narcos theme song.mp3")
      end
    end
  else
    isBossSubZone = nil
  end
  testprint('isBossSubZone: ' .. (isBossSubZone or 'nil') .. ',' .. maxPlayers .. ',' .. playerDifficulty .. '')
end

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local function isTanking()
  return UnitThreatSituation("player", "boss1") ~= nil and UnitThreatSituation("player", "boss1") >= 3
end

--------------------------------------------------------------------------------------------------------
-- немного функций для определения спека позаимствовано из дбм, лапками впадлу всё чисто своё делать
--------------------------------------------------------------------------------------------------------
local function getTalentpointsSpent(spellID)
  local spellName = GetSpellInfo(spellID)
  for tabIndex = 1, GetNumTalentTabs() do
    for talentID = 1, GetNumTalents(tabIndex) do
      local name, _, _, _, spent = GetTalentInfo(tabIndex, talentID)
      if (name == spellName) then
        return spent
      end
    end
  end
  return 0
end

local function IsDeathKnightTank()
  local tankTalents = (getTalentpointsSpent(16271) >= 5 and 1 or 0) + (getTalentpointsSpent(49042) >= 5 and 1 or 0) +
  (getTalentpointsSpent(55225) >= 5 and 1 or 0)
  return tankTalents >= 2
end

local function IsMeleeDps()
  return playerClass == "ROGUE" or (playerClass == "WARRIOR" and select(3, GetTalentTabInfo(3)) < 13) or
  (playerClass == "DEATHKNIGHT" and not IsDeathKnightTank()) or
  (playerClass == "PALADIN" and select(3, GetTalentTabInfo(3)) >= 51) or
  (playerClass == "SHAMAN" and select(3, GetTalentTabInfo(2)) >= 50)
end

----------------------------------------------------
-- слоты оружий нашего класса
----------------------------------------------------
local function rememberOurSlotsBySpec()
  --if playerClass == "ROGUE" or playerClass == "SHAMAN" or (playerClass == "DEATHKNIGHT" and select(3, GetTalentTabInfo(2)) >= 50) or (playerClass == "WARRIOR" and select(3, GetTalentTabInfo(2)) >= 50) then
  if playerClass == "ROGUE" or playerClass == "SHAMAN" or playerClass == "DEATHKNIGHT" or playerClass == "WARRIOR" then
    ourSpecWeaponSlots = { 16, 17 } -- rogue,ensham,fdk,fwar
  elseif playerClass == "HUNTER" then
    ourSpecWeaponSlots = { 18 }
  elseif playerClass == "PALADIN" then
    ourSpecWeaponSlots = { 16 }
  end

  -- бой стартовал но мы: не хант и не мили дпс - отмена
  if not disposedForCurrentFight and not (playerClass == 'HUNTER' or IsMeleeDps()) then
    disposedForCurrentFight = true
    testprint("бой стартовал но мы: не хант и не мили дпс (2)")
  end
end

----------------------------------------------------
-- для проверки наличия свободных слотов
----------------------------------------------------
local function getNumFreeBagSlots()
  local count = 0
  for i = 0, 4 do
    local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(i)
    if not bagType then
      break
    end
    if bagType == 0 then
      count = count + numberOfFreeSlots
    end
  end
  return count
end

----------------------------------------------------
-- перевести бы это на ру юзая спелл айди...
----------------------------------------------------
local controlAuras =
{
  "Sap", "Polymorph", "Repentance", "Fear", "Freezing Trap Effect", "Freezing Arrow Effect", "Hammer of Justice", "Blind",
  "Psychic Scream", "Psychic Horror", "Cheap Shot", "Kidney Shot", "Cyclone", "Hungering Cold", "Scatter Shot",
  "Seduction", "Hex", "Howl of Terror", "Gnaw", "Shadowfury", "Mind Control", "Gouge", "Banish", "Cobalt Frag Bomb",
  "Shockwave", "Turn Evil", "Dragon Breath", "Concussion Blow", "Charge Stun", "Intercept", "Death Coil", "Shadowfury",
  "Hungering Cold", "Shackle Undead", "Hibernate", "War Stomp",
}

----------------------------------------------------
-- чек станов фиров итд, крч контроля
----------------------------------------------------
function playerIsControlled()
  if (UnitIsControlled and UnitIsControlled('player')) or UnitIsPossessed("player") then -- UnitIsControlled - ставим awesomewotlk lib если нету
    return true
  end
  -- если не хотим ставить то гоняем по списку дебафов..
  for _, debuff in pairs(controlAuras) do
    if UnitDebuff("player", debuff) then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------------------------------
-- запоминание пушек перед снятием если включена опция временного сета и есть фри слоты в экипировке
--------------------------------------------------------------------------------------------------------
local function func_saveWeaponAndSlotBeforeUnequip()
  if not settings["Enabled"] then
    return
  end

  for _, weaponSlot in pairs(ourSpecWeaponSlots) do
    local weaponLink = GetInventoryItemLink('player', weaponSlot)
    if weaponLink ~= nil then
      savedSlotAndWeaponLinkInfo[weaponSlot] = weaponLink
      testprint("запоминаем пушку+слот " .. weaponSlot .. " " .. GetInventoryItemLink('player', weaponSlot) .. "")
    end
  end

  if tablelength(savedSlotAndWeaponLinkInfo) ~= 0 then
    testprint("сохраняем временный сет для эквипа пушек") -- только если все слоты оружий нашего спека содержат оружие чтобы на всякий не сохранился сет без какой-то пухи, а то вдруг
    if GetEquipmentSetInfoByName(TMP_SET_NAME) ~= nil then
      DeleteEquipmentSet(TMP_SET_NAME)
    end
    SaveEquipmentSet(TMP_SET_NAME, 1)
  end

  if GetEquipmentSetInfoByName(TMP_SET_NAME) == nil then
    testprint("временный сет для эквипа пушек |cffff0000НЕ БЫЛ СОЗДАН!|r")
  end
end

----------------------------------------------------
-- проверка на то что все пухи экипированы
----------------------------------------------------
local function condition_weaponsAreEquipped()
  return tablelength(weaponUnequipedSlots) == 0
end

----------------------------------------------------
-- проверка на возможность одеть пухи
----------------------------------------------------
local function condition_equipConditions()
  return settings["Enabled"] and not disposedForCurrentFight and not waitIsEquipingSet and
  not condition_weaponsAreEquipped() and lastEquipOrUnequipTryTime + 0.5 <= GetTime() and not UnitIsDeadOrGhost("player") and
  not UnitCastingInfo("player") and not UnitChannelInfo("player") and playerIsControlled() == false
end

----------------------------------------------------
-- проверка на возможность снять пухи
----------------------------------------------------
local function condition_unequipConditions()
  --func_saveWeaponAndSlotBeforeUnequip()
  return settings["Enabled"] and not disposedForCurrentFight and not waitIsEquipingSet and
  lastEquipOrUnequipTryTime + 0.5 <= GetTime() and condition_weaponsAreEquipped() and not isTanking() and
  not UnitIsDeadOrGhost("player") and not UnitCastingInfo("player") and not UnitChannelInfo("player") and
  getNumFreeBagSlots() >= tablelength(ourSpecWeaponSlots)
end

----------------------------------------------------
-- функция по снятию
----------------------------------------------------
function func_unequipWeapons(reason)
  func_saveWeaponAndSlotBeforeUnequip()

  for weaponSlot, weaponLink in pairs(savedSlotAndWeaponLinkInfo) do
    local texture = select(10, GetItemInfo(weaponLink)) or [=[Interface\icons\INV_Misc_QuestionMark]=]
    testprint("траим снять  |T" .. texture .. ":14|t " .. weaponLink ..
    " слот " .. weaponSlot .. " (" .. (reason or "test") .. ")")
    PickupInventoryItem(weaponSlot) -- берем в курсор итем
    auto[weaponSlot] = true         -- авто = снято аддоном а не челом/игроком(тобой)
    lastEquipOrUnequipTryTime = GetTime()
    PutItemInBackpack()             -- кладем в сумку
  end
end

----------------------------------------------------
-- функция по одеванию
----------------------------------------------------
function func_equipWeapons(reason, test)
  -- сначала траим одеть временный сет если опция вкл
  if settings["alwaysUseTmpSetForEquip"] then
    if GetEquipmentSetInfoByName(TMP_SET_NAME) == nil then
      testprint(GetEquipmentSetInfoByName(TMP_SET_NAME) == nil, tablelength(savedSlotAndWeaponLinkInfo) == 0)
      testprint("|ccc55ffaa" ..
      ADDON_NAME ..
      ":|r" ..
      (LANG == "ruRU" and "|cccff0000Нет свободных слотов для создания временного комплекта экипировки! Выключаем эту опцию|r" or "|cccff0000There are no slots available to create a temporary equipment set! Disabling this setting|r"))
      func_alert(
      (LANG == "ruRU" and "|cccff0000Нет свободных слотов для создания временного комплекта экипировки! Выключаем эту опцию|r" or "|cccff0000There are no slots available to create a temporary equipment set! Disabling this setting|r"),
        { 1, 1, 1 }, nil, 5, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
      settings["alwaysUseTmpSetForEquip"] = false
      _G[ADDON_NAME .. "_alwaysUseTmpSetForEquipCheckbox"]:SetChecked(false)
    else
      local texture = "Interface\\icons\\" ..
      (select(1, GetEquipmentSetInfoByName(TMP_SET_NAME)) or [=[INV_Misc_QuestionMark]=])
      testprint("траим одеть временный сет  |T" .. texture .. ":14|t \"" .. TMP_SET_NAME .. "\" (" .. reason .. ")")
      for weaponSlot in pairs(savedSlotAndWeaponLinkInfo) do
        --print("auto",weaponSlot,"true1")
        auto[weaponSlot] = true
      end
      lastEquipOrUnequipTryTime = GetTime()
      UseEquipmentSet(TMP_SET_NAME)
      return -- если временный оделся - ок, выходим из функции
    end
  end

  -- если временный не оделся и опция названия сета вкл
  if settings["setNameForEquip"] and settings["setNameForEquip"] ~= "" and tablelength(savedSlotAndWeaponLinkInfo) ~= 0 then
    if GetEquipmentSetInfoByName(settings["setNameForEquip"]) == nil then
      testprint("|ccc55ffaa" ..
      ADDON_NAME .. ":|r |cccff0000Equipment set with name has \"" .. settings["setNameForEquip"] .. "\" not found!|r")
      func_alert("|cccff0000комплект экипировки с названием \"" .. settings["setNameForEquip"] .. "\" не найден!|r",
        { 1, 1, 1 }, nil, 3, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
      return
    end

    local texture = "Interface\\icons\\" ..
    (select(1, GetEquipmentSetInfoByName(settings["setNameForEquip"])) or [=[INV_Misc_QuestionMark]=])
    testprint("траим одеть сет  |T" ..
    texture ..
    ":14|t \"" .. settings["setNameForEquip"] .. "\" (" .. reason .. "), " .. tablelength(savedSlotAndWeaponLinkInfo) ..
    "")
    for weaponSlot in pairs(savedSlotAndWeaponLinkInfo) do
      auto[weaponSlot] = true
      --print("auto",weaponSlot,"true2")
    end
    lastEquipOrUnequipTryTime = GetTime()
    UseEquipmentSet(settings["setNameForEquip"])
  end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- эквип/анэквип по таймерам, тротлим с кд 0.1 сек, маст хев проверить как работает чек на бой по крику "как вы смеете бла бла бла" босса когда выключено "encounter unit frames" (или проще говоря когда boss1==nil)
------------------------------------------------------------------------------------------------------------------------------------------------------------
local frame = CreateFrame("frame")
frame:SetScript("OnUpdate", function(self, elapsed)
  onUpdateTimer = onUpdateTimer + elapsed

  if onUpdateTimer > actionTimer then
    onUpdateTimer = 0

    -- адон выключен в опциях - отмена
    if not settings["Enabled"] then
      --print('settings["Enabled"]',settings["Enabled"])
      return
    end

    -- персонажу не требуется снимать пухи - отмена
    if bossFightStarted and disposedForCurrentFight then
      testprint('диспоз на время этого боя')
      return
    end

    -- вне зоны босса - отмена
    if not isBossSubZone then
      if condition_equipConditions() then
        func_equipWeapons("выход из комнаты босса")
      end
      MKLastUsedTime, MKLastAppliedTime, disposedForCurrentFight, MKAffectedPlayerGuids, bossFightStarted, bossIsDefeated =
      nil, nil, nil, {}, nil, nil
      return
    end

    if bossFightStarted and not spectatorMode and (bossIsDefeated or not UnitAffectingCombat('player')) then
      bossFightStarted = nil
      testprint('бой завершен')
    end

    -- бос крикнул КАК ВЫ СМЕЕТЕ ВСТУПАТЬ В ЭТИ СВЯЩЕННЫЕ ПОКОИ и если мы в бою: пошла жара
    if bossFightStartYelled then
      bossFightStartYelled = nil
      if not bossFightStarted and UnitAffectingCombat('player') then
        bossFightStarted = true
        testprint('bossFightStarted (yell)')
        rememberOurSlotsBySpec()
      end
    end

    local bossName = UnitName('boss1')

    -- крик не чекнулся или бой не повесился, чето пошло не так, но есть имя босса и фреймы босов включены: бой с боссом есть
    if not bossFightStarted and bossName and (bossName == "Lady Deathwhisper" or bossName == "Леди Смертный Шепот") then
      testprint('bossFightStarted (bossName)')
      bossFightStarted = true
      rememberOurSlotsBySpec()
    end

    -- нет боса - нет боя - отмена
    if not bossFightStarted then
      --testprint("нет боса - нет боя")
      if condition_equipConditions() then
        func_equipWeapons("нет боса - нет боя")
      end
      MKLastUsedTime, MKLastAppliedTime, disposedForCurrentFight, MKAffectedPlayerGuids, bossIsDefeated = nil, nil, nil,
          {}, nil
      return
    end

    -- бой стартовал но мы: не хант и не мили дпс - отмена
    if not disposedForCurrentFight and not (playerClass == 'HUNTER' or IsMeleeDps()) then
      disposedForCurrentFight = true
      testprint("бой стартовал но мы: не хант и не мили дпс (1)")
      return
    end

    -- на этом моменте: бой типа стартовал и мы в нём активно участвуем, чекаем таймеры дбм/недбм если требуется
    local curTime = GetTime()
    if not MKLastUsedTime then MKLastUsedTime = curTime - 10 end -- на старте боя мк будет применяться через 30 сек, так как кд мк = +-40 сек то минусуем от времени старта боя 10 сек
    if not MKLastAppliedTime then MKLastAppliedTime = curTime - 10 end
    local MKLastUsedSecondsPass = curTime -
    MKLastUsedTime                                               -- сколько сек тому было применено мк, обычно прокает на 0.5 - 1 сек раньше наложения самой ауры мк ауры
    local MKLastAppliedSecondsPass = curTime -
    MKLastAppliedTime                                            -- сколько сек тому была применена последняя аура мк на игрока

    -- ПОЛУЧЕНИЕ ТАЙМЕРА КОНТРОЛЯ ИЗ ДБМ:
    -- DBM_DOMINATE_MIND_CD -- вариация с переменной на кд мк через дбм, по дефолту переменная в этом коде ниловая, ниже грязный способ получать этот таймер прямо из дбм: добавляем в нужном месте в код дбм (в класик версии это в DBT.lua, в "новой" - хз, в функцию barPrototype:Update примерно перед её end-ом) код КОТорый ниже:
    ------------------------------------------------------------------------------------------
    -- local DBM_DOMINATE_MIND_CD_BarName = getglobal(frame:GetName().."BarName"):GetText()
    -- if DBM_DOMINATE_MIND_CD_BarName == "Dominate Mind CD" then
    --    DBM_DOMINATE_MIND_CD = self.timer
    -- end
    ------------------------------------------------------------------------------------------
    -- !!! для ру клиентов вместо "Dominate Mind CD" нужно будет прописать соответствующий ру вариант текста полоски с кд, хз какой там в ру текст

    --print(string.format('%.1f',MKLastUsedSecondsPass))
    if (settings["UnequipByTimer"] and DBM_DOMINATE_MIND_CD and DBM_DOMINATE_MIND_CD >= 0.5 and DBM_DOMINATE_MIND_CD <= 1 and condition_unequipConditions()) then
      func_unequipWeapons("по дбм таймеру, DBM_DOMINATE_MIND_CD: " .. string.format('%.1f', DBM_DOMINATE_MIND_CD) .. "")
    elseif (DBM_DOMINATE_MIND_CD and DBM_DOMINATE_MIND_CD > 5 and MKLastUsedSecondsPass > 2 and MKLastAppliedSecondsPass > 1 and MKLastUsedSecondsPass < 20 and condition_equipConditions()) then
      func_equipWeapons("по дбм таймеру, DBM_DOMINATE_MIND_CD: " .. string.format('%.1f', DBM_DOMINATE_MIND_CD) .. "")
    elseif (settings["UnequipByTimer"] and not DBM_DOMINATE_MIND_CD and MKLastUsedSecondsPass > MK_COOLDOWN and condition_unequipConditions()) then
      func_unequipWeapons("без дбм таймера, " .. string.format('%.1f', MKLastUsedSecondsPass) .. "")
    elseif (not DBM_DOMINATE_MIND_CD and MKLastUsedSecondsPass > 2 and MKLastAppliedSecondsPass > 1 and MKLastUsedSecondsPass < 20 and condition_equipConditions()) then
      func_equipWeapons("без дбм таймера, " ..
      string.format('%.1f', MKLastUsedSecondsPass) .. ", " .. string.format('%.1f', MKLastAppliedSecondsPass) .. "")
    end

    if MKLastAppliedSecondsPass > 2 and ((tablelength(MKAffectedPlayerGuids) >= 3 and maxPlayers == 25 and playerDifficulty == 1) or (tablelength(MKAffectedPlayerGuids) >= 1 and not (maxPlayers == 25 and playerDifficulty == 1))) then
      MKAffectedPlayerGuids = {} -- цели давноооо выбраны, очищаем таблицу
      --print('MKAffectedPlayerGuids={}')
    end
    --print('xxx')
  end
end)

----------------------------------------------------
-- эвенты
----------------------------------------------------
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UNIT_FLAGS")
frame:RegisterEvent("EQUIPMENT_SWAP_PENDING")
frame:RegisterEvent("EQUIPMENT_SWAP_FINISHED")

frame:SetScript("OnEvent", function(self, event, ...)
  if not settings["Enabled"] and event ~= "ADDON_LOADED" and event ~= "PLAYER_ENTERING_WORLD" then
    return
  end
  if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
    local _, subEvent, srcGuid, srcName, srcFlags, dstGuid, dstName, dstFlags, spellid, spellname = ...
    if (spellname == "Dominate Mind" or spellname == "Господство над разумом" or spellid == 71289) then
      if (subEvent == "SPELL_CAST_SUCCESS") then
        MKLastUsedTime = GetTime()
        MKAffectedPlayerGuids[dstGuid] = true -- будущие цели мк
        testprint("мк будет на " .. (dstName or dstGuid or "?") .. " (" .. subEvent .. ")")

        -- local _,classFilename = GetPlayerInfoByGUID(srcGuid)
        -- if tarCD + 3 < GetTime() and (classFilename=="WARRIOR" or classFilename=="PALADIN" or classFilename=="DEATHKNIGHT" or classFilename=="ROGUE" or classFilename=="HUNTER") then
        -- RunMacroText("/tar "..dstName.."") 
        -- SendChatMessage(".sp view")
        -- tarCD=GetTime()
        -- end

        if (dstGuid == playerGuid and condition_unequipConditions()) then
          --print("снятие пухи", subEvent)
          func_unequipWeapons(subEvent .. " мк будет на нас") -- леди выбрала нас, остальным соболезнуем (если пушка вдруг не снялась)
        end

        -- if tablelength(MKAffectedPlayerGuids) >= 3 and maxPlayers == 25 and playerDifficulty == 1 then
        -- print("sadasdsa")
        -- end
        -- в 25 гере мк кидается на 3 челов, в 25 об и 10 гер на одного, тен так ли?
        if (tablelength(MKAffectedPlayerGuids) >= 3 and maxPlayers == 25 and playerDifficulty == 1) or (tablelength(MKAffectedPlayerGuids) >= 1 and not (maxPlayers == 25 and playerDifficulty == 1)) then
          --if not contains(MKAffectedPlayerGuids,playerGuid) then
          --print("GSGDFSD",condition_equipConditions())
          --end
          if not contains(MKAffectedPlayerGuids, playerGuid) and condition_equipConditions() then
            func_equipWeapons("мк нас не коснётся") -- потому как леди выбрала всех целей и среди них нас нет
          end
          MKAffectedPlayerGuids = {} -- цели выбраны, очищаем таблицу
        end
      elseif (subEvent == "SPELL_AURA_REMOVED" and dstGuid == playerGuid and condition_equipConditions()) then
        --print("одевание пухи", subEvent)
        func_equipWeapons(subEvent)
      elseif subEvent == "SPELL_AURA_APPLIED" then
        if (dstGuid == playerGuid) then
          func_playSound("Interface\\addons\\" .. ADDON_NAME .. "\\eto ne normalno.wav")
        end
        MKLastAppliedTime = GetTime()
        --print("мк аура получена", dstName or dstGuid or "?", subEvent)
      elseif (subEvent == "UNIT_DIED" and (dstName == "Lady Deathwhisper" or dstName == "Леди Смертный Шепот")) then
        bossIsDefeated = true
        --bossFightStarted=nil
        testprint('bossIsDefeated')
        if condition_equipConditions() then
          func_equipWeapons("победа!")
        end
      end
    end
  elseif (event == "ADDON_LOADED" and arg1 == ADDON_NAME) then
    settings = CLWH_CoolLadyWeaponHelper_Settings

    if settings == nil then
      settings = {}
      CLWH_CoolLadyWeaponHelper_Settings = settings
      settings["Enabled"] = true
      settings["UnequipByTimer"] = true
      settings["DebugMessagesEnabled"] = false
      settings["debugMessagesInSeparateChatWindow"] = false
      settings["CenterTextEnabled"] = true
      settings["SoundsEnabled"] = true
      settings["TestAlertTime"] = time()
      settings["setNameForEquip"] = ""
      if GetNumEquipmentSets() < 10 then
        settings["alwaysUseTmpSetForEquip"] = true
      else
        settings["alwaysUseTmpSetForEquip"] = false
      end
      testprint('firstLoad', GetNumEquipmentSets())
      PlaySoundFile("Interface\\addons\\" .. ADDON_NAME .. "\\narcos theme song.mp3")
      firstLoad = true
    end

    --_G[ADDON_NAME.."_enabledCheckbox"]:SetChecked(settings["Enabled"])
    _G[ADDON_NAME .. "_unequipByTimerCheckbox"]:SetChecked(settings["UnequipByTimer"])
    _G[ADDON_NAME .. "_debugMessagesCheckbox"]:SetChecked(settings["DebugMessagesEnabled"])
    _G[ADDON_NAME .. "_debugMessagesInSeparateChatWindowCheckbox"]:SetChecked(settings
    ["debugMessagesInSeparateChatWindow"])
    _G[ADDON_NAME .. "_centerTextCheckbox"]:SetChecked(settings["CenterTextEnabled"])
    _G[ADDON_NAME .. "_enableSoundsCheckbox"]:SetChecked(settings["SoundsEnabled"])
    _G[ADDON_NAME .. "_setNameEditbox"]:SetText(settings["setNameForEquip"])
    _G[ADDON_NAME .. "_alwaysUseTmpSetForEquipCheckbox"]:SetChecked(settings["alwaysUseTmpSetForEquip"])
    --print("54321")
  elseif (event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA") then
    checkIsBossSubZone(GetSubZoneText())
  elseif (event == "PLAYER_LOGIN") then
    func_playSound(gunpickup2wav)
  elseif (event == "PLAYER_ENTERING_WORLD") then
    if not playerEnteredWorld then
      playerEnteredWorld = 1
      for k, v in pairs(settings) do
        testprint('|ccc55ffaa' .. ADDON_NAME .. ':|r |cccff3355' .. k .. ':|r |ccc55ffaa' .. tostring(v) .. '|r')
      end
    end
    checkIsBossSubZone(GetSubZoneText())
    playerClass = select(2, UnitClass("player"))
    playerGuid = UnitGUID('player')
    -- if playerClass == 'HUNTER' then
    -- ourSpecWeaponSlots = {18}
    -- elseif playerClass == 'PALADIN' then
    -- ourSpecWeaponSlots = {16}
    -- else
    -- ourSpecWeaponSlots = {16,17}
    -- end
    if not disposed and (playerClass == 'MAGE' or playerClass == 'PRIEST' or playerClass == 'WARLOCK' or playerClass == 'DRUID') then
      disposed = true
      settings["Enabled"] = false
      _G[ADDON_NAME .. "_enabledCheckbox"]:Disable()
      _G[ADDON_NAME .. "_enabledText"]:SetTextColor(0.5, 0.5, 0.5)
      _G[ADDON_NAME .. "_enabledText"]:SetText(_G[ADDON_NAME .. "_enabledText"]:GetText() ..
      " " ..
      (LANG == "ruRU" and "(автоотключено, потому что вы: " .. playerClass .. ")" or "(disabled because player class is: " .. playerClass .. ")") ..
      "")
      --print("12345")
    else
      _G[ADDON_NAME .. "_enabledCheckbox"]:SetChecked(settings["Enabled"])
    end
    if firstLoad then
      firstLoad = nil
      --print('firstLoad', GetNumEquipmentSets())
      if GetNumEquipmentSets() < 10 then
        settings["alwaysUseTmpSetForEquip"] = true
      else
        settings["alwaysUseTmpSetForEquip"] = false
      end
      _G[ADDON_NAME .. "_alwaysUseTmpSetForEquipCheckbox"]:SetChecked(settings["alwaysUseTmpSetForEquip"])
      if not disposed then
        SetCVar('scriptErrors', '1') -- отображение луа ошибок
        --PlaySoundFile("Interface\\addons\\"..ADDON_NAME.."\\narcos theme song.mp3")
        func_alert(msgFirstLoadAlert(), { 1, 1, 1 }, nil, 25, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
        print(msgFirstLoadAlert())
      end
    end
    if settings["alwaysUseTmpSetForEquip"] and GetEquipmentSetInfoByName(TMP_SET_NAME) ~= nil then
      DeleteEquipmentSet(TMP_SET_NAME)
      testprint("удаляем временный сет, который чудным образом не удалился")
    end
    rememberOurSlotsBySpec()
  elseif (event == "PLAYER_EQUIPMENT_CHANGED") then
    --print(event,arg1,arg2)
    if not auto[arg1] then return end
    local weaponSlot = arg1
    local equiped = arg2
    local weaponLink, texture
    auto[weaponSlot] = nil
    if equiped == nil then
      weaponUnequipedSlots[weaponSlot] = true -- пушка снята, + инфа в таблице
      weaponLink = savedSlotAndWeaponLinkInfo[weaponSlot] or "?"
      texture = select(10, GetItemInfo(weaponLink)) or [=[Interface\icons\INV_Misc_QuestionMark]=]
      testprint("|T" .. texture .. ":14|t " .. weaponLink .. " |cffff0000СНЯТО|r из слота " .. weaponSlot .. "")
      func_alert("|T" .. texture .. ":12|t " .. weaponLink .. " |cffff0000СНЯТО|r из слота " .. weaponSlot .. "", { 1, 1, 1 },
        nil, 2, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
      func_playSound(weapondrop1wav)
      --func_playSound("Interface\\addons\\"..ADDON_NAME.."\\weapon removed.wav")
    else
      weaponUnequipedSlots[weaponSlot] = nil     -- пушка одета
      savedSlotAndWeaponLinkInfo[weaponSlot] = nil -- пушка одета, ранее сохранённые данные по слоту + линку удалены
      weaponLink = GetInventoryItemLink('player', weaponSlot) or "?"
      texture = select(10, GetItemInfo(weaponLink)) or [=[Interface\icons\INV_Misc_QuestionMark]=]
      testprint("|T" .. texture .. ":14|t " .. weaponLink .. " |cff00ff00ЭКИПИРОВАНО|r в слот " .. weaponSlot .. "")
      func_alert("|T" .. texture .. ":12|t " .. weaponLink .. " |cff00ff00ЭКИПИРОВАНО|r в слот " .. weaponSlot .. "",
        { 1, 1, 1 }, nil, 2, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
      func_playSound(gunpickup2wav)
      --func_playSound("Interface\\addons\\"..ADDON_NAME.."\\weapon equipped.wav")
      savedSlotAndWeaponLinkInfo = {} -- если хотя бы одна пушка одета - то по идее сет оделся - таблица сохраненных более не нужна
      weaponUnequipedSlots = {}
      --auto={}
      if settings["alwaysUseTmpSetForEquip"] and tablelength(savedSlotAndWeaponLinkInfo) == 0 and GetEquipmentSetInfoByName(TMP_SET_NAME) ~= nil then
        DeleteEquipmentSet(TMP_SET_NAME)
        testprint("оружия экипированы, удаляем временный сет")
      end
      --print(tablelength(savedSlotAndWeaponLinkInfo))
    end
  elseif (event == "CHAT_MSG_MONSTER_YELL" and (arg2 == "Lady Deathwhisper" or arg2 == "Леди Смертный Шепот")) then
    if (arg1 == "Как вы смеете ступать в эти священные покои? Это место станет вашей могилой!" or arg1 == "What is this disturbance? You dare trespass upon this hallowed ground? This shall be your final resting place!") then
      bossFightStartYelled = true
      savedSlotAndWeaponLinkInfo = {}
      weaponUnequipedSlots = {}
      rememberOurSlotsBySpec()
      --print('bossFightStartYelled')
    elseif ((arg1 == "Ты не в силах противиться моей воле!" or arg1 == "You are weak, powerless to resist my will!") and condition_unequipConditions()) then
      --print("снятие пухи", event)
      func_unequipWeapons(event)
    end
  elseif (event == "UNIT_FLAGS" and arg1 == 'player') then
    if not inCombat and UnitAffectingCombat('player') then
      inCombat = true
      testprint('inCombat', inCombat)
      rememberOurSlotsBySpec()
    elseif inCombat and not UnitAffectingCombat('player') then
      inCombat = nil
      testprint('inCombat', inCombat)
    end
  elseif (event == "EQUIPMENT_SWAP_PENDING") then
    waitIsEquipingSet = true
    testprint(event, waitIsEquipingSet)
  elseif (event == "EQUIPMENT_SWAP_FINISHED") then
    waitIsEquipingSet = nil
    testprint(event, waitIsEquipingSet)
  end
end)




--==========================================================================================================================================================
-- нястройки на минималках в самом минималистическом виде, без ACE, именно так хотел, делал только на тест
--==========================================================================================================================================================

----------------------------------------------------
-- settingsScrollFrame - прокрутка для настроек
----------------------------------------------------
local width, height = 800, 800
local settingsScrollFrame = CreateFrame("ScrollFrame",  ADDON_NAME .. "_settingsScrollFrame", InterfaceOptionsFramePanelContainer,
  "UIPanelScrollFrameTemplate")
settingsScrollFrame.name = GetAddOnMetadata(ADDON_NAME, "TitleShort")
settingsScrollFrame:SetSize(width, height)
settingsScrollFrame:Hide()
--settingsScrollFrame:SetPoint("CENTER", UIParent, "CENTER")
settingsScrollFrame:SetAllPoints(InterfaceOptionsFramePanelContainer)
settingsScrollFrame:SetVerticalScroll(10)
settingsScrollFrame:SetHorizontalScroll(10)

----------------------------------------------------
-- settingsFrame - мейн фрейм настроек
----------------------------------------------------
local settingsFrame = CreateFrame("Frame", nil, settingsScrollFrame)
settingsFrame:Hide()
settingsFrame:SetSize(width, height) -- Измените размеры фрейма настроек ++ 4.3.24
settingsFrame:SetAllPoints(InterfaceOptionsFramePanelContainer)

settingsScrollFrame:SetScript("OnShow", function()
  settingsFrame:Show()
  --print('settingsFrame:Show')
end)
settingsScrollFrame:SetScript("OnHide", function()
  settingsFrame:Hide()
  --print('settingsFrame:Hide')
end)
settingsScrollFrame:SetScrollChild(settingsFrame)

local settingsTitleText = settingsFrame:CreateFontString(nil, "ARTWORK")
settingsTitleText:SetFont(THIN_FONT_NAME, 27, 'OUTLINE')
settingsTitleText:SetPoint("TOPLEFT", 16, -16)
settingsTitleText:SetText("" .. GetAddOnMetadata(ADDON_NAME, "Title") .. " Settings")

----------------------------------------------------
-- enabledCheckbox
----------------------------------------------------
local enabledCheckbox = CreateFrame("CheckButton", ADDON_NAME .. "_enabledCheckbox", settingsFrame,
  "UICheckButtonTemplate")
enabledCheckbox:SetScale(1.5)
enabledCheckbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 0, -10)

local enabledCheckboxLabel = settingsFrame:CreateFontString(ADDON_NAME .. "_enabledText", "ARTWORK")
enabledCheckboxLabel:SetFont(THIN_FONT_NAME, 14, 'OUTLINE')
enabledCheckboxLabel:SetPoint("LEFT", enabledCheckbox, "RIGHT", 5, 0)
enabledCheckboxLabel:SetText("" .. (LANG == "ruRU" and "Включено" or "Enable addon") .. "")

enabledCheckbox:SetScript("OnClick", function(self)
  if self:GetChecked() then
    settings["Enabled"] = true
    func_playSound(gunpickup2wav)
  else
    settings["Enabled"] = false
    func_playSound(weapondrop1wav)
  end
  testprint('|ccc55ffaa' .. ADDON_NAME .. ':|r |cccff3355Enabled:|r |ccc55ffaa' .. tostring(settings["Enabled"]) .. '|r')
end)

----------------------------------------------------
-- unequipByTimerCheckbox
----------------------------------------------------
local unequipByTimerCheckbox = CreateFrame("CheckButton", ADDON_NAME .. "_unequipByTimerCheckbox", settingsFrame,
  "UICheckButtonTemplate")
unequipByTimerCheckbox:SetScale(1.5)
unequipByTimerCheckbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 0, -40)

local unequipByTimerCheckboxLabel = settingsFrame:CreateFontString(nil, "ARTWORK")
unequipByTimerCheckboxLabel:SetFont(THIN_FONT_NAME, 12, 'OUTLINE')
unequipByTimerCheckboxLabel:SetPoint("LEFT", unequipByTimerCheckbox, "RIGHT", 5, 0)
unequipByTimerCheckboxLabel:SetJustifyH("LEFT")
unequipByTimerCheckboxLabel:SetJustifyV("BOTTOM")
unequipByTimerCheckboxLabel:SetText("" ..
(LANG == "ruRU" and "Снятие по таймеру 40 сек от юза мк вместо SPELL_CAST_SUCCESS или крика босса.\nИспользовать при не идеальном пинге.\nЕсли включено: возможны простои на 2 фазе без оружия в лапках." or "Unequip by 40 sec timer instead of SPELL_CAST_SUCCESS or boss yell.\nUse when latency is not ideal.\nIf enabled: there may be downtime in phase 2 without weapons in hands.") ..
"")

unequipByTimerCheckbox:SetScript("OnClick", function(self)
  if self:GetChecked() then
    settings["UnequipByTimer"] = true
    func_playSound(gunpickup2wav)
  else
    settings["UnequipByTimer"] = false
    func_playSound(weapondrop1wav)
  end
  testprint("|ccc55ffaa" ..
  ADDON_NAME .. ":|r |cccff3355Unequip by timer:|r |ccc55ffaa" .. tostring(settings["UnequipByTimer"]) .. "|r")
end)

----------------------------------------------------
-- debugMessagesCheckbox
----------------------------------------------------
local debugMessagesCheckbox = CreateFrame("CheckButton", ADDON_NAME .. "_debugMessagesCheckbox", settingsFrame,
  "UICheckButtonTemplate")
debugMessagesCheckbox:SetScale(1.5)
debugMessagesCheckbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 0, -70)

local debugMessagesCheckboxLabel = settingsFrame:CreateFontString(nil, "ARTWORK")
debugMessagesCheckboxLabel:SetFont(THIN_FONT_NAME, 14, 'OUTLINE')
debugMessagesCheckboxLabel:SetPoint("LEFT", debugMessagesCheckbox, "RIGHT", 5, 0)
debugMessagesCheckboxLabel:SetJustifyH("LEFT")
debugMessagesCheckboxLabel:SetJustifyV("BOTTOM")
debugMessagesCheckboxLabel:SetText("" ..
(LANG == "ruRU" and "Отображение сообщений в чате для отладки" or "Display debug messages in the chat") .. "")

debugMessagesCheckbox:SetScript("OnClick", function(self)
  if self:GetChecked() then
    settings["DebugMessagesEnabled"] = true
    func_playSound(gunpickup2wav)
  else
    settings["DebugMessagesEnabled"] = false
    func_playSound(weapondrop1wav)
  end
  testprint('|ccc55ffaa' ..
  ADDON_NAME ..
  ':|r |cccff3355Debug messages enabled:|r |ccc55ffaa' .. tostring(settings["DebugMessagesEnabled"]) .. '|r')
end)

----------------------------------------------------
-- centerTextCheckbox
----------------------------------------------------
local centerTextCheckbox = CreateFrame("CheckButton", ADDON_NAME .. "_centerTextCheckbox", settingsFrame,
  "UICheckButtonTemplate")
centerTextCheckbox:SetScale(1.5)
centerTextCheckbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 0, -100)

local centerTextCheckboxLabel = settingsFrame:CreateFontString(nil, "ARTWORK")
centerTextCheckboxLabel:SetFont(THIN_FONT_NAME, 14, 'OUTLINE')
centerTextCheckboxLabel:SetPoint("LEFT", centerTextCheckbox, "RIGHT", 5, 0)
centerTextCheckboxLabel:SetJustifyH("LEFT")
centerTextCheckboxLabel:SetJustifyV("BOTTOM")
centerTextCheckboxLabel:SetText("" .. (LANG == "ruRU" and "Сообщения по центру экрана" or "Enable center text") .. "")

centerTextCheckbox:SetScript("OnClick", function(self)
  if self:GetChecked() then
    settings["CenterTextEnabled"] = true
    func_playSound(gunpickup2wav)
    func_alert("|T" .. select(3, GetSpellInfo(1604)) .. ":12|t Center text: |ccc00ff00enabled|r", { 1, 1, 1 }, nil, 5,
      { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
  else
    func_playSound(weapondrop1wav)
    func_alert("|T" .. select(3, GetSpellInfo(58858)) .. ":12|t Center text: |cccff0000disabled|r", { 1, 1, 1 }, nil, 5,
      { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
    settings["CenterTextEnabled"] = false
    -- for i = 1, maxTextFrames do
    -- _G[ADDON_NAME.."_alertFrame"..i]:Hide()
    -- end
  end
  testprint('|ccc55ffaa' ..
  ADDON_NAME .. ':|r |cccff3355Center text enabled:|r |ccc55ffaa' .. tostring(settings["CenterTextEnabled"]) .. '|r')
end)

----------------------------------------------------
-- enableSoundsCheckbox
----------------------------------------------------
local enableSoundsCheckbox = CreateFrame("CheckButton", ADDON_NAME .. "_enableSoundsCheckbox", settingsFrame,
  "UICheckButtonTemplate")
enableSoundsCheckbox:SetScale(1.5)
enableSoundsCheckbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 0, -130)

local enableSoundsCheckboxLabel = settingsFrame:CreateFontString(nil, "ARTWORK")
enableSoundsCheckboxLabel:SetFont(THIN_FONT_NAME, 14, 'OUTLINE')
enableSoundsCheckboxLabel:SetPoint("LEFT", enableSoundsCheckbox, "RIGHT", 5, 0)
enableSoundsCheckboxLabel:SetJustifyH("LEFT")
enableSoundsCheckboxLabel:SetJustifyV("BOTTOM")
enableSoundsCheckboxLabel:SetText("" .. (LANG == "ruRU" and "Включить звуки" or "Enable sounds") .. "")

enableSoundsCheckbox:SetScript("OnClick", function(self)
  if self:GetChecked() then
    settings["SoundsEnabled"] = true
    func_playSound(gunpickup2wav)
  else
    settings["SoundsEnabled"] = false
    func_playSound(weapondrop1wav)
  end
  testprint('|ccc55ffaa' ..
  ADDON_NAME .. ':|r |cccff3355Sounds enabled:|r |ccc55ffaa' .. tostring(settings["SoundsEnabled"]) .. '|r')
end)

----------------------------------------------------
-- set name editbox
----------------------------------------------------
local setNameEditbox = CreateFrame("EditBox", ADDON_NAME .. "_setNameEditbox", settingsFrame, "InputBoxTemplate")
--setNameEditbox:SetScale(1.5)
setNameEditbox:SetPoint("TOPLEFT", ADDON_NAME .. "_enableSoundsCheckbox", "BOTTOMLEFT", 11, -10)
setNameEditbox:SetAutoFocus(false)
setNameEditbox:SetHeight(10)
setNameEditbox:SetWidth(100)
setNameEditbox:SetFont(THIN_FONT_NAME, 14)
setNameEditbox:SetText(settings["setNameForEquip"] or "")
setNameEditbox:SetTextColor(0.5, 0.5, 0.5)

----------------------------------------------------
-- Устанавливаем всплывающую подсказку
----------------------------------------------------
setNameEditbox.tooltipText = LANG == "ruRU" and
"Необходимо для экипировки оружий если выключена опция временного комплекта, либо включена но все слоты экипировки заняты." or
"Required for equipping weapons if the temporary equipment set option is disabled, or enabled but all equipment slots are occupied."

----------------------------------------------------
-- Функция, которая будет вызываться при наведении курсора на чекбокс
----------------------------------------------------
setNameEditbox:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
  GameTooltip:Show()
end)

----------------------------------------------------
-- Функция, которая будет вызываться при уходе курсора с чекбокса
----------------------------------------------------
setNameEditbox:SetScript("OnLeave", function(self)
  GameTooltip:Hide()
end)

local setNameEditboxLabel = settingsFrame:CreateFontString(nil, "ARTWORK")
setNameEditboxLabel:SetFont(THIN_FONT_NAME, 13, 'OUTLINE')
setNameEditboxLabel:SetPoint("LEFT", setNameEditbox, "RIGHT", 10, 0)
setNameEditboxLabel:SetJustifyH("LEFT")
setNameEditboxLabel:SetJustifyV("BOTTOM")
local setNameEditboxLabelText = "" ..
(LANG == "ruRU" and "Название комплекта необходимое для экипировки оружий" or "The name of the equipment required set for equip weapons") ..
""
setNameEditboxLabel:SetText(setNameEditboxLabelText)

local function setNameEditboxUpdateColor()
  if setNameEditbox:GetText() == "" then
    setNameEditboxLabel:SetText(setNameEditboxLabelText ..
    "\n" ..
    (LANG == "ruRU" and "|ccc777777Опция выключена: пустая строка|r" or "|ccc777777Option disabled: empty string|r"))
  elseif GetEquipmentSetInfoByName(setNameEditbox:GetText()) ~= nil then
    setNameEditbox:SetTextColor(0, 1, 0)
    setNameEditboxLabel:SetText(setNameEditboxLabelText ..
    "\n" .. (LANG == "ruRU" and "|ccc00ff00Комплект найден: всё ОК|r" or "|ccc00ff00Set found: all is OK!|r"))
  else
    setNameEditbox:SetTextColor(1, 0, 0)
    setNameEditboxLabel:SetText(setNameEditboxLabelText ..
    "\n" ..
    (LANG == "ruRU" and "|cccff0000Комплект не найден: не создан либо неправильное название!|r" or "|cccff0000Set not found: not created or incorrect name|r"))
  end
end

setNameEditbox:SetScript('OnEnterPressed', function()
  setNameEditbox:ClearFocus()
  local text = setNameEditbox:GetText()
  if #text:gsub('[\128-\191]', '') <= 16 and #text > 0 then
    settings["setNameForEquip"] = text
    testprint("|ccc55ffaa" ..
    ADDON_NAME ..
    ":|r |ccc55ffaa" ..
    (LANG == "ruRU" and "Название комплекта для экипировки оружия установлено: \"|ccc55ffaa" .. settings["setNameForEquip"] .. "\"" or "Set name for equip weapons: \"|ccc55ffaa" .. settings["setNameForEquip"] .. "\"") ..
    "|r")
    func_alert(
    "|ccc55ffaa" ..
    (LANG == "ruRU" and "Название комплекта для экипировки оружия установлено: \"|ccc55ffaa" .. settings["setNameForEquip"] .. "\"" or "Set name for equip weapons: \"|ccc55ffaa" .. settings["setNameForEquip"] .. "\"") ..
    "|r", { 1, 1, 1 }, nil, 10, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
    if GetEquipmentSetInfoByName(settings["setNameForEquip"]) == nil then
      testprint("|ccc55ffaa" ..
      ADDON_NAME ..
      ":|r |cccff0000" ..
      (LANG == "ruRU" and "В данный момент комплект экипировки с названием \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r\" |cccff0000НЕ найден, не забываем создать его!" or "At the moment, the set with the name \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r|cccff0000\" is NOT found, dont forget to create it!") ..
      "|r")
      func_alert(
      "|cccff0000" ..
      (LANG == "ruRU" and "В данный момент комплект экипировки с названием \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r|cccff0000\" НЕ найден, не забываем создать его!" or "At the moment, the set with the name \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r|cccff0000\" is NOT found, dont forget to create it!") ..
      "|r", { 1, 1, 1 }, nil, 10, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
      func_playSound(weapondrop1wav)
    else
      testprint("|ccc55ffaa" ..
      ADDON_NAME ..
      ":|r |ccc00ff00" ..
      (LANG == "ruRU" and "Комплект экипировки с названием \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r|cccff0000\" найден: всё ОК" or "Equipment set with the name \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r|ccc00ff00\" found, all is OK") ..
      "|r")
      func_alert(
      "|ccc00ff00" ..
      (LANG == "ruRU" and "Комплект экипировки с названием \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r|cccff0000\" найден: всё ОК" or "Equipment set with the name \"|ccc55ffaa" .. settings["setNameForEquip"] .. "|r|ccc00ff00\" found, all is OK") ..
      "|r", { 1, 1, 1 }, nil, 10, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
      func_playSound(gunpickup2wav)
    end
  else
    testprint("|ccc55ffaa" ..
    ADDON_NAME ..
    ":|r |cccff0000" ..
    (LANG == "ruRU" and "Название комплекта должно быть: длиной минимум 1 символ и не больше 16 символов!" or "The set name must be at least 1 character long and no more than 16 characters long!") ..
    "|r")
    func_alert(
    "|cccff0000" ..
    (LANG == "ruRU" and "Название комплекта должно быть: длиной минимум 1 символ и не больше 16 символов!" or "The set name must be at least 1 character long and no more than 16 characters long!") ..
    "|r", { 1, 1, 1 }, nil, 10, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
    func_playSound(weapondrop1wav)
    setNameEditbox:SetText("")
    settings["setNameForEquip"] = ""
  end
  setNameEditboxUpdateColor()
end)

setNameEditbox:SetScript('OnEscapePressed', function()
  setNameEditbox:ClearFocus()
  setNameEditbox:SetText(settings["setNameForEquip"])
  setNameEditboxUpdateColor()
end)

setNameEditbox:SetScript('OnEditFocusGained', function()
  --setNameEditbox:SetText(settings["setNameForEquip"] or "")
  setNameEditbox:SetTextColor(1, 1, 1)
  setNameEditbox:HighlightText()
end)

setNameEditbox:SetScript('OnEditFocusLost', function()
  setNameEditboxUpdateColor()
end)

setNameEditbox:SetScript('OnShow', function()
  setNameEditboxUpdateColor()
end)

-- setNameEditbox:SetScript('OnUpdate', function()
-- if not setNameEditbox:HasFocus() and setNameEditbox:IsVisible() then
-- print('12345 OnUpdate')
-- setNameEditbox:SetText(settings["setNameForEquip"] or "")
-- end
-- end)

----------------------------------------------------
-- useAlwaysTmpSetForEquip
----------------------------------------------------
local useAlwaysTmpSetForEquipCheckbox = CreateFrame("CheckButton", ADDON_NAME .. "_alwaysUseTmpSetForEquipCheckbox",
  settingsFrame, "UICheckButtonTemplate")
useAlwaysTmpSetForEquipCheckbox:SetScale(1.5)
useAlwaysTmpSetForEquipCheckbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 0, -185)

----------------------------------------------------
-- Устанавливаем всплывающую подсказку
----------------------------------------------------
useAlwaysTmpSetForEquipCheckbox.tooltipText = LANG == "ruRU" and
"Временный комплект будет автоматически создаваться в бою на основании того, что надето на персонажа и удаляться после использования.\nЕсли не будет свободных слотов для создания временного комплекта: будет использоваться опция выше, с названием комплекта. При правильных условиях: опция выше игнорируется." or
"The temporary set will be automatically created during combat and removed after use.\nIf there are no free slots to create a temporary set, the option with set name will be used.\nUnder the right conditions, the above option with set name is ignored."

----------------------------------------------------
-- Функция, которая будет вызываться при наведении курсора на чекбокс
----------------------------------------------------
useAlwaysTmpSetForEquipCheckbox:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
  GameTooltip:Show()
end)

----------------------------------------------------
-- Функция, которая будет вызываться при уходе курсора с чекбокса
----------------------------------------------------
useAlwaysTmpSetForEquipCheckbox:SetScript("OnLeave", function(self)
  GameTooltip:Hide()
end)

local useAlwaysTmpSetForEquipCheckboxLabel = settingsFrame:CreateFontString(nil, "ARTWORK")
useAlwaysTmpSetForEquipCheckboxLabel:SetFont(THIN_FONT_NAME, 12, 'OUTLINE')
useAlwaysTmpSetForEquipCheckboxLabel:SetPoint("LEFT", useAlwaysTmpSetForEquipCheckbox, "RIGHT", 5, 0)
useAlwaysTmpSetForEquipCheckboxLabel:SetJustifyH("LEFT")
useAlwaysTmpSetForEquipCheckboxLabel:SetJustifyV("BOTTOM")
useAlwaysTmpSetForEquipCheckboxLabel:SetText("" ..
(LANG == "ruRU" and "Использовать временный комплект экипировки для запоминания и экипировки оружия.\nЕсли впадлу прописывать название комплекта в опции выше, либо если в бою будут использоваться оружия отличные от введёного в опции выше комплекта.\nДля работы необходимо: иметь 1 свободный слот комплекта экипировки." or "Use a temporary equipment set to remember and equip weapons.\nConvenient when it's inconvenient to specify the set name above.\nTo function, you need to: have 1 free slot of equipment sets.") ..
"")

useAlwaysTmpSetForEquipCheckbox:SetScript("OnClick", function(self)
  if self:GetChecked() then
    settings["alwaysUseTmpSetForEquip"] = true
    savedSlotAndWeaponLinkInfo = {}
    func_playSound(gunpickup2wav)
  else
    settings["alwaysUseTmpSetForEquip"] = false
    func_playSound(weapondrop1wav)
  end
  testprint("|ccc55ffaa" ..
  ADDON_NAME ..
  ":|r |cccff3355" ..
  (LANG == "ruRU" and "Всегда использовать временный комплект экипировки для одевания оружий:|r |ccc55ffaa" .. tostring(settings["alwaysUseTmpSetForEquip"]) .. "" or "|cccff3355Always use temporary equipment set for equip weapons:|r |ccc55ffaa" .. tostring(settings["alwaysUseTmpSetForEquip"]) .. "") ..
  "|r")
  func_alert(
  "|cccff0000" ..
  (LANG == "ruRU" and "Всегда использовать временный комплект экипировки для одевания оружий:|r |ccc55ffaa" .. tostring(settings["alwaysUseTmpSetForEquip"]) .. "" or "|cccff3355Always use temporary equipment set for equip weapons:|r |ccc55ffaa" .. tostring(settings["alwaysUseTmpSetForEquip"]) .. "") ..
  "|r", { 1, 1, 1 }, nil, 10, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
end)

----------------------------------------------------
-- dbg messages in separate chat windowName
----------------------------------------------------
local debugMessagesInSeparateChatWindowCheckbox = CreateFrame("CheckButton",
  ADDON_NAME .. "_debugMessagesInSeparateChatWindowCheckbox", settingsFrame, "UICheckButtonTemplate")
debugMessagesInSeparateChatWindowCheckbox:SetScale(1.5)
debugMessagesInSeparateChatWindowCheckbox:SetPoint("TOPLEFT", settingsTitleText, "BOTTOMLEFT", 0, -220)

local debugMessagesCheckboxLabel = settingsFrame:CreateFontString(nil, "ARTWORK")
debugMessagesCheckboxLabel:SetFont(THIN_FONT_NAME, 14, 'OUTLINE')
debugMessagesCheckboxLabel:SetPoint("LEFT", debugMessagesInSeparateChatWindowCheckbox, "RIGHT", 5, 0)
debugMessagesCheckboxLabel:SetJustifyH("LEFT")
debugMessagesCheckboxLabel:SetJustifyV("BOTTOM")
debugMessagesCheckboxLabel:SetText("" ..
(LANG == "ruRU" and "Показывать сообщений для отладки в отдельной чат вкладке" or "Debug messages are shown in separate chat window") ..
"")

debugMessagesInSeparateChatWindowCheckbox:SetScript("OnClick", function(self)
  if self:GetChecked() then
    settings["debugMessagesInSeparateChatWindow"] = true
    func_playSound(gunpickup2wav)
    local frame, found, docked = getChatFrameByName("" .. ADDON_NAME .. "_dbg")
    -- for i = 1, NUM_CHAT_WINDOWS do
    -- local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
    -- if (name == ""..ADDON_NAME.."_dbg") then
    -- found = true
    -- frame = _G["ChatFrame" .. i]
    -- break
    -- end
    -- end
    if not found or (frame and not docked) then
      print("|ccc55ffaa" ..
      ADDON_NAME ..
      ":|r |cccff3355" ..
      (LANG == "ruRU" and "Будет создана вкладка чата с названием |ccc55ffaa\"" .. ADDON_NAME .. "_dbg\"|r|cccff3355, сообщения связанные с отладкой будут выводиться в ней." or "A tab with the name |ccc55ffaa\"" .. ADDON_NAME .. "_dbg\"|r |cccff3355will be created. Debug messages will be displayed in it.") ..
      "|r")
      func_alert(
      (LANG == "ruRU" and "|cccff3355Будет создана вкладка чата с названием |ccc55ffaa\"" .. ADDON_NAME .. "_dbg\"|r|cccff3355, сообщения связанные с отладкой будут выводиться в ней.|r" or "|cccff3355A tab with the name |ccc55ffaa\"" .. ADDON_NAME .. "_dbg\"|r |cccff3355will be created. Debug messages will be displayed in it.|r"),
        { 1, 1, 1 }, nil, 15, { 1, 1, 1 }, 1, false, false, nil, nil, nil, 15)
    end
  else
    settings["debugMessagesInSeparateChatWindow"] = false
    func_playSound(weapondrop1wav)
  end
  testprint('|ccc55ffaa' ..
  ADDON_NAME ..
  ':|r |cccff3355Debug messages in separate chat window:|r |ccc55ffaa' ..
  tostring(settings["debugMessagesInSeparateChatWindow"]) .. '|r')
end)

----------------------------------------------------
-- регаем настройки в дефолтном ЮИ
----------------------------------------------------
InterfaceOptions_AddCategory(settingsScrollFrame)
