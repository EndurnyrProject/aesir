defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.TavernLady do
  @moduledoc """
  Complains about the men of Einbech from inside the tavern.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 279,
        y: 92,
        dir: 3,
        sprite: 854,
        name: "Tavern Lady",
        scope: :shared,
        unique_name: "Tavern Lady#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Tavern Lady]")
    |> mes("Most Einbech men are")
    |> mes("crude and primitive male")
    |> mes("chauvinists! They disgust me!")
    |> next()
    |> mes("[Tavern Lady]")
    |> mes("I mean, there's nothing")
    |> mes("good about them! They're")
    |> mes("wild, violent, simple minded")
    |> mes("and ignorant. They settle all")
    |> mes("their arguments with brawn")
    |> mes("and they're so... close minded!")
    |> next()
    |> mes("[Tavern Lady]")
    |> mes("How can they not know")
    |> mes("that women want gentle,")
    |> mes("sensitive men with whom")
    |> mes("they can share their feelings")
    |> mes("and drink chamomile tea over")
    |> mes("freshly knit doilies?")
    |> close()
  end
end
