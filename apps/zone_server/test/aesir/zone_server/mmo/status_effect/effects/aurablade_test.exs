defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AurabladeTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Aurablade
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @tag game_mode: :renewal
  test "renewal level five grants 720 post-defense ATK at base level 90" do
    instance = %StatusEntry{type: :sc_aurablade, val1: 5}

    assert Aurablade.modifiers(instance, %{target: %{base_level: 90}}) ==
             %{post_defense_atk: 720}
  end

  @tag game_mode: :pre_renewal
  test "classic level five grants 100 and excludes Spiral Pierce" do
    instance = %StatusEntry{type: :sc_aurablade, val1: 5}

    assert Aurablade.modifiers(instance, %{target: %{base_level: 90}}) ==
             %{post_defense_atk: 100, post_defense_atk_excludes: [397]}
  end
end
