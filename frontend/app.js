document.addEventListener('DOMContentLoaded', () => {
    const pingBtn = document.getElementById('ping-btn');
    const statusDisplay = document.getElementById('status-display');
    const initBtn = document.getElementById('init-btn');
    const bracketDisplay = document.getElementById('bracket-display');

    // Define 16 teams for test data
    const mockTeams = [
        { teamId: "t1", name: "FaZe Clan", seed: 1, strength: 95.0 },
        { teamId: "t2", name: "Team Spirit", seed: 2, strength: 94.5 },
        { teamId: "t3", name: "Vitality", seed: 3, strength: 93.0 },
        { teamId: "t4", name: "MOUZ", seed: 4, strength: 91.0 },
        { teamId: "t5", name: "G2 Esports", seed: 5, strength: 90.0 },
        { teamId: "t6", name: "Natus Vincere", seed: 6, strength: 89.5 },
        { teamId: "t7", name: "Virtus.pro", seed: 7, strength: 88.0 },
        { teamId: "t8", name: "Astralis", seed: 8, strength: 87.0 },
        { teamId: "t9", name: "Complexity", seed: 9, strength: 85.0 },
        { teamId: "t10", name: "HEROIC", seed: 10, strength: 84.5 },
        { teamId: "t11", name: "ENCE", seed: 11, strength: 83.0 },
        { teamId: "t12", name: "Team Liquid", seed: 12, strength: 82.0 },
        { teamId: "t13", name: "Falcons", seed: 13, strength: 81.0 },
        { teamId: "t14", name: "Cloud9", seed: 14, strength: 80.0 },
        { teamId: "t15", name: "NIP", seed: 15, strength: 78.0 },
        { teamId: "t16", name: "FURIA", seed: 16, strength: 77.0 }
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

            // Backend returns the full TournamentState
            const tournamentState = await response.json();

            // Clear the loading text
            bracketDisplay.innerHTML = "";

            // Render each match
            tournamentState.activeMatches.forEach(match => {
                const matchCard = document.createElement('div');
                matchCard.className = 'match-card';
                matchCard.innerHTML = `
                    <h3>Match ${match.matchId.replace('r1_m', '')} (${match.format})</h3>
                    <div class="team-row">
                        <span>#${match.teamA.seed} ${match.teamA.name}</span>
                        <span>0</span>
                    </div>
                    <div class="team-row">
                        <span>#${match.teamB.seed} ${match.teamB.name}</span>
                        <span>0</span>
                    </div>
                `;
                bracketDisplay.appendChild(matchCard);
            });

        } catch (error) {
            if (error.name === 'AbortError') {
                bracketDisplay.innerHTML = `<span style="color: red;">Error: Request timed out. Is the backend running?</span>`;
            } else {
                bracketDisplay.innerHTML = `<span style="color: red;">Error: ${error.message}</span>`;
            }
            console.error("Init tournament error:", error);
        }
    });
});
