defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Zawa03 do
  @moduledoc """
  A temple passage reveals the next clue in the Sanctuary quest.

  ## Behavior

  - At quest stage 4, describes the surroundings and advances the quest.

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
        x: 94,
        y: 139,
        dir: 0,
        sprite: -1,
        name: "zawa03",
        scope: :shared,
        trigger: {10, 10}
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
    if get_char_var(ctx, :ra_tem_q, 0) == 4 do
      ctx
      |> mes("^3355FFYou hear noises of some")
      |> mes("commotion from the stairs.^000000")
      |> set_char_var(:ra_tem_q, 5)
      |> close()
    else
      ctx
    end
  end
end
