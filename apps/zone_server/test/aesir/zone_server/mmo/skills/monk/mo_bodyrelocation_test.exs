defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBodyrelocationTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoBodyrelocation
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(Cell)
    Mimic.copy(StatusStorage)
    :ok
  end

  test "declares Renewal Snap range and costs" do
    {:ok, definition} = Catalog.by_id(264)

    assert definition.range == 18
    assert definition.sp_cost == [14]
    assert definition.sphere_cost == [1]
    assert definition.target_type == :ground
  end

  test "stages a validated destination without moving before commitment" do
    stub(Cell, :traversable?, fn "prontera", 14, 17 -> true end)
    caster = %PlayerState{map_name: "prontera", x: 10, y: 13}
    {:ok, definition} = Catalog.by_id(264)

    assert {:ok, updated} = MoBodyrelocation.cast(caster, {:ground, 14, 17}, 1, definition)
    assert updated.x == 10
    assert updated.y == 13
    assert %ForcedMovement{map_name: "prontera", x: 14, y: 17} = updated.pending_forced_movement
  end

  test "Fury removes only Snap's sphere cost" do
    stub(StatusStorage, :get_status, fn :player, 4000, :sc_explosionspirits ->
      %StatusEntry{expires_at: System.monotonic_time(:millisecond) + 1_000}
    end)

    {:ok, definition} = Catalog.by_id(264)
    caster = %PlayerState{character_id: 4000, stats: %{current_state: %{sp: 20}}}

    assert %Cost{hp: 0, sp: 14, spheres: 0} =
             MoBodyrelocation.dynamic_cost(caster, {:ground, 14, 17}, 1, definition)
  end

  test "an expired Fury row does not remove Snap's sphere cost" do
    :ok =
      StatusStorage.apply_status(
        :player,
        4000,
        :sc_explosionspirits,
        duration: 1_000
      )

    :ok =
      StatusStorage.update_status(
        :player,
        4000,
        :sc_explosionspirits,
        &%{&1 | expires_at: System.monotonic_time(:millisecond) - 1}
      )

    {:ok, definition} = Catalog.by_id(264)
    caster = %PlayerState{character_id: 4000, stats: %{current_state: %{sp: 20}}}

    assert %Cost{hp: 0, sp: 14, spheres: 1} =
             MoBodyrelocation.dynamic_cost(caster, {:ground, 14, 17}, 1, definition)
  end

  test "invalid destinations fail before staging" do
    stub(Cell, :traversable?, fn "prontera", 14, 17 -> false end)
    caster = %PlayerState{map_name: "prontera", x: 10, y: 13}
    {:ok, definition} = Catalog.by_id(264)

    assert {:error, :invalid_destination} =
             MoBodyrelocation.cast(caster, {:ground, 14, 17}, 1, definition)

    assert caster.pending_forced_movement == nil
  end
end
