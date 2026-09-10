window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.type === "open") {
        document.getElementById('scoreboard-wrapper').style.display = 'flex';
        document.getElementById('online-count').innerText = data.total;

        let rowsHTML = '';
        data.players.forEach(player => {
            let kdClass = parseFloat(player.kd) >= 1.0 ? 'kd-positive' : '';
            rowsHTML += `
                <tr>
                    <td>#${player.id}</td>
                    <td>${player.name}</td>
                    <td>${player.gang}</td>
                    <td style="color: #2ecc71;">${player.kills}</td>
                    <td style="color: #e74c3c;">${player.deaths}</td>
                    <td class="${kdClass}">${player.kd}</td>
                    <!-- [MODIFICADO] Adicionado um ID único para cada ping usando o ID do player -->
                    <td id="ping-${player.id}">${player.ping}ms</td>
                </tr>
            `;
        });
        document.getElementById('player-rows').innerHTML = rowsHTML;

    } else if (data.type === "close") {
        document.getElementById('scoreboard-wrapper').style.display = 'none';
    } 
    
    // [NOVO] Adicionado o receptor do loop de atualização de pings em tempo real
    else if (data.type === "updatePings") {
        // Percorre cada ID e Ping que o servidor enviou
        for (const [id, ping] of Object.entries(data.pings)) {
            let pingElement = document.getElementById(`ping-${id}`);
            if (pingElement) {
                pingElement.innerText = ping + "ms";
            }
        }
    }
});
