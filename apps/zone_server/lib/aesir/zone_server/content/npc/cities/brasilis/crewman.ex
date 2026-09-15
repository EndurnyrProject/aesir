defmodule Aesir.ZoneServer.Content.Npc.Cities.Brasilis.Crewman do
  @moduledoc """
  Offers travelers passage from Brasilis back to Alberta.

  ## Behavior

  - Lets the player return to Alberta or remain in Brasilis.
  - Uses mode-specific arrival coordinates in Alberta.

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
        map: "brasilis",
        x: 316,
        y: 57,
        dir: 3,
        sprite: 100,
        name: "Crewman",
        scope: :shared,
        unique_name: "Crewman#bra1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Crewman]")
      |> mes("My ship is going to back to Alberta, do you want to join us?")
      |> next()
      |> select(["Go back to Alberta.", "Not yet~."])

    case choice do
      1 ->
        return_to_alberta(ctx)

      2 ->
        ctx
        |> mes("[Crewman]")
        |> mes("Ok, suit yourself. We'll see you when we get back then.")
        |> close()

      _ ->
        ctx
    end
  end

  defp return_to_alberta(ctx) do
    ctx = ctx |> mes("[Crewman]") |> mes("I sure do miss home.") |> close()

    if Rathena.truthy?(checkre(ctx, 0)) do
      warp(ctx, "alberta", 245, 87)
    else
      warp(ctx, "alberta", 244, 115)
    end
  end
end
