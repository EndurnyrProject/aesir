defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbroch.Morei do
  @moduledoc """
  Offers to return Einbroch Tower visitors to ground level.

  ## Behavior

  - Transfers consenting visitors to one of three randomly selected exits.
  - Leaves visitors in the tower when they decline.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - reddozen
    - Komurka
    - erKURITA
    - RockmanEXE
    - Dj-Yhn
    - Silent
    - Evera
    - Samuray22
    - DZeroX
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 175,
        y: 196,
        dir: 5,
        sprite: 854,
        name: "Morei",
        scope: :shared,
        unique_name: "Morei#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Morei]")
      |> mes("Greetings,")
      |> mes("I am Morei,")
      |> mes("Assistant Guide")
      |> mes("of Einbroch Tower.")
      |> next()
      |> mes("[Morei]")
      |> mes("If you wish to return")
      |> mes("to the ground floor,")
      |> mes("please let me know.")
      |> mes("Would you like to go")
      |> mes("back to ground level?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> return_to_ground(ctx)
      2 -> stay_in_tower(ctx)
      _ -> ctx
    end
  end

  defp return_to_ground(ctx) do
    ctx =
      ctx
      |> mes("[Morei]")
      |> mes("I see.")
      |> mes("Let me lead you")
      |> mes("to the ground floor.")
      |> mes("Thank you for using")
      |> mes("our services.")
      |> close()

    case Enum.random(1..3) do
      1 -> warp(ctx, "einbroch", 170, 229)
      2 -> warp(ctx, "einbroch", 216, 188)
      3 -> warp(ctx, "einbroch", 178, 167)
      _ -> stay_in_tower(ctx)
    end
  end

  defp stay_in_tower(ctx) do
    ctx
    |> mes("[Morei]")
    |> mes("I see.")
    |> mes("I hope you")
    |> mes("enjoy your time")
    |> mes("in Einbroch Tower.")
    |> close()
  end
end
