defmodule Commons.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Aesir.Repo
    ]

    opts = [strategy: :one_for_one, name: Commons.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
