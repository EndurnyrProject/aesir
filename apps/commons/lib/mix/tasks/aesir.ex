defmodule Mix.Tasks.Aesir do
  @moduledoc """
  Lists available Aesir server tasks.

  ## Usage

      mix aesir

  This will display all available Aesir server tasks that can be run.

  ## Available Tasks

  - `mix aesir.account` - Starts only the Account Server
  - `mix aesir.char` - Starts only the Character Server
  - `mix aesir.zone` - Starts only the Zone Server
  """
  use Mix.Task

  @shortdoc "Lists available Aesir server tasks"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("""

    Aesir Ragnarok Online Server
    ============================

    Available server tasks:

      mix aesir.account  # Start only the Account Server (port 6901)
      mix aesir.char     # Start only the Character Server
      mix aesir.zone     # Start only the Zone Server (port 5121)

    For more information about a specific task, run:

      mix help <task>

    Example:

      mix help aesir.account
    """)
  end
end
