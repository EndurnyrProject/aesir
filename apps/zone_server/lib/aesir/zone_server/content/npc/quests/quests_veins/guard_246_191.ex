defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Guard246191 do
  @moduledoc """
  A guard lets visitors leave the volcano camp.

  ## Behavior

  - Offers a way out of the camp.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "thor_camp",
        x: 246,
        y: 191,
        dir: 3,
        sprite: 939,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#goto"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guard]")
      |> mes("What now?")
      |> mes("Can't you see I'm busy?")
      |> next()
      |> select(["Let me go out.", "I'm sorry."])

    if choice == 1 do
      ctx
      |> mes("[Guard]")
      |> mes("Hurry up, and get out!")
      |> close2()
      |> warp("que_thor", 145, 60)
    else
      ctx |> mes("[Guard]") |> mes("If you're sorry,") |> mes("stop bugging me!") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
