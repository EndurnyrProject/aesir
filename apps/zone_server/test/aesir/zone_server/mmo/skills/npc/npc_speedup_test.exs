defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSpeedupTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcSpeedup
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  test "speeds the trick-casting mob up while more than 700 ms are left" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 3_000, last_skillcheck: now)

    assert {:ok, faster} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert faster.walk_speed == 550
    assert faster.trickcasting == mob.trickcasting
    assert faster.last_skillcheck == now
    assert faster.can_escape
  end

  test "lowers the base speed and keeps its statuses on top" do
    now = System.system_time(:millisecond)

    mob =
      70_007
      |> MobState.new(mob_data(), spawn_ref(), "prontera", 30, 30)
      |> Map.merge(%{base_walk_speed: 800, trickcasting: now + 3_000, last_skillcheck: now})

    UnitRegistry.register_unit(:mob, 70_007, MobState, mob, self())
    :ok = StatusStorage.apply_status(:mob, 70_007, :sc_decreaseagi, val1: 1, duration: 60_000)

    on_exit(fn ->
      StatusStorage.remove_status(:mob, 70_007, :sc_decreaseagi)
      UnitRegistry.unregister_unit(:mob, 70_007)
    end)

    assert {:ok, faster} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert faster.base_walk_speed == 550
    # Decrease AGI's 25% slow on the lowered base: 550 * 125 / 100.
    assert faster.walk_speed == 687
  end

  test "the last interval delays the next skill check by 100 ms" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 1_200, last_skillcheck: now)

    assert {:ok, faster} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert faster.walk_speed == 550
    assert faster.last_skillcheck in (now + 100)..(System.system_time(:millisecond) + 100)
  end

  test "never drops below the minimum walk speed" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 3_000, walk_speed: 100)

    assert {:ok, %MobState{walk_speed: 20}} =
             NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})
  end

  test "under 700 ms left it ends the trick cast and the escape" do
    now = System.system_time(:millisecond)
    mob = mob(trickcasting: now + 500, last_skillcheck: now)

    assert {:ok, stopped} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert stopped.walk_speed == 800
    assert stopped.trickcasting == nil
    assert stopped.last_skillcheck == now + 500
    refute stopped.can_escape
  end

  test "without a trick cast it only resets the escape" do
    mob = mob(trickcasting: nil, last_skillcheck: 123)

    assert {:ok, stopped} = NpcSpeedup.mob_cast(mob, {:unit, :mob, 7}, 1, definition(), %{})

    assert stopped.walk_speed == 800
    assert stopped.last_skillcheck == 0
    refute stopped.can_escape
  end

  test "only a monster casts it" do
    assert {:error, :mob_only} = NpcSpeedup.cast(mob([]), {:unit, 7}, 1, definition())
  end

  defp definition, do: NpcSpeedup.definition()

  defp mob_data do
    struct!(MobDefinition, %{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 800,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    })
  end

  defp spawn_ref do
    struct!(MobSpawn, %{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: struct!(SpawnArea, %{x: 30, y: 30})
    })
  end

  defp mob(fields) do
    fields = Keyword.merge([mob_id: 1142, walk_speed: 800, can_escape: true], fields)

    7
    |> MobState.new(mob_data(), spawn_ref(), "prontera", 30, 30)
    |> struct(Keyword.put_new(fields, :base_walk_speed, fields[:walk_speed]))
  end
end
