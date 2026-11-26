defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Imir2 do
  @moduledoc """
  Draws attention to something beneath the sanctuary water.

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
        y: 133,
        dir: 0,
        sprite: -1,
        name: "imir2",
        scope: :shared,
        unique_name: "imir2#rachel",
        trigger: {20, 5}
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
      |> mes("^3355FFThere's something here")
      |> mes("beneath the water. This")
      |> mes("may warrant a closer look.^000000")
      |> close()
    else
      ctx
    end
  end
end
