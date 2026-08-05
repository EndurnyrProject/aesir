defmodule Aesir.ZoneServer.Mmo.Skill.CastabilityTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Requirement

  @kinds [:player, :homunculus, :mob]

  test "checks every requirement against every caster kind" do
    for requirement <- Requirement.all(), kind <- @kinds do
      expected =
        case {kind, requirement} do
          {:player, _requirement} -> :ok
          {:homunculus, :homunculus_state} -> :ok
          _other -> {:error, {:missing, [requirement]}}
        end

      assert Castability.check(definition([requirement]), kind) == expected
    end
  end

  test "returns every missing requirement in deterministic order" do
    definition = definition(Enum.reverse(Requirement.all()))

    assert {:error, {:missing, missing}} = Castability.check(definition, :mob)
    assert missing == Enum.sort(Requirement.all())
  end

  test "accepts a skill with no requirements for every caster kind" do
    for kind <- @kinds do
      assert :ok = Castability.check(definition([]), kind)
    end
  end

  test "checks a catalog skill by id and reports an unknown id" do
    assert :ok = Castability.check_by_id(29, :mob)
    assert :error = Castability.check_by_id(999_999, :player)
  end

  defp definition(requires) do
    Definition.build!(
      [
        id: 999_998,
        name: :castability_test,
        display_name: "Castability Test",
        max_level: 1,
        requires: requires
      ],
      __MODULE__
    )
  end
end
