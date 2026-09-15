defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.BanquetStaff do
  @moduledoc """
  Describes the banquet hall and its current lack of events.

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
      %{map: "lhz_in01", x: 14, y: 28, dir: 3, sprite: 109, name: "Banquet Staff", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Banquet Staff]")
    |> mes("This Banquet Hall is used")
    |> mes("to hold events such as dinner")
    |> mes("parties with partners, clients")
    |> mes("and other associates, and press")
    |> mes("conferences. Of course, there's")
    |> mes("nothing going on right now.")
    |> next()
    |> mes("[Banquet Staff]")
    |> mes("Sometimes peace and quiet")
    |> mes("is a welcome change of pace,")
    |> mes("but right now I'm feeling quite")
    |> mes("bored. I think I would rather")
    |> mes("be busy than twiddling my")
    |> mes("thumbs, to tell the truth.")
    |> close()
  end
end
