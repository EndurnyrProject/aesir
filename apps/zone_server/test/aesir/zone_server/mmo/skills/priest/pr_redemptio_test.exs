defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrRedemptioTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrRedemptio
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defp caster(party_id \\ 0) do
    %{
      character_id: 1_000,
      party_id: party_id,
      x: 100,
      y: 100,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        current_state: %{hp: 1_000, sp: 1_000},
        progression: %{
          base_exp: 123_456,
          job_exp: 65_432,
          job_id: 8,
          learned_skills: %{1014 => 1}
        }
      }
    }
    |> Aesir.ZoneServer.PlayerStateFixture.build()
  end

  defp member(char_id, map_name \\ "prontera") do
    %Member{
      char_id: char_id,
      name: "Member#{char_id}",
      base_level: 99,
      online: true,
      map_name: map_name
    }
  end

  defp party_state(member_ids) do
    %PartyState{
      party_id: 7,
      name: "Priests",
      leader_char_id: 1_000,
      exp_share: false,
      item_pickup_share: false,
      members: Map.new(member_ids, &{&1, member(&1)})
    }
  end

  defp corpse(char_id, x, y, map_name \\ "prontera") do
    %PlayerState{
      character_id: char_id,
      x: x,
      y: y,
      map_name: map_name,
      action_state: :dead,
      stats: %{current_state: %{hp: 0}}
    }
  end

  test "exposes the exact Renewal definition" do
    assert {:ok, definition} = Catalog.by_id(1014)

    assert definition.name == :pr_redemptio
    assert definition.max_level == 1
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :magic
    assert definition.element == :holy
    assert definition.splash_radius == 14
    assert definition.cast_time == [3_200]
    assert definition.fixed_cast_time == [800]
    assert definition.sp_cost == [800]
    assert definition.ignore_dex

    assert CastTime.compute(definition, 1, %{dex: 200, int: 200}) == %{
             fixed: 800,
             variable: 2_400,
             total: 3_200
           }
  end

  test "requires party membership" do
    assert {:error, :party_required} =
             PrRedemptio.cast(caster(), :self, 1, PrRedemptio.definition())
  end

  test "is catalogued but unavailable through ordinary Priest skill-point learning" do
    progression = %PlayerProgression{
      base_level: 99,
      job_level: 50,
      base_exp: 0,
      job_exp: 0,
      job_id: 8,
      skill_point: 1,
      status_point: 0,
      learned_skills: %{}
    }

    assert {:error, :not_in_tree} = SkillTree.can_learn(progression, 1014)
  end

  test "revives a nearby same-map party corpse at 50 percent and leaves the caster at one HP" do
    target_pid = self()
    target = corpse(2_000, 114, 100)

    stub(PartyManager, :get, fn 7 -> {:ok, party_state([1_000, 2_000])} end)

    stub(UnitRegistry, :get_unit, fn :player, 2_000 ->
      {:ok, {PlayerState, target, target_pid}}
    end)

    expect(PlayerSession, :resurrect, fn ^target_pid, 1_000, 50 -> :ok end)

    assert {:ok, updated} =
             PrRedemptio.cast(caster(7), :self, 1, PrRedemptio.definition())

    assert updated.stats.current_state.hp == 1
    assert updated.stats.current_state.sp == 1_000
    assert updated.stats.progression.base_exp == 123_456
    assert updated.stats.progression.job_exp == 65_432
  end

  test "Renewal completion charges only the normal 800 SP cost and no experience" do
    target_pid = self()
    target = corpse(2_000, 114, 100)

    stub(PartyManager, :get, fn 7 -> {:ok, party_state([1_000, 2_000])} end)

    stub(UnitRegistry, :get_unit, fn :player, 2_000 ->
      {:ok, {PlayerState, target, target_pid}}
    end)

    stub(PlayerSession, :resurrect, fn ^target_pid, 1_000, 50 -> :ok end)
    stub(ModifierCalculator, :get_all_modifiers, fn :player, 1_000 -> %{} end)

    assert {:ok, updated} = Interpreter.complete_cast(caster(7), 1014, 1, :self)

    assert updated.stats.current_state == %CurrentState{hp: 1, sp: 200}
    assert updated.stats.progression.base_exp == 123_456
    assert updated.stats.progression.job_exp == 65_432
  end

  test "fails without changing caster HP when no party corpse is eligible" do
    living = %{
      corpse(2_000, 101, 100)
      | action_state: :idle,
        stats: %{current_state: %{hp: 100}}
    }

    out_of_range = corpse(2_001, 115, 100)
    other_map = corpse(2_002, 101, 100, "geffen")

    stub(PartyManager, :get, fn 7 -> {:ok, party_state([1_000, 2_000, 2_001, 2_002])} end)

    stub(UnitRegistry, :get_unit, fn
      :player, 2_000 -> {:ok, {PlayerState, living, self()}}
      :player, 2_001 -> {:ok, {PlayerState, out_of_range, self()}}
      :player, 2_002 -> {:ok, {PlayerState, other_map, self()}}
    end)

    reject(&PlayerSession.resurrect/3)
    original = caster(7)

    assert {:error, :no_targets} =
             PrRedemptio.cast(original, :self, 1, PrRedemptio.definition())

    assert original.stats.current_state.hp == 1_000
  end

  test "counts corpses before revival attempts and tries every eligible target" do
    test_pid = self()
    first_pid = spawn(fn -> Process.sleep(:infinity) end)
    second_pid = spawn(fn -> Process.sleep(:infinity) end)
    first = corpse(2_000, 114, 100)
    second = corpse(2_001, 100, 86)

    on_exit(fn ->
      Process.exit(first_pid, :kill)
      Process.exit(second_pid, :kill)
    end)

    stub(PartyManager, :get, fn 7 -> {:ok, party_state([1_000, 2_000, 2_001])} end)

    stub(UnitRegistry, :get_unit, fn
      :player, 2_000 -> {:ok, {PlayerState, first, first_pid}}
      :player, 2_001 -> {:ok, {PlayerState, second, second_pid}}
    end)

    stub(PlayerSession, :resurrect, fn target_pid, 1_000, 50 ->
      send(test_pid, {:revival_attempt, target_pid})
      if target_pid == first_pid, do: {:error, :target_not_found}, else: :ok
    end)

    assert {:ok, updated} =
             PrRedemptio.cast(caster(7), :self, 1, PrRedemptio.definition())

    assert updated.stats.current_state.hp == 1
    assert_received {:revival_attempt, ^first_pid}
    assert_received {:revival_attempt, ^second_pid}
  end
end
