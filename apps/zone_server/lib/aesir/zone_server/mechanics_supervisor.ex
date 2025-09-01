defmodule Aesir.ZoneServer.MechanicsSupervisor do
  use Supervisor

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

  def init([]) do
    :ok = MapCache.init()
    :ok = Interpreter.init()

    children = [
      Aesir.ZoneServer.Mmo.JobManagement.JobDataLoader,
      Aesir.ZoneServer.Mmo.MobManagement.MobDataLoader,
      Aesir.ZoneServer.Map.PartitionedSupervisor,
      Aesir.ZoneServer.Map.MapManager,
      Aesir.ZoneServer.Unit.Player.PlayerSupervisor,
      Aesir.ZoneServer.Mmo.StatusTickManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
end
