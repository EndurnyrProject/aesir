defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Coach50100 do
  @moduledoc """
  Congratulates challengers after the final battle.

  ## Behavior

  - Advances the quest, returns the player and resets the challenge.

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
        map: "ama_test",
        x: 50,
        y: 100,
        dir: 3,
        sprite: 762,
        name: "Coach",
        scope: :shared,
        unique_name: "Coach#after",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Coach#after")
  def on_event("OnTouch_", ctx), do: finish_challenge(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  defp finish_challenge(ctx) do
    ctx
    |> mes("[Coach]")
    |> mes("( Clap- Clap- Clap- )")
    |> next()
    |> mes("[Coach]")
    |> mes("Hohoho~ You are really something.")
    |> mes("You've got the moves, kiddo.")
    |> mes("I'll give you that.")
    |> next()
    |> mes("[Coach]")
    |> mes("Well, time's up so...")
    |> mes("Let me show you the exit.")
    |> mes("I had a great time...")
    |> mes("Don't forget to get your reward~")
    |> close()
    |> set_char_var(:event_momo, 3)
    |> changequest(8129, 8130)
    |> warp("amatsu", 223, 230)
    |> disablenpc("Coach#after")
    |> donpcevent("Timer#ama::OnDisable")
    |> donpcevent("Assistant#ama::OnReset")
  end
end
