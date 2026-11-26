defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Imir3163152 do
  @moduledoc """
  Describes the adventurer’s return to Rachel.

  ## Behavior

  - Clears blindness and advances the sanctuary quest after Niren’s intervention.

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
        x: 163,
        y: 152,
        dir: 0,
        sprite: -1,
        name: "imir3",
        scope: :shared,
        unique_name: "imir3#rachel2",
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
    if get_char_var(ctx, :ra_tem_q, 0) == 22 do
      ctx
      |> mes("^3355FFYou feel a slight headache")
      |> mes("after you recollect your senses.")
      |> mes("Somehow, you're been brought")
      |> mes("back to Rachel Town. How long")
      |> mes("have you been unconscious?^000000")
      |> next()
      |> sc_end(:sc_blind)
      |> mes("^3355FFIt would be best to")
      |> mes("ask High Priest Zhed")
      |> mes("about what had happened.^000000")
      |> set_char_var(:ra_tem_q, 23)
      |> close()
    else
      ctx
    end
  end
end
