defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Letter do
  @moduledoc """
  The room’s touch event lets the adventurer pick up a letter for the Kiel Hyre investigation.

  ## Behavior

  - Checks inventory capacity before awarding the letter and advancing the quest.
  - Otherwise announces entry into the room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    cond do
      get_char_var(ctx, :KielHyreQuest, 0) != 18 ->
        ctx |> mes("^3355FFYou entered the room.^000000") |> close()

      checkweight(ctx, [{7490, 1}]) == 0 ->
        ctx
        |> mes("^3355FFJust a minute...!")
        |> mes("There's something on")
        |> mes("the floor here, but you")
        |> mes("can't pick it up since")
        |> mes("you're carrying too")
        |> mes("many items now.^000000")
        |> close()

      true ->
        ctx
        |> mes("^3355FFYou've found a letter")
        |> mes("on the floor. Naturally,")
        |> mes("you pick it up, despite")
        |> mes("the fact that it's not")
        |> mes("addressed to you.^000000")
        |> give_item(7490, 1)
        |> set_char_var(:KielHyreQuest, 20)
        |> close()
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnTouch", ctx)
end
