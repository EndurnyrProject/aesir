defmodule Aesir.ZoneServer.MechanicsSupervisor do
  use Supervisor

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.BossRespawn
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalogs, as: HomunculusCatalogs
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.MobSkill.Db, as: MobSkillDb
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Mmo.Woe.CastleVerifier
  alias Aesir.ZoneServer.Mmo.Woe.Persistence
  alias Aesir.ZoneServer.Npc.Events, as: NpcEvents
  alias Aesir.ZoneServer.Npc.QuestInfo, as: NpcQuestInfo
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Shops
  alias Aesir.ZoneServer.Npc.ShopVerifier
  alias Aesir.ZoneServer.Npc.Verifier, as: NpcVerifier
  alias Aesir.ZoneServer.Npc.Warps

  def init([]) do
    :ok = MapCache.init()
    :ok = Interpreter.init()
    :ok = ItemGroups.reload()
    :ok = ScriptCompiler.compile_all!()
    :ok = NpcVerifier.verify!(NpcRegistry.reload().entries)
    :ok = NpcQuestInfo.reload()
    :ok = NpcEvents.run_on_init()
    :ok = Warps.reload()
    :ok = Shops.reload()
    :ok = MobSkillDb.reload()
    :ok = LevelPenalty.reload()
    :ok = RefineDatabase.reload()
    :ok = HomunculusCatalogs.reload()
    :ok = ShopVerifier.verify!(Shops.all())

    # WoE boot: reload the castle catalog and its static mapflags, seed the
    # runtime castle store from the persisted owners, then fail loudly if any
    # castle emperium/respawn cell is unwalkable (a bad coordinate would
    # otherwise surface only as a failed Emperium summon at AgitStart).
    :ok = CastleDb.reload()
    :ok = MapFlags.reload()
    :ok = CastleStore.init()
    :ok = CastleStore.hydrate(Persistence.load_all())
    :ok = CastleVerifier.verify!()

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
      ] ++ woe_server_child() ++ clock_scheduler_child() ++ woe_scheduler_child()

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # Excluded in test: the zone app boots inside the test VM, so a supervised
  # `Woe.Server` would hold the via-registered name the WoE unit/integration
  # tests claim via `start_supervised!/1` (the module API targets exactly one
  # named instance). The same reasoning excludes the schedulers below.
  if Mix.env() == :test do
    defp woe_server_child, do: []
  else
    defp woe_server_child, do: [Aesir.ZoneServer.Mmo.Woe.Server]
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

  # Excluded in test: a real scheduler would fire `Woe.Server.start/0`/`stop/0`
  # on real wall-clock edges during the suite; `Woe.Scheduler` is unit/integration
  # tested via `start_supervised!/1` with an injected `now_fun` instead.
  if Mix.env() == :test do
    defp woe_scheduler_child, do: []
  else
    defp woe_scheduler_child, do: [Aesir.ZoneServer.Mmo.Woe.Scheduler]
  end
end
