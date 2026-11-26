defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Key1 do
  @moduledoc """
  Places a small key in the temple.

  ## Behavior

  - Lets the adventurer ignore the key or pick it up to advance the quest.

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
        map: "ra_temin",
        x: 272,
        y: 143,
        dir: 0,
        sprite: -1,
        name: "key1",
        scope: :shared,
        unique_name: "key1#rachel",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :ra_tem_q, 0) == 20 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFYou find a small")
        |> mes("shining object laid")
        |> mes("on the floor.^000000")
        |> next()
        |> select(["Ignore", "Pick It Up"])

      if choice == 1 do
        ctx
        |> mes("^3355FFYou decided to ignore")
        |> mes("the small shining object,")
        |> mes("no matter how important it")
        |> mes("may be to you in the future.^000000")
        |> close()
      else
        ctx
        |> mes("^3355FFUpon picking up the")
        |> mes("object, you are able to")
        |> mes("identify it as a small key.")
        |> mes("Perhaps you can use it to")
        |> mes("open some kind of lock.")
        |> set_char_var(:ra_tem_q, 21)
        |> close()
      end
    else
      ctx
    end
  end
end
