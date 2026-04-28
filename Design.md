This is design document, inspired by the V-model, for FPCSSIM ==(working name)==. FPCSSIM is a simulator for simulating outcomes in stages of Counter-Strike 2 majors using the ruleset for the IEM Cologne 2026 major. The user inputs teams and their respective strengths in a web-based GUI, runs a simulation of a Swiss stage using a functional (as in functional programming) backend, and sees the result in the same GUI.
## Purpose
There are three main reasons for creating this project:
- To learn **functional programming** concepts.
- To get better understanding of the **V-model development process**.
- To get experience using **generative AI tools** during the whole development process.
I have no previous experience with functional programming or the V-model and have mostly used generative AI tools for writing and reviewing code. This project uses Gemini 3 Pro from start to finish to plan the project as well as to design and implement the software, including writing this document. However, Gemini is used as a tool to help me build the project, not to build the entire project by itself.

---

# 1 Requirements Analysis
User-level requirements for the project, with no implementation-level details.
## 1.1 Input Requirements
- The system must provide a GUI to input 16 teams and their respective strength metrics.
- The system must allow the user to define the initial pre-event seeds (1 through 16) for all teams.
- The system must allow the simulation engine to differentiate win probabilities between Best-of-1 (Bo1) and Best-of-3 (Bo3) matches to account for increased variance in shorter series.
- The GUI must provide a control for the user to specify whether they are simulating Stage 1/2 (Mixed match length) or Stage 3 (All Bo3 format).
- The GUI must provide a control to trigger the simulation.
## 1.2 Domain Requirements (Valve Swiss System Rules)
- **Format:** The stage must adhere to a 16-team Swiss bracket where teams play against opponents with identical win-loss (W-L) records.
- **Advancement/Elimination:** Teams advance upon achieving three wins and are eliminated upon suffering three losses.
- **Match Length:** 
	- Stage 1 and Stage 2: All elimination and advancement matches must be simulated as Bo3, while all other matches must be simulated as Bo1.
	- Stage 3: All matches must be simulated as Bo3.
- **Rematch Prevention:** Teams must not play the same opponent twice in the same stage, if possible.
- **Round 1 Matchups:** Initial pairings must strictly follow the seed format: 1v9, 2v10, 3v11, 4v12, 5v13, 6v14, 7v15, and 8v16.
- **Dynamic Seeding (Rounds 2–5):** Teams must be dynamically seeded based on the following priority:
    1. Current W-L record in the stage.
    2. Difficulty Score (Buchholz), calculated as the sum of current wins minus the sum of current losses for every past opponent.
    3. Initial pre-event seeding.
- **Pairing Logic (Rounds 2–5):** The highest dynamically seeded team must face the lowest dynamically seeded team available that does not result in a rematch.
## 1.3 Output Requirements
- The system must display the matchups for each round clearly, grouped by their respective W-L pools.
- The system must accurately update and display current Buchholz scores alongside team standings.
- Upon completion, the system must clearly designate the 8 advancing teams and the 8 eliminated teams.
## 1.4 User Acceptance Testing
==Stub==
Run a simulation and ensure that...
- The simulation follows Valve's rules
	- _Verify Rematch Prevention Edge Cases:_ Ensure that in Rounds 4 and 5 (the 2-1, 1-2, and 2-2 pools), the system can successfully pair all teams without violating the "no rematches" rule, even when the pool of available opponents is highly constrained.
- The simulation result is correct
- The user experience meets user expectations (functionality, user interface)

Here is the formal Markdown output for Phase 2: System Design, updated to reflect the streamlined, vanilla JavaScript approach we discussed initially. You can copy and paste this directly into your specification document.

---

# 2: System Design
Proposed system-level design for implementing the user requirements.
## 2.1 High-Level Architecture
The system will utilize a strict **Client-Server Architecture**. This design separates the user interface and data visualization (Client) from the complex mathematical simulation and strict state management (Server).

This separation ensures that the system's core objective (practicing purely functional programming) is achieved by keeping all domain logic fully isolated on the server. The client will act purely as a "dumb terminal," handling no calculations or state mutations of its own.
## 2.2 Technology Stack
- **Backend (Simulation Engine & API):** Haskell
    - _Reasoning:_ Haskell enforces purely functional programming paradigms, immutability, and strict types. It will handle the complex Swiss system logic and state transformations.
    - _Web Framework:_ Scotty (a lightweight web framework for Haskell to expose REST endpoints).
- **Frontend (User Interface):** JavaScript, HTML, and CSS.
    - _Reasoning:_ Ensures zero configuration overhead (no build tools like Webpack or Vite). It allows for rapid prototyping of the UI using native browser APIs (`fetch` for network requests and DOM manipulation for rendering).
- **Data Exchange Format:** JSON over HTTP
    - _Reasoning:_ The universal standard for web communication, easily serialized by Haskell and natively parsed by JavaScript.
## 2.3 Subsystem Responsibilities
### 2.3.1 The Client Subsystem (Frontend)
- Provides the HTML form for the user to input the 16 teams, their initial seeds, and their strength metrics.
- Sends user inputs to the backend to initialize the tournament.
- Sends trigger commands (e.g., "Simulate Next Round") to the backend.
- Receives JSON payloads representing the current tournament state and dynamically renders the bracket pools, match results, and standings to the DOM.
### 2.3.2 The Server Subsystem (Backend)
- Receives tournament initialization data and constructs the initial immutable state.
- Executes all business logic mandated by the Major Supplemental Rulebook (Swiss pairings, rematch prevention, Buchholz calculation).
- Handles the mathematical simulation of matches, correctly distinguishing between Best-of-1 and Best-of-3 probability models.
- Exposes HTTP endpoints to serve the current state and trigger state transitions.

## 2.4 System Testing
===Stub===
System Testing evaluates the complete, integrated system to ensure the architecture (the client-server split, the Haskell-JS communication) actually works in reality.
- **System Test 1 (Integration):** The Vanilla JS frontend successfully sends a payload to the Haskell server running on a local port, and the browser correctly logs the JSON response without CORS or network errors.
- **System Test 2 (End-to-End Environment):** The system can run entirely on a fresh machine by executing a single start script for the Haskell server and opening `index.html` in a standard web browser.

---

# 3: Architecture Design
High-level design of architecture and modules.
## 3.1 Component Architecture
The system is divided into two distinct environments (Client and Server), which are further subdivided into specific functional components.

### 3.1.1 Client Components (Vanilla JavaScript)
- **State Container:** A simple in-memory JavaScript variable that holds the latest `TournamentState` JSON object received from the server.
- **API Interface:** A module utilizing the native `fetch` API to serialize the State Container into JSON, send it to the server via POST requests, and parse the responses.
- **DOM Renderer:** A module responsible for taking the `TournamentState` object, clearing the current HTML view, and dynamically generating HTML elements (divs, spans) to display the bracket, standings, and match results.

### 3.1.2 Server Components (Haskell)
- **HTTP Router (Scotty):** The outermost layer that listens for HTTP POST requests, deserializes JSON into Haskell data types, passes the data to the pure core, and serializes the result back to JSON.
- **Tournament Engine (Pure Core):** The primary domain module. It applies the Valve-mandated Swiss format rules, calculates Buchholz scores, and pairs teams for the next round while preventing rematches.
- **Match Simulator (Pure Core):** A mathematical module that takes two teams and a `MatchFormat` (Bo1 or Bo3) and calculates a winner based on their relative strength metrics (using a random seed for variance).

## 3.2 Stateless Data Flow
To strictly adhere to functional programming principles, the server will maintain absolutely no persistent state. All state transitions happen purely through the API boundaries.

**Flow 1: Tournament Initialization**
1. **Client:** The user submits the HTML form with 16 teams. The API Interface sends an array of `Team` objects to `POST /api/init`.
2. **Server:** The HTTP Router passes the teams to the Tournament Engine. The engine creates the initial `TournamentState` (Round 1 matchups generated by seed).
3. **Server:** The HTTP Router returns the state as JSON.
4. **Client:** The State Container updates with the initial state, and the DOM Renderer draws Round 1.

**Flow 2: Round Simulation**
1. **Client:** The user clicks "Simulate Round". The API Interface sends the _entire current_ `TournamentState` JSON to `POST /api/simulate-round`.
2. **Server:** The HTTP Router passes the state to the Pure Core.
3. **Server (Match Simulator):** Resolves all `Pending` matches into `Completed` matches.
4. **Server (Tournament Engine):** Updates W-L records, calculates new Buchholz scores, moves active matches to history, and generates the `Pending` matches for the _next_ round.
5. **Server:** Returns the newly transformed `TournamentState` JSON.
6. **Client:** The State Container overwrites its data with the new state, and the DOM Renderer repaints the screen.

## 3.3 Integration Testing
===Stub===
Do these components talk to each other correctly according to the architecture?
- **Integration Test 1 (Client API to Server Router):** Ensure the frontend `API Interface` successfully serializes a `TournamentState` object, sends it via `POST`, and that the Haskell `HTTP Router` correctly deserializes it without throwing a parsing error.
- **Integration Test 2 (Router to Pure Core):** Ensure the Haskell `HTTP Router` correctly passes the deserialized data to the `Tournament Engine` and returns the resulting new state back down the HTTP pipeline.

---

# 4 Module Design
Defines the low-level contracts, precise data structures, and function signatures that the individual components from the architecture design will use.
## 4.1 API Endpoints
The stateless API will expose exactly two endpoints. Both accept and return `application/json`.
- **`POST /api/init`**
    - **Input Payload:** `{ teams: Team[], stageType: "Stage1" | "Stage3" }` where `Team[]` is an array of 16 teams with `id`, `name`, `seed`, and `strength`.
    - **Process:** Validates exactly 16 teams are provided. Generates Round 1 matchups (1v9, 2v10, etc.) based on the Valve rulebook. Initializes all W-L records to 0-0.
    - **Output Payload:** `TournamentState` (The complete initial state).
- **`POST /api/simulate-round`**
    - **Input Payload:** `TournamentState` (The current state).
    - **Process:** Resolves all `Pending` matches using the Match Simulator. Updates the standings and Buchholz scores. Uses the Tournament Engine to pair the next round based on dynamic seeding and rematch prevention.
    - **Output Payload:** `TournamentState` (The next chronological state).
## 4.2 Domain Data Structures (JSON & Haskell Types)
These JSON structures represent the "Single Source of Truth" passed between the frontend and backend.
```
// Example: Team Object
{
  "id": "faze_01",
  "name": "FaZe Clan",
  "seed": 1,
  "strength": 1850.5 // E.g., Elo rating
}

// Example: Match Object
{
  "matchId": "r1_m1",
  "round": 1,
  "teamA": { /* Team Object */ },
  "teamB": { /* Team Object */ },
  "format": "Bo1", // "Bo1" or "Bo3"
  "status": "Pending", // "Pending" or "Completed"
  "scoreA": 0, // #maps won by Team A
  "scoreB": 0, // #maps won by Team B
  "winnerId": null // Populated when Completed
}

// Example: TeamStanding Object
{
  "wins": 1,
  "losses": 0,
  "buchholz": 0, 
  "pastOpponents": ["spirit_02"] // Used for rematch prevention & Buchholz calculation
}

// Example: TournamentState Object
{
  "currentRound": 1,
  "teams": [ /* Array of 16 Team Objects */ ],
  "history": [ /* Array of Completed Match Objects */ ],
  "activeMatches": [ /* Array of Pending Match Objects */ ],
  "standings": {
    "faze_01": { /* TeamStanding Object */ }
  }
}
```
## 4.3 Core Haskell Function Signatures (The Pure Core)
To enforce strict functional purity, randomness (required for simulations) must be handled explicitly. The core engine will take a random seed/generator along with the state.
- `initTournament :: [Team] -> TournamentState`
    - Takes a list of teams and strictly applies the Round 1 seeding rules (1v9, 2v10...) to return the starting state.
- `simulateMatch :: StdGen -> Match -> (Match, StdGen)`
    - Takes a random number generator and a Pending match. Uses the team strengths and the format (Bo1 vs Bo3) to calculate a winner, returning a Completed match and the updated random generator.
- `simulateRound :: StdGen -> TournamentState -> (TournamentState, StdGen)`
	- The master function called by the API. It maps `simulateMatch` over all `activeMatches` (threading the random generator through each), updates all `TeamStanding` records, moves the completed matches to `history`, and finally passes the intermediate state to `generateNextRound`.
- `calculateBuchholz :: TournamentState -> String -> Int`
    - Takes the current state and a `teamId`. Looks up past opponents and sums their wins minus their losses.
- `generateNextRound :: TournamentState -> TournamentState`
    - The most complex module. Groups teams by W-L record, sorts them by dynamic seeding (Buchholz -> Initial Seed), and pairs them top-to-bottom while avoiding past opponents.

## 4.4 Unit Testing
Unit testing focuses on verifying the smallest testable parts of the software in complete isolation from the rest of the system. It directly validates the data structures, logic, and function signatures defined in the **Module Design** phase.

In the context of this stateless architecture, Unit Testing will primarily target the pure Haskell functions within the Tournament Engine and Match Simulator. Because these functions are purely functional (they have no side effects, do not require a database, and their output is determined solely by their input), they are highly predictable and suited for rigorous unit testing.

**Specific Unit Testing Targets:**
===Stub===
- **`initTournament` Validation:** Given an array of 16 valid `Team` objects, verify that the function returns a `TournamentState` where the Round 1 `activeMatches` strictly adhere to the 1v9, 2v10, 3v11 seeding rule.
- **`calculateBuchholz` Validation:** Given a mock `TournamentState` where a target team's past opponents have current W-L records of 3-0, 1-2, and 0-3, verify that the function correctly calculates and returns a Buchholz score of `-1`.
- **`simulateMatch` Validation:** By passing a fixed random seed (to temporarily remove non-determinism during testing), verify that the function correctly parses the `MatchFormat` (Bo1 vs. Bo3) and mathematically processes the team strength metrics to output a valid `Completed` match state.

---

# Notes
===Notes for WIP version of this design document===
- Remember to take map veto advantage into consideration (top seed goes first).
- How should team strengths be decided? Just seeding isn't enough, should each team get a strength score or maybe even each individual possible matchup get a probability assigned?
- Fill out design of tests
- 