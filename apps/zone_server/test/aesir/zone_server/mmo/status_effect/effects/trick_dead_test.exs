defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TrickDeadTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.TrickDead
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn _unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1_000, max_sp: 100, hp: 800, sp: 80, level: 50}
       }}
    end)

    :ok
  end

  describe "id/0" do
    test "returns :sc_trickdead" do
      assert TrickDead.id() == :sc_trickdead
    end
  end

  describe "metadata" do
    test "is a persistent action-preventing status" do
      assert %{
               permanent: true,
               icon: :trickdead,
               properties: properties
             } = TrickDead.metadata()

      assert :prevents_movement in properties
      assert :prevents_skills in properties
      assert :prevents_attack in properties
    end
  end

  describe "apply / toggle" do
    test "apply_status stores entry with nil expires_at" do
      :ok = Interpreter.apply_status(:player, 10, :sc_trickdead)

      assert %{expires_at: nil} = StatusStorage.get_status(:player, 10, :sc_trickdead)
    end

    test "toggle_status applies then removes" do
      assert {:ok, :applied} = Interpreter.toggle_status(:player, 11, :sc_trickdead)
      assert StatusStorage.has_status?(:player, 11, :sc_trickdead)

      assert {:ok, :removed} = Interpreter.toggle_status(:player, 11, :sc_trickdead)
      refute StatusStorage.has_status?(:player, 11, :sc_trickdead)
    end
  end
end
