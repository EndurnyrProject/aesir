defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Lady do
  @moduledoc """
  Mrs. Lecollane receives the wine delivery at the academy.

  ## Behavior

  - Accepts the wine and advances the quest while reprimanding Elly.
  - Turns away outsiders and asks the player to leave after the delivery.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_school",
        x: 176,
        y: 60,
        dir: 4,
        sprite: 101,
        name: "Lady",
        scope: :shared,
        unique_name: "Lady#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :KielHyreQuest, 0) do
      quest_stage when quest_stage < 2 ->
        ctx
        |> mes("[Mrs. Lecollane]")
        |> mes("Is there a problem?")
        |> mes("Outsiders are not allowed to come")
        |> mes("in here, please leave.")
        |> close()

      2 ->
        receive_delivery(ctx)

      4 ->
        ctx
        |> mes("[Mrs Lecollane]")
        |> mes("Well, our business is")
        |> mes("completed, so would you")
        |> mes("please leave the campus")
        |> mes("as soon as you can? *Sigh*")
        |> mes("I can't believe our future")
        |> mes("is in these girls' hands...")
        |> close()

      _ ->
        ctx
    end
  end

  defp receive_delivery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mrs. Lecollane]")
      |> mes("Oh, hello. Ah!")
      |> mes("have you come to")
      |> mes("deliver my wine? The")
      |> mes("security guard called and")
      |> mes("mentioned you were coming.")
      |> next()
      |> select(["Yes, that's right!", "Er, s-sorry!"])

    case choice do
      1 ->
        accept_wine(ctx)

      2 ->
        ctx
        |> mes("[Mrs. Lecollane]")
        |> mes("Hm...?")
        |> mes("I guess I must")
        |> mes("be mistaken. I'm")
        |> mes("sorry, I thought you")
        |> mes("were somebody else.")
        |> close()

      _ ->
        ctx
    end
  end

  defp accept_wine(ctx) do
    ctx
    |> mes("[Mrs. Lecollane]")
    |> mes("Well, you've come a little")
    |> mes("later than I thought, but")
    |> mes("I suppose it can't be helped.")
    |> mes("I guess the waiting has just")
    |> mes("heightened my anticipation")
    |> mes("for this bottle of wi--")
    |> next()
    |> mes("^3355FF*Cling! Crrrack!*^000000")
    |> next()
    |> mes("[Mrs. Lecollane]")
    |> mes("Elly? Elly did you")
    |> mes("break something again?!")
    |> mes("You've got to be more careful!")
    |> mes("If you don't finish baking those")
    |> mes("cookies by the end of today, your")
    |> mes("semester grades will suffer!")
    |> next()
    |> mes("[Elly]")
    |> mes("B-but I just...")
    |> next()
    |> mes("[Mrs. Lecollane]")
    |> mes("^FF0000Elly^000000!!")
    |> next()
    |> mes("[Elly]")
    |> mes("......")
    |> mes("Yes, Mrs. Lecollane.")
    |> next()
    |> mes("[Mrs. Lecollane]")
    |> mes("*Ahem* Excuse me.")
    |> mes("Would you please leave")
    |> mes("the wine over there? You")
    |> mes("may go now, and please")
    |> mes("don't wander needlessly")
    |> mes("around the academy.")
    |> delitem(7487, 1)
    |> set_char_var(:KielHyreQuest, 4)
    |> close()
  end
end
