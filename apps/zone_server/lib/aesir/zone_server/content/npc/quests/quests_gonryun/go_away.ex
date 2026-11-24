defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.GoAway do
  @moduledoc """
  An unseen voice guards the doctor's room in Juno and turns away visitors in the Broken Sword
  quest.

  ## Behavior

  - Talking to it or stepping into its area before the quest reaches the doctor warps the
    player out to Juno.
  - Once the player is looking for the doctor, a 1 in 10 chance lets them through to meet her;
    otherwise they are warped out to Juno.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in01",
        x: 104,
        y: 94,
        dir: 0,
        sprite: 139,
        name: "go away",
        scope: :shared,
        unique_name: "go away#gnbs",
        trigger: {2, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :b_sword, 0) do
      step when step < 22 -> get_out(ctx)
      22 -> may_pass(ctx)
      _ -> ctx
    end
  end

  defp may_pass(ctx) do
    if Enum.random(1..10) == 10 do
      ctx
      |> mes("[??????]")
      |> mes("I am very busy right now. Please leave.")
      |> set_char_var(:b_sword, 23)
      |> close()
    else
      get_out(ctx)
    end
  end

  defp get_out(ctx) do
    ctx
    |> mes("[??????]")
    |> mes("^FF0000What are you doing here?")
    |> mes("Get out of here!^000000")
    |> close()
    |> warp("yuno", 246, 143)
  end
end
