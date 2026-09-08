# Aesir - Ragnarok Online Server Emulator

[![](https://dcbadge.limes.pink/api/server/https://discord.gg/xGq832HYey)](https://discord.gg/xGq832HYey)

Aesir is an Elixir-based implementation of a Ragnarok Online server.

## Project Structure

The project is organized into several applications within an umbrella structure, each responsible for a specific part of the server's functionality:

- `account_server`: Handles user login, account management, and authentication.
- `char_server`: Manages character data and related operations.
- `zone_server`: Responsible for in-game maps, NPCs, and general MMO mechanics.
- `commons`: Contains shared modules, utilities, and common dependencies used across the other server applications.

## Getting Started

### Prerequisites

- Elixir (version 1.20 or higher)
- Erlang/OTP

### Installation

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/ygorcastor/aesir.git
    cd aesir
    ```

2.  **Fetch dependencies:**

    ```bash
    mix deps.get
    ```

3.  **Compile the project:**

    ```bash
    mix compile
    ```

### Running the Servers

```bash
# To start the Account Server
RELEASE_COOKIE=imthecookie iex --name account@127.0.0.1 -S mix aesir.account

# To start the Char Server
RELEASE_COOKIE=imthecookie iex --name char@127.0.0.1 -S mix aesir.char

# To start the Zone Server
RELEASE_COOKIE=imthecookie iex --name zone@127.0.0.1 -S mix aesir.zone
```

or use the `start_servers.sh` script.

## Testing

Run the test matrix serially from the umbrella root, without setting environment variables:

```bash
mix test.re                  # Renewal unit tests and doctests
mix test.integration.re      # Renewal integrations
mix test.pre_re              # Pre-renewal unit tests and doctests
mix test.integration.pre_re  # Pre-renewal integrations
```

These aliases select the mode before boot and override an inherited `AESIR_DB_MODE`.
Run each command separately because the game mode is cached for the node's lifetime.
`mix test` and `mix test.integration` still use `AESIR_DB_MODE`, defaulting to Renewal
when it is unset. Unit runs exclude integrations.

All aliases accept normal test arguments, for example:

```bash
mix test.pre_re apps/commons/test/aesir/commons/game_mode_test.exs --seed 0
```

To run tests for a specific application (e.g., `account_server`):

```bash
mix test apps/account_server
```

## FAQ

**Q: Can I run my server with it?**

A: No, too early.

**Q: Is it compatible with rAthena DB?**

A: No, and will not be.

**Q: Which client version is supported?**

A: I'm working on my own client, so it's not compatible with the official Ragnarok client.

## Acknowledgents

[rAthena](https://github.com/rathena/rathena) - C/C++ Implementation of the Ragnarok Server  
[Openkore](https://github.com/OpenKore/openkore) - custom client and intelligent automated assistant for Ragnarok Online.
