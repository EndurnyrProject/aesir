defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.LouisGreg do
  @moduledoc """
  Louis Greg, Haijara's youngest son, who relays news in the Close Confine skill quest.

  ## Behavior

  - Starts the quest for Rogues and Stalkers who have not begun it.
  - Reads his father's letter and hands the player a letter for his brother Thor.
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
        x: 152,
        y: 29,
        dir: 0,
        sprite: 84,
        name: "Louis Greg",
        scope: :shared,
        unique_name: "Louis Greg#rogueguild"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if rogue_or_stalker?(ctx) do
      ctx |> mes("[Louis Greg]") |> quest_step(get_char_var(ctx, :ROG_SK, 0)) |> close()
    else
      ctx
      |> mes("[Louis Greg]")
      |> mes("Why'd I become a Rogue?")
      |> mes("I guess I just like being")
      |> mes("sneaky. That, and being")
      |> mes("moral and law abiding is")
      |> mes("just too tough, you know?")
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
    |> mes("My father just...")
    |> mes("He just vanished!")
    |> mes("He was teaching me and")
    |> mes("my brothers a new skill,")
    |> mes("but lately he began acting")
    |> mes("paranoid for some reason...")
    |> next()
    |> mes("[Louis Greg]")
    |> mes("Maybe he went into hiding?")
    |> mes("I know there's a hidden panic")
    |> mes("room in the Rogue Guild, but")
    |> mes("even I don't know where to find")
    |> mes("it. I hope everything's okay...")
    |> set_char_var(:ROG_SK, 1)
  end

  defp quest_step(ctx, 1) do
    ctx
    |> mes("Father did warn that")
    |> mes("people might come after us")
    |> mes("if they're learned about the")
    |> mes("new skill we were learning.")
    |> mes("Maybe he went into hiding in")
    |> mes("the Rogue Guild's panic room...")
  end

  defp quest_step(ctx, 2) do
    ctx
    |> mes("What's this...?")
    |> mes("A letter from my")
    |> mes("father? Oh, he must")
    |> mes("be alright! Quick, let")
    |> mes("me read it right away!")
    |> set_char_var(:ROG_SK, 3)
    |> next()
    |> mes("[Louis Greg]")
    |> mes("Oh no, he may be safe for")
    |> mes("now, but father is being hunted")
    |> mes("by some dangerous people? My")
    |> mes("brother Thor will want to know")
    |> mes("about this. Let me write him")
    |> mes("a letter really quickly...")
    |> next()
    |> mes("[Louis Greg]")
    |> mes("I know that I'm in no")
    |> mes("position to ask any favors,")
    |> mes("but I guess my father must")
    |> mes("trust you. Please, would you")
    |> mes("take my letter and deliver it")
    |> mes("to my older brother, Thor?")
    |> next()
    |> mes("[Louis Greg]")
    |> mes("You can find Thor")
    |> mes("next to Hermanthorn Jr.")
    |> mes("inside the Rogue Guild.")
    |> mes("I'd really appreciate it if")
    |> mes("you could help my family.")
  end

  defp quest_step(ctx, 3) do
    ctx
    |> mes("My elder brother, ^FF0000Thor^000000,")
    |> mes("must know about this right")
    |> mes("away! Please bring him this")
    |> mes("letter for me. He should be")
    |> mes("near ^FF0000Hermanthorn Jr.^000000 here")
    |> mes("inside the Rogue Guild.")
  end

  defp quest_step(ctx, 4) do
    ctx
    |> mes("You're looking for my")
    |> mes("brother, Jay? He's usually")
    |> mes("hanging out here in the")
    |> mes("Rogue Guild with Antonio Jr.")
  end

  defp quest_step(ctx, 5) do
    ctx
    |> mes("If you need to speak")
    |> mes("to my father, he's still")
    |> mes("probably in the hidden panic")
    |> mes("room inside the Rogue Guild.")
    |> mes("I still don't know where that")
    |> mes("place could possibly be...")
  end

  defp quest_step(ctx, 6) do
    ctx
    |> mes("You want to learn the")
    |> mes("secret Rogue skill? Oh,")
    |> mes("you should probably talk")
    |> mes("to ^FF0000Thor^000000 about that. I...")
    |> mes("I'm really bad at explaining")
    |> mes("things to people. Really bad.")
  end

  defp quest_step(ctx, 7) do
    ctx
    |> mes("Hm? You're in the middle")
    |> mes("of learning the secret Rogue")
    |> mes("skill, aren't you? Ooh, then")
    |> mes("you're not supposed to be here")
    |> mes("just yet. Please go back and")
    |> mes("talk to ^FF0000Thor^000000 again, okay?")
  end

  defp quest_step(ctx, 8) do
    ctx
    |> mes("Oh, oh!")
    |> mes("You're done with")
    |> mes("the training? Ah,")
    |> mes("then you need to")
    |> mes("talk to Thor again!")
  end

  defp quest_step(ctx, 9) do
    ctx
    |> mes("You wanted to learn")
    |> mes("more about Close Confine?")
    |> mes("Ugh, then you better speak")
    |> mes("to my father. I just learned")
    |> mes("that skill myself, you know.")
  end

  defp quest_step(ctx, 11) do
    ctx
    |> mes("I just heard from my")
    |> mes("brothers that Chae Takbae")
    |> mes("developed Close Confine")
    |> mes("as a way to brutally beat his")
    |> mes("enemies, keeping them from")
    |> mes("running away. Is that true?")
  end

  defp quest_step(ctx, _step) do
    ctx
    |> mes("Wow, you're really")
    |> mes("great! I wish I were")
    |> mes("as powerful as you.")
    |> mes("I hate being a kid!")
  end
end
