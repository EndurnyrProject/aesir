defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.BbqVisitor do
  @moduledoc """
  Razy speculates about the village chief’s visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 218,
        y: 309,
        dir: 4,
        sprite: 90,
        name: "BBQ Visitor",
        scope: :shared,
        unique_name: "BBQ Visitor#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Razy]")
    |> mes("Those people over there")
    |> mes("are friends of the Village")
    |> mes("Chief? I was wondering about")
    |> mes("them for the longest time...")
    |> mes("I didn't even know our Chief")
    |> mes("had friends outside of Comodo.")
    |> next()
    |> mes("[Razy]")
    |> mes("You know, they kind of")
    |> mes("strike me as old war buddies,")
    |> mes("sprinkling their conversations")
    |> mes("with words like ''mission'' all")
    |> mes("the time. Then, there's those")
    |> mes("little scars they all have...")
    |> close()
  end
end
