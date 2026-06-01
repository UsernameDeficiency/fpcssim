document.addEventListener('DOMContentLoaded', () => {
    const pingBtn = document.getElementById('ping-btn');
    const statusDisplay = document.getElementById('status-display');
    const initBtn = document.getElementById('init-btn');
    const bracketDisplay = document.getElementById('bracket-display');
    const simRoundBtn = document.getElementById('sim-round-btn');
    simRoundBtn.disabled = true; // Disable simulate button until tournament is initialized
    simRoundBtn.style.opacity = 0.5;

    let tournamentState = null; // Full state in current round

    // Define 16 teams for test data
    const mockTeams = [
        { teamId: "t1", name: "FaZe Clan", seed: 1, odds: 3.50 },
        { teamId: "t2", name: "Team Spirit", seed: 2, odds: 4.00 },
        { teamId: "t3", name: "Vitality", seed: 3, odds: 4.50 },
        { teamId: "t4", name: "MOUZ", seed: 4, odds: 6.00 },
        { teamId: "t5", name: "G2 Esports", seed: 5, odds: 7.50 },
        { teamId: "t6", name: "Natus Vincere", seed: 6, odds: 9.00 },
        { teamId: "t7", name: "Virtus.pro", seed: 7, odds: 13.00 },
        { teamId: "t8", name: "Astralis", seed: 8, odds: 15.00 },
        { teamId: "t9", name: "Complexity", seed: 9, odds: 21.00 },
        { teamId: "t10", name: "HEROIC", seed: 10, odds: 26.00 },
        { teamId: "t11", name: "ENCE", seed: 11, odds: 34.00 },
        { teamId: "t12", name: "Team Liquid", seed: 12, odds: 41.00 },
        { teamId: "t13", name: "Falcons", seed: 13, odds: 51.00 },
        { teamId: "t14", name: "Cloud9", seed: 14, odds: 67.00 },
        { teamId: "t15", name: "NIP", seed: 15, odds: 81.00 },
        { teamId: "t16", name: "FURIA", seed: 16, odds: 101.00 }
    ];

    /**
     * A wrapper around native fetch that adds a timeout functionality.
     */
    async function fetchWithTimeout(resource, options = {}) {
        // Default timeout is 5000ms (5 seconds) if not specified
        const { timeout = 5000 } = options;

        // Create the fresh controller for THIS specific request
        const controller = new AbortController();
        const id = setTimeout(() => controller.abort(), timeout);

        // Merge the abort signal into the user's options
        const response = await fetch(resource, {
            ...options,
            signal: controller.signal
        });

        // If we made it here, the fetch succeeded before the timeout
        clearTimeout(id);
        return response;
    }

    /** 
     * Render tournament state in the UI.
     */
    function renderTournamentState() {
        bracketDisplay.innerHTML = "";

        tournamentState.activeMatches.forEach(match => {
            const matchCard = document.createElement('div');
            matchCard.className = 'match-card';

            // Highlight the winner in green
            const aWon = match.winnerId === match.teamA.teamId;
            const bWon = match.winnerId === match.teamB.teamId;
            const aColor = aWon ? '#4caf50' : '#e0e0e0';
            const bColor = bWon ? '#4caf50' : '#e0e0e0';

            matchCard.innerHTML = `
                    <h3>Match ${match.matchId.replace('r1_m', '')} (${match.format})</h3>
                    <div class="team-row" style="color: ${aColor}">
                        <span>#${match.teamA.seed} ${match.teamA.name}</span>
                        <span>${aWon ? '✓' : '-'}</span>
                    </div>
                    <div class="team-row" style="color: ${bColor}">
                        <span>#${match.teamB.seed} ${match.teamB.name}</span>
                        <span>${bWon ? '✓' : '-'}</span>
                    </div>
                `;
            bracketDisplay.appendChild(matchCard);
        });
    }

    // --- Ping Backend Logic ---
    pingBtn.addEventListener('click', async () => {
        // Visual feedback that a request is happening
        statusDisplay.textContent = "Pinging...";
        statusDisplay.className = "status-box";

        try {
            // Call the Haskell backend
            const response = await fetchWithTimeout('http://localhost:3000/api/health');

            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }

            const data = await response.text();

            // Update the UI on success
            statusDisplay.textContent = `Success: ${data}`;
            statusDisplay.classList.add('success');

        } catch (error) {
            if (error.name === 'AbortError') {
                statusDisplay.textContent = "Connection Failed: Request timed out. Is the backend running?";
            } else {
                statusDisplay.textContent = `Connection Failed: ${error.message}`;
            }
            statusDisplay.classList.add('error');
            console.error("Ping backend error:", error);
        }
    });

    // --- Init Tournament Logic ---
    initBtn.addEventListener('click', async () => {
        bracketDisplay.innerHTML = "Generating matchups...";

        try {
            // Send the teams to backend via POST
            const response = await fetchWithTimeout('http://localhost:3000/api/init', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(mockTeams)
            });

            if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);

            // Backend returns the full TournamentState. Enable the simulate button after initialization.
            tournamentState = await response.json();
            simRoundBtn.disabled = false; // 
            simRoundBtn.style.opacity = 1;

            // Render each match
            renderTournamentState();

        } catch (error) {
            if (error.name === 'AbortError') {
                bracketDisplay.innerHTML = `<span style="color: red;">Error: Request timed out. Is the backend running?</span>`;
            } else {
                bracketDisplay.innerHTML = `<span style="color: red;">Error: ${error.message}</span>`;
            }
            console.error("Init tournament error:", error);
        }
    });

    // --- Simulate Round Logic ---
    simRoundBtn.addEventListener('click', async () => {
        bracketDisplay.innerHTML = "Simulating round...";
        try {
            const response = await fetchWithTimeout('http://localhost:3000/api/simulate', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(tournamentState)
            });

            if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);

            tournamentState = await response.json();

            // Render each match with results
            renderTournamentState();

            // Can't simulate more until re-initializing tournament
            simRoundBtn.disabled = true;
            simRoundBtn.style.opacity = 0.5;

        } catch (error) {
            if (error.name === 'AbortError') {
                bracketDisplay.innerHTML = `<span style="color: red;">Error: Request timed out. Is the backend running?</span>`;
            } else {
                bracketDisplay.innerHTML = `<span style="color: red;">Error: ${error.message}</span>`;
            }
            console.error("Simulate round error:", error);
        }
    });
});
