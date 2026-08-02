defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcHummingTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcHumming
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

  test "definition matches the pinned Focus Ballet table" do
    assert {:ok, DcHumming} = Catalog.active_module_for(:dc_humming)
    assert {:ok, definition} = Catalog.by_id(327)

    assert definition.name == :dc_humming
    assert definition.display_name == "Focus Ballet"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 15
    assert definition.duration == List.duplicate(180_000, 10)
    assert definition.sp_cost == Enum.to_list(33..60//3)
    assert definition.cast_time == List.duplicate(1_000, 10)
    assert definition.fixed_cast_time == List.duplicate(300, 10)
    assert definition.after_cast_delay == List.duplicate(300, 10)
    assert definition.cooldown == List.duplicate(20_000, 10)
    assert Catalog.performance?(327)
  end

  test "snapshots level values that grant HIT through the stat pipeline" do
    for {level, hit_bonus} <- [{1, 4}, {10, 40}] do
      caster = player(level)
      register(caster)
      baseline = Stats.calculate_stats(caster.stats, caster.character_id)

      assert {:ok, _result} = DcHumming.cast(caster, :self, level, DcHumming.definition())

      assert %{val1: ^level, expires_at: expires_at, started_at: started_at} =
               StatusStorage.get_status(:player, caster.character_id, :sc_humming)

      assert expires_at - started_at == 180_000

      with_humming = Stats.calculate_stats(caster.stats, caster.character_id)
      assert with_humming.combat_stats.hit == baseline.combat_stats.hit + hit_bonus
    end
  end

  test "snapshots only living online party members in range and leaves the status after movement" do
    caster = player(1, party_id: 10)
    nearby = player(2, x: 115, y: 115)
    outside = player(3, x: 116)
    late = player(4, x: 105)

    dead =
      player(5, x: 105)
      |> put_in([Access.key(:stats), Access.key(:current_state), Access.key(:hp)], 0)

    offline = player(6, x: 105)

    register(caster)
    register(nearby)
    register(outside)
    register(dead)
    register(offline)

    stub(PartyManager, :get, fn 10 ->
      {:ok,
       %PartyState{
         party_id: 10,
         name: "Focus Ballet",
         leader_char_id: 1,
         exp_share: false,
         item_pickup_share: false,
         members: %{
           1 => member(1),
           2 => member(2),
           3 => member(3),
           4 => member(4),
           5 => member(5),
           6 => %{member(6) | online: false}
         }
       }}
    end)

    assert {:ok, _result} = DcHumming.cast(caster, :self, 5, DcHumming.definition())

    assert %{val1: 5} = StatusStorage.get_status(:player, 1, :sc_humming)
    assert %{val1: 5} = StatusStorage.get_status(:player, 2, :sc_humming)
    refute StatusStorage.has_status?(:player, 3, :sc_humming)
    refute StatusStorage.has_status?(:player, 5, :sc_humming)
    refute StatusStorage.has_status?(:player, 6, :sc_humming)

    register(late)
    refute StatusStorage.has_status?(:player, 4, :sc_humming)

    %{generation: generation, expires_at: expires_at} =
      StatusStorage.get_status(:player, 2, :sc_humming)

    register(%{nearby | x: 116, y: 100})

    assert %{generation: ^generation, expires_at: ^expires_at} =
             StatusStorage.get_status(:player, 2, :sc_humming)
  end

  test "an unpartied caster affects only themself" do
    caster = player(1, party_id: 0)
    register(caster)

    assert {:ok, _result} = DcHumming.cast(caster, :self, 1, DcHumming.definition())

    assert StatusStorage.has_status?(:player, 1, :sc_humming)
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
      luk: 10,
      party_id: Keyword.get(opts, :party_id, 0)
    }
    |> PlayerState.new()
  end

  defp register(state) do
    UnitRegistry.register_unit(:player, state.character_id, PlayerState, state, self())
  end

  defp member(id), do: Member.new(id, "Dancer#{id}", 100, true, "prontera")
end
