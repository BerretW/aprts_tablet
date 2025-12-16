// NUI Listeners (Lua -> JS)
$(document).ready(function () {
  window.addEventListener("message", function (event) {
    let data = event.data;

    switch (data.action) {
      case "bootSystem":
        AppState.isOpen = true;
        System.boot(data);
        break;

      // NOVÉ: Aktualizace času a Wi-Fi
      case "updateInfobar":
        UI.updateStatusBar(
          data.time,
          data.wifi,
          data.wifiName,
          data.wifiLevel,
          data.battery,
          data.isCharging // <--- NOVÉ
        );
        AppState.hasInternet = data.wifi;
                AppState.batteryHistory.push(data.battery);
        // Pokud je v historii více než 10 záznamů, smažeme ten nejstarší (posuvný graf)
        if (AppState.batteryHistory.length > 10) {
            AppState.batteryHistory.shift();
        }
        break;

      case "close":
        AppState.isOpen = false;
        UI.toggleTablet(false);
        $.post("https://aprts_tablet/closeTablet", JSON.stringify({}));
        break;

      case "registerApp":
        AppState.allRegisteredApps[data.appName] = data;
        // Systémové appky auto-install
        if (["settings", "store", "calendar"].includes(data.appName)) {
          if (!AppState.installedApps.includes(data.appName)) {
            AppState.installedApps.push(data.appName);
          }
        }
        break;

      case "setAppContent":
        $("#app-content").html(data.html);
        break;
      case "plugin_api":
        // data vypadá takto: { action: 'plugin_api', method: 'renderChart', payload: {...} }

        if (System.API && System.API[data.method]) {
          System.API[data.method](data.payload);
        } else {
          console.error(`[Tablet API] Neznámá metoda: ${data.method}`);
        }
        break;
    }
  });

  // === DOM Events ===

  // Kliknutí na ikonu (delegovaný event pro dynamické prvky)
  $(document).on("click", ".app-icon", function () {
    let appName = $(this).data("app");
    System.openApp(appName);
  });

  // Tlačítko Home
  $(".home-button").click(function () {
    UI.showAppFrame(false);
  });

  // Zavření přes ESC
  document.onkeyup = function (data) {
    if (data.which == 27) {
      // ESC
      AppState.isOpen = false;
      UI.toggleTablet(false);
      $.post("https://aprts_tablet/closeTablet", JSON.stringify({}));
    }
  };

  // Odesílání formulářů z aplikací (Bridge)
  $(document).on("submit", ".app-form", function (e) {
    e.preventDefault();
    if (!AppState.activeApp) return;

    let action = $(this).data("action");
    let formData = {};
    $(this)
      .find("input, textarea, select")
      .each(function () {
        formData[this.name] = $(this).val();
      });

    $.post(
      "https://aprts_tablet/appAction",
      JSON.stringify({
        appId: AppState.activeApp,
        action: action,
        data: formData,
      })
    );
  });
});
