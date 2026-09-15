defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.Iriya do
  @moduledoc """
  Directs visitors to Niels and wonders about his latest journey.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in01",
        x: 175,
        y: 120,
        dir: 3,
        sprite: 69,
        name: "Iriya",
        scope: :shared,
        unique_name: "Iriya#um"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Iriya]")
    |> mes("Mr. Niels is at the table in the")
    |> mes("corner. He has many interesting")
    |> mes("stories about the world.")
    |> next()
    |> mes("[Iriya]")
    |> mes("I am not sure where he has been")
    |> mes("this time. He just laughs and")
    |> mes("says 'I don't think I am fit")
    |> mes("for this teaching job.'")
    |> next()
    |> mes("[Iriya]")
    |> mes("In the meantime, people keep")
    |> mes("visiting Mr. Niels... and I")
    |> mes("can't help but wonder...")
    |> mes("Where has he gone?")
    |> close()
  end
end
