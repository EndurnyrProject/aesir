defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Guide do
  @moduledoc """
  Shows Lasoei's boredom before she notices and welcomes a visitor.

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
        x: 72,
        y: 209,
        dir: 5,
        sprite: 862,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#lt0"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Lasoei]")
    |> mes("Oh phooey.")
    |> mes("The same customers")
    |> mes("are always coming in,")
    |> mes("day after day. Can it")
    |> mes("get any less exciting?")
    |> next()
    |> mes("[Lasoei]")
    |> mes("Oh...!")
    |> mes("W-welcome~")
    |> mes("C-can I help you")
    |> mes("with anything?")
    |> close()
  end
end
