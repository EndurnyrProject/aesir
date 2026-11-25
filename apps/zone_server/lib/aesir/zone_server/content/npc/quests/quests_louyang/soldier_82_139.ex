defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Soldier82139 do
  @moduledoc """
  A soldier guards the entrance to a restricted room.

  ## Behavior

  - Refuses entry to players carrying prohibited materials; otherwise sends them inside.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in01",
        x: 82,
        y: 139,
        dir: 7,
        sprite: 825,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(count_item(ctx, 7068)) or Rathena.truthy?(count_item(ctx, 7096)) or
         Rathena.truthy?(count_item(ctx, 7004)) do
      ctx
      |> mes("[Soldier]")
      |> mes("I am sorry, but it is prohibited to enter with some of the products")
      |> mes("you are carrying. I cannot let you in.")
      |> close()
    else
      ctx
      |> mes("[Soldier]")
      |> mes(
        "There is nothing much, but if you wish to look around this room, please be my guest."
      )
      |> close2()
      |> warp("lou_in01", 47, 141)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
