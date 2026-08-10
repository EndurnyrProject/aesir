defmodule Aesir.ZoneServer.Unit.Trade.Supervisor do
  @moduledoc """
  Dynamic supervisor for accepted trade sessions.
  """

  use DynamicSupervisor

  alias Aesir.ZoneServer.Unit.Trade.Session

  @doc "Starts the trade supervisor."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    case name do
      nil -> DynamicSupervisor.start_link(__MODULE__, opts)
      name -> DynamicSupervisor.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc "Starts a trade session."
  @spec start_child(Session.init_arg()) :: DynamicSupervisor.on_start_child()
  def start_child(init_arg) do
    DynamicSupervisor.start_child(supervisor(), {Session, init_arg})
  end

  @impl true
  def init(_opts), do: DynamicSupervisor.init(strategy: :one_for_one)

  defp supervisor do
    ProcessTree.get({__MODULE__, :server}) || __MODULE__
  end
end
