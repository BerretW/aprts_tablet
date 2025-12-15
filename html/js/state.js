// Globální stav aplikace
const AppState = {
    allRegisteredApps: {}, // Všechny definované v Lua
    installedApps: [],     // Ty, které má aktuální tablet
    currentConfig: {},     // Config aktuálního tabletu (OS, Storage)
    activeApp: null,       // Která appka je otevřená
    isOpen: false
};