defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.Soldier45138 do
  @moduledoc """
  A soldier guards the gunpowder room.

  ## Behavior

  - Stops players carrying gunpowder; otherwise sends them outside.

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
        x: 45,
        y: 138,
        dir: 3,
        sprite: 825,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(count_item(ctx, 7204)) do
      ctx
      |> mes("[Soldier]")
      |> mes("Hold on there!")
      |> next()
      |> mes("[Soldier]")
      |> mes("You're not allowed to bring any gunpowder out of here. Now go")
      |> mes("and put it back, Midgardian! Move!")
      |> close()
    else
      ctx
      |> mes("[Soldier]")
      |> mes(
        "It's strange to see outsiders in this kind of place. We don't have any business with you,"
      )
      |> mes("so move along.")
      |> close2()
      |> warp("lou_in01", 82, 141)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
