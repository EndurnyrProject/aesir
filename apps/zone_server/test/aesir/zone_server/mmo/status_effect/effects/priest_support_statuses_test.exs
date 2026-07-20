defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PriestSupportStatusesTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.StatusChange
  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Aspersio
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Benedictio
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Gloria
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Impositio
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Kyrie
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Magnificat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Suffragium
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 7_001

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player = player_state()
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_player(@player_id, player.x, player.y, player.map_name)

    %{player: player}
  end

  test "Priest support statuses expose their Renewal lifecycle metadata" do
    assert Aspersio.metadata().flags == [:remove_on_unequip_weapon]
    assert Aspersio.metadata().calc_flags == [:atk_ele]
    assert Aspersio.metadata().icon == :aspersio
    refute Aspersio.metadata().no_dispel

    assert Benedictio.metadata().calc_flags == [:def_ele]
    assert Benedictio.metadata().icon == :benedictio
    assert Benedictio.metadata().no_save
    refute Benedictio.metadata().no_dispel

    assert Gloria.metadata().calc_flags == [:luk]
    assert Gloria.metadata().icon == :gloria
    refute Gloria.metadata().no_dispel

    assert Impositio.metadata().calc_flags == [:watk, :matk]
    assert Impositio.metadata().end_on_start == [:sc_impositio]
    assert Impositio.metadata().icon == :impositio
    refute Impositio.metadata().no_dispel

    assert Kyrie.metadata().icon == :kyrie
    refute Kyrie.metadata().no_dispel

    assert Magnificat.metadata().calc_flags == [:regen]
    assert Magnificat.metadata().end_on_start == [:sc_offertorium]
    assert Magnificat.metadata().icon == :magnificat
    assert Magnificat.metadata().no_save
    refute Magnificat.metadata().no_dispel

    assert Suffragium.metadata().icon == :suffragium
    refute Suffragium.metadata().no_dispel
  end

  test "Priest support statuses apply, replace their prior instance, and expose display icons" do
    statuses = [
      :sc_aspersio,
      :sc_benedictio,
      :sc_gloria,
      :sc_impositio,
      :sc_kyrie,
      :sc_magnificat,
      :sc_suffragium
    ]

    :ok = Interpreter.apply_status(:player, @player_id, :sc_fireweapon, duration: 30_000)
    :ok = Interpreter.apply_status(:player, @player_id, :sc_aspersio, duration: 30_000)
    refute StatusStorage.has_status?(:player, @player_id, :sc_fireweapon)

    Enum.each(statuses, fn status_id ->
      :ok =
        Interpreter.apply_status(:player, @player_id, status_id,
          duration: 30_000,
          val1: 1,
          val2: 10,
          val3: 5
        )

      first = StatusStorage.get_status(:player, @player_id, status_id)

      :ok =
        Interpreter.apply_status(:player, @player_id, status_id,
          duration: 60_000,
          val1: 3,
          val2: 30,
          val3: 6
        )

      refreshed = StatusStorage.get_status(:player, @player_id, status_id)
      assert refreshed.val1 == 3
      assert refreshed.val2 == 30
      assert refreshed.expires_at > first.expires_at
    end)

    assert Enum.sort(Enum.map(StatusDisplay.active_icons(:player, @player_id), & &1.efst)) ==
             Enum.sort(
               for status_id <- statuses do
                 assert [%StatusChange{on: true, total_ms: 60_000}] =
                          StatusDisplay.active_icons(:player, @player_id)
                          |> Enum.filter(&(&1.efst == icon_efst(status_id)))

                 icon_efst(status_id)
               end
             )
  end

  test "Kyrie absorbs qualifying physical damage until its HP or hit quota is exhausted" do
    :ok =
      Interpreter.apply_status(:player, @player_id, :sc_kyrie,
        duration: 30_000,
        val2: 100,
        val3: 2
      )

    assert Interpreter.absorb_damage(:player, @player_id, 30, %{dmg_type: :physical}) == 0
    kyrie = StatusStorage.get_status(:player, @player_id, :sc_kyrie)
    assert kyrie.state == %{shield_hp: 70, hits_remaining: 1}

    assert Interpreter.absorb_damage(:player, @player_id, 20, %{dmg_type: :physical}) == 0
    refute StatusStorage.has_status?(:player, @player_id, :sc_kyrie)

    :ok =
      Interpreter.apply_status(:player, @player_id, :sc_kyrie,
        duration: 30_000,
        val2: 50,
        val3: 5
      )

    assert Interpreter.absorb_damage(:player, @player_id, 70, %{dmg_type: :physical}) == 20
    refute StatusStorage.has_status?(:player, @player_id, :sc_kyrie)

    :ok =
      Interpreter.apply_status(:player, @player_id, :sc_kyrie,
        duration: 30_000,
        val2: 50,
        val3: 5
      )

    assert Interpreter.absorb_damage(:player, @player_id, 20, %{dmg_type: :magic}) == 20
    kyrie = StatusStorage.get_status(:player, @player_id, :sc_kyrie)
    assert kyrie.state == %{shield_hp: 50, hits_remaining: 5}
  end

  test "Benedictio, Gloria, and Impositio reach the combat and stat readers", %{player: player} do
    baseline = Stats.calculate_stats(player.stats, @player_id, [])

    :ok = Interpreter.apply_status(:player, @player_id, :sc_benedictio, duration: 30_000)
    :ok = Interpreter.apply_status(:player, @player_id, :sc_gloria, duration: 30_000)
    supported = Stats.calculate_stats(player.stats, @player_id, [])

    :ok =
      Interpreter.apply_status(:player, @player_id, :sc_impositio,
        duration: 30_000,
        val2: 25
      )

    boosted = Stats.calculate_stats(player.stats, @player_id, [])
    combatant = PlayerState.to_combatant(%{player | stats: boosted})

    assert combatant.element == {:holy, 1}

    assert Stats.get_effective_stat(boosted, :luk) ==
             Stats.get_effective_stat(baseline, :luk) + 30

    assert boosted.combat_stats.matk_min == supported.combat_stats.matk_min + 25
    assert boosted.combat_stats.matk_max == supported.combat_stats.matk_max + 25
    assert ModifierCalculator.get_all_modifiers(:player, @player_id).watk == 25
  end

  test "Magnificat doubles the natural SP regeneration rate", %{player: player} do
    stats = Stats.calculate_stats(player.stats, @player_id, [])
    passive = %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}
    accumulators = %{elapsed_ms: 60_000, hp_acc: 0, sp_acc: 0, skill_hp_acc: 0, skill_sp_acc: 0}

    {_hp, base_sp, _accumulators} =
      NaturalHeal.compute(stats, :idle, :standing, %{}, passive, accumulators)

    :ok = Interpreter.apply_status(:player, @player_id, :sc_magnificat, duration: 30_000)
    modifiers = ModifierCalculator.get_all_modifiers(:player, @player_id)

    {_hp, boosted_sp, _accumulators} =
      NaturalHeal.compute(stats, :idle, :standing, modifiers, passive, accumulators)

    assert modifiers.sp_regen == 100
    assert boosted_sp == base_sp * 2
  end

  test "Priest support statuses are dispelled and naturally expire with their icons" do
    statuses = [
      :sc_aspersio,
      :sc_benedictio,
      :sc_gloria,
      :sc_impositio,
      :sc_kyrie,
      :sc_magnificat,
      :sc_suffragium
    ]

    Enum.each(statuses, fn status_id ->
      :ok = Interpreter.apply_status(:player, @player_id, status_id, duration: 30_000)
    end)

    assert :ok = Dispel.dispel({:player, @player_id})
    assert StatusStorage.get_unit_statuses(:player, @player_id) == []
    assert StatusDisplay.active_icons(:player, @player_id) == []

    Enum.each(statuses, fn status_id ->
      :ok = Interpreter.apply_status(:player, @player_id, status_id, duration: 30_000)

      :ok =
        StatusStorage.update_status(:player, @player_id, status_id, fn status ->
          %{status | expires_at: System.monotonic_time(:millisecond) - 1}
        end)
    end)

    assert {:noreply, %StatusTickManager.State{}} =
             StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    assert StatusStorage.get_unit_statuses(:player, @player_id) == []
    assert StatusDisplay.active_icons(:player, @player_id) == []
  end

  defp icon_efst(status_id) do
    status_id
    |> Registry.get_definition()
    |> Map.fetch!(:icon)
    |> Efst.id()
  end

  defp player_state do
    %Character{
      id: @player_id,
      account_id: 8_001,
      name: "PriestSupportTarget",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
    |> PlayerState.new()
  end
end
