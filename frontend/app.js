document.addEventListener('DOMContentLoaded', () => {
    const pingBtn = document.getElementById('ping-btn');
    const statusDisplay = document.getElementById('status-display');

    pingBtn.addEventListener('click', async () => {
        // Visual feedback that a request is happening
        statusDisplay.textContent = "Pinging...";
        statusDisplay.className = "status-box";

        try {
            // Call the Haskell backend
            const response = await fetch('http://localhost:3000/api/health');

            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }

            // Parse the response text
            const data = await response.text();

            // Update the UI on success
            statusDisplay.textContent = `Success: ${data}`;
            statusDisplay.classList.add('success');

        } catch (error) {
            // Update the UI on failure
            statusDisplay.textContent = `Connection Failed: ${error.message}. Is the Haskell server running?`;
            statusDisplay.classList.add('error');
            console.error("Backend connection error:", error);
        }
    });
});
