defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaAppleidunTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot, as: Song
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaAppleidun
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.AppleIdun
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  Mimic.copy(Song)

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Idun table" do
    assert {:ok, BaAppleidun} = Catalog.active_module_for(:ba_appleidun)
    assert {:ok, definition} = Catalog.by_id(322)

    assert definition.name == :ba_appleidun
    assert definition.display_name == "The Apple of Idun"
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

  test "completion snapshots exact capped level-only MaxHP rates" do
    caster = player()

    for level <- 1..10 do
      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_appleidun, params ->
        assert params[:val2] == min(9 + level, 20)
        assert params[:duration] == 180_000
        refute Keyword.has_key?(params, :val3)
        :ok
      end)

      assert {:ok, result} = BaAppleidun.cast(caster, :self, level, BaAppleidun.definition())
      assert result.last_song == %{skill_id: 322, level: level}
    end
  end

  test "completion replaces an existing song without healing" do
    caster = player()
    hp = caster.stats.current_state.hp
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_poembragi, duration: 10_000, val2: 20)

    assert {:ok, result} = BaAppleidun.cast(caster, :self, 10, BaAppleidun.definition())
    refute StatusStorage.has_status?(:player, 1, :sc_poembragi)
    assert %{val2: 19} = StatusStorage.get_status(:player, 1, :sc_appleidun)
    assert result.stats.current_state.hp == hp
    assert result.last_song == %{skill_id: 322, level: 10}
  end

  test "status exposes MaxHP only and registers no tick or recovery behavior" do
    entry = %Aesir.ZoneServer.Mmo.StatusEntry{type: :sc_appleidun, val2: 20, val3: 999}

    assert AppleIdun.modifiers(entry, %{}) == %{max_hp_rate: 20}
    assert AppleIdun.on_tick({:player, 1}, entry, %{}) == {:ok, entry}
    assert AppleIdun.metadata().tick_interval == nil
  end

  test "dynamic cost uses Bard cost ordering" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_adaptation, duration: 10_000)

    assert %Cost{sp: 32, sp_requirement: 32} =
             BaAppleidun.dynamic_cost(cost_state(), :self, 1, BaAppleidun.definition())
  end

  test "a failed snapshot commits neither memory nor replacement state" do
    caster = player()
    :ok = StatusStorage.apply_status(:player, 1, :sc_poembragi, duration: 10_000, val2: 20)

    expect(Song, :snapshot, fn ^caster, _definition, 1, :sc_appleidun, _params, [] ->
      {:error, :failed}
    end)

    assert {:error, :failed} = BaAppleidun.cast(caster, :self, 1, BaAppleidun.definition())
    assert caster.last_song == nil
    assert StatusStorage.has_status?(:player, 1, :sc_poembragi)
    refute StatusStorage.has_status?(:player, 1, :sc_appleidun)
  end

  defp cost_state do
    %{
      character_id: 1,
      stats: %{current_state: %{hp: 100, sp: 100}, derived_stats: %{max_hp: 100}}
    }
  end

  defp player do
    %Character{
      id: 1,
      account_id: 1,
      name: "Bard",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 19,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      party_id: 0
    }
    |> PlayerState.new()
  end
end
