defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Zawa01 do
  @moduledoc """
  A temple passage reveals the next clue in the Sanctuary quest.

  ## Behavior

  - At quest stage 2, describes the surroundings and advances the quest.

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
        map: "que_rachel",
        x: 60,
        y: 80,
        dir: 0,
        sprite: -1,
        name: "zawa01",
        scope: :shared,
        trigger: {5, 5}
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
    if get_char_var(ctx, :ra_tem_q, 0) == 2 do
      ctx
      |> mes("^3355FFIt's strangely")
      |> mes("dark in here.^000000")
      |> set_char_var(:ra_tem_q, 3)
      |> close()
    else
      ctx
    end
  end
end
