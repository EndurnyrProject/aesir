defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M22.Crusader.ManInAnguish do
  @moduledoc """
  Murnak Mijoul, the patience test of the Crusader job change quest.

  ## Behavior

  - Turns away Crusaders, Novices and any other class with their own lines, and
    hints a Swordsman at where the tests stand.
  - Offers the endurance test to a Swordsman on step 4, requiring an equipped
    Rosary, then sets `CRUS_Q` to 5 and advances quest 3009 to 3010 before
    warping into the test corridor.
  - Lets a player on step 5 retake the test with the same Rosary requirement.
    The reference ends that branch with a `close2` and then still falls into the
    refusal lines, so a retaking player hears them after the warp as well.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - yyCC
    - Kisuka
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-2/crusader.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_cas",
        x: 238,
        y: 94,
        dir: 5,
        sprite: 733,
        name: "Man in Anguish",
        scope: :renewal
      },
      %{
        map: "prt_castle",
        x: 164,
        y: 32,
        dir: 1,
        sprite: 733,
        name: "Man in Anguish",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @rosary 2608

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Murnak Mijoul]")
    job = Rathena.job_id(base_job(ctx))
    quest = get_char_var(ctx, :CRUS_Q, 0)

    cond do
      job != Rathena.job_id(:swordman) -> turn_away(ctx, job)
      quest in 0..3 -> waiting_lines(ctx)
      quest == 4 -> offer_test(ctx)
      quest == 5 -> retake_test(ctx)
      quest == 6 -> congratulations(ctx)
      true -> pending_lines(ctx)
    end
  end

  defp turn_away(ctx, job) do
    cond do
      job == Rathena.job_id(:crusader) ->
        ctx
        |> mes(
          "Don't linger around in a place like this and forge your own path towards discovering your own strengths. The day that we will join hands in battle will come soon."
        )
        |> close()

      job == Rathena.job_id(:novice) ->
        ctx
        |> mes("A Novice...?")
        |> mes("So green, and yet,")
        |> mes("so much potential.")
        |> next()
        |> mes("[Murnak Mijoul]")
        |> mes(
          "Let me assure you that I'm no criminal. I'm here merely to train myself. Perhaps as you become stronger, you will understand."
        )
        |> close()

      true ->
        ctx
        |> mes(
          "Hm. You have no business in a place like this. Please leave, and do not interrupt my training."
        )
        |> close()
    end
  end

  defp waiting_lines(ctx) do
    ctx
    |> mes("What do you want...?")
    |> mes("If you have no business here,")
    |> mes("then please leave. A tranquil state of mind is essential in self training...")
    |> next()
    |> mes("[Murnak Mijoul]")
    |> mes(
      "I wish to improve the sense of serenity in my heart in preparation for the Holy War that is to come. So please, do not disturb me."
    )
    |> close()
  end

  defp offer_test(ctx) do
    ctx = ctx |> mes("What is it...?") |> mes("Do you have business")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "with me, man of the sword?")
      else
        mes(ctx, "with me, woman of the sword?")
      end

    {ctx, answer} =
      ctx |> next() |> select(["I'd like to take the Crusader test.", "Nothing."])

    if answer == 1, do: begin_test(ctx), else: brush_off(ctx)
  end

  defp brush_off(ctx) do
    ctx
    |> mes("[Murnak Mijoul]")
    |> mes(
      "You seem to have a lot of time on your hands. Why don't you do something more productive, like pick Jellopy off the streets or something?"
    )
    |> close()
  end

  defp begin_test(ctx) do
    ctx =
      ctx
      |> mes("[Murnak Mijoul]")
      |> mes(
        "You wish to become a Crusader...? Hm, fighting in the Holy War is an admirable goal we may both share."
      )
      |> next()
      |> mes("[Murnak Mijoul]")
      |> mes("Your name is")
      |> mes(char_name(ctx, 0) <> "...?")
      |> mes("Let me take")
      |> mes("a look at your face.")
      |> next()

    if wearing_rosary?(ctx) do
      enter_corridor(ctx)
    else
      ctx
      |> mes("[Murnak Mijoul]")
      |> mes(
        "Hmm. You wish to become a Crusader, but do not wear a Rosary? I have no business with you if you cannot uphold our customs."
      )
      |> close()
    end
  end

  defp enter_corridor(ctx) do
    ctx
    |> mes("[Murnak Mijoul]")
    |> mes("Hmm...")
    |> mes(
      "You seem so-so, but also young and ambitious. Ambition may work against you if it is not tempered with patience."
    )
    |> next()
    |> mes("[Murnak Mijoul]")
    |> mes(
      "Don't give me a reason to doubt you, and show me your patience. You must endure my test with your patience if you wish to become a Crusader."
    )
    |> next()
    |> mes("[Murnak Mijoul]")
    |> mes(
      "You may take my test right away. It's actually quite simple. All you must do is walk to the end of the corridor."
    )
    |> next()
    |> mes("[Murnak Mijoul]")
    |> mes("But...")
    |> mes(
      "You must keep one thing in mind. Under no condition are you allowed to kill the monsters."
    )
    |> next()
    |> set_char_var(:CRUS_Q, 5)
    |> changequest(3009, 3010)
    |> mes("[Murnak Mijoul]")
    |> mes("Well then...")
    |> mes("Good luck.")
    |> close()
    |> warp("job_cru", 98, 40)
  end

  defp retake_test(ctx) do
    {ctx, answer} =
      ctx
      |> mes("What is it...?")
      |> mes("You're the Swordman from before. What happened, did you fail?")
      |> next()
      |> select(["Let me retake the test.", "What kind of test was that?!"])

    if answer == 1, do: retake(ctx), else: refuse_retake(ctx)
  end

  defp retake(ctx) do
    ctx =
      ctx
      |> mes("[Murnak Mijoul]")
      |> mes(
        "I'll let you retake the test as much as you like. But if you continuously fail, there's an inherent problem with your"
      )
      |> mes("state of mind.")
      |> next()

    if wearing_rosary?(ctx) do
      ctx
      |> mes("[Murnak Mijoul]")
      |> mes(
        "Your problem is your habit of hitting monsters the moment you see one. You must develop your patience and endurance."
      )
      |> next()
      |> mes("[Murnak Mijoul]")
      |> mes("Just focus...")
      |> mes(
        "Your only goal is to walk from one end of the corridor to the other. It's simple when you think"
      )
      |> mes("about it.")
      |> next()
      |> mes("[Murnak Mijoul]")
      |> mes(
        "No matter what you do, do not kill any of the monsters. This time, think carefully before you draw your sword."
      )
      |> next()
      |> set_char_var(:CRUS_Q, 5)
      |> mes("[Murnak Mijoul]")
      |> mes("Well then...")
      |> mes("Good luck.")
      |> close()
      |> warp("job_cru", 98, 40)
      # The reference closes and warps without `end`, so the refusal lines below
      # still play for a player who just started the retake.
      |> refuse_retake()
    else
      ctx
      |> mes("[Murnak Mijoul]")
      |> mes("Wait...")
      |> mes(
        "Where have you left your Rosary? You can't let that lie around just anywhere. We are supposed to be warriors of holiness."
      )
      |> next()
      |> mes("[Murnak Mijoul]")
      |> mes(
        "Carelessly losing things is an attitude for mere Swordsmen. If you really want to retake the test, you must respect the Crusader traditions."
      )
      |> close()
    end
  end

  defp refuse_retake(ctx) do
    ctx
    |> mes("[Murnak Mijoul]")
    |> mes(
      "Who are you to say that you don't like my test? With that kind of attitude, you'll never become a Crusader."
    )
    |> next()
    |> mes("[Murnak Mijoul]")
    |> mes(
      "I can understand if you are easily frustrated, but you must overcome your frustration to pass this test."
    )
    |> close()
  end

  defp congratulations(ctx) do
    ctx
    |> mes(
      "Hmm, seems like you did well. It shouldn't have been too hard. You no longer have any business"
    )
    |> mes("with me.")
    |> next()
    |> mes("[Murnak Mijoul]")
    |> mes(
      "For your next test, go look for Gabriel Valentine in the Prontera Sanctuary. Well then, I'll see you around."
    )
    |> close()
  end

  defp pending_lines(ctx) do
    ctx
    |> mes("Hmmm...")
    |> mes("You still have tests to complete if you want to become a Crusader, don't you?")
    |> close()
  end

  defp wearing_rosary?(ctx), do: getequipid(ctx, 0) == @rosary or getequipid(ctx, 1) == @rosary
end
