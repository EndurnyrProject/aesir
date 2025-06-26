defmodule Mix.Tasks.Aesir.Account do
  @moduledoc """
  Starts the Aesir Account Server.

  ## Usage

      mix aesir.account

  This starts only the account server, which handles login and account management
  on the default port (6901).
  """
  use Mix.Task

  @shortdoc "Starts the Aesir Account Server"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    # Start only the account_server application
    Application.ensure_all_started(:ranch)
    Application.ensure_all_started(:account_server)

    # Keep the task running
    Process.sleep(:infinity)
  end
end
