defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Gonknife do
  @moduledoc """
  A hidden knife advances the Lost Knife quest.

  ## Behavior

  - Gives the knife to adventurers who have started the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_fild01",
        x: 245,
        y: 257,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#gonknife",
        trigger: {3, 3}
      }
    ]

  @knife 1201

  @impl true
  def on_talk(ctx), do: on_event("OnTouch_", ctx)

  @impl true
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :nakha, 0) == 1 do
      ctx
      |> set_char_var(:nakha, 2)
      |> changequest(10034, 10035)
      |> mes("^3355FFHm? What's this?")
      |> mes(" ")
      |> mes("Something was hidden beneath the leaves...^000000")
      |> mes(" ")
      |> mes("- You have found an old knife -")
      |> close()
      |> give_item(@knife, 1)
    else
      ctx
    end
  end
end
