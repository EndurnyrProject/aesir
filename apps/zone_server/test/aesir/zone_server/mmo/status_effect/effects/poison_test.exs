defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoisonTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Poison
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :setup_ets_tables
  setup :set_mimic_private

  @instance %StatusEntry{type: :sc_poison, state: %{}}

  defp tick(target, hp, max_hp),
    do: Poison.on_tick(target, @instance, %{target: %{hp: hp, max_hp: max_hp}})

  describe "on_tick/3" do
    test "a player loses 2 + 3/200 of Max HP, a non-player 2 + 1/200" do
      expect(Helpers, :deal_damage, fn {:player, 1}, 17 -> :ok end)
      expect(Helpers, :deal_damage, fn {:mob, 2}, 7 -> :ok end)
      expect(Helpers, :deal_damage, fn {:homunculus, 3}, 7 -> :ok end)

      assert {:ok, @instance} = tick({:player, 1}, 1_000, 1_000)
      assert {:ok, @instance} = tick({:mob, 2}, 1_000, 1_000)
      assert {:ok, @instance} = tick({:homunculus, 3}, 1_000, 1_000)
    end

    test "deals nothing at a quarter of Max HP or below" do
      reject(&Helpers.deal_damage/2)

      assert {:ok, @instance} = tick({:player, 1}, 250, 1_000)
      assert {:ok, @instance} = tick({:homunculus, 3}, 1, 1_000)
    end

    test "deals nothing unless HP is above the tick damage itself" do
      expect(Helpers, :deal_damage, fn {:mob, 2}, 2 -> :ok end)

      assert {:ok, @instance} = tick({:mob, 2}, 2, 4)
      assert {:ok, @instance} = tick({:mob, 2}, 3, 4)
    end
  end
end
