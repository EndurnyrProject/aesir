defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkAurabladeTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkAurablade
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "catalog resolves Aura Blade and a sword caster applies its status" do
    assert {:ok, definition} = Catalog.by_name(:lk_aurablade)
    assert definition.id == 355
    assert definition.sp_cost == [18, 26, 34, 42, 50]

    player = player()
    assert {:error, :wrong_weapon} = LkAurablade.validate(player, :self, 3, definition)
    sword = put_in(player.stats.equipment, %Equipment{right_hand: 1101})
    assert :ok = LkAurablade.validate(sword, :self, 3, definition)
    :ok = UnitRegistry.register_player(sword, self())

    assert {:ok, ^sword} = LkAurablade.cast(sword, :self, 3, definition)
    assert %{val1: 3} = StatusStorage.get_status(:player, sword.character_id, :sc_aurablade)
  end

  test "mob caster bypasses the player weapon gate" do
    mob_data = %MobDefinition{
      id: 1003,
      aegis_name: "test_lk",
      name: "Test LK",
      level: 50,
      hp: 1_000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn = %MobSpawn{
      mob: 1003,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 50, y: 50}
    }

    mob = MobState.new(9_001, mob_data, spawn, "prontera", 50, 50)
    assert :ok = LkAurablade.validate(mob, :self, 1, %{})
  end

  defp player do
    PlayerState.new(%Character{
      id: 5_001,
      account_id: 5_002,
      name: "LK",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 90,
      job_level: 50,
      class: 7
    })
  end
end
