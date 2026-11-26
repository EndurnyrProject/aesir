defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Imir1 do
  @moduledoc """
  Describes the sanctuary to a searching adventurer.

  ## Behavior

  - Shows a clue during the sanctuary investigation.

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
        map: "que_san04",
        x: 119,
        y: 115,
        dir: 0,
        sprite: -1,
        name: "imir1",
        scope: :shared,
        unique_name: "imir1#rachel",
        trigger: {2, 2}
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
    if get_char_var(ctx, :ra_tem_q, 0) == 21 do
      ctx
      |> mes("^3355FFThis large area looks")
      |> mes("like it was artificially build")
      |> mes("for some reason-- it doesn't")
      |> mes("seem like an area naturally")
      |> mes("infested by monsters.^000000")
      |> next()
      |> mes("^3355FFPerhaps if you explore")
      |> mes("this place, you'll be able")
      |> mes("to find something interesting.^000000")
      |> close()
    else
      ctx
    end
  end
end
