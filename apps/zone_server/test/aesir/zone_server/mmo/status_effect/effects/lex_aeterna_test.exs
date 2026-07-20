defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LexAeternaTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.LexAeterna
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @target {:mob, 2_000}
  @entry %StatusEntry{type: :sc_aeterna}

  test "doubles and consumes the next qualifying hit before HP application" do
    hit = %{damage: 1_234, dmg_type: :physical, skill_id: :sm_bash}

    assert {:remove, 2_468} = LexAeterna.absorb_damage(@target, @entry, hit, %{})
  end

  test "does not double or consume Soul Breaker's physical part" do
    hit = %{damage: 1_234, dmg_type: :physical, skill_id: 379}

    assert {:ok, 1_234, @entry} = LexAeterna.absorb_damage(@target, @entry, hit, %{})
  end

  test "does not double or consume Soul Burn" do
    hit = %{damage: 1_234, dmg_type: :magic, skill_id: 375}

    assert {:ok, 1_234, @entry} = LexAeterna.absorb_damage(@target, @entry, hit, %{})
  end

  test "keeps the status on non-damaging events" do
    hit = %{damage: 0, dmg_type: :physical, skill_id: :sm_bash}

    assert {:ok, 0, @entry} = LexAeterna.absorb_damage(@target, @entry, hit, %{})
  end

  test "conflicts with both Freeze and Stone" do
    assert %{conflicts_with: [:sc_freeze, :sc_stone]} = LexAeterna.metadata()
  end
end
