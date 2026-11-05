defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.FactoryBAreaDoor do
  @moduledoc """
  Kiel Hyre passes a metal module through the factory door to a trusted rescuer.

  ## Behavior

  - At the required quest stage, checks inventory capacity, explains his imprisonment, and gives
    the module for Allysia.
  - Advances the quest and offers only silence on later visits.

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
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    case get_char_var(ctx, :KielHyreQuest, 0) do
      40 -> rescue_kiel(ctx)
      stage when stage >= 42 -> ctx |> mes("[Kiel Hyre]") |> mes("......") |> close()
      _ -> ctx
    end
  end

  defp rescue_kiel(ctx) do
    if checkweight(ctx, [{7497, 1}]) == 0 do
      inventory_full(ctx)
    else
      receive_module(ctx)
    end
  end

  defp inventory_full(ctx) do
    ctx
    |> mes("^3355FFJust a second...")
    |> mes("You're carrying too")
    |> mes("many items with you")
    |> mes("right now, so you'll")
    |> mes("need to free up more")
    |> mes("Inventory space first...^000000")
    |> close()
  end

  defp receive_module(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou can faintly hear")
      |> mes("a voice from the other")
      |> mes("side of this door.^000000")
      |> next()
      |> mes("[????]")
      |> mes("^333333...Kiehl...")
      |> mes("...How dare you...!^000000")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Mister Kiel Hyre?")
      |> mes("Is that you in there?")
      |> next()
      |> mes("[Kiel Hyre]")
      |> mes("Wh-who's there?")
      |> mes("Identify yourself!")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I'm... I'm...")
    |> next()
    |> mes("^3355FFYou explain your story")
    |> mes("to the voice behind the")
    |> mes("door, and tell him what")
    |> mes("happened to Elly and Allysia.^000000")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("^333333...Yes... It's me.")
    |> mes("I'm Kiel Hyre, trapped")
    |> mes("in here. He went so far")
    |> mes("as to modify Elly, eh?")
    |> mes("...............................^000000")
    |> next()
    |> mes("[Kiel Hyre]")
    |> mes("^333333Hurry, take this")
    |> mes("module to Allysia!")
    |> mes("She'll know what to do")
    |> mes("with it. If you're really")
    |> mes("helping us, then she'll have")
    |> mes("some instructions for you too.^000000 ")
    |> next()
    |> mes("^3355FFKiel Hyre slid")
    |> mes("a strange metal")
    |> mes("fragment through")
    |> mes("the gap between the")
    |> mes("door and the floor.^000000")
    |> give_item(7497, 1)
    |> set_char_var(:KielHyreQuest, 42)
    |> close()
  end
end
