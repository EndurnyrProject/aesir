defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.TimerAlba01 do
  @moduledoc """
  The hidden recruitment timer of Breeder Taab's part-time work, which recruits five helpers
  every two hours.

  ## Behavior

  - Clears the recruiting globals on boot and starts the timer, then announces the five openings
    one second later.
  - At three and six minutes repeats the call for help while fewer than five were recruited, and
    the closing announcement otherwise.
  - At ten minutes closes the round and clears the recruiting flag, and at 130 minutes re-arms
    itself together with the escaped-pet controller.
  - A GM who passes the password check can see the current status and reset the round.

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
        map: "mid_camp",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#timer_alba01"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Todo

  @npc "#timer_alba01"
  @map "mid_camp"
  @recruiting "PartTimeOn"
  @slots "PartTimeSlots"

  @opening_announcement "Breeder Taab: Attention adventurers in the camp! I'm recruiting 5 part-timers for my breeding farm. Only the first to arrive here will be hired!"
  @looking_for_help "Breeder Taab: I'm looking for a part-timer who can work for my breeding farm. If you're interested, please visit me at the farm."
  @recruitment_over "Breeder Taab: The recruitment for my breeding farm has ended. I'll see you next time. Thanks!"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> todo(:callfunc, ["F_GM_NPC"]) |> mes("Please enter the password") |> next()

    if Todo.call!(:callfunc, ["F_GM_NPC", 1854, 0]) < 1 do
      ctx |> mes("Wrong password.") |> close()
    else
      admin_menu(ctx)
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  # The reference's `OnInit` body has no terminator, so boot also runs `OnEnable`'s
  # `initnpctimer`.
  def on_event("OnInit", ctx) do
    ctx
    |> set_server_temp_var(@recruiting, 0)
    |> set_server_temp_var(@slots, 0)
    |> initnpctimer()
  end

  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnStop", ctx), do: stopnpctimer(ctx)

  def on_event("OnTimer1000", ctx) do
    ctx
    |> set_server_temp_var(@slots, 0)
    |> set_server_temp_var(@recruiting, 1)
    |> mapannounce(@map, @opening_announcement, 1, "0x00ff00")
  end

  def on_event("OnTimer180000", ctx), do: announce_help_wanted(ctx)
  def on_event("OnTimer360000", ctx), do: announce_help_wanted(ctx)

  def on_event("OnTimer600000", ctx) do
    ctx
    |> mapannounce(@map, @recruitment_over, 1, "0x00ff00")
    |> set_server_temp_var(@recruiting, 0)
  end

  def on_event("OnTimer7800000", ctx) do
    ctx
    |> donpcevent("#{@npc}::OnEnable")
    |> donpcevent("#monster_master::OnEnable")
  end

  defp admin_menu(ctx) do
    ctx = mes(ctx, "Current Status:")

    ctx =
      if get_server_temp_var(ctx, @recruiting, 0) == 1 do
        mes(ctx, "Recruiting.")
      else
        mes(ctx, "Not Recruiting.")
      end

    {ctx, choice} =
      ctx
      |> mes("Recruited #{get_server_temp_var(ctx, @slots, 0)} part-timers.")
      |> mes("What do you want to do?")
      |> next()
      |> select(["Reset the recruiting.", "Cancel."])

    case choice do
      1 -> reset_recruiting(ctx)
      2 -> ctx |> mes("Canceled.") |> close()
      _ -> ctx
    end
  end

  defp reset_recruiting(ctx) do
    ctx
    |> mes("Recruiting has been reset.")
    |> mes("Timer has stopped!")
    |> stopnpctimer()
    |> next()
    |> mes("Global values have been reset.")
    |> set_server_temp_var(@recruiting, 0)
    |> set_server_temp_var(@slots, 0)
    |> next()
    |> mes("Recruiting has been reset.")
    |> mes("Timer has started!")
    |> donpcevent("#{@npc}::OnEnable")
    |> close()
  end

  defp announce_help_wanted(ctx) do
    if get_server_temp_var(ctx, @recruiting, 0) < 5 do
      mapannounce(ctx, @map, @looking_for_help, 1, "0x00ff00")
    else
      mapannounce(ctx, @map, @recruitment_over, 1, "0x00ff00")
    end
  end
end
