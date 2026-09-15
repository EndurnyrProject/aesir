defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.MukaYoungMan do
  @moduledoc """
  Recounts an encounter with a Muka while crossing the Morocc Desert.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 115,
        y: 144,
        dir: 3,
        sprite: 83,
        name: "Muka Young Man",
        scope: :shared,
        unique_name: "Muka Young Man#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Young Man]")
    |> mes(
      "I work in the trading business, so I always have to cross the hot, dry Morocc Desert on business."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes("But I can't do that anymore.")
    |> next()
    |> mes("[Young Man]")
    |> mes("Now that I can't, I kind of miss the old days.")
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "Like this one time, while I was in the middle of the desert, I got so thirsty that I caught a cactus.. but before I was able to cut it, it slapped me! Then it shot me in the arse with all these needles..."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "Later, I learned that it wasn't a normal cactus I found, but the monster we call 'Muka.'"
    )
    |> mes("Now I come to think of it, it was fun as much as dangerous.")
    |> close()
  end
end
