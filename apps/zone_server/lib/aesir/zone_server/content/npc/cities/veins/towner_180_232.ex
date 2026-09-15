defmodule Aesir.ZoneServer.Content.Npc.Cities.Veins.Towner180232 do
  @moduledoc """
  Shares a resident's observations about life in Veins.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_in",
        x: 180,
        y: 232,
        dir: 5,
        sprite: 946,
        name: "Towner",
        scope: :shared,
        unique_name: "Towner#ve20"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Towner]")
    |> mes("It's nice when a town")
    |> mes("is peaceful and quiet...")
    |> mes("But it's lame when a")
    |> mes("tavern is dead like this.")
    |> next()
    |> mes("[Towner]")
    |> mes("Well, there's good")
    |> mes("and bad points to")
    |> mes("everything. Hopefully")
    |> mes("things will pick up")
    |> mes("around here as more of")
    |> mes("you adventurers come visit.")
    |> close()
  end
end
