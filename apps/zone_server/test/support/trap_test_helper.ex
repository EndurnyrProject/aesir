defmodule Aesir.ZoneServer.TrapTestHelper do
  @moduledoc """
  Living unit fixtures for trap `unit_targets/3` and `on_unit_hit/4` tests.

  `stub_units/1` resolves `UnitRegistry.get_unit/2` from the given states, so
  the trap's caster check, living check and hostility check run on real
  player and monster shapes without a session or a registered world.
  """

  import Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"

  @doc "An armed trap's lifecycle state, paying back one trap item."
  def armed_trap(attrs \\ []) do
    {:ok, trap} = TrapState.new(Keyword.merge([reclaim_item_id: 1065], attrs))
    trap
  end

  @doc "A living player at `{50, 50}`."
  def player(id, attrs \\ %{}) do
    PlayerStateFixture.build(
      Map.merge(
        %{character_id: id, account_id: id, map_name: @map, x: 50, y: 50, stats: %{}},
        attrs
      )
    )
  end

  @doc "A living monster at `{50, 50}`; `modes:` and `race:` shape boss/plant/immune cases."
  def mob(id, opts \\ []) do
    definition = %MobDefinition{
      id: 1002,
      aegis_name: "TRAP_TEST_MOB",
      name: "Trap Test Mob",
      level: Keyword.get(opts, :level, 20),
      hp: 1_000,
      sp: 50,
      stats: %{str: 10, agi: Keyword.get(opts, :agi, 10), vit: 10, int: 5, dex: 10, luk: 5},
      attack_range: 1,
      size: :medium,
      race: Keyword.get(opts, :race, :formless),
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      modes: Keyword.get(opts, :modes, [])
    }

    spawn = %MobSpawn{
      mob: definition.id,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 50, y: 50}
    }

    MobState.new(id, definition, spawn, @map, 50, 50)
  end

  @doc "A living, active Homunculus owned by `owner_id`."
  def homunculus(id, owner_id) do
    %HomunculusState{
      id: id,
      world_gid: id,
      owner_character_id: owner_id,
      class_id: 6001,
      name: "Trap Test Homunculus",
      lifecycle: :active,
      action_state: :idle,
      hp: 100,
      map_name: "prontera",
      x: 50,
      y: 50
    }
  end

  @doc "Resolves `UnitRegistry.get_unit/2` from the given unit states only."
  def stub_units(states) do
    units = Map.new(states, fn state -> {ref(state), state} end)

    stub(UnitRegistry, :get_unit, fn type, id ->
      case Map.fetch(units, {type, id}) do
        {:ok, %module{} = state} -> {:ok, {module, state, self()}}
        :error -> {:error, :not_found}
      end
    end)
  end

  defp ref(%PlayerState{character_id: id}), do: {:player, id}
  defp ref(%MobState{instance_id: id}), do: {:mob, id}
  defp ref(%HomunculusState{world_gid: id}), do: {:homunculus, id}
end
