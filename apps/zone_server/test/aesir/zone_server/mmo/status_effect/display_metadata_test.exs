defmodule Aesir.ZoneServer.Mmo.StatusEffect.DisplayMetadataTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Efst
  alias Aesir.ZoneServer.Mmo.Opt1
  alias Aesir.ZoneServer.Mmo.Opt2
  alias Aesir.ZoneServer.Mmo.Opt3
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  describe "display metadata resolves" do
    test "every display atom declared by an implemented status resolves to a wire id" do
      for module <- Effects.all() do
        metadata = module.metadata()

        assert_resolves(module, :icon, Efst, metadata.icon)
        assert_resolves(module, :opt1, Opt1, metadata.opt1)
        assert_resolves(module, :opt2, Opt2, metadata.opt2)
        assert_resolves(module, :option, Option, metadata.option)
        assert_resolves(module, :opt3, Opt3, metadata.opt3)
      end
    end
  end

  describe "Poison apply" do
    setup :setup_ets_tables

    test "broadcasts a UnitStateChange with the poison health_state bit and no StatusChange icon" do
      target_id = 1
      test_pid = self()

      setup_unit_mock(target_id)
      Registry.register_module(Effects.Poison)

      Mimic.copy(SpatialIndex)
      Mimic.copy(Broadcast)

      stub(SpatialIndex, :get_unit_position, fn _type, _id ->
        {:ok, {100, 100, "prontera"}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:broadcast, packet})
        :ok
      end)

      assert :ok = Interpreter.apply_status(:player, target_id, :sc_poison, duration: 30_000)

      poison_bit = Opt2.id(:poison)

      assert_received {:broadcast, %Aesir.Net.UnitStateChange{health_state: ^poison_bit}}
      refute_received {:broadcast, %Aesir.Net.StatusChange{}}
    end
  end

  defp assert_resolves(_module, _field, _resolver, nil), do: :ok

  defp assert_resolves(module, field, resolver, atom) do
    assert resolver.id(atom) != nil,
           "#{inspect(module)} declares #{field}: #{inspect(atom)} which does not resolve via #{inspect(resolver)}"
  end

  defp setup_unit_mock(unit_id) do
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1000, max_sp: 100, hp: 800, sp: 80, level: 50, base_level: 50}
       }}
    end)

    stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> true end)
  end
end
