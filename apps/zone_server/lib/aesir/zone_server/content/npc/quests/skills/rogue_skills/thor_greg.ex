defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.ThorGreg do
  @moduledoc """
  Thor Greg, Haijara's middle son, who sends Rogues to the Close Confine training ground.

  ## Behavior

  - Starts the quest for Rogues and Stalkers who have not begun it.
  - Reads Louis's letter and hands the player a letter for his brother Jay.
  - Once his father approves, optionally explains the exercise and warps the player to the
    training ground waiting room; a player who left mid-training can be sent back.
  - Confirms completed training and points the player back to his father; otherwise gives
    hints for the current step. Non-Rogues get idle chatter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 268,
        y: 125,
        dir: 2,
        sprite: 86,
        name: "Thor Greg",
        scope: :shared,
        unique_name: "Thor Greg#rogueguild"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if rogue_or_stalker?(ctx) do
      quest_step(ctx, get_char_var(ctx, :ROG_SK, 0))
    else
      ctx
      |> mes("[Thor Greg]")
      |> mes("Hmm, gank this, gank")
      |> mes("that. *Sigh* It's my most")
      |> mes("shameful fault: I spend zeny")
      |> mes("almost as quickly as I can")
      |> mes("steal it. It's irresponsible...")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp rogue_or_stalker?(ctx) do
    Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) or
      Rathena.job_id(class(ctx)) == Rathena.job_id(:thief_high)
  end

  defp quest_step(ctx, step) when step < 1 do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Where did father go?")
    |> mes("I hope those weird men")
    |> mes("didn't get to him. With")
    |> mes("any luck, he's hidden in")
    |> mes("the panic room, but still...")
    |> set_char_var(:ROG_SK, 1)
    |> close()
  end

  defp quest_step(ctx, 1) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Hm... My father might")
    |> mes("be hiding in the panic")
    |> mes("room. I've never been able")
    |> mes("to find it, but Markie says")
    |> mes("that the entrance is cleverly")
    |> mes("hidden to her left. Hmmm...")
    |> close()
  end

  defp quest_step(ctx, 2) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Are you looking for")
    |> mes("my little brother, ^FF0000Louis^000000?")
    |> mes("Oh, he's always hanging")
    |> mes("around that ^FF0000Hollgrehenn Jr.^000000")
    |> mes("here in the Rogue Guild.")
    |> mes("What did you need him for?")
    |> close()
  end

  defp quest_step(ctx, 3) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("What's this you're")
    |> mes("giving me? A letter")
    |> mes("from Louis? Let's see...")
    |> set_char_var(:ROG_SK, 4)
    |> next()
    |> mes("[Thor Greg]")
    |> mes("Oh God, father's in")
    |> mes("serious trouble! I better")
    |> mes("tell my older brother, Jay,")
    |> mes("right away! Quick, find ^FF0000Jay^000000")
    |> mes("next to ^FF0000Antonio Jr.^000000 here in")
    |> mes("the guild! P-please hurry!")
    |> close()
  end

  defp quest_step(ctx, 4) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("You can find Jay hanging")
    |> mes("out with Antonio Jr. here")
    |> mes("inside the Rogue Guild. ")
    |> mes("Please bring him the letter")
    |> mes("I've written as soon as possible!")
    |> close()
  end

  defp quest_step(ctx, 5) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Hopefully, father hasn't")
    |> mes("gone outside of the Rogue")
    |> mes("Guild's panic room. That")
    |> mes("may be the only place")
    |> mes("where he's safe...")
    |> close()
  end

  defp quest_step(ctx, 6) do
    {ctx, choice} =
      ctx
      |> mes("[Thor Greg]")
      |> mes("What's that? Father")
      |> mes("wanted me to teach you")
      |> mes("the secret Rogue skill?")
      |> mes("Alright, I'll train you in the")
      |> mes("same way father did. Would")
      |> mes("you like an explanation first?")
      |> next()
      |> mes("[Thor Greg]")
      |> mes("If you don't want an")
      |> mes("explanation, I'll just")
      |> mes("send you to the training")
      |> mes("ground right away so that")
      |> mes("you can learn ^FF0000Close Confine^000000.")
      |> next()
      |> select(["Listen to Explanation", "Go to Training Ground"])

    if choice == 1 do
      ctx |> explain_training() |> close() |> send_to_training()
    else
      send_to_training(ctx)
    end
  end

  defp quest_step(ctx, 7) do
    {ctx, choice} =
      ctx
      |> mes("[Thor Greg]")
      |> mes("Alright, I'm going to break")
      |> mes("the fourth wall here and assume")
      |> mes("you were disconnected from the")
      |> mes("game. Would you like to return")
      |> mes("to the training ground in order")
      |> mes("to learn ^FF0000Close Confine^000000?")
      |> next()
      |> select(["Yes, please.", "No, thanks."])

    if choice == 1 do
      ctx
      |> explain_training()
      |> set_char_var(:ROG_SK, 6)
      |> close()
      |> send_to_training()
    else
      ctx
      |> mes("[Thor Greg]")
      |> mes("Alright, alright.")
      |> mes("When you feel ready")
      |> mes("to resume training,")
      |> mes("just let me know.")
      |> close()
    end
  end

  defp quest_step(ctx, 8) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Ah, I hear from Kienna")
    |> mes("that you've completed your")
    |> mes("training. Congratulations!")
    |> mes("Now, please speak to my")
    |> mes("father so that he can explain the Close Confine skill in detail.")
    |> set_char_var(:ROG_SK, 9)
    |> close()
  end

  defp quest_step(ctx, 9) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Please talk to my father")
    |> mes("so that he can explain the")
    |> mes("nuances of the Close Confine")
    |> mes("skill to you. He should still be in the Rogue Guild's panic room.")
    |> close()
  end

  defp quest_step(ctx, 11) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("You know, Chae Takbae")
    |> mes("would say, ''I'm Chae")
    |> mes("Takbae. And you are...?''")
    |> mes("to opponents, and right")
    |> mes("before they could answer,")
    |> mes("he'd beat them to a pulp.")
    |> next()
    |> mes("[Thor Greg]")
    |> mes("He really is")
    |> mes("a legendary hero")
    |> mes("amongst Rogues...!")
    |> close()
  end

  defp quest_step(ctx, _step) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Hm...?")
    |> mes("It seems that")
    |> mes("you're much stronger")
    |> mes("than even me. There's")
    |> mes("probably not too many")
    |> mes("people who'd mess with you...")
    |> close()
  end

  defp explain_training(ctx) do
    ctx
    |> mes("[Thor Greg]")
    |> mes("Alright, the very first step")
    |> mes("to learning ^FF0000Close Confine^000000")
    |> mes("is to master blocking your")
    |> mes("enemy's movement. I'll send")
    |> mes("you to a special training")
    |> mes("ground so you can practice.")
    |> next()
    |> mes("[Thor Greg]")
    |> mes("There, you'll encounter our")
    |> mes("training partner. Approach her")
    |> mes("closely and make sure that you")
    |> mes("predict and block her movements")
    |> mes("to the left, right or backward. Get ready, I'm sending you now...")
  end

  defp send_to_training(ctx), do: warp(ctx, "in_rogue", 89, 114)
end
