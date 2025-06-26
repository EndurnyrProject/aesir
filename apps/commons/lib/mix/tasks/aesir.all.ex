defmodule Mix.Tasks.Aesir.All do
  @moduledoc """
  Starts all Aesir servers (Account, Character, and Zone).

  ## Usage

      mix aesir.all

  This starts all three servers:
  - Account Server (port 6901)
  - Character Server
  - Zone Server (port 5121)
  """
  use Mix.Task

  @shortdoc "Starts all Aesir servers"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    # Start all applications
    Application.ensure_all_started(:ranch)
    Application.ensure_all_started(:account_server)
    Application.ensure_all_started(:char_server)
    Application.ensure_all_started(:zone_server)

    # Keep the task running
    Process.sleep(:infinity)
  end
end
