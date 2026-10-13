defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnsembleStatusesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdSiegfried
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DrumBattle
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EternalChaos
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.IntoAbyss
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Nibelungen
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RokisWeil
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Siegfried
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @ensembles [RichmanKim, EternalChaos, DrumBattle, Nibelungen, RokisWeil, IntoAbyss, Siegfried]
  @ensemble_ids [
    :sc_richmankim,
    :sc_eternalchaos,
    :sc_drumbattle,
    :sc_nibelungen,
    :sc_rokisweil,
    :sc_intoabyss,
    :sc_siegfried
  ]

  defp entry(type, vals), do: struct(StatusEntry, [type: type, state: %{}] ++ vals)

  @tag game_mode: :renewal
  test "renewal ensemble statuses end every ensemble status" do
    for module <- @ensembles, do: assert(module.metadata().end_on_start == @ensemble_ids)
  end

  @tag game_mode: :pre_renewal
  test "classic ensemble statuses end no status and the field ones last 60 seconds" do
    for module <- @ensembles, do: assert(module.metadata().end_on_start == [])

    for module <- [RichmanKim, EternalChaos, DrumBattle, RokisWeil, IntoAbyss, Siegfried] do
      assert module.metadata().duration == 60_000
    end
  end

  test "Mr. Kim and Roki's Weil are resisted by status-immune targets" do
    assert :boss in RichmanKim.metadata().immunity
    assert :boss in RokisWeil.metadata().immunity
  end

  @tag game_mode: :pre_renewal
  test "classic Drum of the Battlefield grants weapon ATK and DEF from its level" do
    assert DrumBattle.modifiers(entry(:sc_drumbattle, val1: 1), %{}) == %{watk: 50, def: 4}
    assert DrumBattle.modifiers(entry(:sc_drumbattle, val1: 5), %{}) == %{watk: 150, def: 12}
  end

  @tag game_mode: :pre_renewal
  test "classic Eternal Chaos zeroes only soft DEF" do
    assert EternalChaos.modifiers(entry(:sc_eternalchaos, []), %{}) == %{def2_rate: -100}
  end

  @tag game_mode: :renewal
  test "renewal Eternal Chaos zeroes DEF and soft DEF" do
    assert EternalChaos.modifiers(entry(:sc_eternalchaos, []), %{}) ==
             %{def_rate: -100, def2_rate: -100}
  end

  @tag game_mode: :pre_renewal
  test "classic Acoustic Rhythm resists every element but Neutral with its unit values" do
    assert BdSiegfried.params(5) == [val1: 80, val2: 50]

    assert Siegfried.modifiers(entry(:sc_siegfried, val1: 80, val2: 50), %{}) == %{
             subele_water: 80,
             subele_earth: 80,
             subele_fire: 80,
             subele_wind: 80,
             subele_poison: 80,
             subele_holy: 80,
             subele_shadow: 80,
             subele_ghost: 80,
             subele_undead: 80
           }
  end

  @tag game_mode: :renewal
  test "renewal Acoustic Rhythm keeps its four elements and per-level values" do
    assert BdSiegfried.params(5) == [val1: 15, val2: 25]

    assert Siegfried.modifiers(entry(:sc_siegfried, val1: 15, val2: 25), %{}) == %{
             subele_water: 15,
             subele_earth: 15,
             subele_fire: 15,
             subele_wind: 15
           }
  end
end
