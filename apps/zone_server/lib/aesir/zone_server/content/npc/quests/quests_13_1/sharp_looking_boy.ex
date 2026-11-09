defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.SharpLookingBoy do
  @moduledoc """
  Jack, who keeps an eye on the ruined tavern in eastern Morocc.

  ## Behavior

  - Assassins get a short explanation of the destroyed town and are let in.
  - Everyone else is told the tavern no longer restricts access, and is praised for
    their courage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 43,
        y: 108,
        dir: 5,
        sprite: 82,
        name: "Sharp-Looking Boy",
        scope: :shared,
        unique_name: "Sharp-Looking Boy#dan_07"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Jack]")

    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:assassin) do
      assassin_lines(ctx)
    else
      greeting(ctx)
    end
  end

  defp assassin_lines(ctx) do
    ctx
    |> mes("Almost half of this town has been destroyed,")
    |> mes("and yet some people still come to visit.")
    |> mes(
      "I must say that it's amazing that our stronghold is still intact, and withstood all the devastation."
    )
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes(
      "As you see, half of this town is gone. I guess there's no real reason to control access to this tavern."
    )
    |> mes("Just feel free to go in.")
    |> next()
    |> mes("[Jack]")
    |> mes("I'm impressed by your courage to step into this hell.")
    |> close()
  end
end
