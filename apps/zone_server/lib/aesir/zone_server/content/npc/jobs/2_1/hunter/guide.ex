defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.Guide do
  @moduledoc """
  Guide at the entrance of the Hunter test arena.

  ## Behavior

  - Explains the test rules to a new examinee and saves them at the arena.
  - Restores the HP and SP of an examinee who failed and offers to let them keep trying or resign.
  - Sends resigning examinees and those who already passed back to Payon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_hunte",
        x: 178,
        y: 32,
        dir: 1,
        sprite: 107,
        name: "Guide",
        scope: :shared,
        unique_name: "Guide#hnt",
        trigger: {5, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    quest = get_char_var(ctx, :HNTR_Q, 0)

    cond do
      quest == 12 -> explain_rules(ctx)
      quest > 12 and quest < 16 -> offer_resignation(ctx)
      quest > 15 -> send_away(ctx)
      true -> ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp explain_rules(ctx) do
    ctx
    |> mes("[Guide]")
    |> mes(
      "Good day. Welcome to the Hunter testing site. The test begins when you enter the next room."
    )
    |> next()
    |> mes("[Guide]")
    |> mes(
      "As explained before, hunt 4 or more of the monsters named ^3355FFJob change monster^000000. Upon doing so, a switch in the center of the map will then appear."
    )
    |> next()
    |> mes("[Guide]")
    |> mes(
      "When you destroy the switch, the exit will appear in the 12 o'clock direction of the map. Complete everything within the given time and escape."
    )
    |> next()
    |> mes("[Guide]")
    |> mes(
      "If you faint in the middle, fall into a trap, or go over the time limit, you'll fail. Then you must then retake the test."
    )
    |> next()
    |> mes("[Guide]")
    |> mes(
      "We will provide the arrows, so just make sure that you bring a bow. Well, then. Please enter when you are ready."
    )
    |> savepoint("job_hunte", 176, 22)
    |> close()
  end

  defp offer_resignation(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Guide]")
      |> mes("Hmm...")
      |> mes("Did you mess up?")
      |> mes("I'll recover some")
      |> mes("of your HP and SP for now.")
      |> percent_heal(hp: 100, sp: 100)
      |> next()
      |> mes("[Guide]")
      |> mes(
        "If it's too hard, it wouldn't hurt to try again next time. Would you like to resign for now?"
      )
      |> next()
      |> select(["Keep trying.", "Resign."])

    if choice == 1 do
      ctx
      |> mes("[Guide]")
      |> mes(
        "Okay. Do your best and become a great Hunter. Please enter the waiting room. If someone is already taking the test, you must wait until that person is done."
      )
      |> close()
    else
      ctx
      |> mapannounce(
        "job_hunte",
        "#{char_name(ctx, 0)} has resigned. Next person, please enter.",
        1
      )
      |> mes("[Guide]")
      |> mes(
        "Very well. I'll send you to Payon. Hope to see you next time. Don't forget to save when you leave."
      )
      |> close()
      |> set_char_var(:HNTR_Q, 13)
      |> savepoint("payon", 104, 99)
      |> warp("payon_in02", 21, 27)
    end
  end

  defp send_away(ctx) do
    ctx
    |> mes("[Guide]")
    |> mes("You shouldn't be here. How about finding the required job change item first?")
    |> close()
    |> savepoint("payon", 104, 99)
    |> warp("payon_in02", 21, 27)
  end
end
