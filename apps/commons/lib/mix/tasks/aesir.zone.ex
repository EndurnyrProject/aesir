defmodule Mix.Tasks.Aesir.Zone do
  @moduledoc """
  Starts the Aesir Zone Server.

  ## Usage

      mix aesir.zone

  This starts only the zone server, which handles the game world, maps, and NPCs
  on the default port (5121).
  """
  use Mix.Task

  @shortdoc "Starts the Aesir Zone Server"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    # Start only the zone_server application
    Application.ensure_all_started(:zone_server)

    # Keep the task running
    Process.sleep(:infinity)
  end
end
