defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Mudasamu do
  @moduledoc """
  Mudasamu complains about the Alberta Security Knights’ expedition.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "tur_dun03",
        x: 105,
        y: 74,
        dir: 4,
        sprite: 119,
        name: "Mudasamu",
        scope: :shared,
        unique_name: "Mudasamu#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Mudasamu]")
    |> mes("My name is Mudasamu...")
    |> mes("Second in command of the")
    |> mes("Alberta Security Knights.")
    |> next()
    |> mes("[Mudasamu]")
    |> mes(
      "We've come here to rescue treasure hunters that might be in trouble. However, our leader is this porky specimen right next to me. So I guess I foresaw that this mission would fail."
    )
    |> next()
    |> mes("[Mudasamu]")
    |> mes(
      "Basically, our leader was so distracted by the idea of finding treasure himself that we've lost our men. It's bad enough that he's a fat slob, but he's a greedy slob too!"
    )
    |> next()
    |> emotion(:anger)
    |> mes("[Takuyaka]")
    |> mes("Hey, Mudasamu!")
    |> mes("Are you talking")
    |> mes("about me?!")
    |> next()
    |> mes("[Mudasamu]")
    |> mes("No, fat one,")
    |> mes("we're not")
    |> mes("talking about you.")
    |> next()
    |> mes("[Mudasamu]")
    |> mes("*Sigh...*")
    |> mes("I better be paid")
    |> mes("overtime for")
    |> mes("putting up with this.")
    |> close()
  end
end
