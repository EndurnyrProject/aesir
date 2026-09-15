defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.LabStaff do
  @moduledoc """
  Shares Lab Staff's remarks with visitors to Lighthalzen.

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
        map: "lhz_in02",
        x: 265,
        y: 273,
        dir: 6,
        sprite: 865,
        name: "Lab Staff",
        scope: :shared,
        unique_name: "Lab Staff#amano08"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Assam]")
    |> mes("This place is nice")
    |> mes("and usually pretty quiet.")
    |> mes("I like to come here after")
    |> mes("work, have a drink and just")
    |> mes("chat with the bartender.")
    |> next()
    |> mes("[Assam]")
    |> mes("The rum here is incredibly")
    |> mes("good too. It might even be")
    |> mes("the best in the world. I dunno")
    |> mes("why, but for some reason, its")
    |> mes("taste reminds me of teamwork~")
    |> close()
  end
end
