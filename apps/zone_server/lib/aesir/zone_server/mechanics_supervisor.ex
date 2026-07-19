defmodule Aesir.ZoneServer.MechanicsSupervisor do
  use Supervisor

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.BossRespawn
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
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
    :ok = NpcEvents.run_on_init()
    :ok = Warps.reload()
    :ok = Shops.reload()
    :ok = MobSkillDb.reload()
    :ok = LevelPenalty.reload()
    :ok = RefineDatabase.reload()
    :ok = ShopVerifier.verify!(Shops.all())
    # Runs before any coordinator starts, as a single grouped query. It records
    # deadlines only: spawning or arming anything here would be duplicated by
    # each map's lazy first spawn. Spawn data is read lazily by `Spawns`, so it
    # needs no explicit load ahead of this call.
    if Config.boss_respawn_reconcile_on_boot?(), do: :ok = BossRespawn.reconcile()

    children =
      [
        Aesir.ZoneServer.Map.PartitionedSupervisor,
        Aesir.ZoneServer.Map.MapManager,
        Aesir.ZoneServer.Unit.Player.PlayerSupervisor,
        Aesir.ZoneServer.Mmo.StatusTickManager,
        Aesir.ZoneServer.Mmo.Skill.Unit.Manager
      ] ++ clock_scheduler_child()

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # Excluded in test: dozens of tests swap the shared persistent_term NPC
  # registry with fixture modules via `Npc.Registry.reload/1`; a real,
  # permanently-running scheduler ticking against that shared state would be
  # an untraceable once-a-minute flake risk the moment a fixture declares a
  # clock-parseable label. `Npc.ClockScheduler` itself is still fully
  # unit/integration tested via `start_supervised!/1`.
  if Mix.env() == :test do
    defp clock_scheduler_child, do: []
  else
    defp clock_scheduler_child, do: [Aesir.ZoneServer.Npc.ClockScheduler]
  end
end
