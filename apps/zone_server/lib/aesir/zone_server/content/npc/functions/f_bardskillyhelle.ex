defmodule Aesir.ZoneServer.Content.Npc.Functions.FBardskillyhelle do
  @moduledoc """
  Startles Yhelle the hen when a player walks into one of her Niflheim roosts during the Bard
  Pang Voice skill quest.

  ## Behavior

  - Refuses and ends the calling script when the player lacks inventory space or weight capacity.
  - Hides the touched roost and reveals the next one in the five-roost cycle.
  - One time in three, a Bard still collecting eggs finds an Egg and advances the egg count.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - L0ne_W0lf
    - DracoRPG

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/bard_skills.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @egg 574

  @doc """
  Callable rAthena global function `F_BardSkillYhelle(current, next)`; returns `{ctx, nil}`, or
  throws `{:script_end, ctx}` after the refusal dialog.
  """
  @spec call(Ctx.t(), [integer()]) :: {Ctx.t(), nil} | no_return()
  def call(ctx, args) do
    if checkweight(ctx, [{1201, 1}]) == 0 or
         get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 2000 do
      refuse(ctx)
    else
      {startle(ctx, args), nil}
    end
  end

  defp refuse(ctx) do
    ctx =
      ctx
      |> mes("^3355FFHold it right there!")
      |> mes(
        "You're carrying too many items and don't have enough inventory space to receive any rewards. Please make more inventory space available and come back to take this challenge."
      )
      |> close()

    throw({:script_end, ctx})
  end

  defp startle(ctx, args) do
    ctx =
      ctx
      |> emotion(:huk)
      |> emotion(:huk)
      |> mes("[Hen Yhelle]")
      |> mes("Cluck-Cluuuck?")
      |> mes("Cluck cluck cluck!")
      |> next()

    left_egg? = Enum.random(1..3) == 2

    ctx =
      ctx
      |> disablenpc("Yhelle#bard_chick#{Enum.at(args, 0, 0)}")
      |> donpcevent("Yhelle#bard_chick#{Enum.at(args, 1, 0)}::OnEnable")
      |> mes("^3355FFUpon sensing your")
      |> mes("presense, the hen")
      |> mes("quickly ran away.^000000")

    if left_egg? and collecting_eggs?(ctx), do: find_egg(ctx), else: ctx
  end

  defp collecting_eggs?(ctx) do
    progress = get_char_var(ctx, :qskill_bard, 0)
    progress > 1 and progress < 7
  end

  defp find_egg(ctx) do
    progress = get_char_var(ctx, :qskill_bard, 0)

    ctx
    |> mes("^3355FFYou found ^3333331 Egg^3355FF in the")
    |> mes("place where Yhelle the")
    |> mes("Hen was roosting.^000000")
    |> set_char_var(:qskill_bard, progress + 1)
    |> give_item(@egg, 1)
  end
end
