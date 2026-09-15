defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.LittleGirl do
  @moduledoc """
  Cries for her missing parents after Morocc’s destruction.

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
        y: 82,
        dir: 0,
        sprite: 703,
        name: "Little Girl",
        scope: :shared,
        unique_name: "Little Girl#moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Little Girl]")
    |> mes("-Crying-")
    |> next()
    |> mes("[Little Girl]")
    |> mes("I'm so scared! Where's mom and dad...! hhooooo... Where's our house...")
    |> next()
    |> mes("[Little Boy]")
    |> mes(
      "Please stop crying, Eliese... You could even faint if you cry all day long, you know..."
    )
    |> next()
    |> mes("[Little Girl]")
    |> mes("No! No... Mommy... Daddy....")
    |> close()
  end
end
