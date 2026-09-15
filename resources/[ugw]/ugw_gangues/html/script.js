let currentGangType = "player";
let myPlayerGrade = 0;
let inviteSenderSource = null;
let inviteSenderGangName = null;

// Função auxiliar unificada para envio seguro e padronizado ao Client.lua
function sendNuiData(eventName, dataObject) {
    fetch(`https://${window.GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(dataObject || {})
    }).catch(err => console.log('Erro na chamada NUI:', err));
}

window.addEventListener('message', function(event) {
    const item = event.data;

    if (item.action === "openCreation") {
        document.getElementById('creation-cost').innerText = "$" + item.cost.toLocaleString();
        document.getElementById('creation-screen').classList.remove('hidden');
    } 
    
   else if (item.action === "openDashboard") {
        currentGangType = item.data.type;
        myPlayerGrade = item.data.myGrade;

        document.getElementById('gang-title').innerText = item.data.label;
        
        // CORREÇÃO: Resgate seguro do link do banco de dados (aceita minúsculo ou maiúsculo)
        let rawLogo = item.data.logoUrl || item.data.logo_url || "";
        
        // Se houver um link gravado no banco, aplica na tag. Se não, limpa o atributo src
        if (rawLogo && rawLogo.trim() !== "") {
            // O timestamp impede que o cache local do Chromium mantenha a tela travada em branco
            document.getElementById('gang-logo').src = rawLogo + "?v=" + Date.now();
        } else {
            // Imagem invisível/transparente padrão em formato Base64 para não quebrar o motor do FiveM
            document.getElementById('gang-logo').src = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
        }
        
        const badge = document.getElementById('gang-type-badge');
        badge.innerText = item.data.type.toUpperCase();
        if (item.data.type === "fixed") {
            badge.style.background = "#0288d1"; 
        } else {
            badge.style.background = "#c62828"; 
        }

        document.getElementById('stat-funds').innerText = "$" + item.data.funds.toLocaleString();
        document.getElementById('vault-current-funds').innerText = "$" + item.data.funds.toLocaleString();
        document.getElementById('stat-online').innerText = item.data.membersOnlineCount + "/" + item.data.membersList.length;

        if (myPlayerGrade >= 3) {
            document.querySelectorAll('.id-leader-only').forEach(el => el.classList.remove('hidden'));
        } else {
            document.querySelectorAll('.id-leader-only').forEach(el => el.classList.add('hidden'));
        }

        if (myPlayerGrade >= 2) {
            document.querySelectorAll('.id-invite-only, .id-withdraw-only, .id-promote-only').forEach(el => el.classList.remove('hidden'));
        } else {
            document.querySelectorAll('.id-invite-only, .id-withdraw-only, .id-promote-only').forEach(el => el.classList.add('hidden'));
        }

        const tbody = document.getElementById('members-list-tbody');
        tbody.innerHTML = "";
        
        item.data.membersList.forEach(member => {
            const tr = document.createElement('tr');
            
            let actionButtons = "";
            if (myPlayerGrade >= 2 && myPlayerGrade > member.grade) {
                actionButtons = `
                    <button class="action-btn up" onclick="memberAction('promote', '${member.sourceId}', '${member.citizenid}')" title="Promover"><i class="fas fa-chevron-up"></i></button>
                    <button class="action-btn down" onclick="memberAction('demote', '${member.sourceId}', '${member.citizenid}')" title="Rebaixar"><i class="fas fa-chevron-down"></i></button>
                    <button class="action-btn kick" onclick="memberAction('kick', '${member.sourceId}', '${member.citizenid}')" title="Expulsar"><i class="fas fa-user-times"></i></button>
                `;
            }

            const statusClass = member.isOnline ? "status-online" : "status-offline";
            const statusLabel = member.isOnline ? "Online" : "Offline";

            tr.innerHTML = `
                <td>${member.name}</td>
                <td>${member.gradeLabel}</td>
                <td class="${statusClass}">${statusLabel}</td>
                <td class="id-promote-only">${actionButtons}</td>
            `;
            tbody.appendChild(tr);
        });

        const select = document.getElementById('invite-candidates-select');
        select.innerHTML = '<option value="">Selecione um jogador...</option>';
        item.data.candidates.forEach(cand => {
            const opt = document.createElement('option');
            opt.value = cand.id;
            opt.innerText = cand.name;
            select.appendChild(opt);
        });

        document.getElementById('dashboard-screen').classList.remove('hidden');
    }
    
    else if (item.action === "openAdmin") {
        const tbody = document.getElementById('admin-gangs-tbody');
        tbody.innerHTML = "";

        item.data.forEach(gang => {
            const tr = document.createElement('tr');
            const timeLabel = gang.type === 'fixed' ? 'Imutável' : gang.hoursInactive + 'h / ' + gang.maxLimit + 'h';
            
            tr.innerHTML = `
                <td><strong>${gang.gang_name}</strong></td>
                <td>${gang.label}</td>
                <td>${gang.type.toUpperCase()}</td>
                <td>$${gang.funds.toLocaleString()}</td>
                <td>${gang.onlineMembers} online</td>
                <td>${timeLabel}</td>
                <td>
                    <button class="btn btn-green" style="width:auto; padding:5px 10px; font-size:12px; display:inline-block; margin-right:6px;" onclick="adminAction('modifyFunds', '${gang.gang_name}')"><i class="fas fa-dollar-sign"></i> Injetar $10k</button>
                    ${gang.type === 'player' ? `<button class="btn btn-red" style="width:auto; padding:5px 10px; font-size:12px; display:inline-block;" onclick="adminAction('forceWipe', '${gang.gang_name}')"><i class="fas fa-trash-alt"></i> Force Wipe</button>` : ''}
                </td>
            `;
            tbody.appendChild(tr);
        });

        document.getElementById('admin-screen').classList.remove('hidden');
    }
    
    else if (item.action === "receiveInvite") {
        inviteSenderSource = item.leaderSource;
        inviteSenderGangName = item.gangName;
        document.getElementById('invite-receive-text').innerText = `A organização "${item.gangLabel}" enviou um convite para você.`;
        document.getElementById('invite-receive-popup').classList.remove('hidden');
    }
    
    else if (item.action === "closeAll") {
        closeUiGlobal();
    }
});

document.querySelectorAll('.tab-item').forEach(tab => {
    tab.addEventListener('click', function() {
        document.querySelectorAll('.tab-item').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.add('hidden'));
        
        this.classList.add('active');
        const targetTab = this.getAttribute('data-tab');
        document.getElementById(targetTab).classList.remove('hidden');
    });
});

document.getElementById('btn-create-org').addEventListener('click', function() {
    const id = document.getElementById('create-id').value;
    const label = document.getElementById('create-label').value;
    
    if(id.trim() === "" || label.trim() === "") return;

    sendNuiData('registerNewGang', { gangId: id, gangLabel: label });
    
    document.getElementById('create-id').value = "";
    document.getElementById('create-label').value = "";
});

document.getElementById('btn-deposit').addEventListener('click', function() {
    const amt = document.getElementById('deposit-amount').value;
    if(!amt || amt <= 0) return;
    sendNuiData('manageFunds', { action: 'deposit', amount: amt });
    document.getElementById('deposit-amount').value = "";
});

document.getElementById('btn-withdraw').addEventListener('click', function() {
    const amt = document.getElementById('withdraw-amount').value;
    if(!amt || amt <= 0) return;
    sendNuiData('manageFunds', { action: 'withdraw', amount: amt });
    document.getElementById('withdraw-amount').value = "";
});

document.getElementById('btn-save-settings').addEventListener('click', function() {
    const label = document.getElementById('settings-label').value;
    const logo = document.getElementById('settings-logo').value;
    sendNuiData('saveLeaderSettings', { label: label, logoUrl: logo });
});

document.getElementById('btn-open-invite').addEventListener('click', () => {
    document.getElementById('invite-modal').classList.remove('hidden');
});

document.getElementById('btn-close-invite-modal').addEventListener('click', () => {
    document.getElementById('invite-modal').classList.add('hidden');
});

document.getElementById('btn-send-invite-action').addEventListener('click', function() {
    const target = document.getElementById('invite-candidates-select').value;
    if (target) {
        sendNuiData('invitePlayer', { targetId: target });
        document.getElementById('invite-modal').classList.add('hidden');
    }
});

document.getElementById('btn-accept-invite').addEventListener('click', () => {
    sendNuiData('respondToInvite', { gangName: inviteSenderGangName, leaderSource: inviteSenderSource, accepted: true });
    document.getElementById('invite-receive-popup').classList.add('hidden');
});

document.getElementById('btn-decline-invite').addEventListener('click', () => {
    sendNuiData('respondToInvite', { gangName: inviteSenderGangName, leaderSource: inviteSenderSource, accepted: false });
    document.getElementById('invite-receive-popup').classList.add('hidden');
});

function memberAction(action, sourceId, citizenid) {
    sendNuiData('executeMemberAction', { action: action, targetId: sourceId, targetCitizenId: citizenid });
}

function adminAction(action, gangName) {
    let extra = null;
    if (action === "modifyFunds") extra = 10000; 
    sendNuiData('adminForceAction', { action: action, gangName: gangName, extraData: extra });
}

function closeUiGlobal() {
    document.getElementById('creation-screen').classList.add('hidden');
    document.getElementById('dashboard-screen').classList.add('hidden');
    document.getElementById('admin-screen').classList.add('hidden');
    sendNuiData('closeUi', {});
}

// Agrupa os seletores dos botões que possuem o mesmo comportamento
const closeButtons = ['btn-close-dash', 'btn-close-admin'];

// Adiciona o evento de clique para cada botão do grupo
closeButtons.forEach(id => {
  const button = document.getElementById(id);
  if (button) {
    button.addEventListener('click', closeUiGlobal);
  }
});

// Atalho para fechar com a tecla Escape (Esc)
window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeUiGlobal();
});
