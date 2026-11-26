defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MjolnirSeal.DwarfBlacksmith209341 do
  @moduledoc """
  Sudri, the dwarf blacksmith of southern Mount Mjolnir, challenges players on the Mjolnir Seal
  quest to a bare knuckle brawl.

  ## Behavior

  - Before the Mjolnir seal phase opens he only dreams of defeating Ivaldi; once the seal is
    broken he says it is not the time for fighting.
  - On the first round he is the second dwarf and on the second round the third: once the
    previous dwarves are done, a respectful "Excuse me, sir." gets a challenge offer, and
    accepting it (or admitting to being scared) unlocks the fight.
  - The fight is a menu duel: the player picks an attack, then a defense, against Sudri's random
    guard and attack until one side runs out of HP. Winning marks his part of the quest as done;
    losing or a cancelled menu lets the player try again.
  - Answering "Excuse me, sir." when he is not the dwarf to visit, or staying silent at the
    challenge, marks the player as rude, after which he only threatens them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - Samuray22
    - L0ne_W0lf
    - Zephyrus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - The finished-quest greeting was gated on `god_mjo_10 == 10`, a variable nothing sets, so it
    never showed; it checks `god_mjo_0 == 10` like the other Mjolnir dwarves.
  - The first round's fight result compared the HP locals with the unset character variables
    `n_vit` and `p_vit` (`.@p_vit < n_vit`, `.@n_vit < p_vit`), so a fight ending at exactly
    0 HP gave no result; it compares the two HP locals like the second round's fight.
  - On the second round's first meeting, "Nothing." used `close2` and fell through into the
    challenge offer; it ends with `close` like the first round's same menu.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_09",
        x: 209,
        y: 341,
        dir: 3,
        sprite: 826,
        name: "Dwarf Blacksmith",
        scope: :shared,
        unique_name: "Dwarf Blacksmith#south"
      }
    ]

  @separator "--------------------"

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God3", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        ctx
        |> mes("[Sudri]")
        |> mes("I want to compete")
        |> mes("and fight with stronger and stronger opponents!")
        |> next()
        |> mes("[Sudri]")
        |> mes("One day, I'll return to Svartalfaheimr and defeat Ivaldi! Mwahahaha!")
        |> close()

      get_server_var(ctx, "God4", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ctx
        |> mes("[Sudri]")
        |> mes("Wait, this is")
        |> mes("not the right time")
        |> mes("for fighting...")
        |> next()
        |> mes("[Sudri]")
        |> mes(
          "Something that has been hidden is about to be born out of the sweat of determination and tears of sacrifice. We must wait until then."
        )
        |> close()

      true ->
        talk(ctx, get_char_var(ctx, :god_mjo_0, 0))
    end
  end

  defp talk(ctx, 11) do
    ctx
    |> mes("[Sudri]")
    |> mes("I want to compete with a stronger one!")
    |> mes("I will be stronger and stronger,")
    |> mes("one day when I get back to Svartalfaheimr")
    |> mes("I shall defeat Ivaldi!")
    |> mes("Muhahahaha...!")
    |> close()
  end

  defp talk(ctx, 10) do
    ctx
    |> mes("[Sudri]")
    |> mes(
      "I must admit that you're a really strong human. Let us fight again when we have a chance. The next time, you may not be so lucky!"
    )
    |> close()
  end

  defp talk(ctx, 1), do: first_round(ctx)
  defp talk(ctx, 2), do: second_round(ctx)

  defp talk(ctx, 0) do
    ctx
    |> mes("[Sudri]")
    |> mes(
      "In a one on one fight, you put everything on the line to show your might to your opponent."
    )
    |> next()
    |> mes("[Sudri]")
    |> mes(
      "Have you ever felt the same way I do, human? Win or lose, just giving your all is the most satisfying accomplishment."
    )
    |> close()
  end

  defp talk(ctx, _stage), do: sleeping(ctx)

  defp first_round(ctx) do
    cond do
      rude?(ctx) ->
        ctx
        |> mes("[Sudri]")
        |> mes("Go back to where you belong before I beat you to death!")
        |> next()
        |> mes("[Sudri]")
        |> mes("All you can gain here are a few herbs.")
        |> close()

      get_char_var(ctx, :god_mjo_2, 0) == 2 ->
        ctx
        |> mes("[Sudri]")
        |> mes("That was a great fight!")
        |> mes(
          "Mwahahaha! I'm satisfied with the results. I may have lost, but we fought honorably with everything we had."
        )
        |> close()

      get_char_var(ctx, :god_mjo_1, 0) in [0, 1] or get_char_var(ctx, :god_mjo_3, 0) != 0 or
          get_char_var(ctx, :god_mjo_4, 0) != 0 ->
        first_round_rude_menu(ctx)

      get_char_var(ctx, :god_mjo_2, 0) == 1 ->
        ctx |> fight(:first) |> fight_outcome(:god_mjo_2)

      get_char_var(ctx, :god_mjo_2, 0) == 0 ->
        first_round_meeting(ctx)

      true ->
        sleeping(ctx)
    end
  end

  defp second_round(ctx) do
    cond do
      rude?(ctx) ->
        ctx
        |> mes("[Sudri]")
        |> mes("[Sudri]")
        |> mes(
          "Get out of here before I beat you to death! All you can gain over here is a few herbs, anyway!"
        )
        |> close()

      get_char_var(ctx, :god_mjo_3, 0) == 2 ->
        ctx
        |> mes("[Sudri]")
        |> mes("That was a great fight!")
        |> mes("Hahahahahahahahahaah!")
        |> mes("I regret nothing.")
        |> mes("I may have lost, but")
        |> mes("I gave it my all!")
        |> close()

      get_char_var(ctx, :god_mjo_1, 0) in [0, 1] or get_char_var(ctx, :god_mjo_2, 0) in [0, 1] or
          get_char_var(ctx, :god_mjo_4, 0) != 0 ->
        second_round_rude_menu(ctx)

      get_char_var(ctx, :god_mjo_3, 0) == 1 ->
        ctx
        |> mes("[Sudri]")
        |> mes("Cool, let's fight!")
        |> next()
        |> fight(:second)
        |> fight_outcome(:god_mjo_3)

      get_char_var(ctx, :god_mjo_3, 0) == 0 ->
        second_round_meeting(ctx)

      true ->
        sleeping(ctx)
    end
  end

  defp rude?(ctx) do
    Enum.any?([:god_mjo_1, :god_mjo_2, :god_mjo_3, :god_mjo_4], &(get_char_var(ctx, &1, 0) == 3))
  end

  defp sleeping(ctx), do: ctx |> mes("[Sudri]") |> mes("Zzzz Zzzz...") |> close()

  defp first_round_rude_menu(ctx) do
    case ctx
         |> mes("[Sudri]")
         |> mes("So...")
         |> mes("What brings")
         |> mes("you here?")
         |> next()
         |> select(["Nothing.", "Excuse me, sir."]) do
      {ctx, 1} ->
        ctx
        |> mes("[Sudri]")
        |> mes(
          "You have too much time on your hands. Why don't you log out and hang out with your friends instead?"
        )
        |> close()

      {ctx, 2} ->
        ctx
        |> set_char_var(:god_mjo_2, 3)
        |> mes("[Sudri]")
        |> mes("Why should")
        |> mes("I excuse you?")
        |> next()
        |> mes("[Sudri]")
        |> mes("If there's")
        |> mes("anything I hate,")
        |> mes("it's insincerity and")
        |> mes("sarcasm. What, you")
        |> mes("wanna fight?!")
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp first_round_meeting(ctx) do
    case ctx
         |> mes("[Sudri]")
         |> mes("So...")
         |> mes("What brings")
         |> mes("you here, human?")
         |> next()
         |> select(["Nothing.", "Excuse me, sir."]) do
      {ctx, 1} ->
        ctx
        |> mes("[Sudri]")
        |> mes(
          "You have too much time on your hands. Why don't you log out and hang out with your buddies for a while?"
        )
        |> close()

      {ctx, 2} ->
        challenge_offer(ctx, :god_mjo_2)

      {ctx, _} ->
        ctx
    end
  end

  defp second_round_rude_menu(ctx) do
    case what_made_you_come(ctx) do
      {ctx, 1} ->
        too_much_time(ctx)

      {ctx, 2} ->
        ctx
        |> set_char_var(:god_mjo_3, 3)
        |> mes("[Sudri]")
        |> mes("Why should")
        |> mes("I excuse you?")
        |> mes("Do you want to")
        |> mes("fight with me, huh?")
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp second_round_meeting(ctx) do
    case what_made_you_come(ctx) do
      {ctx, 1} -> too_much_time(ctx)
      {ctx, 2} -> challenge_offer(ctx, :god_mjo_3)
      {ctx, _} -> ctx
    end
  end

  defp what_made_you_come(ctx) do
    ctx
    |> mes("[Sudri]")
    |> mes("What made you come to me?")
    |> next()
    |> select(["Nothing.", "Excuse me, sir."])
  end

  defp too_much_time(ctx) do
    ctx
    |> mes("[Sudri]")
    |> mes("You have too much")
    |> mes("time on your hands.")
    |> mes("Why don't you log out and go out with your friends instead?")
    |> close()
  end

  defp challenge_offer(ctx, quest_var) do
    choice =
      ctx
      |> mes("[Sudri]")
      |> mes(
        "Huh. You're different than other humans. But still, trusting you because you know how to speak respectfully isn't very wise."
      )
      |> next()
      |> mes("[Sudri]")
      |> mes("If there's anything I love,")
      |> mes("it's bare knuckle brawling,")
      |> mes("old school style.")
      |> next()
      |> mes("[Sudri]")
      |> mes("Words can be deceptive,")
      |> mes("but if you can beat me in")
      |> mes("a fight, I think I might")
      |> mes("just talk to you.")
      |> mes("How about it?")
      |> next()
      |> select(["...", "Yes, I accept your challenge.", "No, I'm scared!"])

    case choice do
      {ctx, 1} ->
        ctx
        |> set_char_var(quest_var, 3)
        |> mes("[Sudri]")
        |> mes("You didn't")
        |> mes("even answer me!")
        |> mes("Fine! Whatever!")
        |> close()

      {ctx, 2} ->
        ctx
        |> set_char_var(quest_var, 1)
        |> mes("[Sudri]")
        |> mes(
          "Ah, I like you already, human! Now why don't you go do some warm ups, and we'll fight when you're ready."
        )
        |> close()

      {ctx, 3} ->
        ctx
        |> set_char_var(quest_var, 1)
        |> mes("[Sudri]")
        |> mes("Eh...?")
        |> mes("Why are you being")
        |> mes("such a coward?")
        |> mes("Are you afraid of")
        |> mes("this old and tiny Dwarf?")
        |> next()
        |> mes("[Sudri]")
        |> mes(
          "Come on, I'll even let you have the first hit. Just come to me when you're ready to fight!"
        )
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp fight_outcome({:ended, ctx}, _quest_var), do: ctx

  defp fight_outcome({:over, ctx, %{player: player, sudri: sudri}}, quest_var) do
    cond do
      player < sudri ->
        ctx
        |> mes("[Sudri]")
        |> mes("Muhahahaha!")
        |> mes("You're not strong enough to beat me! I want someone who can offer")
        |> mes("me a challenge!")
        |> next()
        |> mes("[Sudri]")
        |> mes("Go out, train some and get stronger before you even think about coming back!")
        |> close()

      sudri < player ->
        ctx
        |> set_char_var(quest_var, 2)
        |> mes("[Sudri]")
        |> mes("You're stronger than me. I never thought I'd meet a human as strong as you.")
        |> next()
        |> mes("[Sudri]")
        |> mes(
          "I'm impressed! Alright, I'll tell my friends good things about you. Hopefully, my brothers will give you the help you're looking for."
        )
        |> next()
        |> mes("[Sudri]")
        |> mes("Okay then,")
        |> mes("be safe on")
        |> mes("your travels!")
        |> close()

      true ->
        ctx
    end
  end

  defp fight(ctx, round), do: fight_turns(ctx, %{sudri: 200, player: 100}, round)

  defp fight_turns(ctx, hp, round) do
    with {:next, ctx, hp} <- player_turn(ctx, hp),
         {:next, ctx, hp} <- sudri_turn(ctx, hp, round) do
      fight_turns(ctx, hp, round)
    end
  end

  defp hp_status(ctx, hp) do
    ctx
    |> mes("Sudri : #{hp.sudri} HP")
    |> mes("#{char_name(ctx, 0)} : #{hp.player} HP")
    |> mes(@separator)
  end

  defp player_turn(ctx, hp) do
    choice =
      ctx
      |> hp_status(hp)
      |> mes(char_name(ctx, 0))
      |> mes("initiated")
      |> mes("an attack!")
      |> next()
      |> select(["...?!", "Strike Head!", "Strike Chest!", "Strike Legs!", "Take a break."])

    case choice do
      {ctx, choice} when choice in 1..5 ->
        attack = choice - 1
        guard = Enum.random(1..3)
        damage = Enum.random(15..25)

        ctx
        |> announce_attack(attack)
        |> resolve_attack(attack, guard, damage, hp)
        |> check_sudri_down()

      {ctx, _} ->
        {:ended, ctx}
    end
  end

  defp announce_attack(ctx, 1), do: ctx |> mes(char_name(ctx, 0)) |> mes("attacks Sudri's head!")
  defp announce_attack(ctx, 2), do: ctx |> mes(char_name(ctx, 0)) |> mes("strikes Sudri's chest!")
  defp announce_attack(ctx, 3), do: ctx |> mes(char_name(ctx, 0)) |> mes("aims for Sudri's legs!")
  defp announce_attack(ctx, 4), do: ctx |> mes(char_name(ctx, 0)) |> mes("requests a break!")

  defp announce_attack(ctx, _attack) do
    ctx |> mes("#{char_name(ctx, 0)}'s") |> mes("weak point revealed!")
  end

  defp resolve_attack(ctx, guard, guard, _damage, hp) do
    ctx = ctx |> specialeffect(:guard) |> mes(@separator)

    ctx =
      case guard do
        1 ->
          ctx
          |> mes("Sudri easily dodges")
          |> mes("your attack by twisting")
          |> mes("his small, yet svelte, body.")
          |> mes(@separator)
          |> mes("#{char_name(ctx, 0)} misses!")

        2 ->
          ctx
          |> mes("Sudri blocks your")
          |> mes("attack by crossing")
          |> mes("his stout arms.")
          |> mes(@separator)
          |> mes("#{char_name(ctx, 0)}'s attack is blocked!")

        3 ->
          ctx
          |> mes("Sudri dodges your")
          |> mes("attack with a graceful")
          |> mes("leap to the heavens.")
          |> mes(@separator)
          |> mes("#{char_name(ctx, 0)} misses!")
      end

    {:next, ctx, hp}
  end

  defp resolve_attack(ctx, 4, _guard, _damage, hp) do
    ctx =
      ctx
      |> specialeffect2(:heal)
      |> mes(@separator)
      |> mes(char_name(ctx, 0))
      |> mes("has gained 10 HP!")

    {:next, ctx, %{hp | player: hp.player + 10}}
  end

  defp resolve_attack(ctx, 1, _guard, damage, hp) do
    ctx =
      ctx
      |> specialeffect(:hit5)
      |> mes(@separator)
      |> mes("You successfully hit")
      |> mes("Sudri on the head!")
      |> mes(@separator)
      |> mes("Sudri has lost #{damage} HP!")

    {:next, ctx, %{hp | sudri: hp.sudri - damage}}
  end

  defp resolve_attack(ctx, 2, _guard, damage, hp) do
    ctx = ctx |> specialeffect(:hit2) |> sudri_hit("Sudri on the chest!", damage)
    {:next, ctx, %{hp | sudri: hp.sudri - damage}}
  end

  defp resolve_attack(ctx, 3, _guard, damage, hp) do
    ctx = ctx |> specialeffect(:hit4) |> sudri_hit("Sudri on the legs!", damage)
    {:next, ctx, %{hp | sudri: hp.sudri - damage}}
  end

  defp resolve_attack(ctx, 0, _guard, _damage, hp) do
    hp = %{hp | player: hp.player - 10}

    ctx =
      ctx
      |> specialeffect2(:hit5)
      |> mes(@separator)
      |> mes("You were hit by")
      |> mes("Sudri's counter attack!")
      |> mes(@separator)
      |> mes("#{char_name(ctx, 0)} has lost 10 HP!")

    if hp.player < 1 do
      {:over, ctx |> mes("Defeated...") |> next(), hp}
    else
      {:next, ctx, hp}
    end
  end

  defp resolve_attack(ctx, _attack, _guard, _damage, _hp), do: fight_stopped(ctx)

  defp sudri_hit(ctx, part, damage) do
    ctx
    |> mes(@separator)
    |> mes("You successfully hit")
    |> mes(part)
    |> mes(@separator)
    |> mes("Sudri has")
    |> mes("lost #{damage} HP!")
  end

  defp check_sudri_down({:next, ctx, %{sudri: sudri} = hp}) when sudri < 1 do
    {:over, ctx |> mes("#{char_name(ctx, 0)} wins!") |> next(), hp}
  end

  defp check_sudri_down({:next, ctx, hp}), do: {:next, next(ctx), hp}
  defp check_sudri_down(result), do: result

  defp sudri_turn(ctx, hp, round) do
    choice =
      ctx
      |> hp_status(hp)
      |> mes("Sudri attacks...!")
      |> next()
      |> select(["...?!", "Dodge!", "Block!", "Jump!", "Counter back!"])

    case choice do
      {ctx, choice} when choice in 1..5 ->
        defense = choice - 1
        attack = Enum.random(1..3)
        damage = Enum.random(20..25)

        ctx
        |> announce_sudri_attack(attack)
        |> resolve_defense(attack, defense, damage, hp, round)
        |> check_player_down()

      {ctx, _} ->
        {:ended, ctx}
    end
  end

  defp announce_sudri_attack(ctx, 1), do: mes(ctx, "Sudri aims for the head!")
  defp announce_sudri_attack(ctx, 2), do: mes(ctx, "Sudri strikes the chest!")
  defp announce_sudri_attack(ctx, _attack), do: mes(ctx, "Sudri attacks the legs!")

  defp resolve_defense(ctx, defense, defense, _damage, hp, round) do
    ctx = ctx |> specialeffect2(:guard) |> mes(@separator)

    ctx =
      case defense do
        1 -> dodged(ctx, round)
        2 -> ctx |> mes(char_name(ctx, 0)) |> mes("barely blocked") |> mes("Sudri's attack.")
        3 -> ctx |> mes("#{char_name(ctx, 0)} jumped,") |> mes("dodged Sudri's attack at ease.")
      end

    {:next, ctx |> mes(@separator) |> mes("Sudri has failed to attack."), hp}
  end

  defp resolve_defense(ctx, _attack, 4, _damage, hp, _round) do
    count = Enum.random(1..4)
    ctx = ctx |> mes(@separator) |> mes(char_name(ctx, 0)) |> mes("counters!")

    if count == 1 do
      hp = %{hp | sudri: hp.sudri - 20}

      ctx =
        ctx
        |> specialeffect2(:autocounter)
        |> specialeffect(:magnumbreak)
        |> mes("You successfully")
        |> mes("counter attacked!")
        |> mes(@separator)
        |> mes("Sudri has lost 20 HP!")

      if hp.sudri < 1 do
        {:over, ctx |> mes("#{char_name(ctx, 0)} won!") |> next(), hp}
      else
        {:next, ctx, hp}
      end
    else
      ctx =
        ctx
        |> specialeffect2(:crashearth)
        |> mes("You've taken")
        |> mes("critical damage")
        |> mes("on your weak spot!")
        |> mes(@separator)
        |> mes("#{char_name(ctx, 0)} has lost 30 HP!")

      {:next, ctx, %{hp | player: hp.player - 30}}
    end
  end

  defp resolve_defense(ctx, 1, _defense, damage, hp, _round) do
    ctx = ctx |> specialeffect2(:hit5) |> player_hit("on the head!", damage)
    {:next, ctx, %{hp | player: hp.player - damage}}
  end

  defp resolve_defense(ctx, 2, _defense, damage, hp, _round) do
    ctx = ctx |> specialeffect2(:hit2) |> player_hit("on the chest!", damage)
    {:next, ctx, %{hp | player: hp.player - damage}}
  end

  defp resolve_defense(ctx, 3, _defense, damage, hp, _round) do
    ctx = ctx |> specialeffect2(:hit4) |> player_hit("on the legs!", damage)
    {:next, ctx, %{hp | player: hp.player - damage}}
  end

  defp resolve_defense(ctx, 0, _defense, damage, hp, _round) do
    ctx =
      ctx
      |> specialeffect2(:hit5)
      |> mes(@separator)
      |> mes("Sudri successfully")
      |> mes("hits #{char_name(ctx, 0)}")
      |> mes("during a moment of")
      |> mes("absent-mindedness!")
      |> mes(@separator)
      |> mes("#{char_name(ctx, 0)} has lost #{damage} HP!")

    {:next, ctx, %{hp | player: hp.player - damage}}
  end

  defp resolve_defense(ctx, _attack, _defense, _damage, _hp, _round), do: fight_stopped(ctx)

  defp dodged(ctx, :first) do
    ctx
    |> mes(char_name(ctx, 0))
    |> mes("quickly dodged!")
    |> mes("Sudri's arms were")
    |> mes("too short and missed!")
  end

  defp dodged(ctx, :second) do
    ctx
    |> mes("#{char_name(ctx, 0)} quickly dodged,")
    |> mes("Sudri's arms were too")
    |> mes("short to reach at you.")
  end

  defp player_hit(ctx, part, damage) do
    ctx
    |> mes(@separator)
    |> mes("Sudri successfully")
    |> mes("hit #{char_name(ctx, 0)}")
    |> mes(part)
    |> mes(@separator)
    |> mes("#{char_name(ctx, 0)} has lost #{damage} HP!")
  end

  defp check_player_down({:next, ctx, %{player: player} = hp}) when player < 1 do
    {:over, ctx |> mes("Sudri won!") |> next(), hp}
  end

  defp check_player_down({:next, ctx, hp}), do: {:next, next(ctx), hp}
  defp check_player_down(result), do: result

  defp fight_stopped(ctx) do
    ctx =
      ctx
      |> mes(@separator)
      |> mes("Something happened")
      |> mes("and the fight has stopped!")
      |> close()

    {:ended, ctx}
  end
end
