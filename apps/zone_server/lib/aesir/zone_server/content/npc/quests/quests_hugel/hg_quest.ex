defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.HgQuest do
  @moduledoc """
  The arcade owner directs players seeking the bingo coordinator.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_bingo",
        x: 49,
        y: 12,
        dir: 0,
        sprite: 139,
        name: "",
        scope: :shared,
        unique_name: "#Hg_Quest",
        trigger: {4, 4}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :hg_ma1, 0) == 6 do
      {ctx, _} =
        ctx
        |> mes("[Arcade Owner]")
        |> mes("Welcome to the")
        |> mes("Bingo Game Arcade.")
        |> mes("Would you like to")
        |> mes("play a game?")
        |> next()
        |> select(["I want to meet the game coordinator."])

      ctx
      |> mes("[Arcade Owner]")
      |> mes("I'm sorry, but if he's on")
      |> mes("duty, we can't really let you")
      |> mes("meet him unless you come")
      |> mes("here to play a game. Our")
      |> mes("game coordinators tend")
      |> mes("to be pretty busy...")
      |> close()
    else
      ctx
    end
  end
end
