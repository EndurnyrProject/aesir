defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrImpositioSuffragiumTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrImpositio
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrSuffragium
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  test "Impositio Manus exposes its exact Renewal metadata" do
    assert {:ok, definition} = Catalog.by_id(66)

    assert definition.name == :pr_impositio
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.splash_radius == 18
    assert definition.sp_cost == [59, 62, 65, 68, 71]
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == List.duplicate(500, 5)
    assert definition.after_cast_delay == List.duplicate(1_000, 5)
    assert definition.cooldown == List.duplicate(30_000, 5)
    assert definition.duration == List.duplicate(120_000, 5)
  end

  test "Suffragium exposes its exact Renewal metadata" do
    assert {:ok, definition} = Catalog.by_id(67)

    assert definition.name == :pr_suffragium
    assert definition.max_level == 3
    assert definition.target_type == :self
    assert definition.splash_radius == 18
    assert definition.sp_cost == [8, 8, 8]
    assert definition.cast_time == [1_000, 1_000, 1_000]
    assert definition.fixed_cast_time == [500, 500, 500]
    assert definition.after_cast_delay == [1_000, 1_000, 1_000]
    assert definition.cooldown == [30_000, 30_000, 30_000]
    assert definition.duration == [60_000, 60_000, 60_000]
  end

  test "Impositio Manus applies exact parameters to eligible nearby party members" do
    {:ok, definition} = Catalog.by_id(66)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    register_member(2, map: "prontera", x: 160, y: 150)

    expect(PartyManager, :get, fn 10 -> {:ok, party(1, 2)} end)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_impositio, params ->
      assert params == [val1: 5, val2: 25, caster_id: 1, duration: 120_000]
      :ok
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 2, :sc_impositio, params ->
      assert params == [val1: 5, val2: 25, caster_id: 1, duration: 120_000]
      :ok
    end)

    assert {:ok, ^caster} = PrImpositio.cast(caster, :self, 5, definition)
  end

  test "Suffragium applies exact parameters to eligible nearby party members" do
    {:ok, definition} = Catalog.by_id(67)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    register_member(2, map: "prontera", x: 160, y: 150)

    expect(PartyManager, :get, fn 10 -> {:ok, party(1, 2)} end)

    for target_id <- [1, 2] do
      expect(StatusInterpreter, :apply_status, fn :player, ^target_id, :sc_suffragium, params ->
        assert params == [val1: 3, caster_id: 1, duration: 60_000]
        :ok
      end)
    end

    assert {:ok, ^caster} = PrSuffragium.cast(caster, :self, 3, definition)
  end

  test "Suffragium only affects the caster without a party" do
    {:ok, definition} = Catalog.by_id(67)
    caster = caster_state(1, party_id: 0)

    reject(&PartyManager.get/1)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_suffragium, params ->
      assert params == [val1: 3, caster_id: 1, duration: 60_000]
      :ok
    end)

    assert {:ok, ^caster} = PrSuffragium.cast(caster, :self, 3, definition)
  end

  test "Impositio Manus only affects the caster without a party" do
    {:ok, definition} = Catalog.by_id(66)
    caster = caster_state(1, party_id: 0)

    reject(&PartyManager.get/1)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_impositio, params ->
      assert params == [val1: 2, val2: 10, caster_id: 1, duration: 120_000]
      :ok
    end)

    assert {:ok, ^caster} = PrImpositio.cast(caster, :self, 2, definition)
  end

  test "Suffragium skips dead, distant, cross-map, and missing party members" do
    assert_ineligible_members_skipped(PrSuffragium, 67, :sc_suffragium)
  end

  test "Impositio Manus skips dead, distant, cross-map, and missing party members" do
    assert_ineligible_members_skipped(PrImpositio, 66, :sc_impositio)
  end

  test "Impositio Manus does not propagate when its caster cannot receive the status" do
    {:ok, definition} = Catalog.by_id(66)
    caster = caster_state(1, party_id: 10)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_impositio, _params ->
      {:error, :prevented}
    end)

    reject(&PartyManager.get/1)

    assert {:error, :prevented} = PrImpositio.cast(caster, :self, 1, definition)
  end

  defp character(char_id, opts) do
    %Character{
      id: char_id,
      account_id: char_id,
      name: "Char#{char_id}",
      last_map: Keyword.get(opts, :map, "prontera"),
      last_x: Keyword.get(opts, :x, 150),
      last_y: Keyword.get(opts, :y, 150),
      class: 0,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 7,
      party_id: Keyword.get(opts, :party_id, 0)
    }
  end

  defp caster_state(char_id, opts), do: PlayerState.new(character(char_id, opts))

  defp register_member(char_id, opts) do
    state = PlayerState.new(character(char_id, opts))

    state =
      if Keyword.get(opts, :dead, false) do
        put_in(state.stats.current_state.hp, 0)
      else
        state
      end

    UnitRegistry.register_unit(:player, char_id, PlayerState, state, self())
  end

  defp party_member(char_id, map_name),
    do: Member.new(char_id, "Char#{char_id}", 100, true, map_name)

  defp party(caster_id, member_id) do
    %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: caster_id,
      exp_share: false,
      members: %{
        caster_id => party_member(caster_id, "prontera"),
        member_id => party_member(member_id, "prontera")
      }
    }
  end

  defp assert_ineligible_members_skipped(skill_module, skill_id, status) do
    {:ok, definition} = Catalog.by_id(skill_id)
    caster = caster_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    register_member(2, map: "prontera", x: 169, y: 150)
    register_member(3, map: "geffen", x: 150, y: 150)
    register_member(4, map: "prontera", x: 155, y: 150, dead: true)

    party_state = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: Map.new(1..5, fn char_id -> {char_id, party_member(char_id, "prontera")} end)
    }

    expect(PartyManager, :get, fn 10 -> {:ok, party_state} end)

    expect(StatusInterpreter, :apply_status, fn :player, 1, ^status, _params -> :ok end)

    assert {:ok, ^caster} = skill_module.cast(caster, :self, 1, definition)
  end
end
