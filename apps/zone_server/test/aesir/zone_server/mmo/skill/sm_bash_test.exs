defmodule Aesir.ZoneServer.Mmo.Skill.SmBashTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors.SmBash
  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  setup :verify_on_exit!

  test "Behaviors.module_for/1 resolves sm_bash" do
    assert {:ok, SmBash} = Behaviors.module_for(:sm_bash)
  end

  test "cast/4 hits the target for 100% + 30% per level, without crit" do
    {:ok, definition} = Catalog.by_id(5)
    caster = %{character_id: 1000}

    expect(Combat, :execute_skill_attack, fn ^caster, 2002, opts ->
      assert opts[:skill_id] == definition.id
      assert opts[:skill_level] == 7
      assert opts[:skill_ratio] == 100 + 30 * 7
      assert opts[:skip_crit] == true
      :ok
    end)

    assert {:ok, ^caster} = SmBash.cast(caster, {:unit, 2002}, 7, definition)
  end

  test "cast/4 propagates combat errors" do
    {:ok, definition} = Catalog.by_id(5)
    caster = %{character_id: 1000}

    stub(Combat, :execute_skill_attack, fn _, _, _ -> {:error, :target_out_of_range} end)

    assert {:error, :target_out_of_range} = SmBash.cast(caster, {:unit, 2002}, 1, definition)
  end
end
