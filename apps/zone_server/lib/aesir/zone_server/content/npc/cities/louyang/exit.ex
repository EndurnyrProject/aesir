defmodule Aesir.ZoneServer.Content.Npc.Cities.Louyang.Exit do
  @moduledoc """
  Operates the descent apparatus from Luoyang's Observation Tower.

  ## Behavior

  - Usually transfers users safely to the tower entrance.
  - Has a one-percent mishap that drains 99 percent HP, drops the user nearby, and announces the fall.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Vidar
    - Mass Zero
    - Dino9021
    - Celest
    - MasterOfMuppets
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "louyang",
        x: 84,
        y: 254,
        dir: 0,
        sprite: 111,
        name: "Exit",
        scope: :shared,
        unique_name: "Exit#lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere is some sort")
      |> mes("of descent apparatus.")
      |> mes("Would you like to use it?^000000")
      |> next()
      |> select(["Yes.", "No."])

    if choice == 1 do
      descend(ctx)
    else
      close(ctx)
    end
  end

  defp descend(ctx) do
    if Enum.random(1..100) == 34 do
      ctx =
        ctx
        |> percent_heal(hp: -99, sp: 0)
        |> warp("louyang", 86, 269)

      mapannounce(
        ctx,
        "louyang",
        "#{strnpcinfo(ctx, 0)} : Oh God, I'm faaaaaaaaaaaalling~~!!!!",
        1
      )
    else
      warp(ctx, "lou_in01", 10, 18)
    end
  end
end
