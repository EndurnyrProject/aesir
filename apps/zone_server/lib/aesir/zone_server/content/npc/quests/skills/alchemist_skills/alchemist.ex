defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Alchemist do
  @moduledoc """
  A Lighthalzen alchemist who praises Kellasus as a scientist and family man.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - L0ne_W0lf
    - DracoRPG
    - Toms
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 218,
        y: 141,
        dir: 7,
        sprite: 98,
        name: "Alchemist",
        scope: :shared,
        unique_name: "Alchemist#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Alchemist]")
    |> mes("Out of all humans,")
    |> mes("I believe Kellasus is")
    |> mes("the one who has come")
    |> mes("closest to discovering")
    |> mes("the secrets of life. He")
    |> mes("never fails to amaze me...")
    |> next()
    |> mes("[Alchemist]")
    |> mes("I'm also impressed by the")
    |> mes("fact that he doesn't let his")
    |> mes("work keep him from being the")
    |> mes("best father and husband that")
    |> mes("he can for his family. He's")
    |> mes("an example for all of us.")
    |> next()
    |> mes("[Alchemist]")
    |> mes("Kellasus really is")
    |> mes("an amazing person.")
    |> mes("There isn't one Alchemist")
    |> mes("that I know who doesn't look")
    |> mes("up to him in the realms of")
    |> mes("both science and personal life.")
    |> close()
  end
end
