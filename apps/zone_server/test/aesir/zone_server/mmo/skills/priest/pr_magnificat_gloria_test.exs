defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnificatGloriaTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrGloria
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnificat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

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

  defp player_state(char_id, opts), do: PlayerState.new(character(char_id, opts))

  defp register_member(char_id, opts) do
    state = player_state(char_id, opts)

    state =
      if Keyword.get(opts, :dead, false) do
        state
        |> put_in([Access.key!(:stats), Access.key!(:current_state), Access.key!(:hp)], 0)
        |> Map.put(:action_state, :dead)
      else
        state
      end

    UnitRegistry.register_unit(:player, char_id, PlayerState, state, self())
  end

  defp party_member(char_id, map_name),
    do: Member.new(char_id, "Char#{char_id}", 100, true, map_name)

  defp party_state do
    %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      members: %{
        1 => party_member(1, "prontera"),
        2 => party_member(2, "prontera")
      }
    }
  end

  test "Magnificat exposes the exact Renewal definition" do
    assert {:ok, definition} = Catalog.by_id(74)
    assert definition.name == :pr_magnificat
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.splash_radius == 18
    assert definition.cast_time == List.duplicate(3_200, 5)
    assert definition.fixed_cast_time == List.duplicate(800, 5)
    assert definition.after_cast_delay == List.duplicate(2_000, 5)
    assert definition.duration == [30_000, 45_000, 60_000, 75_000, 90_000]
    assert definition.sp_cost == List.duplicate(40, 5)
  end

  test "Gloria exposes the exact Renewal definition" do
    assert {:ok, definition} = Catalog.by_id(75)
    assert definition.name == :pr_gloria
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.damage_type == :no_damage
    assert definition.splash_radius == 18
    assert definition.cast_time == List.duplicate(0, 5)
    assert definition.fixed_cast_time == List.duplicate(0, 5)
    assert definition.after_cast_delay == List.duplicate(2_000, 5)
    assert definition.duration == [10_000, 15_000, 20_000, 25_000, 30_000]
    assert definition.sp_cost == List.duplicate(20, 5)
  end

  test "both skills are runtime-discoverable active skills" do
    assert {:ok, PrMagnificat} = Catalog.active_module_for(:pr_magnificat)
    assert {:ok, PrGloria} = Catalog.active_module_for(:pr_gloria)
  end

  test "Magnificat applies its selected Renewal duration to the caster" do
    assert {:ok, definition} = Catalog.by_id(74)
    caster = %{character_id: 500, party_id: 0}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_magnificat, params ->
      assert params[:val1] == 3
      assert params[:caster_id] == 500
      assert params[:duration] == 60_000
      :ok
    end)

    assert {:ok, ^caster} = PrMagnificat.cast(caster, :self, 3, definition)
  end

  test "Gloria applies its selected Renewal duration to the caster" do
    assert {:ok, definition} = Catalog.by_id(75)
    caster = %{character_id: 500, party_id: 0}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_gloria, params ->
      assert params[:val1] == 4
      assert params[:caster_id] == 500
      assert params[:duration] == 25_000
      :ok
    end)

    assert {:ok, ^caster} = PrGloria.cast(caster, :self, 4, definition)
  end

  test "Magnificat reaches a living same-map party member within 18 cells" do
    assert {:ok, definition} = Catalog.by_id(74)
    caster = player_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    assert :ok = register_member(2, map: "prontera", x: 168, y: 150)
    expect(PartyManager, :get, fn 10 -> {:ok, party_state()} end)

    expect(StatusInterpreter, :apply_status, 2, fn :player, target_id, :sc_magnificat, params ->
      assert target_id in [1, 2]
      assert params[:caster_id] == 1
      assert params[:duration] == 30_000
      :ok
    end)

    assert {:ok, ^caster} = PrMagnificat.cast(caster, :self, 1, definition)
  end

  test "Gloria reaches a living same-map party member within 18 cells" do
    assert {:ok, definition} = Catalog.by_id(75)
    caster = player_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    assert :ok = register_member(2, map: "prontera", x: 168, y: 150)
    expect(PartyManager, :get, fn 10 -> {:ok, party_state()} end)

    expect(StatusInterpreter, :apply_status, 2, fn :player, target_id, :sc_gloria, params ->
      assert target_id in [1, 2]
      assert params[:caster_id] == 1
      assert params[:duration] == 15_000
      :ok
    end)

    assert {:ok, ^caster} = PrGloria.cast(caster, :self, 2, definition)
  end

  test "both buffs exclude corpses, distant members, cross-map members, and missing snapshots" do
    caster = player_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    assert :ok = register_member(2, map: "prontera", x: 155, y: 150, dead: true)
    assert :ok = register_member(3, map: "prontera", x: 169, y: 150)
    assert :ok = register_member(4, map: "geffen", x: 150, y: 150)

    members =
      Map.new(1..5, fn char_id ->
        map_name = if char_id == 4, do: "geffen", else: "prontera"
        {char_id, party_member(char_id, map_name)}
      end)

    party = %{party_state() | members: members}
    stub(PartyManager, :get, fn 10 -> {:ok, party} end)
    test_pid = self()

    stub(StatusInterpreter, :apply_status, fn :player, target_id, status, _params ->
      send(test_pid, {status, target_id})
      :ok
    end)

    for {skill, skill_id} <- [{PrMagnificat, 74}, {PrGloria, 75}] do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:ok, ^caster} = skill.cast(caster, :self, 1, definition)
    end

    assert_received {:sc_magnificat, 1}
    assert_received {:sc_gloria, 1}

    for status <- [:sc_magnificat, :sc_gloria], target_id <- 2..5 do
      refute_received {^status, ^target_id}
    end
  end

  test "a rejected caster application does not attempt party propagation" do
    caster = player_state(1, party_id: 10, map: "prontera", x: 150, y: 150)
    reject(&PartyManager.get/1)

    expect(StatusInterpreter, :apply_status, 2, fn
      :player, 1, status, _params when status in [:sc_magnificat, :sc_gloria] ->
        {:error, :prevented}
    end)

    for {skill, skill_id} <- [{PrMagnificat, 74}, {PrGloria, 75}] do
      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert {:error, :prevented} = skill.cast(caster, :self, 1, definition)
    end
  end
end
