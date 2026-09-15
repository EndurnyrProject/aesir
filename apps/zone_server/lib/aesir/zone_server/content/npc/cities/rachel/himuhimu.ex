defmodule Aesir.ZoneServer.Content.Npc.Cities.Rachel.Himuhimu do
  @moduledoc """
  Sleeps through a game of Hide-and-Seek with Anku.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Tsuyuki and Harp
    - L0ne_W0lf
    - Lupus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 272,
        y: 141,
        dir: 3,
        sprite: 921,
        name: "Himuhimu",
        scope: :shared,
        unique_name: "Himuhimu#aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Himuhimu]")
    |> mes("Zzzz...Z...")
    |> mes("Anku, you'll never")
    |> mes("find m... never find")
    |> mes("me here... Zzzzz...")
    |> mes("... So hungry...")
    |> close()
  end
end
