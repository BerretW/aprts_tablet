System.registerModule('settings', {
    label: 'Nastavení',
    icon: 'fas fa-cog',
    color: '#636e72',
    
    render: function() {
        let storageUsed = (AppState.installedApps.length * 150).toFixed(0);
        let storageTotal = AppState.currentConfig.storage;
        let percent = Math.min((storageUsed / storageTotal) * 100, 100);

        $("#app-content").html(`
            <div style="padding: 40px; height: 100%; box-sizing: border-box; overflow-y: auto;">
                <h1 style="margin-top: 0;">Nastavení</h1>
                
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

                <!-- DIAGNOSTIKA (Graf) -->
                <div style="margin-top: 30px;">
                    <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">Diagnostika</h3>
                    <div style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.05);">
                        <div style="height: 200px; width: 100%;">
                            <canvas id="settingsCpuChart"></canvas>
                        </div>
                    </div>
                </div>

                <!-- SYSTÉM -->
                <div style="margin-top: 30px;">
                    <h3 style="opacity: 0.7; font-size: 14px; text-transform: uppercase; margin-bottom: 10px;">O systému</h3>
                     <div style="background: rgba(255,255,255,0.05); border-radius: 12px; overflow: hidden;">
                        <div style="padding: 15px; border-bottom: 1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between;">
                            <span>Verze OS</span>
                            <span style="opacity: 0.5;">v2.1 (Beta)</span>
                        </div>
                        <div style="padding: 15px; display:flex; justify-content:space-between;">
                            <span>Serial</span>
                            <span style="opacity: 0.5; font-family: monospace;">${AppState.currentData.serial || "N/A"}</span>
                        </div>
                     </div>
                </div>
                
                <!-- Tlačítko (volá funkci definovanou níže) -->
                <button onclick="System.Apps.settings.factoryReset()" style="margin-top:50px; margin-bottom: 30px; width: 100%; background:rgba(214, 48, 49, 0.2); border:1px solid #d63031; color:#ff7675; padding:12px; border-radius:8px; cursor:pointer; font-weight: bold;">
                    Resetovat tablet
                </button>
            </div>
        `);

        // Render Grafu
        System.API.renderChart({
            targetId: 'settingsCpuChart',
            config: {
                type: 'line',
                data: {
                    labels: ['10s', '8s', '6s', '4s', '2s', 'Teď'],
                    datasets: [{
                        label: 'Využití CPU (%)',
                        data: [12, 19, 15, 25, 22, 30],
                        borderColor: '#00b894',
                        backgroundColor: 'rgba(0, 184, 148, 0.2)',
                        borderWidth: 2,
                        tension: 0.4,
                        fill: true,
                        pointRadius: 4
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { display: false } },
                    scales: {
                        x: { display: false },
                        y: { beginAtZero: true, max: 100, grid: { color: 'rgba(255,255,255,0.05)' } }
                    }
                }
            }
        });
    },

    // Interní funkce modulu (volaná přes System.Apps.settings.factoryReset())
    factoryReset: function() {
        System.API.showNotification({
            title: 'Chyba',
            text: 'Tato funkce je dočasně zablokována administrátorem.',
            icon: 'error'
        });
    }
});