defmodule Mix.Tasks.Aesir.Char do
  @moduledoc """
  Starts the Aesir Character Server.

  ## Usage

      mix aesir.char

  This starts only the character server, which handles character data management.
  """
  use Mix.Task

  @shortdoc "Starts the Aesir Character Server"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    # Start only the char_server application
    Application.ensure_all_started(:char_server)

    # Keep the task running
    Process.sleep(:infinity)
  end
end
