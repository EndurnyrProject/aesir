defmodule Aesir.ZoneServer.Unit.ConcealmentTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.UnitStateChange
  alias Aesir.ZoneServer.Unit.Concealment
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  # hide(2) | cloak(4) | chasewalk(16_384)
  @conceal_mask 16_390
  @riding 32

  defp player(equipment) do
    %PlayerState{stats: %Stats{modifiers: %Modifiers{equipment: equipment}}}
  end

  describe "conceal_mask/0 and concealed?/1" do
    test "the mask covers hiding, cloaking and chase walk" do
      assert Concealment.conceal_mask() == @conceal_mask
    end

    test "concealed? is true only when a concealment bit is set" do
      assert Concealment.concealed?(2)
      assert Concealment.concealed?(4)
      assert Concealment.concealed?(16_384)
      assert Concealment.concealed?(Bitwise.bor(2, @riding))
      refute Concealment.concealed?(0)
      refute Concealment.concealed?(@riding)
    end
  end

  describe "reveal_effect_state/1" do
    test "clears concealment bits and keeps every other bit" do
      assert Concealment.reveal_effect_state(4) == 0
      assert Concealment.reveal_effect_state(Bitwise.bor(2, @riding)) == @riding
      assert Concealment.reveal_effect_state(@riding) == @riding
    end
  end

  describe "reveal/2" do
    test "masks a packet's effect_state only when reveal? is true" do
      packet = %UnitSpawn{effect_state: 6}
      assert Concealment.reveal(packet, false) == packet
      assert %UnitSpawn{effect_state: 0} = Concealment.reveal(packet, true)
    end
  end

  describe "reveal_for/2 and intravision?/1" do
    test "reveals a concealed packet for an intravision observer" do
      stub(UnitRegistry, :get_unit, fn :player, 7 ->
        {:ok, {PlayerState, player(%{intravision: 1}), self()}}
      end)

      assert Concealment.intravision?(7)

      assert %UnitStateChange{effect_state: 0} =
               Concealment.reveal_for(%UnitStateChange{effect_state: 2}, 7)
    end

    test "leaves the packet unchanged for a non-intravision observer" do
      stub(UnitRegistry, :get_unit, fn :player, 7 ->
        {:ok, {PlayerState, player(%{}), self()}}
      end)

      refute Concealment.intravision?(7)

      assert %UnitStateChange{effect_state: 2} =
               Concealment.reveal_for(%UnitStateChange{effect_state: 2}, 7)
    end

    test "treats a missing observer as non-intravision" do
      stub(UnitRegistry, :get_unit, fn :player, 7 -> {:error, :not_found} end)

      refute Concealment.intravision?(7)

      assert %UnitStateChange{effect_state: 2} =
               Concealment.reveal_for(%UnitStateChange{effect_state: 2}, 7)
    end
  end
end
