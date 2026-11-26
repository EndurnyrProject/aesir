defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Callghost do
  @moduledoc """
  A hidden trigger summons the Wanderer during the jewel quest.

  ## Behavior

  - Requires an emerald at the first visit, then summons the Wanderer during later quest stages.

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
        map: "gef_fild08",
        x: 182,
        y: 182,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#CallGhost",
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
  def on_talk(ctx), do: ctx

  def ev_ontouch(ctx) do
    quest_stage = get_char_var(ctx, :jewel_nd, 0)

    cond do
      quest_stage == 21 ->
        has_emerald = count_item(ctx, 7725) > 0

        ctx =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("This must be the place")
          |> mes("that shaman was talking")
          |> mes("about. Let's see now...")

        if has_emerald do
          ctx |> donpcevent("The Wanderer::OnEnable") |> close()
        else
          ctx |> mes("Wait. I need that emerald...") |> close()
        end

      quest_stage > 21 and quest_stage < 29 ->
        donpcevent(ctx, "The Wanderer::OnEnable")

      true ->
        ctx
    end
  end
end
