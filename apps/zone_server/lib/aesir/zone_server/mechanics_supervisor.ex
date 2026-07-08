defmodule Aesir.ZoneServer.MechanicsSupervisor do
  use Supervisor

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.ShopVerifier
  alias Aesir.ZoneServer.Npc.Verifier, as: NpcVerifier
  alias Aesir.ZoneServer.Npc.Warps

  def init([]) do
    :ok = MapCache.init()
    :ok = Interpreter.init()
    :ok = ScriptCompiler.compile_all!()
    :ok = NpcVerifier.verify!(NpcRegistry.reload().entries)
    :ok = Warps.reload()
    :ok = Shops.reload()
    :ok = LevelPenalty.reload()
    :ok = RefineDatabase.reload()
    :ok = ShopVerifier.verify!(Shops.all())

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
