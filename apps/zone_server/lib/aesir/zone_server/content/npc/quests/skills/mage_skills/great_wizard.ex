defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.MageSkills.GreatWizard do
  @moduledoc """
  Blizzardriss teaches the Mage quest skill Energy Coat in Geffen.

  ## Behavior

  - Explains the Energy Coat requirements: 3 Glass Bead, 1 1carat Diamond, 5 Shell,
    and 1 Solid Shell, plus Mage job level 35 or the Wizard or Sage job.
  - Takes the materials and teaches Energy Coat to qualified Mage-class characters
    who do not already know it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Masao
    - Euphy
    - Lupus
    - Silentdragon
    - IVBela

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
    quests/skills/mage_skills.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 151,
        y: 119,
        dir: 4,
        sprite: 64,
        name: "Great Wizard",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @energy_coat 157

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[BLIZZARDRISS]")
      |> mes("Hey ! My friend !")
      |> mes("I see that you are a mage.")
      |> mes("Look into yourself to discover")
      |> mes("your hidden abilities !")
      |> next()
      |> select([
        "About mage's hidden ability ",
        "About skill ^3355FF' Energy Coat '^000000 ",
        "End conversation"
      ])

    case choice do
      1 -> explain_skill(ctx)
      2 -> request_skill(ctx)
      3 -> dismiss(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_skill(ctx) do
    ctx
    |> mes("[BLIZZARDRISS]")
    |> mes("For many years")
    |> mes("I have studied the ancient")
    |> mes("magic's of Geffen.")
    |> mes("Recently, I discovered")
    |> mes("a very good forgotten skill! ! !")
    |> mes("Isn't that fortunate?")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("The skill uses your mental")
    |> mes("energy to block attacks against you.")
    |> mes("It is like a magical shield, or armor.")
    |> mes("Only the most special of persons can")
    |> mes("use this amazing skills.")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("But the most amazing part is that I")
    |> mes("can use the skill! ! !")
    |> mes("I can use this to protect myself !")
    |> mes("Pu hah hah hah !!")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("Ok Ok, don't get too excited.")
    |> mes("Listen carefully to what I can tell you.")
    |> mes("Those who use this spell must tap")
    |> mes("the hidden energies and abilities")
    |> mes("locked within themselves !")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("If you wish to learn this skill, you")
    |> mes("must first have a few items to")
    |> mes("be used during the process.")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("three ^3355FFGlass Bead^000000 ")
    |> mes("one ^3355FF1 carat Diamond^000000 ")
    |> mes("five ^3355FFShell^000000 ")
    |> mes("one ^3355FFSolid Shell^000000 ")
    |> mes("Bring me these items.")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("Also, one more thing. . .")
    |> mes("You must be sufficiently experienced")
    |> mes("in the magical arts. This means you must")
    |> mes("either be a wizard or mage job level 35+.")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("Wizards already have already")
    |> mes("experienced the role of a mage")
    |> mes("and so do not require a job level.")
    |> mes("In any case, one who wishes to")
    |> mes("be trained in this art must be in a")
    |> mes("healthy and strong mental state.")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("Okay . .")
    |> mes("There is nothing more to say, are you interested?")
    |> close()
  end

  defp request_skill(ctx) do
    cond do
      getskilllv(ctx, @energy_coat) == 1 -> already_learned(ctx)
      qualified?(ctx) -> teach_skill(ctx)
      true -> not_prepared(ctx)
    end
  end

  defp qualified?(ctx) do
    count_item(ctx, 746) > 2 and count_item(ctx, 730) > 0 and count_item(ctx, 935) > 4 and
      count_item(ctx, 943) > 0 and
      (job_level(ctx) > 34 or
         (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:wizard) or
            Rathena.job_id(base_job(ctx)) == Rathena.job_id(:sage))) and
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:mage)
  end

  defp already_learned(ctx) do
    ctx
    |> mes("[BLIZZARDRISS]")
    |> mes("It seems that you have ")
    |> mes("already mastered this skill.")
    |> mes("Your skill in 'Energy Coat' ")
    |> mes("is evident.")
    |> mes("I am sorry, ")
    |> mes("I have nothing more to teach you ...")
    |> close()
  end

  defp teach_skill(ctx) do
    ctx
    |> mes("[BLIZZARDRISS]")
    |> mes("Okay, I have received your request.")
    |> mes("I will now awaken your hidden energies . .")
    |> mes(". . . . . .")
    |> mes(". . . . . . . . . . . . .")
    |> mes(". . . . . . . . . . . . . . . . . . . . . . . . . .")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("Ancient powers of")
    |> mes("Geffen! I seek the enlightenment")
    |> mes("and honor of your presence. ")
    |> mes("I am humbled in your presence!")
    |> mes(" ...")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("Grant me your power!")
    |> mes("Release your spirit")
    |> mes("Mana Shield! Metal Armor!")
    |> mes(". . . . . . . . . . . .")
    |> mes("ENERGY COAT! ! !")
    |> next()
    |> delitem(746, 3)
    |> delitem(730, 1)
    |> delitem(935, 5)
    |> delitem(943, 1)
    |> skill(@energy_coat, 1, :permanent)
    |> mes("[BLIZZARDRISS]")
    |> mes(". . . . .")
    |> mes("It is done. . .")
    |> mes("You know have the ")
    |> mes("elite skill of ^3355FF' Energy Coat '^000000 .")
    |> mes("Use it well.")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("Do not shame our")
    |> mes("class with disgraceful")
    |> mes("use of this or any skill.")
    |> mes("Your new power calls for new responsibility.")
    |> close()
  end

  defp not_prepared(ctx) do
    ctx
    |> mes("[BLIZZARDRISS]")
    |> mes("Look!!")
    |> mes("Didn't you listen to my explanation ? !")
    |> mes("You have not prepared fully")
    |> mes("for me to assist you.")
    |> mes("Check that you have all the requirements.")
    |> next()
    |> mes("[BLIZZARDRISS]")
    |> mes("If you need me to explain")
    |> mes("all this again, then ask me.")
    |> mes("I would be happy to explain again")
    |> mes("if only you would listen. . .")
    |> close()
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[BLIZZARDRISS]")
    |> mes("The wise man must have patience !")
    |> mes("Prepare yourself again,")
    |> mes("and return when you are ready.")
    |> close()
  end
end
