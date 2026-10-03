defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BasilicaBuffTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.BasilicaBuff
  alias Aesir.ZoneServer.Mmo.StatusEntry

  test "is an unsaved, dispellable buff with the Basilica buff icon" do
    metadata = BasilicaBuff.metadata()

    assert metadata.no_save
    refute metadata.no_dispel
    assert metadata.icon == :basilica_buff
  end

  test "level 5 adds 25% weapon damage against dark and undead and 15% holy MATK" do
    assert BasilicaBuff.modifiers(%StatusEntry{type: :sc_basilica_buff, val1: 5}, %{}) == %{
             {:addele, :dark} => 25,
             {:addele, :undead} => 25,
             {:magic_atk_ele, :holy} => 15
           }
  end
end
