function updateDateTime() {
    const now = new Date();

    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');

    const day = String(now.getDate()).padStart(2, '0');
    const month = String(now.getMonth() + 1).padStart(2, '0');

    const formatted = `${hours}:${minutes}:${seconds} - ${day}/${month}`;
    document.getElementById('datetime').innerText = formatted;
}

setInterval(updateDateTime, 1000);
updateDateTime();