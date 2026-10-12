defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BleedingTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Bleeding
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :set_mimic_private

  @instance %StatusEntry{type: :sc_bleeding, val1: 10, state: %{}}

  defp seeded_rolls(target) do
    :rand.seed(:exsss, {25, 25, 25})

    for _tick <- 1..6_000 do
      assert {:ok, @instance} = Bleeding.on_tick(target, @instance, %{})
      assert_received {:hp_loss, ^target, damage}
      damage
    end
  end

  describe "on_tick/3" do
    test "a player loses one uniform 200 to 799 HP roll, which may kill" do
      test_pid = self()

      stub(Helpers, :deal_damage, fn target, damage ->
        send(test_pid, {:hp_loss, target, damage})
      end)

      reject(&Helpers.apply_passive_hp_loss/2)

      assert Enum.min_max(seeded_rolls({:player, 1})) == {200, 799}
    end

    test "a non-player loses the same roll but never below 1 HP" do
      test_pid = self()

      stub(Helpers, :apply_passive_hp_loss, fn target, damage ->
        send(test_pid, {:hp_loss, target, damage})
      end)

      reject(&Helpers.deal_damage/2)

      assert Enum.min_max(seeded_rolls({:mob, 2})) == {200, 799}
      assert Enum.min_max(seeded_rolls({:homunculus, 3})) == {200, 799}
    end
  end
end
