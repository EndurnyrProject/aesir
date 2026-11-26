defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.FatherBiscuss2389 do
  @moduledoc """
  Father Biscuss offers to escort investigators out of the tomb.

  ## Behavior

  - On request, warps the player upstairs; otherwise asks them to continue investigating.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 23,
        y: 89,
        dir: 3,
        sprite: 60,
        name: "Father Biscuss",
        scope: :shared,
        unique_name: "Father Biscuss#tomb"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Father Biscuss]")
      |> mes("Hm...?")
      |> mes("Are you ready to")
      |> mes("head back upstairs?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      ctx
      |> mes("[Father Biscuss]")
      |> mes("Please follow me.")
      |> next()
      |> warp("prt_church", 178, 111)
    else
      ctx
      |> mes("[Father Biscuss]")
      |> mes("Please take your time")
      |> mes("and investigate this as")
      |> mes("thoroughly as you can.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
