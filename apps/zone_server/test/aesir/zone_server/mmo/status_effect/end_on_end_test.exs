defmodule Aesir.ZoneServer.Mmo.StatusEffect.EndOnEndTest do
  @moduledoc """
  Ending a status ends its `end_on_end` statuses, after its own end logic, on
  every end path: Devotion ends Guard, Defending Aura, Reflect Shield and
  Endure in both modes; Dancing ends Longing in pre-renewal and Ensemble
  Fatigue in renewal.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    stub(Unit, :destroy_async, fn _group_id -> :ok end)
    :ok
  end

  @player_id 9_701
  @devotion_partners [:sc_autoguard, :sc_defender, :sc_reflectshield, :sc_endure]

  defp apply!(status_id, opts),
    do: :ok = StatusStorage.apply_status(:player, @player_id, status_id, opts)

  defp held?(status_id), do: StatusStorage.has_status?(:player, @player_id, status_id)

  defp dance_with_partners do
    apply!(:sc_dancing, val1: 1, val2: 0, duration: 60_000)
    apply!(:sc_longing, val1: 5, duration: 60_000)
    apply!(:sc_ensemblefatigue, val1: 1, duration: 60_000)
    StatusStorage.get_status(:player, @player_id, :sc_dancing)
  end

  test "ending Devotion ends Guard, Defending Aura, Reflect Shield and Endure" do
    apply!(:sc_devotion, duration: 60_000)
    Enum.each(@devotion_partners, &apply!(&1, val1: 1, duration: 60_000))
    apply!(:sc_blessing, val1: 1, duration: 60_000)

    :ok = Interpreter.remove_status(:player, @player_id, :sc_devotion)

    assert Enum.reject(@devotion_partners, &held?/1) == @devotion_partners
    assert held?(:sc_blessing)
  end

  test "an infinite Endure outlives the Devotion that ends it" do
    apply!(:sc_devotion, duration: 60_000)
    apply!(:sc_endure, val1: 1, val4: 1)

    :ok = Interpreter.remove_status(:player, @player_id, :sc_devotion)

    assert held?(:sc_endure)
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal: Dancing running out ends Longing, not Ensemble Fatigue" do
    stub(UnitRegistry, :get_unit_info, fn :player, @player_id -> {:ok, %{stats: %{}}} end)
    dancing = dance_with_partners()

    assert Interpreter.expire_status_if_current(:player, @player_id, :sc_dancing, dancing)

    refute held?(:sc_longing)
    assert held?(:sc_ensemblefatigue)
  end

  @tag game_mode: :renewal
  test "renewal: Dancing removed ends Ensemble Fatigue, not Longing" do
    dance_with_partners()

    :ok = Interpreter.remove_status(:player, @player_id, :sc_dancing)

    refute held?(:sc_ensemblefatigue)
    assert held?(:sc_longing)
  end

  test "statuses ending each other end once each, without looping" do
    dancing = Registry.get_definition(:sc_dancing)
    longing = Registry.get_definition(:sc_longing)

    stub(Registry, :get_definition, fn
      :sc_dancing -> %{dancing | end_on_end: [:sc_longing]}
      :sc_longing -> %{longing | end_on_end: [:sc_dancing]}
      other -> call_original(Registry, :get_definition, [other])
    end)

    apply!(:sc_dancing, val1: 1, duration: 60_000)
    apply!(:sc_longing, val1: 5, duration: 60_000)

    :ok = Interpreter.remove_status(:player, @player_id, :sc_dancing)

    refute held?(:sc_dancing)
    refute held?(:sc_longing)
  end
end
