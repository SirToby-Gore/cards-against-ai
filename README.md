# Cards Against AI

An interactive, multi-user web adaptation and educational parody of the classic party game; this utility is engineered to raise public awareness regarding the socio-technical, environmental, and infrastructural trade-offs of modern Artificial Intelligence deployment.

The project rejects bloated cloud-hosted subscription models that rot our collective critical faculties; instead, it relies on clean, localized infrastructure to run a lightweight client-server architecture.

## Technical Architecture Overview

The system operates on a decentralized client-server paradigm; the back-end execution engine is written in Dart, establishing an asynchronous HTTP server that handles static file routing and manages state synchronization across clients via persistent HTML5 WebSocket connections.

- Dart Back-End Server (Host)
    - Handles HTTP Static Files
    - Manages WebSocket States

- WebSocket (RFC 6455) (Middle man)
- HTML5 Web Browser (Client)
    - Renders UI Dynamically
    - Dispatches Player Input

### System Rationale

Socio-technical concepts such as sovereign infrastructure deficits, data center carbon footprints, and algorithmic accessibility are frequently perceived as vague at best; this application lowers the cognitive barrier to entry by gamifying these complex debates.

Using a lightweight, local socket-based framework demonstrates that software can be highly interactive without constant dependency on energy-intensive cloud pipelines; this design prioritises local data integrity and minimises network latency.

## Prerequisites

### Host Machine Configuration

- Operating System: A compatible platform running Windows, macOS, or GNU+Linux.

- Runtime Environment: The local Dart software development kit; you must install the [Dart SDK (Stable Channel)](https://dart.dev/get-dart).

### Client Machine Configuration (Players)

- Local Subnet Connectivity: All players must reside on the same local subnet as the hosting machine.

- Compatible Software: Any modern web browser supporting the RFC 6455 WebSocket protocol (e.g., Firefox, Chrome, or Safari).

## Installation and Deployment

Execute the following sequential steps within your terminal interface to configure the local environment:

```sh
# 1. Navigate into the root repository directory

cd cards_against_ai

# 2. Verify current path alignment to prevent execution failures

echo "$(pwd)"

# 3. Confirm presence of structural components (assets, bin, web)

ls

# 4. Fetch and resolve external package dependencies

dart pub get
```

## Execution Frameworks

Upon successful execution, the server console will output the host machine's local IPv4 address and target port (e.g., http://192.168.1.50:8080); distribute this connection string to all clients.

### Methodology A: Just-In-Time (JIT) Compilation (Development Mode)

To run the server dynamically within the Dart Virtual Machine, execute:

```sh
dart run bin/cards_against_ai.dart
```

### Methodology B: Ahead-Of-Time (AOT) Native Compilation (Production Mode)

To compile the system into a standalone, highly optimized machine-code binary:

```sh
# Compile the source to a native binary

dart compile exe bin/cards_against_ai.dart -o cards_against_ai

# Execute the compiled binary directly

./cards_against_ai
```

## Algorithmic Mechanics and Gameplay Loop

### Phase 0: Session Initialization

- Each player navigates to the host IP address via their web browser; they register a unique username string.

- The server initializes an internal state vector for the user; it allocates a starting hand of five random `WhiteCard` assets parsed from `assets/white_cards.txt`.

- The system randomly elects one player to serve as the Card Czar (the prompt reviewer) for the opening round.

### Phase 1: Prompt Broadcast

- he server selects a `BlackCard` prompt from `assets/black_cards.txt` containing syntax blanks (`{}`) and broadcasts the data to all clients; these prompts explicitly highlight real-world structural problems, such as sovereign dependency on foreign data centers or environmental power grid overheads.

### Phase 2: Anonymous Selection

- All players (excluding the active Card Czar) evaluate their local hand against the constraints of the prompt.

- Players select the required number of response cards to satisfy the blank entries; submissions are transferred via WebSockets to the server, which masks player identities to guarantee anonymity.

### Phase 3: Evaluation and Arbitration

- The server collects all responses, performs a randomized shuffle to prevent positional bias, and renders the completed phrases to the Card Czar's graphical interface.

- The Card Czar reads the completed phrases aloud; they select their preferred conceptual combination based on contextual impact or systemic irony.

### Phase 4: Scoring and Hand Replenishment

- The server increments the score tracker of the winning player by one point; it draws replacement cards from the asset repository to restore hands to the default baseline of five cards.

- The Card Czar designation rotates sequentially to the next connection index; the loop resets cleanly to Phase 1.

### Phase 5: Termination Condition

- The loop terminates when the data source runs out of unique black prompt items or an internal server interrupt occurs; the client interface displays final point tallies, declaring the node with the highest aggregate score as the winner.
