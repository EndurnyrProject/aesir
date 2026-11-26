defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.Egnigem do
  @moduledoc """
  Egnigem, the dead Crusader of the 1st Squad, guides wanderers in Niflheim and reveals the
  truth behind the Megingjard mission.

  ## Behavior

  - Outside the Megingjard seal phase, or before the player reaches him in the quest, he marks
    or clears the town's buildings on the mini-map.
  - When the player comes looking for the 1st Squad's truth, he tells the story of the mission,
    the squad's fate and his love for Emma Searth; leaving the talk advances the quest.
  - Once the player has helped him, he grants his remaining strength as base experience scaled
    by base level, with a larger reward outside renewal.
  - Afterwards he only laments that Emma does not remember him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - brianluau
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "niflheim", x: 109, y: 254, dir: 0, sprite: 796, name: "Egnigem", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @buildings [
    {253, 191, 0xFFFF33},
    {217, 196, 0xFFCE63},
    {216, 171, 0xFF55FF},
    {189, 207, 0xFF3355}
  ]

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
         get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      quest_talk(ctx, get_char_var(ctx, :god_eremes, 0))
    else
      guide(
        ctx,
        "...I see. Now, let me introduce you all buildings in Niflheim!",
        6
      )
    end
  end

  defp quest_talk(ctx, stage) when stage > 22 and stage < 25 do
    ctx
    |> mes("[Egnigem]")
    |> mes("Why have you returned to")
    |> mes("this lonely place of darkness?")
    |> next()
    |> mes("[Egnigem]")
    |> mes("Please go back to the world")
    |> mes("of the living. To be here is to suffer, such is the nature of Niflheim.")
    |> close()
  end

  defp quest_talk(ctx, stage) when stage > 19 and stage < 25 do
    ctx
    |> mes("[Egnigem]")
    |> mes("Greetings...")
    |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), "."))
    |> mes("I've been watching you in the")
    |> mes(
      "world of the living. I see you've been busy looking for the truth about the 1st Squad, haven't you?"
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "I can provide you with the answers. After all, I'm the only member of the 1st Squad to retain all of my memories..."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("Heh heh...")
    |> mes("Let me tell you everything")
    |> mes("about the 1st Squad that's")
    |> mes("been forgotten...")
    |> story_menu()
  end

  defp quest_talk(ctx, stage) when stage in [25, 26], do: bestow_strength(ctx)

  defp quest_talk(ctx, stage) when stage < 20 do
    guide(
      ctx,
      "I see. If you better understand Niflheim's layout, you have a greater chance of surviving and escaping.",
      2
    )
  end

  defp quest_talk(ctx, _stage) do
    ctx
    |> mes("[Egnigem]")
    |> mes("I really wish that")
    |> mes("Emma Searth could")
    |> mes("remember me...")
    |> next()
    |> mes("^3355FFHis eyes seemed")
    |> mes("to moisten with sadness.")
    |> mes("Is it really possible for the")
    |> mes("dead to shed tears?^000000")
    |> close()
  end

  defp guide(ctx, buildings_intro, first_marker) do
    {ctx, choice} =
      ctx
      |> mes("[Egnigem]")
      |> mes(
        "Were you betrayed by fate as well, or are you simply a wanderer that's stumbled into this land of darkness?"
      )
      |> next()
      |> mes("[Egnigem]")
      |> mes("Hmm, the living don't deserve")
      |> mes(
        "to be in this realm of cold and suffering. But I can only help you escape by telling you what little"
      )
      |> mes("I know.")
      |> next()
      |> select(["Ask him about buildings.", "Remove marks on mini-map.", "Cancel."])

    case choice do
      1 ->
        ctx
        |> mes("[Egnigem]")
        |> mes(buildings_intro)
        |> next()
        |> buildings_menu(first_marker)

      2 ->
        ctx
        |> remove_marks(first_marker)
        |> mes("[Egnigem]")
        |> mes(
          "Alright, all the marks I've made have been removed from your mini-map. If you want to check the locations in Niflheim again, go ahead and ask me."
        )
        |> close()

      3 ->
        ctx
        |> mes("[Egnigem]")
        |> mes(
          "You're gonna explore this place on your own? Pretty brave, aren't you? Just be careful: here in Niflheim, darkness reigns supreme."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp buildings_menu(ctx, first_marker) do
    {ctx, choice} =
      select(ctx, ["Witch's Castle", "Tool Shop", "Weapon Shop", "Tavern", "Cancel"])

    case choice do
      5 ->
        ctx
        |> mes("[Egnigem]")
        |> mes(
          "Choose 'Remove marks on mini-map' from the menu to remove all the building location marks I've made."
        )
        |> close()

      building when building in 1..4 ->
        ctx
        |> describe_building(building)
        |> mark_building(building, first_marker)
        |> close()

      _ ->
        ctx
    end
  end

  defp describe_building(ctx, 1) do
    ctx
    |> mes("[Egnigem]")
    |> mes("The witch of Niflheim...")
    |> mes("You can find her castle at the ^FF3355+^000000 mark I've made on your mini-map.")
    |> next()
    |> mes("[Egnigem]")
    |> mes("Hrrrm...")
    |> mes(
      "It seems that the living who wind up in Niflheim are seeking out the witch. But I don't quite understand what's so important about her."
    )
  end

  defp describe_building(ctx, 2) do
    ctx
    |> mes("[Egnigem]")
    |> mes("The Tool shop? Here in Niflheim, they sell some unique items that")
    |> mes("you can't buy anywhere else.")
    |> next()
    |> mes("[Egnigem]")
    |> mes("You might want to see their")
    |> mes("wares for yourself. I've drawn")
    |> mes("a ^CE6300+^000000 on your mini-map to mark")
    |> mes("its location.")
  end

  defp describe_building(ctx, 3) do
    ctx
    |> mes("[Egnigem]")
    |> mes(
      "I've marked the location of the Weapon Shop at ^55FF33+^000000. There's nothing too special over there, though."
    )
  end

  defp describe_building(ctx, 4) do
    ctx
    |> mes("[Egnigem]")
    |> mes("Tavern is at ^3355FF+^000000. They only sell drinks to the dead, though...")
  end

  defp mark_building(ctx, building, first_marker) do
    {x, y, color} = Enum.at(@buildings, building - 1)
    viewpoint(ctx, 1, x, y, first_marker + building - 1, color)
  end

  defp remove_marks(ctx, first_marker) do
    @buildings
    |> Enum.with_index(first_marker)
    |> Enum.reduce(ctx, fn {{x, y, _color}, marker}, ctx ->
      viewpoint(ctx, 2, x, y, marker, 0xFF00FF)
    end)
  end

  defp story_menu(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> select([
        "The Mission",
        "Fate of the 1st Squad",
        "Why are you in Niflheim?",
        "Thanks, I've heard enough."
      ])

    case choice do
      1 -> ctx |> mission_story() |> story_menu()
      2 -> ctx |> squad_fate_story() |> story_menu()
      3 -> ctx |> emma_story() |> story_menu()
      4 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp mission_story(ctx) do
    ctx
    |> mes("[Egnigem]")
    |> mes("First of all, the official record of our mission is misleading.")
    |> mes("It contains some truth, based")
    |> mes("on verbal evidence, but the most important details have been left out or changed.")
    |> next()
    |> mes("[Egnigem]")
    |> mes("Now, we were secretly assigned")
    |> mes(
      "to find ^0000FFgodly artifacts^000000 by royal decree. In only three days, we succeeded and found Megingjard!"
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "Now, the records say the mission was unsatisfactory, correct? That would be because of me."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("Are you aware that Megingjard")
    |> mes(
      "was a belt worn by gods? It was actually one of the keys to Thor's great strength. Another name for it is the 'Girdle of Might.'"
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("Now, if a human were to wear")
    |> mes(
      "that, there's a possibility that Megingjard would give him strength comparable to a god. Naturally, you'd be afraid of such a thing falling into the wrong hands."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("In Rebarev Doug's mind, he")
    |> mes(
      "was the only person worthy of the belt since he considered himself the most religious person alive, and thus, closest to the gods."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "He made it clear to us that only he would wear Megingjard. Although he was our leader, some of us felt uneasy about him wearing the belt and not giving it to his superiors, our mission objective."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "Naturally, I opposed him. He was clearly unbalanced, and it would be dangerous to give him control of such power. It led to something of a fist fight between us."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("The rest of the squad couldn't")
    |> mes(
      "agree on whether or not we should simply obey our leader and let him have the belt. Some just wanted to complete the mission, while others were afraid of what might happen."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "But Rebarev didn't wait for us to decide. He destroyed Megingjard into pieces, intending to keep most of it and somehow reconstruct it later, and only bring one piece to the Prontera Military."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("He knew that he couldn't get")
    |> mes(
      "away with keeping all of Megingjard to himself, as the entire squad could easily discredit him."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("But Rebarev knew")
    |> mes("that he could deceive his")
    |> mes(
      "superiors by giving them just a fragment of the artifact, and say that the rest of it was destroyed."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("I discovered his intention when")
    |> mes("I found him taking Megingjard apart. Before I could stop him,")
    |> mes("I was killed. That bastard had")
    |> mes("a trap ready for me...")
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "After the mission, Rebarev Doug only gave a piece of the belt back to the higher-ups, and gave them"
    )
    |> mes("a different account than what had actually happened...")
  end

  defp squad_fate_story(ctx) do
    ctx
    |> mes("[Egnigem]")
    |> mes(
      "Once the mission was completed, Rebarev Doug reported back to the Prontera Military with the intent of keeping most of Megingjard for himself."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "For some reason, he has a very strong influence in the military hierarchy. Now, by this time, I'm sure the squad pretty much figured out that he killed me."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "But Rebarev Doug expected this, and explained to his superiors that the squad was tempted by Megingjard's power and that I led some of us in a mutiny against him."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("He told his superiors that Megingjard was damaged as we")
    |> mes("fought amongst each other, and that the fragment he gave them was all that remained.")
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "Because of the confidential nature of our mission, the 1st Squad was disbanded and we weren't given the story Rebarev fed the beaureaucrats until it was too late."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("The squad was punished and")
    |> mes(
      "sent for disciplinary retraining for three months. During this time, specific memories were unnaturally erased from the squad members."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "In the end, everyone was transferred to other squads and positions. My name had to be removed from all the records since hearing or reading my name might undo the brain washing."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "However, they still needed an official scapegoat, so they used Royal Myst's name in the records. That's probably why he's been going through hard times right now."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "And now Rebarev Doug has been studying godly artifacts based on the pieces of Megingjard that we found on that mission using kingdom research funds. Someday, he might be able to reconstruct the belt."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("There are also")
    |> mes("a few questions that")
    |> mes("I've never been able")
    |> mes("to answer.")
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "I've never known why the King Tristram III ordered the research of godly artifacts. It also bothers me that Rebarev Doug is in charge of Megingjard's research. There must be some reason."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "In any case, for the sake of Midgard, it will be your responsibility to find the answers."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("There's not much a dead man")
    |> mes(
      "can do. But what's worse is that no one remembers me any more. I died alone and I'm still lonely in this place for the dead."
    )
  end

  defp emma_story(ctx) do
    ctx
    |> mes("[Egnigem]")
    |> mes("The worst part of the squad")
    |> mes("having their memories erased is")
    |> mes("that Emma Searth has absolutely")
    |> mes("no recollection of me.")
    |> next()
    |> mes("[Egnigem]")
    |> mes("Do you mind listening")
    |> mes("to me for a while? You're")
    |> mes("the only person with whom")
    |> mes("I can talk about this...")
    |> next()
    |> mes("[Egnigem]")
    |> mes("From here, I've seen that Emma")
    |> mes("is chasing her dream again, and")
    |> mes("I'm happy for her. But it's still")
    |> mes("not easy, knowing the woman you")
    |> mes("love has totally forgotten you.")
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "I remember the first time I met her. I guess it was love at first sight. But I was too cowardly to confess my love, so I despaired when she joined the Crusaders."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("It took me a while, but I made up my mind to enlist as a Crusader")
    |> mes("as well. I wanted to be closer to her so much.")
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "Now, after all our adventures and good times together, I'm in the worst possible scenario."
    )
    |> next()
    |> mes("[Egnigem]")
    |> mes("I'm dead...")
    |> mes("But I don't even have the consolation that she is")
    |> mes("mourning my loss.")
    |> next()
    |> mes("[Egnigem]")
    |> mes("I suppose that's why I'm here")
    |> mes("in Niflheim. I can't quite move on to heaven, Valhalla or anywhere else without her.")
    |> next()
    |> mes("[Egnigem]")
    |> mes(
      "Anyway, go and visit the Crusader Headquarters. You might be able to learn more about Rebarev Doug and stop any new shadiness he might be plotting. Good luck, my friend."
    )
  end

  defp farewell(ctx) do
    ctx =
      ctx
      |> mes("[Egnigem]")
      |> mes("Thank you for")
      |> mes("listening to me...")

    ctx
    |> advance_after_story(get_char_var(ctx, :god_eremes, 0))
    |> close()
  end

  defp advance_after_story(ctx, 21), do: set_char_var(ctx, :god_eremes, 23)
  defp advance_after_story(ctx, 22), do: set_char_var(ctx, :god_eremes, 24)
  defp advance_after_story(ctx, _stage), do: ctx

  defp bestow_strength(ctx) do
    ctx =
      ctx
      |> mes("[Egnigem]")
      |> mes("As a Crusader...")
      |> mes("This is the best thing")
      |> mes("I can do in return for")
      |> mes("what you have done for me.")
      |> next()
      |> mes("[Egnigem]")
      |> mes("Listen...")
      |> mes("I'm going to")
      |> mes("imbue you with the")
      |> mes("^666666last vestiges of my strength^000000...")
      |> specialeffect(:beginspell5)
      |> specialeffect2(:holyhit)
      |> next()
      |> mes("[Egnigem]")
      |> mes("May the heavens")
      |> mes("answer me as I call upon the")
      |> mes(
        "light of justice that empowers the defenders of truth, and threaten the enemies of peace."
      )
      |> specialeffect(:beginspell6)
      |> specialeffect2(:holyhit)
      |> next()
      |> mes("[Egnigem]")
      |> mes("May you always shine with")
      |> mes("the light of truth. Let the light within you eradicate the shadows")
      |> mes("of deception, fear and malice.")
      |> specialeffect(:beginspell6)
      |> specialeffect2(:holyhit)
      |> next()
      |> mes("[Egnigem]")
      |> mes("By the holy power")
      |> mes(
        "invested in me, I humbly bestow upon you my remaining strength. Fight honorably, and do not lose sight of righteousness."
      )
      |> specialeffect(:lockon)
      |> specialeffect2(:holycross)
      |> set_char_var(:god_eremes, 27)

    {renewal_exp, classic_exp} = strength_exp(base_level(ctx))
    exp = if Rathena.truthy?(checkre(ctx, 3)), do: renewal_exp, else: classic_exp

    ctx
    |> getexp(exp, 0)
    |> close()
  end

  defp strength_exp(level) when level < 56, do: {2700, 27_000}
  defp strength_exp(level) when level < 61, do: {3000, 30_000}
  defp strength_exp(level) when level < 66, do: {5605, 56_052}
  defp strength_exp(level) when level < 71, do: {8223, 82_233}
  defp strength_exp(level) when level < 76, do: {21_227, 212_271}
  defp strength_exp(level) when level < 81, do: {39_073, 390_738}
  defp strength_exp(level) when level < 86, do: {45_102, 451_020}
  defp strength_exp(level) when level < 91, do: {54_615, 546_156}
  defp strength_exp(_level), do: {122_035, 1_220_358}
end
