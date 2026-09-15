defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.LittleBoy do
  @moduledoc """
  Tries to comfort his frightened younger companion after Morocc’s destruction.

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
        x: 118,
        y: 82,
        dir: 1,
        sprite: 706,
        name: "Little Boy",
        scope: :shared,
        unique_name: "Little Boy#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Little Boy]")
    |> mes("............... Let's stop crying, Eliese...")
    |> next()
    |> mes("[Little Girl]")
    |> mes("Nooooooo... Mommy... Daddy....!!")
    |> next()
    |> mes("[Little Boy]")
    |> mes("Mom and Dad are now...")
    |> next()
    |> mes("[Little Girl]")
    |> mes("No...... noooooo...")
    |> next()
    |> mes("[Little Boy]")
    |> mes(
      "Right, you love ice-cream, don't you? I.. I can get you an ice-cream if you stop crying. Don't cry, Eliese, please.. Ok? Don't..."
    )
    |> close()
  end
end
