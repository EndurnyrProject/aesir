defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Soldier do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "manuk",
        x: 304,
        y: 195,
        dir: 5,
        sprite: 454,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ep13pa829"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 do
      ctx
      |> mes("[Food Provider]")
      |> mes(
        "The Manuk family subsists mostly on refining Gray Hollows that were buried a long time ago deep down under the ground."
      )
      |> close()
    else
      ctx
      |> mes("[Food Provider]")
      |> mes("Gdiios duuie Dssoas pogggd fdrul fdddoweet")
      |> close()
    end
  end
end
