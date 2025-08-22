defmodule Aesir.ZoneServer.MechanicsSupervisor do
  use Supervisor

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.JobData
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

  def init([]) do
    :ok = MapCache.init()
    :ok = JobData.init()
    :ok = Interpreter.init()

    children = [
      Aesir.ZoneServer.Unit.Player.PlayerSupervisor,
      Aesir.ZoneServer.Mmo.StatusTickManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
end
