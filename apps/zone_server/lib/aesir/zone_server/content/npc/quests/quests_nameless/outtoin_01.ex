defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Outtoin01 do
  @moduledoc """
  The monastery door admits players at the appropriate quest stages.

  ## Behavior

  - Warps players inside during the two permitted quest stages.
  - Otherwise reports that the door cannot be opened.

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
        map: "nameless_i",
        x: 168,
        y: 257,
        dir: 0,
        sprite: 45,
        name: "outtoin_01",
        scope: :shared,
        unique_name: "outtoin_01#mo",
        trigger: {1, 1}
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
    if get_char_var(ctx, :aru_monas, 0) == 18 or get_char_var(ctx, :aru_monas, 0) == 19 do
      warp(ctx, "nameless_in", 12, 41)
    else
      ctx |> mes("^3355FFThe door won't budge:") |> mes("you can't go through.^000000") |> close()
    end
  end
end
