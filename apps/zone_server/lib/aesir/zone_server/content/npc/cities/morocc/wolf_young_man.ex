defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.WolfYoungMan do
  @moduledoc """
  Compares desert wolves with the devastation inflicted on Morocc.

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
        x: 132,
        y: 144,
        dir: 0,
        sprite: 85,
        name: "Wolf Young Man",
        scope: :shared,
        unique_name: "Wolf Young Man#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Young Man]")
    |> mes(
      "I remember I said the bandits of desert are the desert wolves.. Those bastards always roam around in a bunch and they would get so cruel and outrageous if one of them got attacked."
    )
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "They are so vicious, and I'm telling ya, I'm no kidding. You can only find some bones and rotten milk in the backpack after these wolves sweep through."
    )
    |> mes("Those things are so mean and vicious..")
    |> next()
    |> mes("[Young Man]")
    |> mes(
      "But the thing is that.. I even kinda feel those merciless cold-blooded monsters are nothing to be afraid of, compared to what has happened in Morocc. Morocc is already a hell."
    )
    |> close()
  end
end
