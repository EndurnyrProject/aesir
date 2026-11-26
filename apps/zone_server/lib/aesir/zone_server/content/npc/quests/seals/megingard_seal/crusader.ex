defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MegingardSeal.Crusader do
  @moduledoc """
  Zan.Huadoku, a former 1st Squad Crusader working as weapon quartermaster for the Blacksmith
  Guild, slowly recalls his squad's last mission for the Megingard Seal quest.

  ## Behavior

  - Outside the Megingard seal phase, he talks about the importance of supply or shares what he
    learned about Blacksmith forging.
  - Once the player has traced the 1st Squad, asking about the squad makes him remember the
    disobeyed order, and the quest advances.
  - Asking about the last mission afterwards, with the library records as a clue, he recalls the
    unknown fragment, and the quest advances.
  - Talked to again, he remembers his headaches and the quest advances once more; after that he
    only repeats the same words in agony.

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
      %{
        map: "geffen_in",
        x: 109,
        y: 161,
        dir: 3,
        sprite: 751,
        name: "Crusader",
        scope: :shared,
        unique_name: "Crusader#God1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_server_var(ctx, "God1", 0) >= get_server_temp_var(ctx, "god_check1", 0) and
         get_server_var(ctx, "God2", 0) < get_server_temp_var(ctx, "god_check2", 0) do
      quest_talk(ctx)
    else
      supply_talk(ctx)
    end
  end

  defp quest_talk(ctx) do
    megin = get_char_var(ctx, :god_megin_1, 0)

    cond do
      get_char_var(ctx, :god_eremes, 0) > 17 and megin < 2 ->
        squad_menu(ctx)

      megin > 1 and megin < 3 ->
        ctx
        |> mes("...")
        |> next()
        |> mes("...")
        |> mes(".....")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Y-yeah that's right! And then three days after we started the mission, we found some kind of..."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Well, I'm not sure what it was. But we found an ^0000FFunknown fragment^000000 that was a sign from God! And then...!"
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("And then...")
        |> mes("Oh. Oh God.")
        |> mes("I can't remember...")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "I can't think about anything further than that. I can't even remember what we found. Three months after that all happened, I've had these head problems..."
        )
        |> next()
        |> mes("^3355FFZan stood still in silence, with a pained look on his face.^000000")
        |> set_char_var(:god_megin_1, 3)
        |> close()

      megin > 2 ->
        ctx
        |> mes("^3355FFGrabbing his head,")
        |> mes(
          "tearing his hair and writhing in Agony, Zan kept repeating the same words over and over again...^000000"
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("3 days later!")
        |> mes("We f-found some ^0000FFfragment^000000!")
        |> mes("It was G-God's sign! But why")
        |> mes("can't I remember?! Why?!")
        |> close()

      true ->
        ctx |> mes("[Zan.Huadoku]") |> mes("Hey yo.") |> mes("Can I help you?") |> close()
    end
  end

  defp squad_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zan.Huadoku]")
      |> mes("^333333*Phew...*^000000")
      |> mes(
        "This work is really getting to me. Going on a mission with my war buddies sounds a lot better than this."
      )
      |> next()
      |> mes("[Zan.Huadoku]")
      |> mes("At least in those days, I felt like I was actually doing something useful!")
      |> next()
      |> mes("[Zan.Huadoku]")
      |> mes("Hey...")
      |> mes("Can I help you")
      |> mes("with anything?")
      |> next()
      |> select([
        "Ask him about the 1st Squad.",
        "Ask him how he's been doing.",
        "Ask him about the 1st Squad's last mission."
      ])

    case choice do
      1 -> ask_about_squad(ctx)
      2 -> how_he_has_been(ctx)
      3 -> ask_about_last_mission(ctx)
      _ -> ctx
    end
  end

  defp ask_about_squad(ctx) do
    eremes = get_char_var(ctx, :god_eremes, 0)

    cond do
      eremes == 18 ->
        ctx
        |> squad_memories()
        |> close()

      eremes > 18 ->
        ctx
        |> squad_memories()
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Before we went out on our last mission, the seven of us were like brothers and sisters. If ^FF0000he^000000 didn't disobey the order, we'd still be together today."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("Wait...")
        |> mes("What was his name...?")
        |> mes("There's no way I could forget something like that...")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("H-how can I not")
        |> mes("remember his name!")
        |> mes("He's the reason")
        |> mes("my life is...!")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("^333333*Groan...*^000000")
        |> mes("I.... My head...")
        |> mes("My head hurts...")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "^3355FFZan looks very confused and his eyes begin to glaze with a dazed look. You try speaking to him again, but he doesn't respond at all.^000000"
        )
        |> remember_disobeyed_order()
        |> close()

      true ->
        how_he_has_been(ctx)
    end
  end

  defp remember_disobeyed_order(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :god_megin_1, 0)),
      do: ctx,
      else: set_char_var(ctx, :god_megin_1, 1)
  end

  defp remember_fragment(ctx) do
    if get_char_var(ctx, :god_megin_1, 0) == 1,
      do: set_char_var(ctx, :god_megin_1, 2),
      else: ctx
  end

  defp squad_memories(ctx) do
    ctx
    |> mes("[Zan.Huadoku]")
    |> mes(
      "Yeah, I was a member of the 1st Squad in the 3rd Platoon a long time ago. How did you know that?"
    )
    |> next()
    |> mes("[Zan.Huadoku]")
    |> mes("I miss the guys back in the squad. I wonder how our leader's been doing recently...")
    |> next()
    |> mes(
      "^3355FFYou tell Zan about Rebarev Doug, and about how he is now an instructor for Crusader Boot Camp. He seems to be absorbed in his thoughts of the past.^000000"
    )
  end

  defp how_he_has_been(ctx) do
    ctx
    |> mes("[Zan.Huadoku]")
    |> mes("How am I been doing?")
    |> mes("Well, I work for the Blacksmith Guild, picking out good weapons")
    |> mes("to supply the Crusaders.")
    |> next()
    |> mes("[Zan.Huadoku]")
    |> mes("Sometimes, I get really")
    |> mes(
      "bored with what I'm doing. I keep trying to convince myself that my job's important to future Crusaders, but..."
    )
    |> next()
    |> mes("[Zan.Huadoku]")
    |> mes("You know what?")
    |> mes(
      "A lot of people have been asking me weird questions about me recently. I feel like I'm getting spied on, but maybe I'm just getting paranoid."
    )
    |> close()
  end

  defp ask_about_last_mission(ctx) do
    cond do
      get_char_var(ctx, :god_eremes, 0) == 18 ->
        ctx
        |> mes("[Zan.Huadoku]")
        |> mes("Yeah, on our")
        |> mes("final mission...")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Final...? What the? I know it happened, but for some reason, all I can envision is a complete blank when I try to think about it."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("I...")
        |> mes(
          "I guess I need something to remind me? I know it happened, but... I'm so confused."
        )
        |> next()
        |> mes(
          "^3355FFZan seems to be having a very difficult time recalling that specific memory of his past.^000000"
        )
        |> close()

      get_char_var(ctx, :god_eremes, 0) > 18 and get_char_var(ctx, :god_megin_1, 0) > 0 ->
        ctx
        |> mission_blank()
        |> next()
        |> mes("^3355FFZan.Huadoku seemed to")
        |> mes(
          "have a hard time remembering what had happened in the past. You begin to share with him what you had read in the library about the 1st Squad...^000000"
        )
        |> next()
        |> mes("...")
        |> next()
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes(".....")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Y-yeah that's right! And then three days after we started the mission, we found some kind of..."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Well, I'm not sure what it was. But we found an ^0000FFunknown fragment^000000 that was a sign from God! And then...!"
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("And then...")
        |> mes("Oh. Oh God.")
        |> mes("I can't remember...")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "I can't think about anything further than that. I can't even remember what we found. But I'm sure it was damned important."
        )
        |> next()
        |> mes("^3355FFZan stood still in silence, with a pained look on his face.^000000")
        |> remember_fragment()
        |> close()

      true ->
        ctx
        |> mission_blank()
        |> close()
    end
  end

  defp mission_blank(ctx) do
    ctx
    |> mes("[Zan.Huadoku]")
    |> mes("The last mission...")
    |> next()
    |> mes("[Zan.Huadoku]")
    |> mes("Umm...")
    |> mes("Huh. I don't")
    |> mes("remember anything.")
    |> mes("That's weird. Maybe")
    |> mes("I need a bit of a clue?")
  end

  defp supply_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Zan.Huadoku]")
      |> mes("Good day!")
      |> mes("Do you know the")
      |> mes("importance of supply?")
      |> next()
      |> select(["No.", "Yes!"])

    case choice do
      1 ->
        ctx
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Any military force or party needs their supplies to be replenished if they are to continue battling for a prolonged period of time."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "For instance, let's say your group go on hunting without a healer. In this case, everyone would consume health restoration items, like potions."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Since you can only carry so many items at once, you'll eventually run out of potions."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "But if one of your party members traveled between town and the hunting area, he could supply your party with new healing items."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Supplying your party in this way would let you hunt with less worry. For that duty, the Merchant class would be the best by using their Carts."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "I suppose that's why I'm working here in the Blacksmith Guild. As weapon quartermaster, I'm obligated to provide supplies for the Crusader forces."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "The Blacksmiths in this guild also help me provide high quality weapons for the Crusades as well."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "If you happen to run out of health items while hunting, why don't you ask a Merchant for help?"
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Most likely, they will have some spare items and would be willing to share with you if you ask nicely enough."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("I hope to see you later again! May Odin protect you on your journeys.")
        |> close()

      2 ->
        ctx
        |> mes("[Zan.Huadoku]")
        |> mes("Oh...")
        |> mes("Well then.")
        |> mes("In that case.")
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Let me tell you about some useful knowledge I learned while working with the Blacksmiths."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "A Blacksmith character's forging skills are affected by the DEX and LUK stats. DEX and LUK also affect the item creation skills for Alchemists."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes(
          "Since I've been staying here in the Blacksmith guild, I'm trying to better understand Blacksmiths and develop a deeper appreciation of their work."
        )
        |> next()
        |> mes("[Zan.Huadoku]")
        |> mes("Alright then...")
        |> mes("Take it easy.")
        |> close()

      _ ->
        ctx
    end
  end
end
