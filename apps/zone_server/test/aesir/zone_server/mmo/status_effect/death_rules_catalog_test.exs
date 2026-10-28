defmodule Aesir.ZoneServer.Mmo.StatusEffect.DeathRulesCatalogTest do
  @moduledoc """
  Pins whether death ends every implemented status, in the active mode, to the
  reference status database's NoRemoveOnDead flags, from the checked-in extract
  `test/support/fixtures/status_death_rules.tsv`.
  """
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @extract Path.expand("../../../../support/fixtures/status_death_rules.tsv", __DIR__)
  @external_resource @extract

  setup :setup_ets_tables

  test "every implemented status ends on death exactly when the reference does" do
    rules = rules()

    mismatches =
      for module <- Effects.all(),
          not module.metadata().engine_only,
          rule = Map.get(rules, module.id(), :missing),
          rule not in [:absent, :holy_dark],
          rule == :missing or module.metadata().remove_on_death != (rule == :ends),
          do: {module.id(), rule, module.metadata().remove_on_death}

    assert mismatches == []
  end

  test "Elemental Change survives death only while Holy or Dark" do
    for {element, ends?} <- [fire: true, holy: false, shadow: false] do
      :ok =
        StatusStorage.apply_status(:mob, 1, :sc_elementalchange,
          val1: 1,
          val2: Element.id(element)
        )

      :ok = Interpreter.remove_on_death(:mob, 1)
      assert StatusStorage.has_status?(:mob, 1, :sc_elementalchange) == not ends?
      StatusStorage.clear_unit_statuses(:mob, 1)
    end
  end

  defp rules do
    column = if GameMode.mode() == :renewal, do: 1, else: 2

    @extract
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Map.new(fn line ->
      fields = String.split(line, "\t")
      {String.to_atom(hd(fields)), String.to_atom(Enum.at(fields, column))}
    end)
  end
end
