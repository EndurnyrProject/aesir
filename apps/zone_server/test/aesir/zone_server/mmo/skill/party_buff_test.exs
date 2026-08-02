defmodule Aesir.ZoneServer.Mmo.Skill.PartyBuffTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  defp player_state(char_id, opts) do
    %Character{
      id: char_id,
      account_id: char_id,
      name: "Char#{char_id}",
      last_map: Keyword.get(opts, :map, "prontera"),
      last_x: Keyword.get(opts, :x, 150),
      last_y: Keyword.get(opts, :y, 150),
      class: 0,
      base_level: Keyword.get(opts, :base_level, 100),
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: Keyword.get(opts, :party_id, 0)
    }
    |> PlayerState.new()
  end

  defp member(char_id, online \\ true) do
    Member.new(char_id, "Char#{char_id}", 100, online, "prontera")
  end

  defp party(members) do
    %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: false,
      item_pickup_share: false,
      members: Map.new(members, &{&1.char_id, &1})
    }
  end

  test "applies the caller-provided params to the caster without a party" do
    caster = player_state(1, party_id: 0)
    params = [val1: 3, caster_id: 1, duration: 12_345]

    reject(&PartyManager.get/1)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_gloria, ^params -> :ok end)

    assert :ok = PartyBuff.apply(caster, :sc_gloria, params, 18)
  end

  test "skips offline party members" do
    caster = player_state(1, party_id: 10)
    offline = player_state(2, party_id: 10, x: 151)
    params = [caster_id: 1, duration: 10_000]

    UnitRegistry.register_unit(:player, 2, PlayerState, offline, self())
    expect(PartyManager, :get, fn 10 -> {:ok, party([member(1), member(2, false)])} end)
    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_gloria, ^params -> :ok end)

    assert :ok = PartyBuff.apply(caster, :sc_gloria, params, 18)
  end

  test "applies identical params only to eligible nearby party members" do
    caster = player_state(1, party_id: 10)
    eligible = player_state(2, party_id: 10, x: 160, base_level: 42)
    ineligible = player_state(3, party_id: 10, x: 160, base_level: 7)
    params = [val1: 2, caster_id: 1, duration: 22_000]

    UnitRegistry.register_unit(:player, 2, PlayerState, eligible, self())
    UnitRegistry.register_unit(:player, 3, PlayerState, ineligible, self())
    expect(PartyManager, :get, fn 10 -> {:ok, party([member(1), member(2), member(3)])} end)

    expect(StatusInterpreter, :apply_status, 2, fn
      :player, target_id, :sc_gloria, ^params when target_id in [1, 2] -> :ok
    end)

    assert :ok =
             PartyBuff.apply(caster, :sc_gloria, params, 18, fn candidate ->
               candidate.character_id == 2
             end)
  end
end
