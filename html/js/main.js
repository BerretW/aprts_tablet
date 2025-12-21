// html/js/main.js

// 1. Definujeme funkci pro zprávy mimo ready block, aby se neduplikovala
const onMessage = (event) => {
  let data = event.data;

  // Speciální pojistka pro akce, které komunikují se serverem
  // Pokud už jedna akce probíhá, ignorujeme další (v rámci milisekund)
  if (data.action === "appAction" || data.action === "bootSystem") {
    if (window.isProcessingMessage) return;
    window.isProcessingMessage = true;
    setTimeout(() => { window.isProcessingMessage = false; }, 100);
  }

  switch (data.action) {
    case "bootSystem":
      AppState.isOpen = true;
      System.boot(data);
      break;

    case "updateInfobar":
      UI.updateStatusBar(
        data.time,
        data.wifi,
        data.wifiName,
        data.wifiLevel,
        data.battery,
        data.isCharging,
            data.wifiLocked // Nový parametr
      );
      AppState.hasInternet = data.wifi;
      AppState.batteryHistory.push(data.battery);
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
      if (System.API && System.API[data.method]) {
        System.API[data.method](data.payload);
      }
      break;

    case "setAppBadge":
      let $icon = $(`.app-icon[data-app="${data.appName}"]`);
      let $badge = $icon.find(".notification-badge");
      if (data.count > 0) {
        if ($badge.length === 0) {
          $icon.append(`<div class="notification-badge">${data.count}</div>`);
        } else {
          $badge.text(data.count);
        }
        $icon.addClass("animate__animated animate__pulse");
      } else {
        $badge.remove();
      }
      break;
  }
};

// 2. Registrace listeneru (S odebráním starého, pokud existuje - řeší duplicitu při restartu)
window.removeEventListener("message", onMessage);
window.addEventListener("message", onMessage);

// 3. Ostatní DOM události
$(document).ready(function () {
  
  // Kliknutí na ikonu - vyčištění starých eventů před přidáním
  $(document).off("click", ".app-icon").on("click", ".app-icon", function () {
    let appName = $(this).data("app");
    System.openApp(appName);
  });

  // Tlačítko Home
  $(".home-button").off("click").on("click", function () {
    UI.showAppFrame(false);
  });

  // Klikání na tlačítka (zvuk)
  $(document).off("click", "button, .nav-item").on("click", "button, .nav-item", function () {
    System.playSound("click");
  });

  // ESC Zavírání
  document.onkeyup = function (data) {
    if (data.which == 27) {
      AppState.isOpen = false;
      UI.toggleTablet(false);
      $.post("https://aprts_tablet/closeTablet", JSON.stringify({}));
    }
  };

  // FORMULÁŘE - KONEČNÁ OPRAVA
  $(document).off("submit", ".app-form").on("submit", ".app-form", function (e) {
    e.preventDefault();
    e.stopImmediatePropagation(); // Zastaví šíření k dalším případným handlerům

    let $form = $(this);
    if ($form.data('loading')) return false;
    
    $form.data('loading', true);

    let action = $form.data("action");
    let formData = {};
    $form.find("input, textarea, select").each(function () {
      formData[this.name] = $(this).val();
    });

    $.post(
      "https://aprts_tablet/appAction",
      JSON.stringify({
        appId: AppState.activeApp,
        action: action,
        data: formData,
      }),
      function() {
         // Callback po úspěšném odeslání - uvolníme form až po odpovědi serveru
         setTimeout(() => { $form.data('loading', false); }, 500);
      }
    );
    
    return false;
  });
});