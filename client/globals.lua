-- ====================================================================
-- GLOBAL STATE VARIABLES
-- ====================================================================

isTabletOpen = false
tabletProp = nil
currentSerial = nil
currentModel = nil
currentBattery = 100
lastHistoryUpdate = 0
batteryHistory = {} 

-- Wi-Fi
hasInternet = false
currentWifiName = "Žádný signál"
currentWifiLevel = 0

-- Animace
tabletModel = "prop_cs_tablet"
tabletDict = "amb@world_human_seat_wall_tablet@female@base"
tabletAnim = "base"

RegisteredApps = {}

-- Fallback Config (pokud by se nenačetl config.lua)
if not Config then Config = {} end