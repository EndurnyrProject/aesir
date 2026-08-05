defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnchantPoisonTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnchantPoison
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @attacker_id 1
  @target_id 2

  setup :setup_ets_tables

  setup do
    attacker = player_state(@attacker_id)
    target = mob_state(@target_id, :formless)
    :ok = UnitRegistry.register_player(attacker, self())
    :ok = UnitRegistry.register_unit(:mob, @target_id, MobState, target, self())

    %{attacker: attacker, target: target}
  end

  test "is a dispellable Poison endow removed on weapon unequip" do
    metadata = EnchantPoison.metadata()

    assert metadata.flags == [:remove_on_unequip_weapon]
    refute metadata.no_dispel
    assert EnchantPoison.modifiers(%{}, %{}) == %{attack_element: :poison}
  end

  test "replaces and is replaced by every ordinary weapon endow" do
    endows = [
      :sc_aspersio,
      :sc_watk_element,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon
    ]

    for endow <- endows do
      :ok = Interpreter.apply_status(:player, @attacker_id, endow, duration: 30_000, val1: 3)

      :ok =
        Interpreter.apply_status(:player, @attacker_id, :sc_encpoison, duration: 30_000, val1: 1)

      assert only_endow() == :sc_encpoison

      :ok = Interpreter.apply_status(:player, @attacker_id, endow, duration: 30_000, val1: 3)
      assert only_endow() == endow
      Interpreter.remove_status(:player, @attacker_id, endow)
    end
  end

  test "ordinary-swing proc uses exact level-one and level-ten basis-point boundaries" do
    for {level, chance, duration} <- [{1, 300, 10_000}, {10, 750, 100_000}] do
      instance = arm_enchant(level)
      hit_info = %{target: {:mob, @target_id}, damage: 50, element: :poison}
      test_pid = self()

      assert {:ok, ^instance} =
               EnchantPoison.on_dealt_damage(
                 {:player, @attacker_id},
                 instance,
                 hit_info,
                 %{},
                 fn ->
                   send(test_pid, :rolled)
                   chance - 1
                 end
               )

      assert_received :rolled
      refute_received :rolled
      assert %{} = poison = StatusStorage.get_status(:mob, @target_id, :sc_poison)
      assert poison.source_id == @attacker_id
      assert poison.source_type == :player
      assert_in_delta poison.expires_at - System.monotonic_time(:millisecond), duration, 100

      Interpreter.remove_status(:mob, @target_id, :sc_poison)

      assert {:ok, ^instance} =
               EnchantPoison.on_dealt_damage(
                 {:player, @attacker_id},
                 instance,
                 hit_info,
                 %{},
                 fn -> chance end
               )

      refute StatusStorage.has_status?(:mob, @target_id, :sc_poison)
      Interpreter.remove_status(:player, @attacker_id, :sc_encpoison)
    end
  end

  test "non-damaging hit metadata cannot attempt Poison" do
    instance = arm_enchant(10)

    assert {:ok, ^instance} =
             EnchantPoison.on_dealt_damage(
               {:player, @attacker_id},
               instance,
               %{target: {:mob, @target_id}, damage: 0, element: :poison},
               %{},
               fn -> raise "misses must not roll" end
             )

    refute StatusStorage.has_status?(:mob, @target_id, :sc_poison)
  end

  test "Poison immunity rejects a successful proc through the ordinary status gate" do
    immune = mob_state(@target_id, :plant)
    :ok = UnitRegistry.update_unit_state(:mob, @target_id, immune)
    instance = arm_enchant(10)

    assert {:ok, ^instance} =
             EnchantPoison.on_dealt_damage(
               {:player, @attacker_id},
               instance,
               %{target: {:mob, @target_id}, damage: 50, element: :poison},
               %{},
               fn -> 0 end
             )

    refute StatusStorage.has_status?(:mob, @target_id, :sc_poison)
  end

  test "expiry, dispel, and cleanup remove the endow through status lifecycle" do
    for remove <- [:expiry, :dispel, :cleanup] do
      instance = arm_enchant(1)

      case remove do
        :expiry ->
          :ok =
            StatusStorage.update_status(:player, @attacker_id, :sc_encpoison, fn status ->
              %{status | expires_at: System.monotonic_time(:millisecond) - 1}
            end)

          assert {:noreply, %StatusTickManager.State{}} =
                   StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

        :dispel ->
          :ok = Dispel.dispel({:player, @attacker_id})

        :cleanup ->
          :ok = Interpreter.remove_all_statuses(:player, @attacker_id)
      end

      refute StatusStorage.has_status?(:player, @attacker_id, :sc_encpoison)
      assert instance.type == :sc_encpoison
    end
  end

  defp arm_enchant(level) do
    :ok =
      Interpreter.apply_status(:player, @attacker_id, :sc_encpoison,
        val1: level,
        caster_id: @attacker_id,
        source_type: :player,
        duration: 30_000
      )

    StatusStorage.get_status(:player, @attacker_id, :sc_encpoison)
  end

  defp only_endow do
    StatusStorage.get_unit_statuses(:player, @attacker_id)
    |> Enum.find(
      &(&1.type in [
          :sc_aspersio,
          :sc_watk_element,
          :sc_fireweapon,
          :sc_waterweapon,
          :sc_windweapon,
          :sc_earthweapon,
          :sc_encpoison
        ])
    )
    |> Map.fetch!(:type)
  end

  defp player_state(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Player #{id}",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 12
    })
  end

  defp mob_state(id, race) do
    definition = %MobDefinition{
      id: 1002,
      aegis_name: "TARGET",
      name: "Target",
      level: 1,
      hp: 100,
      sp: 0,
      stats: %{str: 1, agi: 1, vit: 0, int: 1, dex: 1, luk: 0},
      atk: 1,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      element: {:neutral, 1},
      race: race,
      size: :medium,
      modes: []
    }

    MobState.new(id, definition, %{respawn_time: 0}, "prontera", 51, 50)
  end
end
