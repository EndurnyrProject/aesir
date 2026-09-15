defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.RekenberEmployee337296 do
  @moduledoc """
  Advertises Rekenber employment opportunities after sufficient quest progress.

  ## Behavior

  - Remains silent until the hg_tre character variable exceeds 54.

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
        x: 337,
        y: 296,
        dir: 3,
        sprite: 868,
        name: "Rekenber Employee",
        scope: :shared,
        unique_name: "Rekenber Employee#li_2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_tre, 0) > 54 do
      ctx
      |> mes("[Rekenber Employee]")
      |> mes("Greetings. As part of our")
      |> mes("effort to relieve the poor,")
      |> mes("Rekenber is providing job")
      |> mes("opportunities targeted for")
      |> mes("citizens of the slum areas.")
      |> next()
      |> mes("[Rekenber Employee]")
      |> mes("You can choose to work")
      |> mes("from home, or undergo a")
      |> mes("little bit of training for more")
      |> mes("professional positions. This")
      |> mes("is a great chance to make a")
      |> mes("difference... and some money~")
      |> emotion(:best)
      |> close()
    else
      ctx
    end
  end
end
