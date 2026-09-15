defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Bodger do
  @moduledoc """
  Laments hunger and the contrast between the slums and Uptown.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 364,
        y: 282,
        dir: 3,
        sprite: 870,
        name: "Bodger",
        scope: :shared,
        unique_name: "Bodger#zen5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Bodger]")
    |> mes("Another hungry day...")
    |> mes("I don't have any money")
    |> mes("and even if I did, there's")
    |> mes("no place that sells food")
    |> mes("I'd actually eat. Oh, man.")
    |> mes("I'm barely living as it is.")
    |> next()
    |> mes("[Bodger]")
    |> mes("I hear that the people")
    |> mes("who live Uptown eat totally")
    |> mes("delicious, gourmet food eight")
    |> mes("times a day! Hopefully it's just an exaggeration. 'Cuz if it")
    |> mes("wasn't, I'd be so mad...")
    |> close()
  end
end
