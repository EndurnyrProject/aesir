defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Out1 do
  @moduledoc """
  Guides the adventurer back toward the conversation.

  ## Behavior

  - At the relevant quest stage, redirects the adventurer to listen at the wall.

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
        x: 293,
        y: 144,
        dir: 0,
        sprite: -1,
        name: "out1",
        scope: :shared,
        unique_name: "out1#rachel",
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
    if get_char_var(ctx, :ra_tem_q, 0) == 18 do
      ctx
      |> mes("^3355FFIt sounds like they're")
      |> mes("still talking. It'd be")
      |> mes("best to patient and wait")
      |> mes("just a little while longer.")
      |> mes("Still... It's awfully boring.^000000")
      |> next()
      |> mes("^3355FFA little eavesdropping")
      |> mes("never hurt anyone. Maybe")
      |> mes("you can hear them a little")
      |> mes("better if you listen from")
      |> mes("the left side of the wall.^000000")
      |> close2()
      |> warp("ra_temin", 300, 153)
    else
      ctx
    end
  end
end
