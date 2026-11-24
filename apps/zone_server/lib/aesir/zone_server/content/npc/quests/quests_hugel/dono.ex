defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Dono do
  @moduledoc """
  Dono prepares medicine for Morriphen and Siria.

  ## Behavior

  - Requests ingredients and sends the player to Makkie for the final component.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "lighthalzen", x: 88, y: 79, dir: 7, sprite: 85, name: "Dono", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @detrimindexta 971
  @coal 1003
  @unripe_apple 619
  @red_herb 507
  @yellow_herb 508
  @white_herb 511
  @green_herb 509
  @blue_herb 510
  @brigan 7053
  @cyfar 7054
  @shell 935

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_bio, 0) do
      2 ->
        request_ingredients(ctx)

      1 ->
        ctx
        |> mes("[Dono]")
        |> mes("Store's closed.")
        |> mes("Get outta here, and")
        |> mes("come back later to")
        |> mes("buy something, got it?")
        |> close()

      3 ->
        prepare_medicine(ctx)

      4 ->
        ctx
        |> mes("[Dono]")
        |> mes("Hey, you should be able")
        |> mes("to find Makkie inside the")
        |> mes("pub across the street. Hurry")
        |> mes("up and bring me some Red")
        |> mes("Plant Stem Power from him. Come on, Morriphen's in trouble!")
        |> close()

      5 ->
        finish_medicine(ctx)

      6 ->
        ctx
        |> mes("[Dono]")
        |> mes("Whoa, what are you still")
        |> mes("doing here?! Hurry and")
        |> mes("get that medicine over to")
        |> mes("Morriphen, or he'll die soon!")
        |> close()

      v when v in [7, 8, 9] ->
        ctx
        |> mes("[Dono]")
        |> mes("Oh, hey, do you know")
        |> mes("how Morriphen's doing?")
        |> mes("Tell that jerk to come")
        |> mes("by more often. He's the")
        |> mes("only guy that can offer me")
        |> mes("a decent challenge at chess...")
        |> close()

      _ ->
        ctx
        |> mes("[Dono]")
        |> mes("Hey, store's closed!")
        |> mes("I'll open when I feel")
        |> mes("like it, so until then,")
        |> mes("I'm not selling you")
        |> mes("anything! Now, scram!")
        |> close()
    end
  end

  defp request_ingredients(ctx) do
    ctx
    |> mes("[Dono]")
    |> mes("What do you want?")
    |> mes("Spit it out, I don't")
    |> mes("have all day.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Excuse me, but")
    |> mes("I'm looking for a")
    |> mes("man named Dono.")
    |> next()
    |> mes("[Dono]")
    |> mes("Yeah, that's me,")
    |> mes("but who the heck")
    |> mes("are you, anyway?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh, I'm just here")
    |> mes("to get some medicine")
    |> mes("for Morriphen. Um, his")
    |> mes("wife Siria said that")
    |> mes("you would have it?")
    |> next()
    |> mes("[Dono]")
    |> mes("Wife? Hurmph! Not likely.")
    |> mes("Alright, I see. He must've")
    |> mes("run out of medicine. Jesus,")
    |> mes("they're both still alive? It's")
    |> mes("a miracle that they've both")
    |> mes("lasted this long. Eh, oh well.")
    |> next()
    |> mes("[Dono]")
    |> mes("It's his own fault his body")
    |> mes("got messed up. Now let's")
    |> mes("see how much medicine we")
    |> mes("got here... Hmm... Dang. This")
    |> mes("isn't good. Hey, you said you")
    |> mes("work for Morriphen, that right?")
    |> next()
    |> mes("[Dono]")
    |> mes("I have the medicine, but it's")
    |> mes("not enough for one person, much")
    |> mes("less the two of them. I need you to help me make some more.")
    |> mes("Now, listen carefully, these")
    |> mes("are the ingredients I need...")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Wait, wait, I thought I was")
    |> mes("only getting medicine for")
    |> mes("Morriphen. Are you saying")
    |> mes("that his wife Siria needs")
    |> mes("the medicine too?")
    |> next()
    |> mes("[Dono]")
    |> mes("Why do you keep calling")
    |> mes("Siria his wife? Yeah, she's")
    |> mes("sick too. If you met her, you'd")
    |> mes("see for yourself, right? Well,")
    |> mes("I'm getting pretty worried about them, so you better hurry this up.")
    |> next()
    |> mes("[Dono]")
    |> mes("Go get")
    |> mes("^3355FF5 Coal^000000,")
    |> mes("^3355FF5 Brigan^000000,")
    |> mes("^3355FF5 Cyfar^000000,")
    |> mes("^3355FF1 Unripe Apple^000000,")
    |> mes("^3355FF3 Detrimindexta^000000...")
    |> next()
    |> mes("[Dono]")
    |> mes("...^3355FF20 Shells^000000,")
    |> mes("^3355FF1 Red Herb^000000,")
    |> mes("^3355FF1 Blue Herb^000000,")
    |> mes("^3355FF1 Green Herb^000000,")
    |> mes("^3355FF1 White Herb^000000, and")
    |> mes("^3355FF1 Yellow Herb^000000.")
    |> next()
    |> mes("[Dono]")
    |> mes("I know this is sudden,")
    |> mes("I know I'm pushing you")
    |> mes("hard, but I've got no choice.")
    |> mes("If you don't hurry, then")
    |> mes("those two will die, simple as that. I'll wait for you here.")
    |> set_char_var(:hg_bio, 3)
    |> changequest(11010, 11011)
    |> close()
  end

  defp prepare_medicine(ctx) do
    if count_item(ctx, @detrimindexta) > 2 and count_item(ctx, @coal) > 4 and
         Rathena.truthy?(count_item(ctx, @unripe_apple)) and
         Rathena.truthy?(count_item(ctx, @red_herb)) and
         Rathena.truthy?(count_item(ctx, @yellow_herb)) and
         Rathena.truthy?(count_item(ctx, @white_herb)) and
         Rathena.truthy?(count_item(ctx, @green_herb)) and
         Rathena.truthy?(count_item(ctx, @blue_herb)) and
         count_item(ctx, @brigan) > 4 and count_item(ctx, @cyfar) > 4 and
         count_item(ctx, @shell) > 19 do
      ctx
      |> delitem(@detrimindexta, 3)
      |> delitem(@coal, 5)
      |> delitem(@unripe_apple, 1)
      |> delitem(@red_herb, 1)
      |> delitem(@yellow_herb, 1)
      |> delitem(@white_herb, 1)
      |> delitem(@green_herb, 1)
      |> delitem(@blue_herb, 1)
      |> delitem(@brigan, 5)
      |> delitem(@cyfar, 5)
      |> delitem(@shell, 20)
      |> set_char_var(:hg_bio, 4)
      |> changequest(11011, 11012)
      |> mes("[Dono]")
      |> mes("Good, good, you've brought")
      |> mes("everything I've asked. Give")
      |> mes("me a moment to process these")
      |> mes("materials and make the medicine. ^333333*Sigh*^000000 I used to have assistants")
      |> mes("do this kind of work for me...")
      |> next()
      |> mes("[Dono]")
      |> mes("Back when I used to work for")
      |> mes("the Rekenber Corporation, I was")
      |> mes("a department head! Oh well, it")
      |> mes("can't be helped now. Ah, it's")
      |> mes("done. Now, let me test this")
      |> mes("out before I give it to you.")
      |> next()
      |> mes("^3355FFDono reveals that he has")
      |> mes("grinded the materials into")
      |> mes("a fine powder. He sprinkles")
      |> mes("a small amount into a glass")
      |> mes("of water, and the liquid turns")
      |> mes("blue after he mixes it.^000000")
      |> next()
      |> mes("[Dono]")
      |> mes("Damn! I used the right")
      |> mes("proportions! Why isn't it")
      |> mes("working?! Morriphen, I hate")
      |> mes("you! Grrr...! Hey, kid, I need")
      |> mes("you to help me again!")
      |> next()
      |> mes("[Dono]")
      |> mes("Go to the Lighthalzen")
      |> mes("Makkie. Tell him I sent you")
      |> mes("to get some Red Plant Stem Powder for Morriphen's medicine.")
      |> next()
      |> mes("[Dono]")
      |> mes("Look, I know it's a pain,")
      |> mes("but hurry and get it for me")
      |> mes("as fast as you can. I need")
      |> mes("that stuff to correct some")
      |> mes("chemical impurities in this")
      |> mes("medicine. Go, go now!")
      |> close()
    else
      ctx
      |> mes("[Dono]")
      |> mes("If you don't hurry and")
      |> mes("gather the materials for")
      |> mes("the medicine, Morriphen")
      |> mes("and Siria are gonna be")
      |> mes("in big trouble. Listen")
      |> mes("up, this is what I need...")
      |> next()
      |> mes("[Dono]")
      |> mes("Go get")
      |> mes("^3355FF5 Coal^000000,")
      |> mes("^3355FF5 Brigan^000000,")
      |> mes("^3355FF5 Cyfar^000000,")
      |> mes("^3355FF1 Unripe Apple^000000,")
      |> mes("^3355FF3 Detrimindexta^000000...")
      |> next()
      |> mes("[Dono]")
      |> mes("...^3355FF20 Shells^000000,")
      |> mes("^3355FF1 Red Herb^000000,")
      |> mes("^3355FF1 Blue Herb^000000,")
      |> mes("^3355FF1 Green Herb^000000,")
      |> mes("^3355FF1 White Herb^000000, and")
      |> mes("^3355FF1 Yellow Herb^000000.")
      |> close()
    end
  end

  defp finish_medicine(ctx) do
    ctx
    |> mes("[Dono]")
    |> mes("Where is it?!")
    |> mes("Okay, good, you brought")
    |> mes("it. Huh. This isn't a lot of")
    |> mes("Red Plant Stem Powder,")
    |> mes("but this should do. Alright,")
    |> mes("let's see if it works now.")
    |> next()
    |> mes("^3355FFDono sprinkles the")
    |> mes("red powder into the")
    |> mes("glass of blue water.")
    |> mes("The liquid immediately")
    |> mes("becomes red.^000000")
    |> next()
    |> mes("[Dono]")
    |> mes("Great, the medicine is")
    |> mes("finally ready! By the way,")
    |> mes("how is Makkie doing? I know")
    |> mes("he's got a big mouth, so did")
    |> mes("he tell you anything stupid?")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Er, he did mention that")
    |> mes("both you and Morriphen used")
    |> mes("to work together for Rekenber.")
    |> next()
    |> mes("[Dono]")
    |> mes("He did, huh? Yeah, that's")
    |> mes("true. Morriphen and I used")
    |> mes("to be researchers... those")
    |> mes("were the best damn days")
    |> mes("of my life. Afterwards, it")
    |> mes("pretty much went downhill.")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What do you mean?")
    |> mes("Did something happen?")
    |> next()
    |> mes("[Dono]")
    |> mes("Oh, hell yeah. That dumb")
    |> mes("romanticist Morriphen caused")
    |> mes("huge trouble for the company.")
    |> mes("It's pretty much his fault that")
    |> mes("I got fired from Rekenber.")
    |> mes("Grr! Let's not talk about it!")
    |> next()
    |> mes("[Dono]")
    |> mes("Just thinking about what")
    |> mes("happened makes me so angry!")
    |> mes("I swear, I'd kill him if he wasn't my best friend! Ah, speaking")
    |> mes("of which, you better get this")
    |> mes("medicine to Morriphen now!")
    |> next()
    |> mes("[Dono]")
    |> mes("Right, and don't")
    |> mes("mention anything")
    |> mes("I said to him, willya?")
    |> mes("If he gets upset, and")
    |> mes("stresses himself to death,")
    |> mes("my work will be for nothing.")
    |> set_char_var(:hg_bio, 6)
    |> changequest(11013, 11014)
    |> close()
  end
end
