defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.RogueGuildsman do
  @moduledoc """
  Markie runs the Rogue Guild's application process and promotes Thieves to Rogue.

  ## Behavior

  - Turns away reincarnated characters, Thieves with unused skill points, and Thieves below job
    level 40.
  - Gives Thief applicants a ten-question quiz drawn from one of three random sets; more than 80
    points passes them on to Mr. Smith, otherwise they must retake it.
  - Changes Thieves who cleared the tunnel test to Rogue, clears their job quest variables, and
    rewards a Gladius (a slotted one at job level 50).
  - Has flavor dialogue for Assassins, Rogues, and other classes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 363,
        y: 122,
        dir: 4,
        sprite: 747,
        name: "Rogue Guildsman",
        scope: :shared,
        unique_name: "Rogue Guildsman#rg"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @quizzes [
    [
      {
        "1. Choose the skill necessary for learning ^880000Stalk^000000.",
        [
          "^880000Hiding^000000",
          "^880000Steal^000000",
          "^880000Improve Dodge^000000",
          "^880000Bash^000000"
        ],
        [1]
      },
      {
        "2. In comparison to the Merchant's Level 10 ^880000Discount^000000 skill, how much more of a discount, in terms of percent, can a Rogue get with Level 10 ^880000Haggle^000000 skill?",
        ["3 %", "2 %", "1 %", "0 %"],
        [3]
      },
      {
        "3. What is the correct description for the skill, ^880000Mug^000000?",
        [
          "Steal items from players",
          "Steal items from monsters",
          "Steal Zeny from monsters",
          "Steal Zeny from players"
        ],
        [3]
      },
      {
        "4. How many Rogues does it require to activate the skill, ^880000Slyness^000000?",
        ["1 Rogues + 2 Assassin", "1 Thief + 2 Rogue", "4 Thieves", "2 Rogues"],
        [4]
      },
      {
        "5. Choose the skill that you can learn at Level 5 ^880000Divest Helm^000000.",
        [
          "^880000Envenom^000000",
          "^880000Strip Tease^000000",
          "^880000Venom Splasher^000000",
          "^880000Divest Shield^000000"
        ],
        [4]
      },
      {
        "6. Choose the skill which allows its user to move while hiding.",
        [
          "^880000Hiding^000000",
          "^880000Back Slide^000000",
          "^880000Stalk^000000",
          "^880000Sand Attack^000000"
        ],
        [3]
      },
      {
        "7. Choose the card that increases the accuracy rate of its owner.",
        ["Andre Card.", "Familiar Card.", "Mummy Card.", "Marina Card."],
        [3]
      },
      {
        "8. Choose the monster that receives more damage when it's attacked by a weapon with the Vadon card (20 % more damage on Fire property).",
        ["Vadon", "Deviruchi", "Elder Willow", "Baphomet"],
        [3]
      },
      {
        "9. How much SP does the skill ^880000Double Attack^000000 require when used with a Dagger?",
        ["15", "Passive skill, no SP required.", "Passive skill, 10 SP", "54"],
        [2]
      },
      {
        "10. Choose the most efficient dagger to use in the Byalan Dungeon.",
        ["Wind Main-Gauche", "Ice Main-Gauche", "Earth Main-Gauche", "Fire Main-Gauche"],
        [1]
      }
    ],
    [
      {
        "1. Which monster drops a slotted Gladius?",
        ["Thief Bug", "Peco Peco", "Desert Wolf", "Kobold"],
        [4]
      },
      {
        "2. Which monster drops a slotted Main-Gauche?",
        ["Hornet", "Desert Wolf", "Marionette", "Myst"],
        [1]
      },
      {
        "3. Choose the class that is able to create unique potions.",
        ["Merchant", "Alchemist", "Blacksmith", "Priest"],
        [2]
      },
      {
        "4. Choose the weapon that Rogues aren't allowed to use.",
        ["Gakkung", "Crossbow", "Gladius", "Katar"],
        [4]
      },
      {
        "5. Choose the property that the monster Hode possesses.",
        ["Water", "Fire", "Wind", "Earth"],
        [4]
      },
      {
        "6. Choose the monster that is unable to be tamed for as a Cute Pet.",
        ["Poporing", "Creamy", "Orc", "Poison Spore"],
        [2]
      },
      {
        "7. Choose the monster that receives more damage from a Dagger with the Fire property.",
        ["Dagger Goblin", "Mace Goblin", "Morning Star Goblin", "Hammer Goblin"],
        [4]
      },
      {
        "8. Choose the town that doesn't have any guild castles.",
        ["Prontera", "Al De Baran", "Alberta", "Payon"],
        [3]
      },
      {
        "9. Choose the plant that drops Blue Herbs.",
        ["Green Plant", "Yellow Plant", "Blue Plant", "Shining Plant"],
        [3, 4]
      },
      {
        "10. Choose the monster that does not have the Undead property.",
        ["Zombie", "Megalodon", "Familiar", "Khalitzburg"],
        [3]
      }
    ],
    [
      {
        "1. By what percentage is the flee rate increased when a Thief masters the ^880000Improve Dodge^000000?",
        ["30", "40", "160", "20"],
        [1]
      },
      {
        "2. Choose the monster that detects a characters using the Hiding or Cloaking skill.",
        ["Worm Tail", "Argos", "Mummy", "Soldier Skeleton"],
        [2]
      },
      {
        "3. Choose the location where Thieves can change their jobs to Rogues.",
        ["Comodo", "Kokomo Beach", "Paros Lighthouse", "Morocc"],
        [3]
      },
      {
        "4. In which town can Novices change their jobs to Thieves?",
        ["Comodo", "Lutie", "Alberta", "Morocc"],
        [4]
      },
      {
        "5. Choose the card that does not affect the DEX stat.",
        ["Rocker Card", "Mummy Card", "Zerom Card", "Drops Card"],
        [2]
      },
      {
        "6. So what's cool about being a Rogue?",
        [
          "Being totally badass.",
          "The clothes, the style.",
          "Getting to call other people, 'foo''",
          "Excellent attack strength"
        ],
        :any
      },
      {
        "7. When is it possible to change jobs from Thief to Rogue?",
        ["At job Level 30", "At job Level 35", "At Job Level 40", "At Job Level 50"],
        [3, 4]
      },
      {
        "8. You want to dye your hair blue. What town do you go to, and in which direction, with 12 o' clock being North.",
        ["Morocc, 7 o'clock", "Prontera, 7 o'clock", "Morocc, 5 o'clock", "Prontera, 1 o'clock"],
        [2]
      },
      {
        "9. Choose the mushroom that is required on the Thief job change quest.",
        [
          "Orange Gooey Mushroom",
          "Red Hairy Mushroom",
          "Orange Net Mushroom",
          "Orange Sticky Mushroom"
        ],
        [1, 3]
      },
      {
        "10. Choose the card that least benefits the Rogue class.",
        ["Whisper Card", "Elder Willow Card", "Zerom Card", "Matyr Card"],
        [2]
      }
    ]
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      upper(ctx) == 1 -> greet_reincarnated(ctx)
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) -> talk_to_thief(ctx)
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:assassin) -> greet_assassin(ctx)
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) -> greet_rogue(ctx)
      true -> chase_away(ctx)
    end
  end

  defp greet_reincarnated(ctx) do
    ctx
    |> mes("[Markie]")
    |> mes("Eh? You...you...?!")
    |> mes("Hey, haven't we met before?")
    |> next()
    |> mes("[Markie]")
    |> mes("..............")
    |> mes("Awww, ^FF0000I am sorry^000000! I think I misunderstood you from someone I know.")
    |> next()
    |> mes("[Markie]")
    |> mes(".......")
    |> mes("........It is strange though. Umm.")
    |> next()
    |> mes("[Markie]")
    |> mes("I never misunderstand people...oh well, be safe anyway!")
    |> close()
  end

  defp talk_to_thief(ctx) do
    cond do
      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("[Rogue Guildsman]")
        |> mes("Yo, what are you doin'?!")
        |> mes(
          "You can't change your job if you got unused skill points, so use 'em all up. You bettah check yo-self before you wreck yo-self."
        )
        |> close()

      job_level(ctx) > 39 ->
        talk_to_applicant(ctx)

      job_level(ctx) < 40 ->
        ctx
        |> mes("[Rogue Guildsman]")
        |> mes(
          "Whoa, slow down newbie. We only accept people who are at least Thief Job Level 40. I ain't risking myself by letting you in before you're ready. Got it?"
        )
        |> close()

      true ->
        ctx
    end
  end

  defp talk_to_applicant(ctx) do
    rogue_q = get_char_var(ctx, :ROGUE_Q, 0)

    cond do
      rogue_q == 0 -> ctx |> introduce_guild() |> offer_quiz()
      rogue_q == 1 -> ctx |> encourage_retry() |> offer_quiz()
      rogue_q == 2 -> send_to_smith(ctx)
      rogue_q > 2 and rogue_q < 16 -> wish_luck(ctx)
      rogue_q == 16 or rogue_q == 17 -> promote(ctx)
      true -> offer_quiz(ctx)
    end
  end

  defp introduce_guild(ctx) do
    ctx =
      ctx
      |> mes("[Rogue Guildsman]")
      |> mes("So what's a kid")
      |> mes("like you doin' here?")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx |> mes("Oh, I get it now...") |> mes("The widdle boy wants")
      else
        ctx |> mes("Oh, I see...") |> mes("Lil' cutie wants ")
      end

    ctx =
      ctx
      |> mes("to be a ^800000Rogue^000000.")
      |> next()
      |> mes("[Rogue Guildsman]")
      |> mes(
        "Eh, nice meetin' you, I guess. I'm Markie, and I do work for the Rogue Guild, a philanthro-- *ahem* a ^800000feelanthropist^000000 group, as you can see. So what's your name?"
      )
      |> next()
      |> mes("[Markie]")

    ctx
    |> mes("...#{char_name(ctx, 0)}?")
    |> mes("Heh heh! Cool name.")
    |> mes("If it was dorky, we'd")
    |> mes("make you change it,")
    |> mes("so you're in luck.")
    |> next()
    |> mes("[Markie]")
    |> mes(
      "So why you wanna join up with the Rogues? I guess you gave me your real name, so you'd be an honest Rogue. Not many of those around, heh heh~"
    )
    |> next()
    |> mes("[Markie]")
    |> mes("Rule number 1 for Rogues...")
    |> mes(
      "Never give out your real identity to most people, most of the time. It's just a little backup measure we like to use."
    )
    |> next()
    |> mes("[Markie]")
    |> mes(
      "Right. I'm officially accepting your application, so now you gotta take a test. Don't sweat it, this first one is real simple."
    )
    |> next()
    |> mes("[Markie]")
    |> mes("Alright...")
    |> mes("Let's get started!")
    |> next()
  end

  defp encourage_retry(ctx) do
    ctx
    |> mes("[Markie]")
    |> mes("You again?")
    |> mes(
      "Okay, you probably screwed up last time 'cuz you were way too nervous. So just chill and pass"
    )
    |> mes("this test, okay?")
    |> next()
  end

  defp send_to_smith(ctx) do
    ctx
    |> mes("[Markie]")
    |> mes(
      "Go talk to Smith. His test might be pretty hard. He's one of the guys who makes sure that people pay up their debts to us. So yeah, he might be a bit of a hard case."
    )
    |> next()
    |> mes("[Markie]")
    |> mes("Yeah...")
    |> mes(
      "That guy can be pretty anal, but we need a guy like him in our guild. Anyway, be careful. Lots of luck to you, pal."
    )
    |> close()
  end

  defp wish_luck(ctx) do
    ctx
    |> mes("[Markie]")
    |> mes("Hey yo...")
    |> mes("Do your best.")
    |> next()
    |> mes("[Markie]")
    |> mes("Heh heh...")
    |> mes("Fresh meat. This'll be")
    |> mes("a cinch to--Wait! Er, I wasn't talkin' about you! I meant the other fresh meat~")
    |> close()
  end

  defp promote(ctx) do
    ctx = ctx |> changequest(2026, 2027) |> mes("[Markie]")

    ctx =
      if get_char_var(ctx, :ROGUE_Q, 0) == 16 do
        ctx
        |> mes("Oh hey, it's you!")
        |> mes("You did a good job, guy.")
        |> mes("Now, lemme change your")
        |> mes("job to Rogue. You earned it!")
        |> next()
        |> mes("[Markie]")
        |> mes("Congrats~!")
        |> mes("You look")
        |> mes("sooo dope!")
      else
        ctx
        |> mes("Oh! It's you!")
        |> mes(
          "You were actually able to put up with that guy? Good stuff! Must've had a rough time collect all those items, eh?"
        )
        |> next()
        |> mes("[Markie]")
        |> mes("Hey hey~")
        |> mes("Congrats!")
        |> mes("You've been")
        |> mes("doin' a great job~")
      end

    thief_job_level = job_level(ctx)
    {ctx, _} = ctx |> jobchange(:rogue) |> FClearjobvar.call([])

    ctx
    |> completequest(2027)
    |> next()
    |> mes("[Markie]")
    |> mes("Now...")
    |> mes("It's time")
    |> mes("for me to make")
    |> mes("a speech~ *Ahem*")
    |> next()
    |> mes("[Markie]")
    |> mes(
      "Enjoy your freedom as a Rogue. Just remember that you gotta be free and responsible at the same time. So treat other guys the way you wanna be treated, kay? Alright, seeya round."
    )
    |> close()
    |> give_item(gladius_for(thief_job_level), 1)
  end

  defp gladius_for(job_level) when job_level == 50, do: 1220
  defp gladius_for(_job_level), do: 1219

  defp offer_quiz(ctx) do
    {ctx, choice} = select(ctx, ["I'm ready.", "Hold on, I need to get ready!"])

    if choice == 2 do
      ctx
      |> mes("[Markie]")
      |> mes("Get ready...?")
      |> mes("Fine, fine.")
      |> mes("Take your sweet")
      |> mes("time, why don't you?")
      |> mes("But hurry up and")
      |> mes("come back, got it?")
      |> close()
    else
      take_quiz(ctx)
    end
  end

  defp take_quiz(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Markie]")
      |> mes("Listen carefully, and")
      |> mes("pick the right answer.")
      |> mes("Capish? Now, lemme")
      |> mes("read these questions...")
      |> next()

    questions = Enum.at(@quizzes, Enum.random(1..3) - 1)
    {ctx, score} = Enum.reduce(questions, {ctx, 0}, &ask_question/2)

    ctx =
      ctx
      |> mes("[Markie]")
      |> mes("*Whew~*")
      |> mes("Finally.")
      |> mes("We're done.")
      |> next()
      |> mes("[Markie]")
      |> mes("Let's see.")
      |> mes("You got...")
      |> mes("#{score} points.")

    if score > 80, do: pass_quiz(ctx), else: fail_quiz(ctx)
  end

  defp ask_question({question, options, correct}, {ctx, score}) do
    {ctx, choice} =
      ctx
      |> mes("[Markie]")
      |> mes(question)
      |> next()
      |> select(options)

    if correct == :any or choice in correct do
      {ctx, score + 10}
    else
      {ctx, score}
    end
  end

  defp pass_quiz(ctx) do
    ctx
    |> set_char_var(:ROGUE_Q, 2)
    |> setquest(2017)
    |> mes("Good. You passed.")
    |> mes("We don't gotta")
    |> mes("do that again.")
    |> next()
    |> mes("[Markie]")
    |> mes(
      "But don't get too comfortable just yet, you got more o' these tests. Your next one will be from Smith."
    )
    |> next()
    |> mes("[Markie]")
    |> mes("So...")
    |> mes(
      "Go find Smith and finish up this test, yeah? Be careful though, Smith's a pretty anal guy."
    )
    |> close()
  end

  defp fail_quiz(ctx) do
    ctx
    |> set_char_var(:ROGUE_Q, 1)
    |> mes("Aw crud... You failed!")
    |> next()
    |> mes("[Markie]")
    |> mes("Man, you shoulda learned more when you had the chance. Thanks for wasting my time.")
    |> next()
    |> mes("[Markie]")
    |> mes(
      "*Sigh...* Lemme give you some tips, yeah? I'm supposed to tell you about some kind of ^990000iro.ragnarokonline.com^000000 to help you learn what you need to know."
    )
    |> next()
    |> mes("[Markie]")
    |> mes(
      "Of course, I don't know what the heck it means, but if you understand it, it'll probably help you out a lot."
    )
    |> close()
  end

  defp greet_assassin(ctx) do
    ctx
    |> mes("[Rogue Guildsman]")
    |> mes("Huh...?")
    |> mes(
      "What's an Assassin doin' here? Uh, you haven't been assigned to kill someone in the Rogue Guild, are you?"
    )
    |> next()
    |> mes("[Rogue Guildsman]")
    |> mes("In any case, don't mess with us! You can't catch me... I'm a smooth criminal!")
    |> next()
    |> mes("[Rogue Guildsman]")
    |> mes(
      "Don't get it, huh? It's something I always used to say to Huey. If you're in the Assassin Guild, you oughta have met him..."
    )
    |> close()
  end

  defp greet_rogue(ctx) do
    ctx
    |> mes("[Markie]")
    |> mes("Hey hey~")
    |> mes("Long time no see.")
    |> mes("Eh, right now we don't")
    |> mes("any requests from the")
    |> mes("guild for you, so just")
    |> mes("check back again later.")
    |> close()
  end

  defp chase_away(ctx) do
    ctx
    |> mes("[Rogue Guildsman]")
    |> mes("Hey you...")
    |> mes("Get your ugly")
    |> mes("ass out of here")
    |> mes("before I redecorate")
    |> mes("that face of yours!")
    |> close()
  end
end
