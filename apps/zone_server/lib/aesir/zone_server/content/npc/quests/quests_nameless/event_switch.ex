defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.EventSwitch do
  @moduledoc """
  An agent summons qualified travelers to Prontera Church.

  ## Behavior

  - On approach, the agent appears, delivers the invitation, then disappears.

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
        map: "airplane_01",
        x: 90,
        y: 63,
        dir: 0,
        sprite: -1,
        name: "Event Switch",
        scope: :shared,
        unique_name: "Event Switch#pc",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    if (get_char_var(ctx, :prt_curse, 0) == 36 or get_char_var(ctx, :prt_curse, 0) == 45 or
          get_char_var(ctx, :prt_curse, 0) == 56 or get_char_var(ctx, :prt_curse, 0) == 61) and
         get_char_var(ctx, :aru_monas, 0) < 1 do
      ctx = ctx |> hideoffnpc("Agent#pc1") |> mes("[????]")

      ctx
      |> mes("Are you #{char_name(ctx, 0)}?")
      |> mes("I've been waiting for you.")
      |> mes("^6B8E23Priest Bamph^000000 is expecting")
      |> mes("your arrival at ^6B8E23Prontera")
      |> mes("Church^000000. Please visit him")
      |> mes("as soon as you can.")
      |> set_char_var(:aru_monas, 1)
      |> close2()
      |> hideonnpc("Agent#pc1")
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx), do: ctx
end
