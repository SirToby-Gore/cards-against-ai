class CardsAgainstAIClient {
    socket;
    clientId = '';
    isReader = false;
    myHand = [];
    selectedCards = [];
    rawBlackCardText = '';
    // UI Cache references
    appContainer;
    lobbyView;
    gameView;
    playersList;
    blackCardContainer;
    whiteCardsContainer;
    actionButton;
    constructor() {
        this.generateClientId();
        this.setupDOM();
        this.connectToServer();
    }
    generateClientId() {
        const letters = 'AEIOUBCDFGHJKLMNPQRSTVXZWYaeioubcdfghjklmnpqrstvxzwy0123456789';
        this.clientId = Array.from({ length: 64 }, () => letters[Math.floor(Math.random() * letters.length)]).join('');
    }
    setupDOM() {
        this.appContainer = document.createElement('main');
        this.appContainer.className = 'game-container';
        document.body.appendChild(this.appContainer);
        // Render Initial Login / Lobby View
        this.lobbyView = document.createElement('div');
        this.lobbyView.className = 'lobby-view';
        this.lobbyView.innerHTML = `
            <h1>Cards Against AI</h1>
            <div class="input-group">
                <input type="text" id="username-input" placeholder="Enter your name..." maxlength="15">
                <button id="join-btn">Join Game</button>
            </div>
            <p class="status-msg" id="lobby-status"></p>
        `;
        this.appContainer.appendChild(this.lobbyView);
        // Render Core Game Layout Layout Shell
        this.gameView = document.createElement('div');
        this.gameView.className = 'game-view hidden';
        this.gameView.innerHTML = `
            <aside class="sidebar">
                <h2>Players</h2>
                <ul id="players-list"></ul>
                <button id="action-btn" class="hidden">Start Game</button>
            </aside>
            <section class="table-area">
                <div class="black-card-zone">
                    <div id="black-card" class="card black">Waiting for game to start...</div>
                </div>
                <div id="white-cards-zone" class="white-cards-zone"></div>
            </section>
        `;
        this.appContainer.appendChild(this.gameView);
        // Cache dynamically generated UI segments
        this.playersList = document.getElementById('players-list');
        this.blackCardContainer = document.getElementById('black-card');
        this.whiteCardsContainer = document.getElementById('white-cards-zone');
        this.actionButton = document.getElementById('action-btn');
        // Attach event listeners
        document.getElementById('join-btn').addEventListener('click', () => this.joinGame());
        this.actionButton.addEventListener('click', () => this.handleActionClick());
    }
    connectToServer() {
        this.socket = new WebSocket(`ws://${window.location.host}`);
        this.socket.onopen = () => {
            console.info('Pipeline connected directly to the unified server wrapper!');
        };
        this.socket.onmessage = (event) => {
            try {
                const response = jsonDecode(event.data);
                this.handleServerMessage(response);
            }
            catch (err) {
                console.error('Failed to parse incoming transmission:', err);
            }
        };
        this.socket.onclose = () => {
            console.error('Pipeline disconnected');
            this.showLobbyStatus('Connection to server lost.', true);
        };
    }
    sendToServer(request, payload = {}) {
        this.socket.send(JSON.stringify({
            request,
            id: this.clientId,
            ...payload,
        }));
    }
    joinGame() {
        const input = document.getElementById('username-input');
        const name = input.value.trim();
        if (!name) {
            this.showLobbyStatus('Please enter a valid name.', true);
            return;
        }
        this.sendToServer('join-game', { name });
    }
    handleActionClick() {
        if (this.actionButton.textContent === 'Start Game') {
            this.sendToServer('start-game');
        }
        else if (this.actionButton.textContent === 'Submit Selection') {
            this.sendToServer('submit-cards', { 'selected-cards': this.selectedCards });
            this.myHand = this.myHand.filter((card) => !this.selectedCards.includes(card));
            this.actionButton.className = 'hidden';
        }
        else if (this.actionButton.textContent === 'Pick Winner') {
            if (this.selectedCards.length === 1) {
                this.sendToServer('pick-winner', { 'winning-card': this.selectedCards[0] });
                this.actionButton.className = 'hidden';
            }
        }
    }
    handleServerMessage(res) {
        if (res['status-code'] >= 400) {
            alert(res.message || 'An error occurred on the server.');
            return;
        }
        switch (res.request) {
            case 'join-game':
                this.lobbyView.classList.add('hidden');
                this.gameView.classList.remove('hidden');
                this.actionButton.textContent = 'Start Game';
                this.actionButton.className = 'btn-action';
                break;
            case 'joined-game':
            case 'round-end':
                if (res.players)
                    this.updatePlayersList(res.players);
                break;
            case 'connection-established':
                if (res['assigned-id']) {
                    this.clientId = res['assigned-id'];
                    this.showLobbyStatus('Connected to server successfully!', false);
                }
                break;
            case 'start-game':
                if (res.players)
                    this.updatePlayersList(res.players);
                this.actionButton.className = 'hidden'; // Hide start button once in motion
                break;
            case 'set-hand':
                if (res.cards) {
                    this.myHand = jsonDecode(res.cards);
                }
                break;
            case 'round-start-reader':
                this.isReader = true;
                this.selectedCards = []; // Clear old choices
                this.rawBlackCardText = res['black-card'] || '';
                this.blackCardContainer.textContent = this.rawBlackCardText;
                this.whiteCardsContainer.innerHTML = `<div class="info-msg">You are the card reader. Waiting for players to submit options...</div>`;
                this.actionButton.className = 'hidden';
                break;
            case 'round-start':
                this.isReader = false;
                this.selectedCards = []; // Clear old choices
                this.rawBlackCardText = res['black-card'] || '';
                this.blackCardContainer.textContent = this.rawBlackCardText;
                this.renderHand(this.myHand, false);
                break;
            case 'round-midway':
                if (this.isReader && res.options) {
                    const choices = typeof res.options === 'string' ? jsonDecode(res.options) : res.options;
                    this.renderReaderOptions(choices); // Call dedicated stack renderer
                }
                else {
                    this.whiteCardsContainer.innerHTML = `<div class="info-msg">${res.message || 'Reader is selecting a winner...'}</div>`;
                }
                break;
            case 'end-of-game':
                alert(`Game Over! ${res.message}`);
                window.location.reload();
                break;
        }
    }
    updatePlayersList(players) {
        players.sort((a, b) => b['won-cards'] - a['won-cards']);
        this.playersList.innerHTML = players
            .map((p) => `
            <li>
                <span class="player-name">${p.name}</span>
                <span class="player-score">${p['won-cards']} pts</span>
            </li>
        `)
            .join('');
    }
    renderReaderOptions(choices) {
        this.whiteCardsContainer.innerHTML = '';
        choices.forEach((option) => {
            // Create a wrapper container for the card selection stack
            const stackContainer = document.createElement('div');
            stackContainer.className = 'card-stack';
            // Render each white card belonging to this player's submission choice
            option.cards.forEach((cardText) => {
                const cardEl = document.createElement('div');
                cardEl.className = 'card white';
                cardEl.textContent = cardText;
                stackContainer.appendChild(cardEl);
            });
            // Handle user choice selection & dynamic black card preview updating
            stackContainer.addEventListener('click', () => {
                // Clear active state highlights across all stacks
                document.querySelectorAll('.card-stack').forEach((s) => s.classList.remove('selected-stack'));
                stackContainer.classList.add('selected-stack');
                // Dynamically parse out and inject values into the black card template live
                let previewText = this.rawBlackCardText;
                option.cards.forEach((cardText) => {
                    previewText = previewText.replace('_____', `[${cardText}]`);
                });
                this.blackCardContainer.textContent = previewText;
                // Save validation target key token to submit back to server pipeline
                this.selectedCards = [option.key];
                this.actionButton.textContent = 'Pick Winner';
                this.actionButton.className = 'btn-action';
            });
            this.whiteCardsContainer.appendChild(stackContainer);
        });
    }
    renderHand(cards, selectionForReader) {
        this.whiteCardsContainer.innerHTML = '';
        // Helper to dynamically inject selected cards into the cached template string
        const updatePreview = () => {
            if (selectionForReader)
                return; // The reader views already fully pre-rendered cards
            let previewText = this.rawBlackCardText;
            this.selectedCards.forEach((cardText) => {
                previewText = previewText.replace('_____', `[${cardText}]`);
            });
            this.blackCardContainer.textContent = previewText;
        };
        cards.forEach((cardText) => {
            const cardEl = document.createElement('div');
            cardEl.className = 'card white';
            cardEl.textContent = cardText;
            cardEl.addEventListener('click', () => {
                if (selectionForReader) {
                    document.querySelectorAll('.card.white').forEach((c) => c.classList.remove('selected'));
                    cardEl.classList.add('selected');
                    this.selectedCards = [cardText];
                    this.actionButton.textContent = 'Pick Winner';
                    this.actionButton.className = 'btn-action';
                }
                else {
                    if (cardEl.classList.contains('selected')) {
                        cardEl.classList.remove('selected');
                        this.selectedCards = this.selectedCards.filter((c) => c !== cardText);
                    }
                    else {
                        cardEl.classList.add('selected');
                        this.selectedCards.push(cardText);
                    }
                    // Dynamically redraw the text with the modifications
                    updatePreview();
                    if (this.selectedCards.length > 0) {
                        this.actionButton.textContent = 'Submit Selection';
                        this.actionButton.className = 'btn-action';
                    }
                    else {
                        this.actionButton.className = 'hidden';
                    }
                }
            });
            this.whiteCardsContainer.appendChild(cardEl);
        });
    }
    showLobbyStatus(msg, isError) {
        const el = document.getElementById('lobby-status');
        el.textContent = msg;
        el.style.color = isError ? '#ff4d4d' : '#4da6ff';
    }
}
// Global window event safely preventing disconnect alerts
window.addEventListener('beforeunload', (event) => {
    event.preventDefault();
    event.returnValue = 'Are you sure you want to leave the game session?';
    return event.returnValue;
});
// Helper function to safely parse server-side layout variables
function jsonDecode(data) {
    return JSON.parse(data);
}
// Fire up client core runtime
document.addEventListener('DOMContentLoaded', () => {
    new CardsAgainstAIClient();
});
