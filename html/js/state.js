// Globální stav aplikace
const AppState = {
    allRegisteredApps: {}, 
    installedApps: [],     
    currentConfig: {},     
    activeApp: null,       
    isOpen: false,
    hasInternet: false,
    batteryHistory: [{ time: "INIT", value: 100 }], // Defaultní hodnoty, aby graf nebyl prázdný
    // Nastavení uživatele (defaultní hodnoty)
    userSettings: {
        showWifiPct: false, // Defaultně vypnuto
        darkMode: true
    }
};