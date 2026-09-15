defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Roberto do
  @moduledoc """
  Boasts about Roberto's successful con.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in02",
        x: 64,
        y: 43,
        dir: 4,
        sprite: 709,
        name: "Roberto",
        scope: :shared,
        unique_name: "Roberto#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Roberto]")
    |> mes("Heh heh heh...")
    |> mes("Whaaaat a gullible")
    |> mes("guy. I took his money")
    |> mes("so easily! I mean, I didn't")
    |> mes("even come up with that great")
    |> mes("of a lie, and he gave it to me!")
    |> close()
  end
end
