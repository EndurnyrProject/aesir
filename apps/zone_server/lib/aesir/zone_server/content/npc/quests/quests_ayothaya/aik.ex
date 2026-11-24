defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.Aik do
  @moduledoc """
  Aik offers adventurers a return trip from the ruins.

  ## Behavior

  - Warps players back to the field if they accept his offer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayo_fild02",
        x: 25,
        y: 154,
        dir: 0,
        sprite: 843,
        name: "Aik",
        scope: :shared,
        unique_name: "Aik#thai"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Aik]")
      |> mes("So, how was your expedition?")
      |> mes(
        "I hope that the evil spirits will not follow you outside of the ruins, and haunt your dreams."
      )
      |> next()
      |> mes("[Aik]")
      |> mes("When you go back,")
      |> mes("remember to ward off")
      |> mes("the evil from your mind.")
      |> mes("Otherwise you will encounter")
      |> mes("trouble later...")
      |> next()
      |> mes("[Aik]")
      |> mes("So, would you")
      |> mes("like to go back?")
      |> next()
      |> select(["Yes.", "No, I need to look around more..."])

    if choice == 1 do
      ctx
      |> mes("[Aik]")
      |> mes("Alright then...")
      |> mes("Here we go...")
      |> next()
      |> mes("^3355FFHe suddenly grabbed you")
      |> mes("and hurled you up into the air!^000000")
      |> close()
      |> warp("ayo_fild01", 115, 200)
    else
      ctx |> mes("[Aik]") |> mes("I see.") |> mes("Take care.") |> close()
    end
  end
end
