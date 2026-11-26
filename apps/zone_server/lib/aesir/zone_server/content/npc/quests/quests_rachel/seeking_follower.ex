defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.SeekingFollower do
  @moduledoc """
  Delivers High Priest Zhed’s message to the adventurer.

  ## Behavior

  - Calls eligible adventurers back to Zhed and otherwise offers a greeting.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "rachel",
        x: 142,
        y: 167,
        dir: 5,
        sprite: 916,
        name: "Seeking Follower",
        scope: :shared,
        unique_name: "Seeking Follower#rachel",
        trigger: {6, 6}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :lost_boy, 0) == 13 and get_char_var(ctx, :ra_tem_q, 0) == 20 do
      deliver_message(ctx)
    else
      ctx
      |> mes("[Arunafeltz Follower]")
      |> mes("May Freya bless you")
      |> mes("on your journeys...")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :lost_boy, 0) == 13 and get_char_var(ctx, :ra_tem_q, 0) == 20 do
      deliver_message(ctx)
    else
      ctx
    end
  end

  defp deliver_message(ctx) do
    ctx = ctx |> mes("[Arunafeltz Follower]") |> mes("Excuse me, but")

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("are you ", char_name(ctx, 0)), "?"))
      |> next()
      |> select(["Yes."])

    ctx =
      ctx |> mes("[Arunafeltz Follower]") |> mes("High Priest Zhed") |> mes("would like to see")

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("you right away, ", char_name(ctx, 0)), "."))
      |> next()
      |> select(["May ask why?"])

    ctx
    |> mes("[Arunafeltz Follower]")
    |> mes("Well, I actually have no")
    |> mes("idea. I'm only supposed to")
    |> mes("inform you that he's looking")
    |> mes("for you. Please visit High")
    |> mes("Priest Zhed in the second")
    |> mes("right room of the temple.")
    |> close()
  end
end
