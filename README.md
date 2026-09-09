# UGW
# 🔫 FiveM Death Match Scripts (QBCore)

Este repositório contém uma coleção de scripts desenvolvidos para servidores de **FiveM** com foco em **DM (Deathmatch)**, utilizando a base **QBCore**. 

Os scripts combinam lógica no lado do servidor/cliente e interfaces visuais modernas para o jogador.

## 🛠️ Tecnologias Utilizadas

*   **Lua:** Lógica principal do jogo, interações com a base QBCore, eventos de rede e mecânicas de combate.
*   **HTML5 / CSS3:** Estruturação e estilização das interfaces de usuário (NUI) como HUDs, placares e menus.
*   **JavaScript (JS):** Comunicação entre o jogo (Lua) e a interface da tela (NUI).

## ✨ Funcionalidades Principais

* Polyzones dentro do mapa com locais para dominação de gangues
* HUD personalizada com horario e data sincronizados com a hora de Brasília
* Sistema de propriedades com opção de compra, venda e ganhos de 2% a cada 10min
* Entre outras edições, tudo focado para um GM de GangWar inspirado nos antigos servidores de SA-MP

## 🚀 Como Instalar no seu Servidor

1. Baixe os arquivos do script ou clone este repositório.
2. Coloque a pasta do script dentro do diretório `resources` do seu servidor (ex: `resources/[scripts]/nome-do-script`).
3. Certifique-se de que a base `qb-core` está rodando antes deste script.
4. Adicione a seguinte linha ao seu arquivo `server.cfg`:
   ```cfg
   ensure nome-do-script
   ```
5. Reinicie o seu servidor ou use `refresh` e `start nome-do-script` no console.

## ⚙️ Configuração

As principais variáveis, permissões e opções de balanceamento do Deathmatch podem ser ajustadas diretamente no arquivo `config.lua`.

---
⚡ *Desenvolvido para proporcionar a melhor experiência de combate PvP no FiveM.*
