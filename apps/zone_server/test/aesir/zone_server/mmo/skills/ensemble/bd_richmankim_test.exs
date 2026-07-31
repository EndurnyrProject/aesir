defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRichmankimTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdRichmankim
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 30_701

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    stub(Stats, :calculate_stats, fn stats, _character_id -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, @player_id, _game_state -> :ok end)

    stub(CharacterPersistence, :update_character, fn _character_id, _attrs, async: true ->
      {:ok, %{}}
    end)

    stub(StatusSync, :send_stat_updates, fn _connection_pid, _stats -> :ok end)
    stub(StatusSync, :send_params, fn _connection_pid, _params -> :ok end)
    stub(Leveling, :next_base_exp, fn _progression -> 0 end)
    stub(Leveling, :next_job_exp, fn _progression -> 0 end)

    :ok
  end

  test "a level-one cast grants 20 percent more base and job experience from a kill" do
    assert_kill_experience(1, 120)
  end

  test "a level-five cast grants 60 percent more base and job experience from a kill" do
    assert_kill_experience(5, 160)
  end

  test "definition and status pin the ensemble data" do
    assert {:ok, BdRichmankim} = Catalog.active_module_for(:bd_richmankim)
    assert [:active, :ensemble] = BdRichmankim.__skill_capabilities__()
    refute function_exported?(BdRichmankim, :dynamic_cost, 4)

    assert %{
             id: 307,
             name: :bd_richmankim,
             display_name: "Mental Sensing",
             max_level: 5,
             target_type: :self,
             damage_type: :no_damage,
             damage_kind: :misc,
             hit_count: 1,
             splash_radius: 15,
             range: 0,
             unit_duration: [],
             sp_cost: [62, 68, 74, 80, 86],
             duration: [180_000, 180_000, 180_000, 180_000, 180_000],
             cast_time: [1_000, 1_000, 1_000, 1_000, 1_000],
             fixed_cast_time: [500, 500, 500, 500, 500],
             after_cast_delay: [300, 300, 300, 300, 300],
             cooldown: [20_000, 20_000, 20_000, 20_000, 20_000],
             require_weapon: [:musical, :whip],
             item_cost: []
           } = BdRichmankim.definition()

    assert RichmanKim.metadata().duration == 180_000

    assert RichmanKim.metadata().end_on_start == [
             :sc_richmankim,
             :sc_eternalchaos,
             :sc_drumbattle,
             :sc_nibelungen,
             :sc_rokisweil,
             :sc_intoabyss,
             :sc_siegfried
           ]
  end

  defp assert_kill_experience(level, expected_experience) do
    caster = player()
    :ok = UnitRegistry.register_unit(:player, @player_id, PlayerState, caster, self())

    assert {:ok, _caster} =
             BdRichmankim.cast(caster, :self, level, BdRichmankim.definition())

    assert %StatusEntry{started_at: started_at, expires_at: expires_at} =
             StatusStorage.get_status(:player, @player_id, :sc_richmankim)

    assert expires_at - started_at == 180_000

    test_pid = self()

    stub(Leveling, :apply_exp, fn progression, base, job ->
      send(test_pid, {:kill_experience, base, job})
      {progression, 0, 0}
    end)

    assert {:noreply, _state} =
             ExperienceHandler.handle_gain_exp(100, 100, :brute, session_state(caster))

    assert_received {:kill_experience, ^expected_experience, ^expected_experience}
  end

  defp session_state(caster), do: %{connection_pid: self(), game_state: caster}

  defp player do
    %Character{
      id: @player_id,
      account_id: @player_id,
      name: "Rich Performer",
      last_map: "richmankim_test",
      last_x: 100,
      last_y: 100,
      class: 19,
      base_level: 50,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
    |> PlayerState.new()
  end
end
