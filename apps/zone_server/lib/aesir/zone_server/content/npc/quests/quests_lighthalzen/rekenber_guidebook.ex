defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.RekenberGuidebook do
  @moduledoc """
  A guidebook describes Rekenber’s vision and commitments.

  ## Behavior

  - Advances the curse quest when read at the right stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 25,
        y: 251,
        dir: 3,
        sprite: 111,
        name: "Rekenber Guidebook",
        scope: :shared,
        unique_name: "Rekenber Guidebook#li"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("..............")
      |> next()
      |> mes("^3131FF#The Vision^000000")
      |> mes("In the pursuit of knowledge,")
      |> mes("Rekenber will search the")
      |> mes("Rune-Midgarts continent for")
      |> mes("ancient relics. We hope to make")
      |> mes("significant scientific progress by learning the secrets of the past.")
      |> next()
      |> mes("By making scientific")
      |> mes("headway, we hope we can")
      |> mes("improve current technologies")
      |> mes("to provide more convenient")
      |> mes("and affordable services in")
      |> mes("the Schwarzwald Republic.")
      |> next()
      |> mes("^3131FF#The Commitment^000000")
      |> mes("Although magic and the")
      |> mes("power of the gods has always")
      |> mes("maintained an aura of mystery")
      |> mes("and superstition, Rekenber hopes^FFFFFF ^3131FF to understand these forces from")
      |> mes("a more logical standpoint.")
      |> next()
      |> mes("^FF0000Our goal is to make")
      |> mes("the lives of our customers")
      |> mes("easier and more enjoyable")
      |> mes("by making the ancient power")
      |> mes("of the gods more accessible")
      |> mes("by means of new technologies.")

    ctx =
      if get_char_var(ctx, :lhz_curse, 0) == 10 do
        set_char_var(ctx, :lhz_curse, 11)
      else
        ctx
      end

    ctx |> next() |> mes("..............") |> close()
  end
end
