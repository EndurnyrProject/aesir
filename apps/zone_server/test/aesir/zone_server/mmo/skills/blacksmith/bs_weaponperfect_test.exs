defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponperfectTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponperfect
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    :ok = Catalog.reload()
  end

  test "exposes the exact level-based duration and SP cost" do
    assert {:ok, definition} = Catalog.by_id(112)
    assert definition.duration == [10_000, 20_000, 30_000, 40_000, 50_000]
    assert definition.sp_cost == [18, 16, 14, 12, 10]
  end

  test "shares Weapon Perfection with nearby party members regardless of weapon" do
    assert {:ok, definition} = Catalog.by_id(112)
    caster = player_state(1, party_id: 10)
    unarmed_member = player_state(2, party_id: 10, x: 164)
    UnitRegistry.register_unit(:player, 2, PlayerState, unarmed_member, self())

    expect(PartyManager, :get, fn 10 -> {:ok, party_state()} end)

    expect(StatusInterpreter, :apply_status, 2, fn
      :player, target_id, :sc_weaponperfection, params when target_id in [1, 2] ->
        assert params == [val1: 4, caster_id: 1, duration: 40_000]
        :ok
    end)

    assert {:ok, ^caster} = BsWeaponperfect.cast(caster, :self, 4, definition)
  end

  test "a party member buffed by the cast takes no size penalty with a dagger" do
    assert {:ok, definition} = Catalog.by_id(112)
    caster = player_state(1, party_id: 10)
    member = player_state(2, party_id: 10, x: 164)
    UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    UnitRegistry.register_unit(:player, 2, PlayerState, member, self())

    expect(PartyManager, :get, fn 10 -> {:ok, party_state()} end)

    assert {:ok, 600.0} =
             DamageCalculator.apply_modifier_pipeline(1_200, dagger_combatant(2), large_target())

    assert {:ok, ^caster} = BsWeaponperfect.cast(caster, :self, 4, definition)

    assert {:ok, 1_200.0} =
             DamageCalculator.apply_modifier_pipeline(1_200, dagger_combatant(2), large_target())
  end

  defp dagger_combatant(player_id) do
    stats =
      %Stats{
        base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
        progression: %{base_level: 0, job_level: 0, learned_skills: %{}},
        derived_stats: %{max_hp: 1, max_sp: 1},
        equipment: %Equipment{},
        modifiers: %{
          equipment: %{},
          status_effects: %{},
          statuses_active?: false,
          job_bonuses: %{}
        }
      }
      |> Stats.apply_status_effects(player_id)
      |> Stats.calculate_combat_stats()

    %{
      CombatTestHelper.create_player_combatant(unit_id: player_id, weapon_type: :dagger)
      | combat_stats: stats.combat_stats
    }
  end

  defp large_target, do: CombatTestHelper.create_mob_combatant(size: :large)

  defp player_state(char_id, opts) do
    %Character{
      id: char_id,
      account_id: char_id,
      name: "Char#{char_id}",
      last_map: "prontera",
      last_x: Keyword.get(opts, :x, 150),
      last_y: 150,
      class: 0,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: Keyword.fetch!(opts, :party_id)
    }
    |> PlayerState.new()
  end

  defp party_state do
    %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => Member.new(1, "Char1", 100, true, "prontera"),
        2 => Member.new(2, "Char2", 100, true, "prontera")
      }
    }
  end
end
