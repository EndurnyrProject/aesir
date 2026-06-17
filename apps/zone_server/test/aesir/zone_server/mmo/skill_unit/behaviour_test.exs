defmodule Aesir.ZoneServer.Mmo.SkillUnit.BehaviourTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.SkillUnit.Group

  defmodule MinimalUnit do
    use Aesir.ZoneServer.Mmo.SkillUnit.Behaviour

    @impl true
    def skill_name, do: :minimal_unit

    @impl true
    def on_interval(group, _now), do: {:ok, group}
  end

  test "default on_expire/1 returns :ok" do
    group = %Group{group_id: 1, skill_name: :minimal_unit, center: {5, 5}}

    assert MinimalUnit.on_expire(group) == :ok
  end

  test "default on_place/1 yields a single cell at the group center" do
    group = %Group{group_id: 1, skill_name: :minimal_unit, center: {7, 9}}

    assert {:ok, %{cells: [{7, 9}]}} = MinimalUnit.on_place(group)
  end
end
