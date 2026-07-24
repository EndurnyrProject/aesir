defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSpringtrapTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSpringtrap
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(Manager)
    :ok
  end

  defp caster(option \\ 0) do
    %PlayerState{
      character_id: 1000,
      map_name: "prontera",
      x: 50,
      y: 50,
      option: option,
      inventory: %{}
    }
  end

  test "has the canonical active ground-target definition" do
    assert {:ok, definition} = Catalog.by_id(131)
    assert definition == HtSpringtrap.definition()
    assert definition.name == :ht_springtrap
    assert definition.display_name == "Spring Trap"
    assert definition.max_level == 5
    assert definition.target_type == :ground
    assert definition.damage_type == :no_damage
    assert definition.range == [4, 5, 6, 7, 8]
    assert definition.sp_cost == [10, 10, 10, 10, 10]
    assert {:ok, HtSpringtrap} = Catalog.active_module_for(:ht_springtrap)
    assert :ground not in HtSpringtrap.__skill_capabilities__()
  end

  test "requires an equipped Falcon before effects" do
    definition = HtSpringtrap.definition()

    assert {:error, :falcon_required} =
             HtSpringtrap.validate(caster(), {:ground, 51, 50}, 1, definition)

    assert :ok =
             HtSpringtrap.validate(
               caster(Option.id(:falcon)),
               {:ground, 51, 50},
               1,
               definition
             )
  end

  test "springs the targeted eligible trap without changing inventory" do
    definition = HtSpringtrap.definition()
    caster = caster(Option.id(:falcon))

    expect(Manager, :spring_trap, fn "prontera", 51, 50 ->
      {:ok, %{group_id: 44, expires_at: 11_500}}
    end)

    assert {:ok, updated} = HtSpringtrap.cast(caster, {:ground, 51, 50}, 3, definition)
    assert updated == caster
  end

  test "manager failures propagate without changing player state" do
    definition = HtSpringtrap.definition()
    caster = caster(Option.id(:falcon))
    errors = %{51 => :not_found, 52 => :already_spent, 53 => :unsupported_trap}

    stub(Manager, :spring_trap, fn "prontera", x, 50 ->
      {:error, Map.fetch!(errors, x)}
    end)

    Enum.each(errors, fn {x, reason} ->
      assert {:error, ^reason} = HtSpringtrap.cast(caster, {:ground, x, 50}, 1, definition)
    end)
  end
end
