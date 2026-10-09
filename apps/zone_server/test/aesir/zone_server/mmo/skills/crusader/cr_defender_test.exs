defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefenderTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefender
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Defender
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :set_mimic_from_context
  setup :verify_on_exit!

  @caster_id 3100
  @shield_id 2109
  @two_handed_spear_id 1424

  defp caster(equipment \\ %Equipment{}),
    do: %PlayerState{character_id: @caster_id, stats: %{equipment: equipment}}

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1004,
      aegis_name: "test_crusader",
      name: "Test Crusader",
      level: 50,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1004,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9003, mob_data, spawn_ref, "prontera", 100, 100)
  end

  describe "validate/4 (player shield gate)" do
    test "rejects a cast without a shield equipped" do
      assert {:error, :requires_shield} = CrDefender.validate(caster(), :self, 1, %{})
    end

    test "allows a cast with a shield equipped" do
      assert :ok =
               CrDefender.validate(
                 caster(%Equipment{left_hand: @shield_id}),
                 :self,
                 1,
                 %{}
               )
    end

    test "rejects a cast with a two-handed weapon occupying the left hand" do
      assert {:error, :requires_shield} =
               CrDefender.validate(
                 caster(%Equipment{left_hand: @two_handed_spear_id}),
                 :self,
                 1,
                 %{}
               )
    end
  end

  describe "validate/4 (mob caster bypass)" do
    test "always allows a mob caster regardless of equipment" do
      assert :ok = CrDefender.validate(mob_caster(), :self, 1, %{})
    end
  end

  describe "cast/4" do
    test "toggles sc_defender on the caster with val1 set to the skill level" do
      caster = caster(%Equipment{left_hand: @shield_id})

      expect(StatusInterpreter, :toggle_status, fn :player, @caster_id, :sc_defender, opts ->
        assert opts[:val1] == 3
        {:ok, :applied}
      end)

      assert {:ok, ^caster} = CrDefender.cast(caster, :self, 3, %{})
    end

    test "re-casting toggles the status off" do
      caster = caster(%Equipment{left_hand: @shield_id})

      expect(StatusInterpreter, :toggle_status, fn :player, @caster_id, :sc_defender, _opts ->
        {:ok, :removed}
      end)

      assert {:ok, ^caster} = CrDefender.cast(caster, :self, 3, %{})
    end

    test "a mob caster toggles through :mob, not :player" do
      mob = mob_caster()

      expect(StatusInterpreter, :toggle_status, fn :mob, 9003, :sc_defender, opts ->
        assert opts[:val1] == 5
        {:ok, :applied}
      end)

      assert {:ok, ^mob} = CrDefender.cast(mob, :self, 5, %{})
    end

    test "propagates a toggle error" do
      caster = caster(%Equipment{left_hand: @shield_id})

      expect(StatusInterpreter, :toggle_status, fn :player, @caster_id, :sc_defender, _opts ->
        {:error, :status_blocked}
      end)

      assert {:error, :status_blocked} = CrDefender.cast(caster, :self, 1, %{})
    end
  end

  describe "sc_defender modifiers/2" do
    defp entry(val1: level), do: defender(level)

    @tag game_mode: :renewal
    test "lv1 reduces ASPD by 20 and floors the walk delay" do
      assert Defender.modifiers(entry(val1: 1), %{}) == %{aspd: -20, walk_speed_floor: 200}
    end

    @tag game_mode: :renewal
    test "lv5 costs no ASPD" do
      assert %{aspd: 0} = Defender.modifiers(entry(val1: 5), %{})
    end

    @tag game_mode: :pre_renewal
    test "classic takes the ASPD loss as a rate: 20% at lv1, none at lv5" do
      assert Defender.modifiers(entry(val1: 1), %{}) == %{aspd_rate: -20, walk_speed_floor: 200}
      assert %{aspd_rate: 0} = Defender.modifiers(entry(val1: 5), %{})

      refute Map.has_key?(Defender.modifiers(entry(val1: 1), %{}), :aspd)
    end
  end

  describe "sc_defender absorb_damage/4" do
    @long_weapon %{damage: 101, dmg_type: :physical, is_short: false}

    test "removes 5 + 15 per level percent of a long-range weapon hit, truncating the cut" do
      entry = defender(5)
      assert {:ok, 21, ^entry} = Defender.absorb_damage({:player, 1}, entry, @long_weapon, %{})

      entry = defender(1)
      assert {:ok, 81, ^entry} = Defender.absorb_damage({:player, 1}, entry, @long_weapon, %{})
    end

    test "leaves melee weapon and long-range magic hits untouched" do
      entry = defender(5)
      melee = %{@long_weapon | is_short: true}
      magic = %{@long_weapon | dmg_type: :magic}

      assert {:ok, 101, ^entry} = Defender.absorb_damage({:player, 1}, entry, melee, %{})
      assert {:ok, 101, ^entry} = Defender.absorb_damage({:player, 1}, entry, magic, %{})
    end
  end

  defp defender(level) do
    %StatusEntry{
      type: :sc_defender,
      val1: level,
      state: %{reduction: 5 + 15 * level, aspd_penalty: 250 - 50 * level}
    }
  end
end
