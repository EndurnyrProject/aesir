defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.KejulleRekenber do
  @moduledoc """
  Shares Kejulle Rekenber's remarks with visitors to Lighthalzen.

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
        map: "lhz_in01",
        x: 116,
        y: 39,
        dir: 7,
        sprite: 822,
        name: "Kejulle Rekenber",
        scope: :shared,
        unique_name: "Kejulle Rekenber#reken"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Kejulle Rekenber]")
    |> mes("Hm? Sure, my last name")
    |> mes("is Rekenber and that's the")
    |> mes("same name as our chairman,")
    |> mes("but that's just a coincidence.")
    |> mes("I'm merely a normal employee.")
    |> mes("Yeah, no special treatment...")
    |> close()
  end
end
