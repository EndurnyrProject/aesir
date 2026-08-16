defmodule Aesir.ZoneServer.Script.DslExportsTest do
  @moduledoc """
  Guards the `Script.Dsl` import surface during and after the domain split.

  The fixture is a snapshot of the pre-split export set (name/arity pairs) and
  is deliberately never regenerated: a missing, renamed, or mis-aritied facade
  delegate must fail here. Adding a new buildin means consciously updating the
  fixture alongside the domain module and facade delegate.
  """
  use ExUnit.Case, async: true

  @snapshot Path.join(__DIR__, "../../../support/fixtures/dsl_exports.snapshot")

  test "facade export surface is unchanged" do
    current =
      Aesir.ZoneServer.Script.Dsl.__info__(:functions)
      |> Enum.sort()
      |> Enum.map_join("\n", fn {name, arity} -> "#{name}/#{arity}" end)

    assert current == String.trim_trailing(File.read!(@snapshot), "\n")
  end
end
