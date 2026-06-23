defmodule Aesir.ZoneServer.MechanicsSupervisor do
  use Supervisor

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

  def init([]) do
    :ok = MapCache.init()
    :ok = Interpreter.init()
    :ok = ScriptCompiler.compile_all!()

    children = [
      Aesir.ZoneServer.Map.PartitionedSupervisor,
      Aesir.ZoneServer.Map.MapManager,
      Aesir.ZoneServer.Unit.Player.PlayerSupervisor,
      Aesir.ZoneServer.Mmo.StatusTickManager,
      Aesir.ZoneServer.Mmo.Skill.Unit.TickManager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
end
