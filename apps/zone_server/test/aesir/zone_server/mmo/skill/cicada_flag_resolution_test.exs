defmodule Aesir.ZoneServer.Mmo.Skill.CicadaFlagResolutionTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Audit
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  test "ignore_cicada_defaults_false_and_resolves_per_mode" do
    opts = [id: 900, name: :test_flag, display_name: "Test Flag", max_level: 1]
    assert Map.fetch!(Definition.build!(opts, __MODULE__), :ignore_cicada) == false

    for {mode, expected} <- [renewal: false, pre_renewal: true] do
      definition =
        opts
        |> Keyword.put(:ignore_cicada, renewal: false, pre_renewal: true)
        |> Definition.resolve_mode(mode)
        |> Definition.build!(__MODULE__)

      assert Map.fetch!(definition, :ignore_cicada) == expected
    end
  end

  test "audit_compares_flags_ignore_cicada_and_missing_means_false" do
    definition = %Definition{id: 900, name: :test_flag, display_name: "Test Flag", max_level: 1}
    row = %{"MaxLevel" => 1, "Flags" => %{"IgnoreCicada" => true}}

    assert %{field: :ignore_cicada, aesir: false, source: true} in Audit.compare(
             definition,
             row,
             :renewal
           )

    refute Enum.any?(
             Audit.compare(definition, %{"MaxLevel" => 1}, :renewal),
             &(&1.field == :ignore_cicada)
           )
  end
end
