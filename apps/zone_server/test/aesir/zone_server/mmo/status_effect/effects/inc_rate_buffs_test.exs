defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncRateBuffsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncDefRate
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncFlee
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncFleeRate
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncMhpRate
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncMspRate
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Scresist
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @target_id 31_400

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(UnitRegistry)
    stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)
    :ok
  end

  describe "sc_scresist" do
    test "emits the ailment resistance rate from val1" do
      assert Scresist.modifiers(%StatusEntry{type: :sc_scresist, val1: 40}, %{}) ==
               %{ailment_resist_rate: 40}
    end

    test "at 100 every debuff application is resisted" do
      :ok =
        StatusStorage.apply_status(:player, @target_id, :sc_scresist, val1: 100, duration: 60_000)

      assert {:error, :resisted} =
               Interpreter.apply_status(:player, @target_id, :sc_blind, success_rate: 100)

      assert :ok = Interpreter.apply_status(:player, @target_id, :sc_blessing, val1: 10)
    end
  end

  describe "val1-driven stat rate buffs" do
    @buffs [
      {IncMhpRate, :sc_incmhprate, :max_hp_rate},
      {IncMspRate, :sc_incmsprate, :max_sp_rate},
      {IncDefRate, :sc_incdefrate, :def_rate},
      {IncHit, :sc_inchit, :hit},
      {IncFlee, :sc_incflee, :flee},
      {IncFleeRate, :sc_incfleerate, :flee_rate}
    ]

    for {module, id, key} <- @buffs do
      test "#{id} emits only #{key} from val1 and is a registered buff" do
        module = unquote(module)
        id = unquote(id)
        key = unquote(key)

        assert module.modifiers(%StatusEntry{type: id, val1: 25}, %{}) == %{key => 25}
        assert %{properties: properties} = Registry.get_definition(id)
        assert :buff in properties
      end
    end

    test "sc_incdefrate carries negative rates for Gospel's DEF curse" do
      assert IncDefRate.modifiers(%StatusEntry{type: :sc_incdefrate, val1: -100}, %{}) ==
               %{def_rate: -100}
    end
  end
end
