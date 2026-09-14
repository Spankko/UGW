window.addEventListener('message', function(event) {
    const item = event.data;

    if (item.action === "openPanel") {
        const panel = document.getElementById('gang-panel');
        const noGang = document.getElementById('no-gang-section');
        const hasGang = document.getElementById('has-gang-section');

        if (panel) panel.style.display = 'block';

        if (item.hasGang) {
            if (noGang) noGang.style.display = 'none';
            if (hasGang) hasGang.style.display = 'block';
            if (item.gangData) updateDashboard(item.gangData);
        } else {
            if (noGang) noGang.style.display = 'block';
            if (hasGang) hasGang.style.display = 'none';
        }
    }
});

function updateDashboard(data) {
    if (!data) return;

    document.getElementById('gang-label-display').innerText = data.label || data.name || "N/A";
    document.getElementById('gang-level-display').innerText = "LVL " + (data.level || 1);
    document.getElementById('gang-bank-balance').innerText = "$" + (data.money || 0).toLocaleString();
    document.getElementById('gang-base-id').innerText = data.baseId && data.baseId !== "Nenhuma" ? "Base #" + data.baseId : "Sem Base";
    document.getElementById('gang-turfs-count').innerText = (data.turfs || 0) + " Dominados";
    document.getElementById('gang-vilas-gz').innerText = (data.vilas || 0) + " Vilas / " + (data.gzs || 0) + " GZs";

    document.getElementById('total-kills').innerText = data.kills || 0;
    document.getElementById('total-deaths').innerText = data.deaths || 0;
    
    let kills = data.kills || 0;
    let deaths = data.deaths || 0;
    let kd = deaths > 0 ? (kills / deaths).toFixed(2) : kills.toFixed(2);
    document.getElementById('kd-ratio').innerText = kd;

    const tbody = document.getElementById('members-list');
    tbody.innerHTML = '';

    if (data.members && data.members.length > 0) {
        data.members.forEach(member => {
            let row = document.createElement('tr');
            let statusHtml = member.isOnline ? '<span class="status-online">Online</span>' : '<span class="status-offline">Offline</span>';
            
            let actionsHtml = '';
            if (data.playerGrade >= 3) {
                actionsHtml += `<button class="action-btn-sm" onclick="promoteMember('${member.citizenid}')" title="Promover"><i class="fa-solid fa-arrow-up"></i></button>`;
                actionsHtml += `<button class="action-btn-sm" onclick="demoteMember('${member.citizenid}')" title="Rebaixar"><i class="fa-solid fa-arrow-down"></i></button>`;
                actionsHtml += `<button class="action-btn-sm" onclick="kickMember('${member.citizenid}')" title="Expulsar"><i class="fa-solid fa-user-xmark"></i></button>`;
            } else {
                actionsHtml = '<span style="color: #555;">Sem Permissão</span>';
            }

            row.innerHTML = `
                <td>${member.name}</td>
                <td>${member.gradeName}</td>
                <td>${statusHtml}</td>
                <td>${actionsHtml}</td>
            `;
            tbody.appendChild(row);
        });
    } else {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">Nenhum membro encontrado.</td></tr>';
    }
}

function closePanel() {
    const panel = document.getElementById('gang-panel');
    if (panel) {
        panel.style.display = 'none';
    }
    fetch(`https://${GetParentResourceName()}/closePanel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function submitCreateGang() {
    const name = document.getElementById('create-gang-name').value;
    const label = document.getElementById('create-gang-label').value;

    if (!name || !label) {
        return;
    }

    fetch(`https://${GetParentResourceName()}/createGang`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name, label: label })
    });

    document.getElementById('create-gang-name').value = '';
    document.getElementById('create-gang-label').value = '';
}

function submitDeposit() {
    const amount = document.getElementById('bank-amount-input').value;
    if (!amount) return;
    fetch(`https://${GetParentResourceName()}/depositBank`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: amount })
    });
    document.getElementById('bank-amount-input').value = '';
}

function submitWithdraw() {
    const amount = document.getElementById('bank-amount-input').value;
    if (!amount) return;
    fetch(`https://${GetParentResourceName()}/withdrawBank`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: amount })
    });
    document.getElementById('bank-amount-input').value = '';
}

function submitInvite() {
    const targetId = document.getElementById('invite-id-input').value;
    if (!targetId) return;
    fetch(`https://${GetParentResourceName()}/inviteMember`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ targetId: targetId })
    });
    document.getElementById('invite-id-input').value = '';
}

function promoteMember(citizenid) {
    fetch(`https://${GetParentResourceName()}/promoteMember`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid: citizenid })
    });
}

function demoteMember(citizenid) {
    fetch(`https://${GetParentResourceName()}/demoteMember`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid: citizenid })
    });
}

function kickMember(citizenid) {
    fetch(`https://${GetParentResourceName()}/kickMember`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid: citizenid })
    });
}

document.onkeyup = function(data) {
    if (data.which === 27) {
        closePanel();
    }
};