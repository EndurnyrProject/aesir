defmodule Aesir.ZoneServer.Content.Npc.Cities.Hugel.Chris do
  @moduledoc """
  Advises visitors where to buy better armor.

  ## Credits

  - Original from rAthena, authors and Contributors
    - vicious_pucca
    - Poki#3
    - erKURITA
    - Munin

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "hu_in01", x: 111, y: 386, dir: 4, sprite: 86, name: "Chris", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Chris]")
    |> mes("You know, the people don't")
    |> mes("fight harmful monsters, they")
    |> mes("just protect themselves by")
    |> mes("equipping armor. That's")
    |> mes("just the way they are.")
    |> next()
    |> mes("[Chris]")
    |> mes("If you want to buy")
    |> mes("some nicer armors,")
    |> mes("then I suggest buying")
    |> mes("some in a bigger city.")
    |> close()
  end
end
