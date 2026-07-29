defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcFortunekissTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcFortunekiss
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Lady Luck table" do
    assert {:ok, DcFortunekiss} = Catalog.active_module_for(:dc_fortunekiss)
    assert {:ok, definition} = Catalog.by_id(329)

    assert definition.name == :dc_fortunekiss
    assert definition.display_name == "Lady Luck"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 15
    assert definition.duration == List.duplicate(180_000, 10)
    assert definition.sp_cost == Enum.to_list(40..85//5)
    assert definition.cast_time == List.duplicate(1_000, 10)
    assert definition.fixed_cast_time == List.duplicate(300, 10)
    assert definition.after_cast_delay == List.duplicate(300, 10)
    assert definition.cooldown == List.duplicate(20_000, 10)
  end

  test "snapshots level values that grant critical through the stat pipeline" do
    for {level, expected_critical} <- [{1, 35}, {10, 52}] do
      caster = player(32_900 + level)
      register(caster)

      assert calculate_stats(caster.character_id).combat_stats.critical == 34
      assert {:ok, _result} = DcFortunekiss.cast(caster, :self, level, DcFortunekiss.definition())

      assert %{val1: ^level, expires_at: expires_at, started_at: started_at} =
               StatusStorage.get_status(:player, caster.character_id, :sc_fortunekiss)

      assert expires_at - started_at == 180_000
      assert calculate_stats(caster.character_id).combat_stats.critical == expected_critical
    end
  end

  test "snapshots only living online party members in range and leaves the status after movement" do
    caster = player(101, party_id: 10)
    nearby = player(102, x: 115, y: 115)
    outside = player(103, x: 116)
    late = player(104, x: 105)

    dead =
      player(105, x: 105)
      |> put_in([Access.key(:stats), Access.key(:current_state), Access.key(:hp)], 0)

    offline = player(106, x: 105)
    wrong_map = player(107, x: 105, map: "geffen")
    non_member = player(108, x: 105)

    Enum.each([caster, nearby, outside, dead, offline, wrong_map, non_member], &register/1)

    stub(PartyManager, :get, fn 10 ->
      {:ok,
       %PartyState{
         party_id: 10,
         name: "Lady Luck",
         leader_char_id: 101,
         exp_share: false,
         members: %{
           101 => member(101),
           102 => member(102),
           103 => member(103),
           104 => member(104),
           105 => member(105),
           106 => %{member(106) | online: false},
           107 => member(107, "geffen")
         }
       }}
    end)

    assert {:ok, _result} = DcFortunekiss.cast(caster, :self, 5, DcFortunekiss.definition())

    assert %{val1: 5} = StatusStorage.get_status(:player, 101, :sc_fortunekiss)
    assert %{val1: 5} = StatusStorage.get_status(:player, 102, :sc_fortunekiss)

    for id <- 103..108 do
      refute StatusStorage.has_status?(:player, id, :sc_fortunekiss)
    end

    register(late)
    refute StatusStorage.has_status?(:player, 104, :sc_fortunekiss)

    %{generation: generation, expires_at: expires_at} =
      StatusStorage.get_status(:player, 102, :sc_fortunekiss)

    register(%{nearby | x: 116, y: 100})

    assert %{generation: ^generation, expires_at: ^expires_at} =
             StatusStorage.get_status(:player, 102, :sc_fortunekiss)
  end

  test "an unpartied caster affects only themself" do
    caster = player(201, party_id: 0)
    bystander = player(202, x: 105)
    register(caster)
    register(bystander)

    assert {:ok, _result} = DcFortunekiss.cast(caster, :self, 1, DcFortunekiss.definition())

    assert StatusStorage.has_status?(:player, 201, :sc_fortunekiss)
    refute StatusStorage.has_status?(:player, 202, :sc_fortunekiss)
  end

  defp calculate_stats(character_id) do
    %Stats{
      base_stats: %{str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 99},
      progression: %{
        base_level: 50,
        job_level: 25,
        base_exp: 0,
        job_exp: 0,
        job_id: 20,
        learned_skills: %{}
      },
      current_state: %{hp: 1, sp: 1}
    }
    |> Stats.calculate_stats(character_id, [])
  end

  defp player(id, opts \\ []) do
    %Character{
      id: id,
      account_id: id,
      name: "Dancer#{id}",
      last_map: Keyword.get(opts, :map, "prontera"),
      last_x: Keyword.get(opts, :x, 100),
      last_y: Keyword.get(opts, :y, 100),
      class: 20,
      base_level: 100,
      job_level: 50,
      sex: "F",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 99,
      party_id: Keyword.get(opts, :party_id, 0)
    }
    |> PlayerState.new()
  end

  defp register(state) do
    UnitRegistry.register_unit(:player, state.character_id, PlayerState, state, self())
  end

  defp member(id, map \\ "prontera"), do: Member.new(id, "Dancer#{id}", 100, true, map)
end
