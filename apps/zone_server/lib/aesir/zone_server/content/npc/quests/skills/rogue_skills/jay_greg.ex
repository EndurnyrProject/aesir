defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.JayGreg do
  @moduledoc """
  Jay Greg, Haijara's eldest son, who relays news in the Close Confine skill quest.

  ## Behavior

  - Starts the quest for Rogues and Stalkers who have not begun it.
  - Reads Thor's letter and hands the player a reply for his father.
  - Otherwise gives hints for the current quest step; non-Rogues get idle chatter.

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
        x: 181,
        y: 114,
        dir: 3,
        sprite: 85,
        name: "Jay Greg",
        scope: :shared,
        unique_name: "Jay Greg#rogueguild"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if rogue_or_stalker?(ctx) do
      ctx |> mes("[Jay Greg]") |> quest_step(get_char_var(ctx, :ROG_SK, 0)) |> close()
    else
      ctx
      |> mes("[Jay Greg]")
      |> mes("Ever since I learned")
      |> mes("Intimdate, I've gotten")
      |> mes("real punchy, maybe even")
      |> mes("masochistic. I mean, if they")
      |> mes("hit you with a skill, you can")
      |> mes("hit them back with it!")
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
    |> mes("My father must be hidden")
    |> mes("in the Rogue Guild's panic")
    |> mes("room. Strangely, my brothers")
    |> mes("and I can never find it and")
    |> mes("figure out whether he's safe...")
    |> set_char_var(:ROG_SK, 1)
    |> next()
    |> mes("[Jay Greg]")
    |> mes("Recently, he's been pursued")
    |> mes("by these strange men who've")
    |> mes("been threatening our family.")
    |> mes("Well, he did just teach us")
    |> mes("a new skill, so he can use")
    |> mes("that to protect himself...")
  end

  defp quest_step(ctx, 1) do
    ctx
    |> mes("I'm guessing my father")
    |> mes("hid himself in the Rogue")
    |> mes("Guild's panic room. We can")
    |> mes("never find it, but supposedly")
    |> mes("the entrance is hidden close")
    |> mes("to Markie somewhere.")
  end

  defp quest_step(ctx, 2) do
    ctx
    |> mes("You're looking for")
    |> mes("Louis, my little brother?")
    |> mes("He's here in the Rouge Guild,")
    |> mes("so it shouldn't be too hard to")
    |> mes("find him. He's probably just")
    |> mes("standing near Hollgrehen Jr.")
  end

  defp quest_step(ctx, 3) do
    ctx
    |> mes("Thor? He should be")
    |> mes("around the Rogue Guild")
    |> mes("somewhere. Have you tried")
    |> mes("looking around Hermathorn Jr.?")
  end

  defp quest_step(ctx, 4) do
    ctx
    |> mes("A letter for me...?")
    |> mes("Ah, it's from Thor, so")
    |> mes("I guess I better read")
    |> mes("it right away. Hmmm...")
    |> set_char_var(:ROG_SK, 5)
    |> next()
    |> mes("[Jay Greg]")
    |> mes("I see... I must report")
    |> mes("this to the Rogue Guild")
    |> mes("right away, and send a reply")
    |> mes("to my father. Hmm. Let me")
    |> mes("write him a letter right now.")
    |> mes("Please give me a moment...")
    |> next()
    |> mes("[Jay Greg]")
    |> mes("There, it's done. Please")
    |> mes("give this to my father with")
    |> mes("all the haste you can muster.")
    |> mes("I know it's much to ask, but")
    |> mes("I cannot find the way to the")
    |> mes("hidden panic room myself...")
  end

  defp quest_step(ctx, 5) do
    ctx
    |> mes("Please give my reply")
    |> mes("to my father as soon as")
    |> mes("you can. He's still hidden")
    |> mes("in the Rogue Guild's panic")
    |> mes("room. That is, if our enemies")
    |> mes("still haven't found him yet.")
  end

  defp quest_step(ctx, step) when step in [6, 7] do
    ctx
    |> mes("You need to train for")
    |> mes("the Close Confine skill?")
    |> mes("I think Thor is the only")
    |> mes("one with access to the")
    |> mes("training ground, so")
    |> mes("talk to him first.")
  end

  defp quest_step(ctx, 8) do
    ctx
    |> mes("Ah, you finished the")
    |> mes("training for Close Confine,")
    |> mes("did you? Great, now go and")
    |> mes("tell my brother, Thor.")
  end

  defp quest_step(ctx, 9) do
    ctx
    |> mes("Hm. You should probably")
    |> mes("talk to my father to learn")
    |> mes("more of the nuances about")
    |> mes("the Close Confine skill.")
    |> mes("Have you seen him in the")
    |> mes("Rogue Guild's panic room?")
  end

  defp quest_step(ctx, 12) do
    ctx
    |> mes("Chae Takbae sure")
    |> mes("seemed like a stubborn,")
    |> mes("thuggish guy. But he must")
    |> mes("have been pretty smart to")
    |> mes("invent some of his own skills.")
  end

  defp quest_step(ctx, _step) do
    ctx
    |> mes("I get the feeling")
    |> mes("that you're going to")
    |> mes("be one of the best Rogues")
    |> mes("around, if you already aren't.")
  end
end
