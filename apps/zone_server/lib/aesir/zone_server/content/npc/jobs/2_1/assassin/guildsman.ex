defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.Guildsman do
  @moduledoc """
  Huey, the Assassin Guild gatekeeper who starts the Assassin job quest and performs the
  job change.

  ## Behavior

  - Turns away transcendent characters and players with unused skill points.
  - Heals applicants who are struggling with the hiding test and lets them retry or quit.
  - Changes Thieves who bring back the Necklace of Oblivion into Assassins; turns away
    those who lost it or carry a fake.
  - Sends qualified Thieves (job level 40+) to the guild office to begin the quest, and
    greets other classes with class-specific remarks.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 19,
        y: 33,
        dir: 1,
        sprite: 55,
        name: "Guildsman",
        scope: :shared,
        unique_name: "Guildsman#asn"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      upper(ctx) == 1 ->
        reject_transcendent(ctx)

      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "You can't change your job if you have any unused skill points from the 1st job. You better go and use those up first."
        )
        |> close()

      get_char_var(ctx, :ASSIN_Q, 0) == 4 ->
        offer_hiding_test_break(ctx)

      thief?(ctx) and count_item(ctx, 1008) == 0 and get_char_var(ctx, :ASSIN_Q, 0) > 7 ->
        scold_missing_necklace(ctx)

      thief?(ctx) and count_item(ctx, 1008) > 0 and get_char_var(ctx, :ASSIN_Q, 0) > 7 ->
        promote_to_assassin(ctx)

      count_item(ctx, 1008) > 0 and thief?(ctx) and get_char_var(ctx, :ASSIN_Q, 0) < 7 ->
        reject_fake_necklace(ctx)

      true ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes("What brings you here?")
        |> mes("I don't think I like the way you're looking at me... Punk.")
        |> next()
        |> greet_by_class()
    end
  end

  defp thief?(ctx), do: Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief)

  defp reject_transcendent(ctx) do
    ctx
    |> mes("[Ferocious-looking guy]")
    |> mes("Hm? You....?")
    |> mes("I sense that you're different than most people...")
    |> next()
    |> mes("[Ferocious-looking guy]")
    |> mes(
      "I've never met anyone as intimidating as you! For some reason, I don't like you. I think you should leave!"
    )
    |> close()
  end

  defp offer_hiding_test_break(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ferocious-looking guy]")
      |> mes("Oh, stop making that face. Can you really be in that much pain?")
      |> next()
      |> mes("[Ferocious-looking guy]")
      |> mes("Wah wah wah, you're hurting, I can see that. Look, I'll restore HP and SP. Happy?")
      |> percent_heal(hp: 100, sp: 100)
      |> next()
      |> mes("[Ferocious-looking guy]")
      |> mes("Is it that hard to stay alive?")
      |> mes(
        "Why don't you try harder next time? You can't force yourself too hard to become an Assassin..."
      )
      |> next()
      |> select(["I will become an Assassin no matter what!", "Oh man, I gotta take a break."])

    if choice == 1 do
      ctx
      |> mes("[Ferocious-looking guy]")
      |> mes("Oh...")
      |> mes("Well then,")
      |> mes("go for it!")
      |> close()
      |> set_char_var(:ASSIN_Q, 0)
      |> warp("in_moc_16", 19, 76)
    else
      ctx =
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "Take a break? Oh alright, have it your way. When you feel like you're ready to become an Assassin, come back."
        )
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "You'll have to walk if you want to get back to town. Oh, and don't forget to save your spawn point, alright?"
        )
        |> close()
        |> set_char_var(:ASSIN_Q, 0)
        |> set_char_var(:ASSIN_Q2, 0)

      ctx =
        if get_char_var(ctx, :ASSIN_Q3, 0) < 3 do
          set_char_var(ctx, :ASSIN_Q3, 0)
        else
          ctx
        end

      ctx
      |> savepoint("in_moc_16", 18, 14)
      |> warp("in_moc_16", 18, 14)
    end
  end

  defp scold_missing_necklace(ctx) do
    ctx
    |> mes("[Assassin Expert 'Huey']")
    |> mes(
      "Hey, what happened...? How come you didn't bring the ^006699Necklace of Oblivion^000000? You're supposed to carry that with you, so where is it?"
    )
    |> next()
    |> mes("[Assassin Expert 'Huey']")
    |> mes(
      "You get better get that ^006699Necklace of Oblivion^000000 again before the guildmaster finds out! Hurry, and do your best to get it!"
    )
    |> next()
    |> mes("[Assassin Expert 'Huey']")
    |> mes("When you finally succeed in getting it, bring it to me! ^666666*Sigh...*^000000")
    |> close()
  end

  defp promote_to_assassin(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Assassin Expert 'Huey']")
      |> mes(
        "Well well well, you got it. Congratulations! But since it's been clearly scratched, I can't accept it. You'll never become an Assassin!"
      )
      |> next()
      |> mes("[Assassin Expert 'Huey']")
      |> mes(
        "Hahahah~! I'm just joking, don't take it seriously. But I do need to check this necklace with the guildmaster first."
      )
      |> next()
      |> mes("[Assassin Expert 'Huey']")
      |> mes("...")
      |> next()
      |> mes("[Assassin Expert 'Huey']")
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("[Assassin Expert 'Huey']")
      |> mes("Alright!")
      |> mes("You've been approved!")
      |> next()
      |> delitem(1008, 1)
      |> changequest(8007, 8008)
      |> completequest(8008)
      |> jobchange(:assassin)
      |> FClearjobvar.call([])

    ctx
    |> mes("[Assassin Expert 'Huey']")
    |> mes(
      "Now! Do your best to be a great Assassin! Travel with faith and kill with dignity. Come by anytime and pay us a visit. Once again, congratulations."
    )
    |> close()
  end

  defp reject_fake_necklace(ctx) do
    ctx
    |> mes("[Ferocious-looking guy]")
    |> mes("Eh?")
    |> mes("What do you want?")
    |> next()
    |> mes("[Ferocious-looking guy]")
    |> mes(
      "I see you're carrying a ^006699Necklace of Oblivion^000000... You want to become an Assassin, don't you? Let me check it..."
    )
    |> next()
    |> mes("[Ferocious-looking guy]")
    |> mes("...")
    |> next()
    |> mes("[Ferocious-looking guy]")
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("[Ferocious-looking guy]")
    |> mes("Wait a second...")
    |> mes("Why you no good BASTARD! THIS IS A FAKE!")
    |> next()
    |> mes("[Ferocious-looking guy]")
    |> mes(
      "How dare you think of trying to trick me with a fake! Are you stupid or what!? I should kill you..."
    )
    |> close()
    |> warp("moc_fild16", 206, 229)
  end

  defp greet_by_class(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "Hey Newbie. You should really get out of here as soon as you can. I can't guarantee your safety."
        )
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:swordman) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "What brings a man of the sword to this place? Why don't you try smashing stuff somewhere else, ya lunkhead."
        )
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:mage) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes("Now what would a magic user be doing here?")
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "There's a library in Prontera and Juno where you're welcome, so why don't you make like a magic trick and disappear?"
        )
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:archer) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes("Well well well.")
        |> mes("Look at that purdy bow.")
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "There aren't many Bowmen with the gall to even come close to this place. Well, what do you think you're doin' here?!"
        )
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "I thought something smelled funny. What's a servant of God doing in this place? You don't belong here."
        )
        |> close()

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:merchant) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "We don't like greedy people around these parts. You better sell your stuff somewhere else, Moneybags."
        )
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "You look like you don't have a care in the world. Well, I hope you enjoy your rest while you stay here. It's okay, since the Rogue and Assassin Guilds have always gotten along pretty well."
        )
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes("By the way...")
        |> mes("Have you ever seen")
        |> mes("a girl named Markie?")
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes("Markie...")
        |> mes(
          "We promised that we'd be together forever. ^666666*Sigh...*^000000 I don't even think she remembers that promise anymore. Then again, we were pretty young back then..."
        )
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:assassin) ->
        greet_assassin(ctx)

      thief?(ctx) and job_level(ctx) > 39 ->
        offer_job_quest(ctx)

      true ->
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "Huh. You're not qualified to become an Assassin yet. There are requirements you need to meet first, you know."
        )
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "Well, keep training. You need to be at least job level 40, got it? But if you're above job level 40, that will probably be even better."
        )
        |> close()
    end
  end

  defp greet_assassin(ctx) do
    ctx
    |> mes("[Assassin Expert 'Huey']")
    |> mes("Hey, I remember you~")
    |> mes("Wasn't your name, umm, I remember 'cause it sounded funny to me...")
    |> next()
    |> mes("[Assassin Expert 'Huey']")
    |> mes(
      ":+:#{char_name(ctx, 0)}:+:, right? No wait, just #{char_name(ctx, 0)}. Yeah, how's it goin'?"
    )
    |> next()
    |> mes("[Assassin Expert 'Huey']")
    |> mes(
      "Unfortunately, I don't have any requests for you at this time from the guild. Just keep focusing on your training. Till then, see ya."
    )
    |> close()
  end

  defp offer_job_quest(ctx) do
    if Rathena.truthy?(skill_point(ctx)) do
      ctx
      |> mes("[Ferocious-looking guy]")
      |> mes(
        "You can't change your job if you still have unused skill points from First Job. You better use up those skill points first."
      )
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("[Ferocious-looking guy]")
        |> mes("Hmm...")
        |> mes("A Thief...?")
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes(
          "And a well-experienced Thief since I can't seem to find my wallet. We do need people like you, you know."
        )
        |> next()
        |> mes("[Ferocious-looking guy]")
        |> mes("So how about taking the next step and becoming an Assassin?")
        |> next()
        |> select([
          "Yes. I've picked my last pocket.",
          "What's the requirements?",
          "Maybe later, I need to steal some things first."
        ])

      respond_to_job_offer(ctx, choice)
    end
  end

  defp respond_to_job_offer(ctx, 1) do
    ctx =
      ctx
      |> mes("[Ferocious-looking guy]")
      |> mes("It's been a while since I've received a guest. I'm sending")
      |> mes("you to the office.")
      |> close()
      |> set_char_var(:ASSIN_Q, 0)

    ctx =
      if checkquest(ctx, 8000) != -1 do
        changequest(ctx, 8000, 8001)
      else
        setquest(ctx, 8001)
      end

    warp(ctx, "in_moc_16", 19, 76)
  end

  defp respond_to_job_offer(ctx, 2) do
    ctx
    |> mes("[Ferocious-looking guy]")
    |> mes(
      "Requirements? Well, first you need to be a Thief. Second, you need to be at least Thief job level 40."
    )
    |> next()
    |> mes("[Ferocious-looking guy]")
    |> mes("And third, you need to pass a test to become an Assassin. You got")
    |> mes("all that? If you're sure of your ability as a Thief, you won't have to worry.")
    |> close()
  end

  defp respond_to_job_offer(ctx, 3) do
    ctx
    |> mes("[Ferocious-looking guy]")
    |> mes("Hmm...")
    |> mes("Alright then.")
    |> mes("But come back when")
    |> mes("you think you're ready.")
    |> close()
  end

  defp respond_to_job_offer(ctx, _choice), do: ctx
end
