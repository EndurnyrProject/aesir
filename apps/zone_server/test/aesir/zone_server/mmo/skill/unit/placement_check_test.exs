defmodule Aesir.ZoneServer.Mmo.Skill.Unit.PlacementCheckTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.PlacementCheck
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @map "prontera"
  @caster {:player, 1}

  defp definition(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition
  end

  defp place(group_id, name, {x, y}, caster \\ {:player, 2}) do
    {caster_type, caster_id} = caster

    :ok =
      Storage.insert(%Group{
        group_id: group_id,
        skill_id: definition(name).id,
        skill_name: name,
        level: 1,
        caster_type: caster_type,
        caster_id: caster_id,
        map_name: @map,
        center: {x, y},
        cells: [{x, y}],
        visibility: :public,
        expires_at: 1_000_000,
        state: %{}
      })
  end

  defp check(name, cell, opts \\ []) do
    PlacementCheck.check(
      definition(name),
      Keyword.get(opts, :caster, @caster),
      @map,
      cell,
      Keyword.get(opts, :as, :player)
    )
  end

  defp add_dead_player(id, {x, y}) do
    state =
      PlayerStateFixture.build(%{
        character_id: id,
        map_name: @map,
        x: x,
        y: y,
        action_state: :dead,
        stats: %{current_state: %{hp: 0}}
      })

    :ok = UnitRegistry.register_unit(:player, id, PlayerState, state, self())
    :ok = SpatialIndex.add_unit(:player, id, x, y, @map)
  end

  defp add_mob(id, {x, y}, mob_id) do
    state = %MobState{
      instance_id: id,
      mob_id: mob_id,
      mob_data: %{},
      spawn_ref: nil,
      map_name: @map,
      x: x,
      y: y,
      hp: 10,
      max_hp: 10,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, id, x, y, @map)
  end

  describe "reiteration" do
    test "a player's trap reaches one cell around the target, a monster's only the cell" do
      place(1, :ht_anklesnare, {101, 101})

      assert {:error, :unit_placement_refused} = check(:ht_landmine, {100, 100})
      assert :ok = check(:ht_landmine, {100, 100}, caster: {:mob, 9}, as: :mob)

      assert {:error, :unit_placement_refused} =
               check(:ht_landmine, {101, 101}, caster: {:mob, 9}, as: :mob)
    end

    test "Warp Portal is blocked by Venom Dust, Scribble only by Scribble" do
      place(1, :as_venomdust, {100, 100})

      assert {:error, :unit_placement_refused} = check(:al_warp, {100, 100})
      assert :ok = check(:rg_graffiti, {100, 100})
    end

    test "Pneuma is blocked by Land Protector anywhere in its 3x3 and by Safety Wall" do
      place(1, :sa_landprotector, {101, 99})
      assert {:error, :unit_placement_refused} = check(:al_pneuma, {100, 100})

      place(2, :mg_safetywall, {110, 110})
      assert {:error, :unit_placement_refused} = check(:al_pneuma, {111, 111})
      assert :ok = check(:mg_safetywall, {111, 111})
    end
  end

  describe "foot set" do
    test "a living character one cell away blocks a player's trap; a monster's cast is not checked" do
      add_mob(500, {101, 100}, 1002)

      assert {:error, :unit_placement_refused} = check(:ht_landmine, {100, 100})
      assert :ok = check(:ht_landmine, {100, 100}, caster: {:mob, 9}, as: :mob)
    end

    test "a dead player blocks Warp Portal only" do
      add_dead_player(7, {100, 100})

      assert :ok = check(:ht_landmine, {100, 100})
      assert {:error, :unit_placement_refused} = check(:al_warp, {100, 100})
    end

    test "Demonstration ignores the Emperium" do
      add_mob(500, {100, 100}, 1288)
      assert :ok = check(:am_demonstration, {100, 100})
    end
  end

  describe "active instances" do
    test "a player or homunculus at the limit is refused, a monster never" do
      for {id, x} <- [{1, 100}, {2, 110}, {3, 120}],
          do: place(id, :mg_firewall, {x, 100}, @caster)

      assert {:error, :unit_placement_refused} = check(:mg_firewall, {130, 100})
      assert :ok = check(:mg_firewall, {130, 100}, caster: {:player, 2})

      for {id, x} <- [{4, 140}, {5, 150}, {6, 160}],
          do: place(id, :mg_firewall, {x, 100}, {:homunculus, 3})

      assert {:error, :unit_placement_refused} =
               check(:mg_firewall, {130, 100}, caster: {:homunculus, 3}, as: :homunculus)

      for {id, x} <- [{7, 170}, {8, 180}, {9, 190}],
          do: place(id, :mg_firewall, {x, 100}, {:mob, 4})

      assert :ok = check(:mg_firewall, {130, 100}, caster: {:mob, 4}, as: :mob)
    end
  end
end
