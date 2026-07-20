defmodule Aesir.ZoneServer.Mmo.StatusEffect.AbsorbDamageTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule PassThroughStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_passthrough,
      no_dispel: false,
      properties: [:buff]
  end

  defmodule HalfStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_half,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def absorb_damage(_target, instance, %{damage: damage}, _context) do
      {:ok, div(damage, 2), instance}
    end
  end

  defmodule BlockOnceStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_block_once,
      no_dispel: false,
      properties: [:buff]

    import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

    @impl true
    def on_apply(_target, instance, _context) do
      {:ok, put_state(instance, :hits_remaining, 2)}
    end

    @impl true
    def absorb_damage(_target, instance, _hit_info, _context) do
      case instance.state.hits_remaining - 1 do
        n when n <= 0 -> {:remove, 0}
        n -> {:ok, 0, put_state(instance, :hits_remaining, n)}
      end
    end
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "absorb_damage/4" do
    test "passes damage through unchanged with the default callback" do
      target_id = 1
      setup_player_mock(target_id)
      Registry.register_module(PassThroughStatus)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_passthrough)

      assert 100 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
    end

    test "a reducing status lowers the damage" do
      target_id = 2
      setup_player_mock(target_id)
      Registry.register_module(HalfStatus)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_half)

      assert 50 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
    end

    test "a blocking status removes itself after exhausting its budget" do
      target_id = 3
      setup_player_mock(target_id)
      Registry.register_module(BlockOnceStatus)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_block_once)

      assert 0 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      assert StatusStorage.has_status?(:player, target_id, :sc_test_block_once)

      assert 0 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      refute StatusStorage.has_status?(:player, target_id, :sc_test_block_once)
    end

    test "no active statuses returns the damage unchanged" do
      target_id = 4
      setup_player_mock(target_id)

      assert 77 = Interpreter.absorb_damage(:player, target_id, 77, %{dmg_type: :magic})
    end
  end

  describe "Kyrie absorb_damage" do
    test "blocks physical hits until hit budget exhausts, then expires" do
      target_id = 5
      setup_player_mock(target_id)

      :ok =
        Interpreter.apply_status(:player, target_id, :sc_kyrie, val2: 10_000, val3: 2)

      assert 0 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      assert StatusStorage.has_status?(:player, target_id, :sc_kyrie)

      assert 100 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      refute StatusStorage.has_status?(:player, target_id, :sc_kyrie)
    end

    test "expires when shield_hp is drained even before hits run out" do
      target_id = 6
      setup_player_mock(target_id)

      :ok = Interpreter.apply_status(:player, target_id, :sc_kyrie, val2: 50, val3: 10)

      assert 100 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :physical})
      refute StatusStorage.has_status?(:player, target_id, :sc_kyrie)
    end

    test "passes magic hits through unchanged" do
      target_id = 7
      setup_player_mock(target_id)

      :ok = Interpreter.apply_status(:player, target_id, :sc_kyrie, val2: 10_000, val3: 5)

      assert 100 = Interpreter.absorb_damage(:player, target_id, 100, %{dmg_type: :magic})
      assert StatusStorage.has_status?(:player, target_id, :sc_kyrie)
    end
  end

  defp setup_player_mock(player_id) do
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok,
       %{
         unit_id: player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 1000,
           max_sp: 100,
           hp: 800,
           sp: 80,
           level: 50,
           base_level: 50,
           str: 10,
           agi: 10,
           vit: 10,
           int: 10,
           dex: 10,
           luk: 10,
           mdef: 5
         }
       }}
    end)

    stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> true end)
  end
end
