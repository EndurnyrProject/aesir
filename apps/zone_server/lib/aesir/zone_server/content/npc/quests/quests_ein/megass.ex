defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Megass do
  @moduledoc """
  Megass confronts intruders in his home.

  ## Behavior

  - Confiscates Calla’s violin and advances the lovers quest when it is carried inside.
  - Has his guards beat and throw out a returning intruder (lovers quest stage 4 or 5).

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Fixes the rAthena returning-intruder gate, `EIN_LOVERQ == 4 && EIN_LOVERQ == 5`,
    which can never be true, to `||` (the form Calla's script uses)
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 21,
        y: 147,
        dir: 3,
        sprite: 853,
        name: "Megass",
        scope: :shared,
        unique_name: "Megass#EIN",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    confront_intruder(ctx)
  end

  @impl true
  def on_talk(ctx) do
    ctx
  end

  defp confront_intruder(ctx) do
    cond do
      get_char_var(ctx, :EIN_LOVERQ, 0) in [4, 5] ->
        ctx
        |> mes("[Megass]")
        |> mes("You again?!")
        |> mes("What do you")
        |> mes("want from me?!")
        |> next()
        |> mes("[Megass]")
        |> mes("Guards...!")
        |> mes("Sweep the driveway with")
        |> mes("this guy's face and keep")
        |> mes("punching the stomach")
        |> mes("until there's nothing")
        |> mes("left to throw up!")
        |> close()
        |> percent_heal(hp: -90, sp: 0)
        |> warp("einbroch", 112, 245)

      get_char_var(ctx, :EIN_LOVERQ, 0) == 3 and count_item(ctx, 1901) > 0 ->
        ctx
        |> mes("[Megass]")
        |> mes("That's...")
        |> mes("That's my")
        |> mes("daughter's Violin.")
        |> mes("I gave that to her")
        |> mes("for her sweet sixteen...")
        |> next()
        |> mes("[Megass]")
        |> mes("It's bad enough to")
        |> mes("intrude into my house,")
        |> mes("but to steal from my Calla?!")
        |> mes("You've crossed the line, punk!")
        |> mes("Guards! Get over here!")
        |> next()
        |> mes("[Megass]")
        |> mes("Men, I want you to")
        |> mes("knock the wind out")
        |> mes("of this fool and anything")
        |> mes("else that might be inside!")
        |> mes("Make sure that if this punk")
        |> mes("wakes up, it won't be today!")
        |> delitem(1901, 1)
        |> set_char_var(:EIN_LOVERQ, 4)
        |> changequest(8077, 8078)
        |> percent_heal(hp: -90, sp: 0)
        |> close()
        |> warp("einbroch", 112, 245)

      true ->
        ctx
        |> mes("[Megass]")
        |> mes("How dare you...")
        |> mes("A vagabond like")
        |> mes("you setting foot")
        |> mes("into my home!?")
        |> mes("Unthinkable!")
        |> next()
        |> mes("[Megass]")
        |> mes("Leave immediately")
        |> mes("before I report you")
        |> mes("to the authorities")
        |> mes("for trespassing!")
        |> next()
        |> warp("einbroch", 112, 245)
        |> close()
    end
  end
end
