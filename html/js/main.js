$(document).ready(function() {
    
    // NUI Listeners (Lua -> JS)
    window.addEventListener('message', function(event) {
        let data = event.data;

        switch(data.action) {
            case 'bootSystem':
                AppState.isOpen = true;
                System.boot(data);
                break;
            
            case 'close':
                AppState.isOpen = false;
                UI.toggleTablet(false);
                $.post('https://aprts_tablet/closeTablet', JSON.stringify({}));
                break;

            case 'registerApp':
                AppState.allRegisteredApps[data.appName] = data;
                // Systémové appky auto-install
                if (['settings', 'store', 'calendar'].includes(data.appName)) {
                    if (!AppState.installedApps.includes(data.appName)) {
                        AppState.installedApps.push(data.appName);
                    }
                }
                break;

            case 'setAppContent':
                $('#app-content').html(data.html);
                break;
        }
    });

    // === DOM Events ===
    
    // Kliknutí na ikonu (delegovaný event pro dynamické prvky)
    $(document).on('click', '.app-icon', function() {
        let appName = $(this).data('app');
        System.openApp(appName);
    });

    // Tlačítko Home
    $('.home-button').click(function() {
        UI.showAppFrame(false);
    });

    // Zavření přes ESC
    document.onkeyup = function (data) {
        if (data.which == 27) { // ESC
            AppState.isOpen = false;
            UI.toggleTablet(false);
            $.post('https://aprts_tablet/closeTablet', JSON.stringify({}));
        }
    };

    // Odesílání formulářů z aplikací (Bridge)
    $(document).on('submit', '.app-form', function(e) {
        e.preventDefault();
        if (!AppState.activeApp) return;

        let action = $(this).data('action');
        let formData = {};
        $(this).find('input, textarea, select').each(function() {
            formData[this.name] = $(this).val();
        });

        $.post('https://aprts_tablet/appAction', JSON.stringify({
            appId: AppState.activeApp,
            action: action,
            data: formData
        }));
    });
});