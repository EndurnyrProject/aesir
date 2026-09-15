defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Npc16655 do
  @moduledoc """
  Describes a bookshelf containing a book with dark power.

  ## Behavior

  - Plays a curse attack effect when the visitor touches the book.

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
        x: 166,
        y: 55,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#crazy4u"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFThis desk has a bookshelf")
    |> mes("that is crammed with all sorts")
    |> mes("of books. Out of curiosity, you")
    |> mes("decide to pick one out.^000000")
    |> next()
    |> mes("^3355FFHowever, the book you")
    |> mes("happen to touch contains")
    |> mes("an amazing amount of dark")
    |> mes("power, causing you to drop it.^000000")
    |> specialeffect(:curseattack)
    |> close()
  end
end
