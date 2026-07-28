defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoemBragiTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoemBragi
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @target {:player, 1000}

  describe "metadata" do
    test "resolves :sc_poembragi as a buff with the Bragi icon" do
      assert :sc_poembragi = PoemBragi.id()

      assert %{properties: [:buff], icon: :poembragi, duration: 180_000} =
               PoemBragi.metadata()
    end
  end

  describe "on_apply/3" do
    test "stores the pinned reduction parameters without deriving legacy formulas" do
      instance = %StatusEntry{type: :sc_poembragi, val1: 99, val2: 20, val3: 30, state: %{}}

      assert {:ok, %StatusEntry{state: %{cast_time_reduction: 20, delay_reduction: 30}}} =
               PoemBragi.on_apply(@target, instance, %{})
    end
  end

  describe "registration" do
    test "is listed in Effects.all/0 so :sc_poembragi resolves like other effects" do
      assert PoemBragi in Effects.all()
    end
  end
end
