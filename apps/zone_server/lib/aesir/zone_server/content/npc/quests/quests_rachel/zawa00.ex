defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Zawa00 do
  @moduledoc """
  An open window offers a way into the temple.

  ## Behavior

  - Quest progress determines whether the player can enter through the window.

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
        map: "ra_temple",
        x: 67,
        y: 209,
        dir: 0,
        sprite: -1,
        name: "zawa00",
        scope: :shared,
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
    quest = get_char_var(ctx, :ra_tem_q, 0)

    cond do
      quest == 2 -> first_visit(ctx)
      quest >= 3 and quest < 10 -> return_visit(ctx)
      true -> ctx
    end
  end

  defp first_visit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou notice a slightly")
      |> mes("open window that")
      |> mes("you can easily enter.^000000")
      |> next()
      |> select(["Stay", "Enter Through Window"])

    if choice == 2 do
      ctx
      |> mes("^3355FFYou pull the window,")
      |> mes("and it smoothly opens.")
      |> mes("This is probably what")
      |> mes("those mischevious hits")
      |> mes("have been using to enter")
      |> mes("unnoticed into this temple.^000000")
      |> close2()
      |> warp("que_rachel", 62, 82)
    else
      ctx
      |> mes("^3355FFYou decide that it's")
      |> mes("wrong to sneak into")
      |> mes("a place. But what if")
      |> mes("you don't get caught?^000000")
      |> close()
    end
  end

  defp return_visit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFWould you like to")
      |> mes("enter the temple")
      |> mes("through this window?^000000")
      |> next()
      |> select(["Enter", "Cancel"])

    if choice == 1 do
      ctx |> close2() |> warp("que_rachel", 62, 82)
    else
      ctx
      |> mes("^3355FFUsing this window is")
      |> mes("probably the only way")
      |> mes("that you can enter.^000000")
      |> close()
    end
  end
end
