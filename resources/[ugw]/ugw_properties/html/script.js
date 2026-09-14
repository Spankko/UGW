const propertyHud = document.getElementById('property-hud');
const propertyName = document.getElementById('property-name');
const propertyPrice = document.getElementById('property-price');
const propertyOwner = document.getElementById('property-owner');
const propertyPayout = document.getElementById('property-payout');
const availableMessage = document.getElementById('available-message');

const buyButton = document.getElementById('buy-button');
const sellButton = document.getElementById('sell-button');
const exitButton = document.getElementById('exit-button');
const closeTop = document.getElementById('close-top');

const sessionSection = document.getElementById('session-section');
const sessionTotal = document.getElementById('session-total');
const earningsList = document.getElementById('earnings-list');

function formatMoney(amount) {
    return '$' + Number(amount || 0).toLocaleString('pt-BR');
}

function renderEarnings(earnings) {
    if (!earningsList) return;
    earningsList.innerHTML = '';

    if (!earnings || earnings.length === 0) {
        earningsList.innerHTML = `<div class="empty-earnings">Nenhum rendimento recebido nesta sessão.</div>`;
        return;
    }

    earnings.forEach(item => {
        const row = document.createElement('div');
        row.className = 'earning-row';
        row.innerHTML = `
            <span class="earning-time">${item.time}</span>
            <span class="earning-value">+ ${formatMoney(item.amount)}</span>
        `;
        earningsList.appendChild(row);
    });

    earningsList.scrollTop = earningsList.scrollHeight;
}

function renderProperty(data) {
    if (!data) return;

    if (propertyName) propertyName.textContent = data.name;
    if (propertyPrice) propertyPrice.textContent = formatMoney(data.price);
    if (propertyOwner) propertyOwner.textContent = data.owner;
    if (propertyPayout) propertyPayout.textContent = formatMoney(data.payout);

    if (availableMessage) {
        if (data.hasOwner) {
            availableMessage.classList.add('hidden');
        } else {
            availableMessage.classList.remove('hidden');
        }
    }

    if (data.isOwner) {
        if (sessionSection) sessionSection.classList.remove('hidden');
        renderEarnings(data.earnings);
        if (sessionTotal) sessionTotal.textContent = formatMoney(data.sessionTotal);

        if (buyButton) buyButton.classList.add('hidden');
        if (sellButton) sellButton.classList.remove('hidden');
    } else {
        if (sessionSection) sessionSection.classList.add('hidden');
        if (sellButton) sellButton.classList.add('hidden');
        if (buyButton) buyButton.classList.remove('hidden');
    }
}

function closeHud() {
    if (propertyHud) propertyHud.classList.add('hidden');

    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

window.addEventListener('message', function(event) {
    const item = event.data;
    if (!item || !item.action) return;

    if (item.action === 'open') {
        renderProperty(item.data);
        if (propertyHud) propertyHud.classList.remove('hidden');
    } else if (item.action === 'close') {
        if (propertyHud) propertyHud.classList.add('hidden');
    } else if (item.action === 'update') {
        renderProperty(item.data);
    } else if (item.action === 'earning') {
        if (!sessionSection || sessionSection.classList.contains('hidden')) return;

        const row = document.createElement('div');
        row.className = 'earning-row';
        row.innerHTML = `
            <span class="earning-time">${item.time}</span>
            <span class="earning-value">+ ${formatMoney(item.amount)}</span>
        `;

        const empty = earningsList.querySelector('.empty-earnings');
        if (empty) empty.remove();

        earningsList.appendChild(row);
        earningsList.scrollTop = earningsList.scrollHeight;

        if (sessionTotal) {
            const currentTotal = Number(sessionTotal.textContent.replace(/[^\d]/g, '')) || 0;
            sessionTotal.textContent = formatMoney(currentTotal + Number(item.amount || 0));
        }
    }
});

if (buyButton) {
    buyButton.addEventListener('click', function() {
        fetch(`https://${GetParentResourceName()}/buyProperty`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    });
}

if (sellButton) {
    sellButton.addEventListener('click', function() {
        fetch(`https://${GetParentResourceName()}/sellProperty`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    });
}

if (exitButton) exitButton.addEventListener('click', closeHud);
if (closeTop) closeTop.addEventListener('click', closeHud);

window.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && propertyHud && !propertyHud.classList.contains('hidden')) {
        closeHud();
    }
});