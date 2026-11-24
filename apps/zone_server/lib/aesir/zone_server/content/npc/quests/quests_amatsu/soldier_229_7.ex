defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier2297 do
  @moduledoc """
  Offers travelers a return from the dungeon.

  ## Behavior

  - Warps the player back after they choose to leave.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_dun01",
        x: 229,
        y: 7,
        dir: 0,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama11"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jyuro]")
      |> mes("Do you want to go back?")
      |> next()
      |> select(["Yes, I do", "I will stay here"])

    if choice == 1 do
      ctx
      |> mes("[Jyuro]")
      |> mes("Take care of yourself.")
      |> close()
      |> warp("ama_in02", 119, 181)
    else
      ctx |> mes("[Jyuro]") |> mes("Take care...") |> close()
    end
  end
end
