defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.MagicalbulletLifecycleTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @moduletag game_mode: :renewal

  setup :setup_ets_tables

  setup do
    Registry.load_definitions()
    :ok = StatusStorage.apply_status(:mob, 1, :sc_magicalbullet, val1: 1)
    on_exit(fn -> StatusStorage.clear_unit_statuses(:mob, 1) end)
  end

  test "is saved at logout" do
    definition = Registry.get_definition(:sc_magicalbullet)
    refute definition.no_save or definition.remove_on_map_change
  end

  test "is removed by Dispel" do
    Dispel.dispel({:mob, 1})
    refute StatusStorage.has_status?(:mob, 1, :sc_magicalbullet)
  end

  test "ends on death" do
    :ok = Interpreter.remove_on_death(:mob, 1)
    refute StatusStorage.has_status?(:mob, 1, :sc_magicalbullet)
  end
end
