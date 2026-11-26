defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.InsideIsland do
  @moduledoc """
  Traces inside the island reveal signs of people and a creature.

  ## Behavior

  - Describes the traces at the relevant point in the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nameless_in",
        x: 21,
        y: 176,
        dir: 0,
        sprite: -1,
        name: "Inside Island",
        scope: :shared,
        unique_name: "Inside Island#Aru",
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
    ctx
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 17 do
      ctx
      |> mes("^3355FFThere are traces of")
      |> mes("humans around here,")
      |> mes("along with some kind")
      |> mes("of creature that you")
      |> mes("can't clearly identify.^000000")
      |> close()
    else
      ctx
    end
  end
end
