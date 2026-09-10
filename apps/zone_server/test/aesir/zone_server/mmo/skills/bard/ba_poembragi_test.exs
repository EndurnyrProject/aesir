defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaPoembragiTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot, as: Song
  alias Aesir.ZoneServer.Mmo.Skills.Bard.BaPoembragi
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  Mimic.copy(Song)

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    :ok
  end

  @tag game_mode: :renewal
  test "definition matches the pinned Bragi table" do
    assert {:ok, BaPoembragi} = Catalog.active_module_for(:ba_poembragi)
    assert {:ok, definition} = Catalog.by_id(321)

    assert definition.name == :ba_poembragi
    assert definition.display_name == "A Poem of Bragi"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.require_weapon == [:musical, :whip]
    assert definition.range == 15
    assert definition.duration == List.duplicate(180_000, 10)
    assert definition.sp_cost == Enum.to_list(65..110//5)
    assert definition.cast_time == List.duplicate(1_000, 10)
    assert definition.fixed_cast_time == List.duplicate(300, 10)
    assert definition.after_cast_delay == List.duplicate(300, 10)
    assert definition.cooldown == List.duplicate(20_000, 10)
  end

  @tag game_mode: :renewal
  test "completion snapshots only the exact variable-cast and delay reductions" do
    caster = player()

    for level <- 1..10 do
      expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_poembragi, params ->
        assert params[:val2] == 2 * level
        assert params[:val3] == 3 * level
        assert params[:duration] == 180_000
        refute Keyword.has_key?(params, :fixed_cast)
        :ok
      end)

      assert {:ok, result} =
               BaPoembragi.cast(caster, :self, level, BaPoembragi.definition())

      assert result.last_song == %{skill_id: 321, level: level}
    end
  end

  @tag game_mode: :renewal
  test "completion replaces an existing song with active reader state" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_appleidun, duration: 10_000, val2: 20)

    assert {:ok, result} = BaPoembragi.cast(caster, :self, 4, BaPoembragi.definition())
    refute StatusStorage.has_status?(:player, 1, :sc_appleidun)

    assert %{state: %{cast_time_reduction: 8, delay_reduction: 12}} =
             StatusStorage.get_status(:player, 1, :sc_poembragi)

    assert result.last_song == %{skill_id: 321, level: 4}
  end

  @tag game_mode: :renewal
  test "dynamic cost uses Bard cost ordering" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_adaptation, duration: 10_000)

    assert %Cost{sp: 52, sp_requirement: 52} =
             BaPoembragi.dynamic_cost(cost_state(), :self, 1, BaPoembragi.definition())
  end

  test "a failed snapshot commits neither memory nor replacement state" do
    caster = player()
    :ok = StatusStorage.apply_status(:player, 1, :sc_appleidun, duration: 10_000, val2: 20)

    expect(Song, :snapshot, fn ^caster, _definition, 1, :sc_poembragi, _params, [] ->
      {:error, :failed}
    end)

    assert {:error, :failed} = BaPoembragi.cast(caster, :self, 1, BaPoembragi.definition())
    assert caster.last_song == nil
    assert StatusStorage.has_status?(:player, 1, :sc_appleidun)
    refute StatusStorage.has_status?(:player, 1, :sc_poembragi)
  end

  defp cost_state do
    %{
      character_id: 1,
      stats: %{current_state: %{hp: 100, sp: 200}, derived_stats: %{max_hp: 100}}
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

  @tag game_mode: :pre_renewal
  test "classic carries the source's instant cast and SP" do
    {:ok, definition} = Catalog.by_id(321)
    assert definition.sp_cost == Enum.to_list(40..85//5)
    assert definition.cast_time == []
    assert definition.fixed_cast_time == []
    assert definition.cooldown == []
  end

  @tag game_mode: :pre_renewal
  test "classic dynamic cost ignores Adaptation" do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, 1, PlayerState, caster, self())
    :ok = StatusStorage.apply_status(:player, 1, :sc_adaptation, duration: 10_000)

    assert %Cost{sp: 40, sp_requirement: 40} =
             BaPoembragi.dynamic_cost(cost_state(), :self, 1, BaPoembragi.definition())
  end

  @tag game_mode: :pre_renewal
  test "classic completion snapshots stat-scaled reductions" do
    caster = player()
    dex = Stats.get_effective_stat(caster.stats, :dex)
    int = Stats.get_effective_stat(caster.stats, :int)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_poembragi, params ->
      assert params[:val2] == 12 + div(dex, 10)
      assert params[:val3] == 12 + div(int, 5)
      :ok
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_poembragi, params ->
      assert params[:val2] == 30 + div(dex, 10)
      assert params[:val3] == 50 + div(int, 5)
      :ok
    end)

    assert {:ok, _result} = BaPoembragi.cast(caster, :self, 4, BaPoembragi.definition())
    assert {:ok, _result} = BaPoembragi.cast(caster, :self, 10, BaPoembragi.definition())
  end
end
