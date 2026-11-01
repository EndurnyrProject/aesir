defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ElementalEndowMagicTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Earthweapon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fireweapon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Waterweapon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Windweapon
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @endows [
    {Fireweapon, :fire},
    {Waterweapon, :water},
    {Windweapon, :wind},
    {Earthweapon, :earth}
  ]

  @tag game_mode: :renewal
  test "Renewal player endows add their level to matching spell-element damage" do
    for {effect, element} <- @endows do
      instance = %StatusEntry{type: effect.id(), val1: 4}

      assert effect.modifiers(instance, %{unit_type: :player}) == %{
               :attack_element => element,
               {:magic_atk_ele, element} => 4
             }
    end
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal player endows only change the weapon element" do
    for {effect, element} <- @endows do
      instance = %StatusEntry{type: effect.id(), val1: 4}

      assert effect.modifiers(instance, %{unit_type: :player}) == %{attack_element: element}
    end
  end

  test "non-player endows never grant the player spell-element bonus" do
    for {effect, element} <- @endows do
      instance = %StatusEntry{type: effect.id(), val1: 4}

      assert effect.modifiers(instance, %{unit_type: :mob}) == %{attack_element: element}
    end
  end
end
