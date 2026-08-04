defmodule Aesir.ZoneServer.Mmo.Combat.PotionRecoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.PotionRecovery

  @production_root Path.expand("../../../../../lib/aesir/zone_server", __DIR__)
  @formula_file Path.join(@production_root, "mmo/combat/potion_recovery.ex")
  @player_handler Path.join(@production_root, "unit/player/handlers/health_handler.ex")
  @homunculus_handler Path.join(
                        @production_root,
                        "unit/homunculus/handlers/combat_handler.ex"
                      )

  test "HP performs one target-side division after combining all recipient terms" do
    terms = %{
      learning_potion: 3,
      effective_vit: 7,
      effective_int: 99,
      item_heal_rate: 4
    }

    assert PotionRecovery.recover({:potion, :hp, 101}, terms) == 134
  end

  test "SP uses INT and intentionally excludes the HP-only item heal term" do
    terms = %{
      learning_potion: 3,
      effective_vit: 99,
      effective_int: 7,
      item_heal_rate: 500
    }

    assert PotionRecovery.recover({:potion, :sp, 101}, terms) == 130
  end

  test "PotionRecovery defines recipient multipliers and both handlers delegate recovery" do
    formula = @formula_file |> File.read!() |> Code.string_to_quoted!()

    assert contains_recipient_multiplier?(formula)
    assert delegates_potion_recovery?(@player_handler)
    assert delegates_potion_recovery?(@homunculus_handler)
  end

  defp contains_recipient_multiplier?(ast) do
    {_ast, found?} =
      Macro.prewalk(ast, false, fn
        {:*, _, [left, right]} = node, found? ->
          {node, found? or left in [2, 5] or right in [2, 5]}

        node, found? ->
          {node, found?}
      end)

    found?
  end

  defp delegates_potion_recovery?(file) do
    ast = file |> File.read!() |> Code.string_to_quoted!()

    {_ast, delegated?} =
      Macro.prewalk(ast, false, fn
        {{:., _, [{:__aliases__, _, [:PotionRecovery]}, :recover]}, _, _} = node, _delegated? ->
          {node, true}

        node, delegated? ->
          {node, delegated?}
      end)

    delegated?
  end
end
