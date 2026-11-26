defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Zawa04 do
  @moduledoc """
  A temple passage reveals the next clue in the Sanctuary quest.

  ## Behavior

  - At quest stage 5, describes the surroundings and advances the quest.

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
        x: 132,
        y: 70,
        dir: 0,
        sprite: -1,
        name: "zawa04",
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
    if get_char_var(ctx, :ra_tem_q, 0) == 5 do
      ctx
      |> mes(" ")
      |> mes(" ")
      |> mes("^ff0000Crash!^000000")
      |> next()
      |> mes("^3355FFYou hear something")
      |> mes("fall from the stairs,")
      |> mes("followed by noises that")
      |> mes("sound like a scuffle.^000000")
      |> set_char_var(:ra_tem_q, 6)
      |> close()
    else
      ctx
    end
  end
end
