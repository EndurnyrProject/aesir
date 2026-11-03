defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AssassinSkills.OldCoffin212267 do
  @moduledoc """
  Coffin in the Sphinx that hides Esmille's Sapphire in the Sonic Acceleration quest.

  ## Behavior

  - On the coffin step, offers several ways to search the coffin until the player reaches
    inside or leaves.
  - Searching inflicts blindness or a curse. Reaching inside bites the player two times in
    three; otherwise they receive a Sapphire and advance the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - DracoRPG
    - L0ne_W0lf
    - 2Spiritual Kid (bug report)

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    if get_char_var(ctx, :ASSN_SK, 0) == 2 do
      ctx
      |> mes("^3355FFIt's an ancient coffin")
      |> mes("with a broken lid that")
      |> mes("is slightly ajar. You")
      |> mes("momentarily catch a glint")
      |> mes("of something shining inside.^000000")
      |> specialeffect(:cone)
      |> next()
      |> search_coffin()
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp search_coffin(ctx) do
    {ctx, choice} =
      select(ctx, [
        "Put your hand inside",
        "Inspect the coffin's opening",
        "Lift the lid",
        "Turn the coffin upside down",
        "Ignore it"
      ])

    case choice do
      1 -> reach_inside(ctx)
      5 -> close(ctx)
      other -> ctx |> fail_search(other) |> search_coffin()
    end
  end

  defp reach_inside(ctx) do
    ctx = reach_into_coffin(ctx)

    if Enum.random(1..3) != 3 do
      ctx |> reach_into_coffin() |> get_bitten()
    else
      ctx
      |> mes("^3355FFYour fingers manage")
      |> mes("to find a solid object")
      |> mes("that you pull out of the")
      |> mes("coffin. You have obtained")
      |> mes("a Sapphire for Esmille.^000000")
      |> set_char_var(:ASSN_SK, 5)
      |> give_item(726, 1)
      |> close()
    end
  end

  defp reach_into_coffin(ctx) do
    ctx
    |> mes("^3355FFYou carefully put your")
    |> mes("hand inside the coffin")
    |> mes("and try to retrieve the")
    |> mes("shining object that")
    |> mes("you had glimpsed.")
    |> mes("...............................^000000")
    |> next()
  end

  defp get_bitten(ctx) do
    ctx
    |> mes("^3355FFSomething inside")
    |> mes("the coffin bit your")
    |> mes("hand really hard!^000000")
    |> sc_start(:sc_poison, 30000, 0)
    |> sc_start(:sc_bleeding, 10000, 0)
    |> emotion(:huk)
    |> close()
  end

  defp fail_search(ctx, 2) do
    ctx
    |> mes("^3355FFYou try to peek")
    |> mes("inside the coffin")
    |> mes("through the gap")
    |> mes("between the coffin's")
    |> mes("edge and the lid.")
    |> mes("...............................^000000")
    |> next()
    |> mes("^3355FFYou're barely able to")
    |> mes("perceive that something")
    |> mes("is squirming inside the")
    |> mes("coffin, but it's far too dark")
    |> mes("to see anything else.^000000")
    |> sc_start(:sc_blind, 30000, 0)
    |> next()
  end

  defp fail_search(ctx, 3) do
    ctx
    |> mes("^3355FFYou don't have the")
    |> mes("strength to move")
    |> mes("something as heavy")
    |> mes("as this coffin's lid...^000000")
    |> sc_start(:sc_curse, 30000, 0)
    |> next()
  end

  defp fail_search(ctx, 4) do
    ctx
    |> mes("^3355FFYou don't have the")
    |> mes("strength to turn this")
    |> mes("coffin upside down.^000000")
    |> next()
  end

  defp fail_search(ctx, _choice), do: ctx
end
