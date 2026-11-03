defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.NoviceSkills.NursingInstructor do
  @moduledoc """
  The Dread Lord, Prontera castle's grumpy nursing director, hands out items for the novice
  skill quests.

  ## Behavior

  - Brushes off every visitor before reacting to their novice quest progress.
  - Hands over the Sterilized Bandage for Nami's First Aid quest.
  - Gives one Newbie Tag to Novices on Bulma's Play Dead run who do not already carry one.
  - Shouts everyone else out of the clinic.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - IVBela
    - L0ne_W0lf
    - Masao
    - Zopokx

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_castle",
        x: 175,
        y: 146,
        dir: 4,
        sprite: 50,
        name: "Nursing Instructor",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @newbie_tag 7039

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Dread Lord]")
      |> mes(". . . . . . . . . .")
      |> mes(". . . . . . . . . .")
      |> mes("Stop pestering me! ! !")
      |> mes("I am very busy ! ! !")
      |> mes("Would you just bug off ? ! ? !")
      |> close()

    quest_step(ctx, get_char_var(ctx, :skill_nov, 0))
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp quest_step(ctx, 0) do
    ctx
    |> mes("[Dread Lord]")
    |> mes("The people who work here at")
    |> mes("Prontera clinic are battling life")
    |> mes("and death everyday.")
    |> mes("It takes a lot of patience and ")
    |> mes("puts a lot of tension on us.")
    |> mes("Sorry if we seem a bit uptight. . .")
    |> next()
    |> mes("[Dread Lord]")
    |> mes("I am the Nursing director.")
    |> mes("There are many things I must do.")
    |> mes("If your business is complete, please leave.")
    |> close()
  end

  defp quest_step(ctx, 1) do
    ctx
    |> mes("[Dread Lord]")
    |> mes("Ohhh . .")
    |> mes("You have come here for bandages ?")
    |> mes("Do you even know how we get these")
    |> mes("precious bandages ?")
    |> mes("They come from a powerful monster")
    |> mes("that is found in the pyramids of Morocc.")
    |> next()
    |> mes("[Dread Lord]")
    |> mes("The monster is some sort of mummy.")
    |> mes("We take the rotten bandages from it's")
    |> mes("diseased body and sanitize them. . .")
    |> mes("Do you believe me ? . .")
    |> mes("Heh heh... There is even poison")
    |> mes("in the bandages.")
    |> next()
    |> mes("[Dread Lord]")
    |> mes("Fortunately, the poison kills other poisons")
    |> mes("and does not hurt the patient . .")
    |> mes("You must destroy poison with poison. . .")
    |> mes("I think I heard something similar that. . .")
    |> mes(". . . . . Anyway, I would usually give you a")
    |> mes("hard time for taking these bandages lightly,")
    |> next()
    |> mes("[Dread Lord]")
    |> mes("but I am much too tired today to")
    |> mes("give you any trouble. . .")
    |> mes("If you ever get skilled in medicine and first aid,")
    |> mes("please consider joining our clinic.")
    |> mes("Now don't take these bandages and then")
    |> mes("go and get killed, be careful. -")
    |> next()
    |> mes("^3355FF- Got 1 Sterilized Bandages -^000000")
    |> set_char_var(:skill_nov, 2)
    |> close()
  end

  defp quest_step(ctx, 2) do
    ctx
    |> mes("[Dread Lord]")
    |> mes("Look, if your business is done")
    |> mes("get out of my site! ! !")
    |> mes("I have no time for this nonsense ..")
    |> mes(". . . . .")
    |> mes("- Click Click *Walks away* . . . . . -")
    |> close()
  end

  defp quest_step(ctx, 4) do
    if count_item(ctx, @newbie_tag) == 0, do: give_tag(ctx), else: only_one(ctx)
  end

  defp quest_step(ctx, 5) do
    ctx
    |> mes("[Dread Lord]")
    |> mes("What more do you want !")
    |> mes("Get out of here !")
    |> mes("OUT !")
    |> close()
  end

  defp quest_step(ctx, _step) do
    ctx
    |> mes("[Dread Lord]")
    |> mes("Argh, Get out of here !!")
    |> mes("I don't like shouting but ..")
    |> mes("GET OUT OF HERE! ! ! ! ! !")
    |> close()
  end

  defp give_tag(ctx) do
    ctx
    |> mes("[Dread Lord]")
    |> mes("Look at this guy!")
    |> mes("Wake up and watch where you are going.")
    |> mes("What are you thinking running around our clinic!")
    |> mes("Running ?!?!")
    |> mes("*Sigh* . . ")
    |> mes("What do you want? ! ? !")
    |> next()
    |> mes("[Dread Lord]")
    |> mes("I see. . . .")
    |> mes(". . . . . what ?")
    |> mes("You want to have a bandage to learn first aid?")
    |> mes(" *Arhg* Here take it !")
    |> mes("-woosh - *storms away*")
    |> next()
    |> mes("^3355FF- Got 1 Newbie Tag -^000000")
    |> set_char_var(:skill_nov, 5)
    |> give_item(@newbie_tag, 1)
    |> close()
  end

  defp only_one(ctx) do
    ctx
    |> mes("[Dread Lord]")
    |> mes("What ! !")
    |> mes("I'm only going to give you one!")
    |> mes("You don't need any more for the test !")
    |> mes("Do you want to stay a novice forever???")
    |> mes("I would be happy to arrange that !")
    |> close()
  end
end
