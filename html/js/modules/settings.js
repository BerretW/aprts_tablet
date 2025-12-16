System.registerModule('settings', {
    label: 'Nastavení',
    icon: 'fas fa-cog',
    color: '#636e72',
    
    render: function() {
        const isChecked = (AppState.userSettings && AppState.userSettings.showWifiPct) ? 'checked' : '';

        let storageUsed = (AppState.installedApps.length * 150).toFixed(0);
        let storageTotal = AppState.currentConfig.storage || 1024;
        let percent = Math.min((storageUsed / storageTotal) * 100, 100);

        $("#app-content").html(`
            <div style="padding: 40px; height: 100%; box-sizing: border-box; overflow-y: auto;">
                <h1 style="margin-top: 0;">Nastavení</h1>
                
                <!-- PŘEPÍNAČE -->
                <div style="margin-top: 20px; background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                    <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; align-items:center;">
                        <span>Zobrazit procenta Wi-Fi</span>
                        <label class="switch">
                          <input type="checkbox" id="toggle-wifi-pct" ${isChecked} onchange="System.Apps.settings.toggleWifiPct(this)">
                          <span class="slider round"></span>
                        </label>
                    </div>
                </div>

                <!-- ÚLOŽIŠTĚ -->
                <div style="margin-top: 30px;">
                    <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Úložiště</h3>
                    <div style="background: rgba(255,255,255,0.05); padding: 20px; border-radius: 12px;">
                        <div style="display:flex; justify-content:space-between; margin-bottom: 10px;">
                            <span>Využito</span>
                            <span style="opacity: 0.7;">${storageUsed} MB / ${storageTotal} MB</span>
                        </div>
                        <div style="background: rgba(255,255,255,0.1); height: 8px; border-radius: 4px; overflow:hidden;">
                            <div style="width:${percent}%; background: ${percent > 80 ? "#d63031" : "#0984e3"}; height:100%; transition: width 1s;"></div>
                        </div>
                    </div>
                </div>

                <!-- GRAF BATERIE (Vráceno zpět) -->
                <div style="margin-top: 30px;">
                    <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Využití baterie</h3>
                    <div style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.05);">
                        <div style="height: 150px; width: 100%;">
                            <canvas id="settingsBatteryChart"></canvas>
                        </div>
                    </div>
                </div>

                <!-- O SYSTÉMU -->
                <div style="margin-top: 30px; margin-bottom: 40px;">
                    <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">O systému</h3>
                     <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                        <div style="padding: 15px; display:flex; justify-content:space-between;">
                            <span>Serial</span>
                            <span style="opacity: 0.5; font-family: monospace;">${AppState.currentData.serial || "N/A"}</span>
                        </div>
                     </div>
                </div>
            </div>
        `);

 const chartLabels = AppState.batteryHistory.map(item => item.time);
    const chartData = AppState.batteryHistory.map(item => item.value);

    // Vykreslení grafu
    System.API.renderChart({
        targetId: 'settingsBatteryChart',
        config: {
            type: 'line',
            data: {
                labels: chartLabels, // Časy na ose X
                datasets: [{
                    label: 'Úroveň baterie (%)',
                    data: chartData,     // Hodnoty na ose Y
                    borderColor: '#00b894',
                    backgroundColor: 'rgba(0, 184, 148, 0.2)',
                    borderWidth: 2,
                    tension: 0.3,
                    fill: true,
                    pointRadius: 2,       // Menší tečky, protože bodů bude hodně
                    pointHoverRadius: 5
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { 
                    legend: { display: false },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        callbacks: {
                            label: function(context) {
                                return context.parsed.y + ' %';
                            }
                        }
                    }
                },
                scales: {
                    x: { 
                        display: true, // Zobrazíme osu X (čas)
                        ticks: {
                            color: 'rgba(255,255,255,0.3)',
                            font: { size: 10 },
                            maxTicksLimit: 6 // Nechceme tam vypsat všech 48 časů, stačí jich pár
                        },
                        grid: { display: false }
                    },
                    y: { 
                        beginAtZero: true, 
                        max: 100, 
                        grid: { color: 'rgba(255,255,255,0.05)' } 
                    }
                },
                animation: false
            }
        }
    });
    },

    toggleWifiPct: function(checkbox) {
        if (!AppState.userSettings) AppState.userSettings = {};
        AppState.userSettings.showWifiPct = checkbox.checked;
        
        let netNameEl = $('#network-name');
        let currentText = netNameEl.text().split('(')[0].trim();
        // Malý hack pro okamžitý refresh bez čekání na server tick
        if(checkbox.checked) netNameEl.text(currentText + " (...)");
        else netNameEl.text(currentText);
    }
});