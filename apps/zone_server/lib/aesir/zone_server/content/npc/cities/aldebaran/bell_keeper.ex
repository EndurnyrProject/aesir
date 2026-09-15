defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.BellKeeper do
  @moduledoc """
  Warns visitors about the Clock Tower and explains its warp network.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 143,
        y: 136,
        dir: 4,
        sprite: 89,
        name: "Bell Keeper",
        scope: :shared,
        unique_name: "Bell Keeper#A"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Bell Keeper]")
      |> mes(
        "I have been charged by the Committee of 'Heaven on Earth' to guard this entrance of the Clock Tower."
      )
      |> next()
      |> select(["About Clock Tower.", "Quit."])

    if choice == 1 do
      ctx
      |> mes("[Bell Keeper]")
      |> mes(
        "Every floor of this tower is connected to each other by a certain device we like to call 'Warp Gear.'"
      )
      |> next()
      |> mes("[Bell Keeper]")
      |> mes(
        "Even though there are interconnecting warps everywhere in the Clock Tower, beware the 'Random Warp.'"
      )
      |> next()
      |> mes("[Bell Keeper]")
      |> mes(
        "The 'Random Warp' will transport you to an unknown spot. Be advised if you don't want to suddenly be separated from your party..."
      )
      |> next()
      |> mes("[Bell Keeper]")
      |> mes(
        "Remember, Random Warps are shown in green on the mini-map. So keep your eyes peeled for that, as well as for those dangerous Clocks."
      )
      |> close()
    else
      ctx
      |> mes("[Bell Keeper]")
      |> mes(
        "Please take heed that this Clock Tower is filled with extremely dangerous monsters."
      )
      |> close()
    end
  end
end
