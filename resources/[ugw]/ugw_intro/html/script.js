window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === "openIntro") {
        document.getElementById('intro-container').style.display = 'flex';
    }
});

function concordar() {
    // Oculta imediatamente o container e limpa o fundo para sumir com a opacidade preta
    let container = document.getElementById('intro-container');
    if (container) {
        container.style.display = 'none';
    }
    document.body.style.background = 'transparent';
    
    fetch(`https://ugw_intro/closeIntro`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    });
}

function discordar() {
    alert("Você precisa concordar com as regras do CLASSIC para jogar no servidor.");
}