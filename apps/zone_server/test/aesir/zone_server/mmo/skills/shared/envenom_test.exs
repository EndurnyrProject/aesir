defmodule Aesir.ZoneServer.Mmo.Skills.Shared.EnvenomTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skills.Shared.Envenom
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "executes the free level-five effect directly with a typed mob source" do
    :rand.seed(:exsss, {1, 2, 3})
    caster = %{instance_id: 1_000}

    expect(Combat, :execute_skill_attack, fn ^caster, {:player, 2_000}, opts ->
      assert opts == [
               skill_id: 52,
               skill_level: 5,
               skill_ratio: 100,
               bonus_atk: 75,
               element: :poison,
               skip_crit: true,
               report_hit: true
             ]

      {:ok, %{hit?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :player, 2_000, :sc_poison, params ->
      assert params == [duration: 18_000, caster_id: 1_000, source_type: :mob]
      :ok
    end)

    assert {:ok, ^caster} = Envenom.execute(caster, {:player, 2_000}, 5)
  end

  test "leaves Poison immunity to the existing status application" do
    :rand.seed(:exsss, {1, 2, 3})
    caster = %{world_gid: 3_000}

    stub(Combat, :execute_skill_attack, fn ^caster, {:mob, 4_000}, _opts ->
      {:ok, %{hit?: true}}
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 4_000, :sc_poison, params ->
      assert params == [duration: 18_000, caster_id: 3_000, source_type: :homunculus]
      {:error, :immune}
    end)

    assert {:ok, ^caster} = Envenom.execute(caster, {:mob, 4_000}, 5)
  end
end
