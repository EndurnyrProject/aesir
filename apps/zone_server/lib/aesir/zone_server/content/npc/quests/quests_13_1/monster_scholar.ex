defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.MonsterScholar do
  @moduledoc """
  Rumis Block is the expedition's timid monster scholar, studying Ash Vacuum's creatures
  with the player's help.

  ## Behavior

  - Before the expedition storyline advances, only asks about the player's role and apologizes.
  - Introduces himself and starts quest 2147; Nepenthes loot prompts a request for specimen
    tools, advancing to 2148, and the materials are consumed before sending a specimen to Terris
    and advancing to 2149.
  - Requests an escort over the eastern bridge, advancing quest 2153 to 2154 if accepted.
  - Sends the player to investigate the tricorn hat's owner, advancing quest 2156 to 2157.
    A completed hunt prompts a name retry loop and a description, completes 2157, and awards
    100,000 base EXP in renewal or 150,000 in pre-renewal.
  - After the report, consumes a Tendrillion horn for a final conversation and awards
    50,000 base EXP in renewal or 100,000 in pre-renewal.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_camp",
        x: 188,
        y: 254,
        dir: 3,
        sprite: 883,
        name: "Monster Scholar",
        scope: :shared,
        unique_name: "Monster Scholar#ep13"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if get_char_var(ctx, :ep13_ryu, 0) < 100 and get_char_var(ctx, :ep13_start, 0) < 100 do
      ctx
      |> asks_about_your_role()
      |> close()
    else
      at_step(ctx, get_char_var(ctx, :ep13_animal, 0))
    end
  end

  defp at_step(ctx, step) do
    cond do
      step == 0 -> introduces_himself(ctx)
      step == 1 -> refuses_to_leave(ctx)
      step == 2 -> considers_nepenthes_loot(ctx)
      step == 3 -> prepares_the_specimen(ctx)
      step > 3 and step < 10 -> awaits_specimen_delivery(ctx)
      step == 10 -> requests_an_escort(ctx)
      step == 11 -> asks_you_to_wait(ctx)
      step == 12 -> packs_his_stuff(ctx)
      step == 13 -> requests_an_investigation(ctx)
      step == 14 -> checks_the_investigation(ctx)
      step == 15 -> considers_the_horn(ctx)
      step == 100 -> anxious(ctx)
      true -> longs_for_midgard(ctx)
    end
  end

  defp asks_about_your_role(ctx) do
    ctx
    |> mes("[Monster Scholar]")
    |> mes("Who... Who are you?")
    |> mes("Are you from the other")
    |> mes("side of the space gap?")
    |> mes("Say, are you a scholar,")
    |> mes("soldier, or village")
    |> mes("representative?")
    |> next()
    |> mes("[Monster Scholar]")
    |> mes("Oh, I'm sorry.")
    |> mes("You don't have to tell")
    |> mes("me if you don't want to...")
  end

  defp introduces_himself(ctx) do
    {ctx, _} =
      ctx
      |> asks_about_your_role()
      |> next()
      |> mes("[Monster Scholar]")
      |> mes("Please go ahead and do")
      |> mes("what you have to do.")
      |> mes("Oh, me? Don't worry.")
      |> mes("I'm fine by myself.")
      |> next()
      |> select(["Who are you?"])

    explains_his_recruitment(ctx)
  end

  defp explains_his_recruitment(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Monster Scholar]")
      |> mes("I'm Rumis Block, and")
      |> mes("I'm working here on behalf of")
      |> mes("the monsternomics academy")
      |> mes("from the Schwarzwald Republic.")
      |> mes("Botanist Terris Block is")
      |> mes("my older twin brother.")
      |> next()
      |> emotion(:think)
      |> mes("[Rumis Block]")
      |> mes("This place is freezing. Not only")
      |> mes("that, it's deserted and too")
      |> mes("quiet... Everything around us is")
      |> mes("watching and threatening us.")
      |> mes("You know, I didn't want to")
      |> mes("come here...")
      |> next()
      |> select(["How did you get here?"])

    explains_his_brother(ctx)
  end

  defp explains_his_brother(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Rumis Block]")
      |> mes("In fact, none of us")
      |> mes("wanted to come here.")
      |> mes("I mean, no one knows")
      |> mes("what kind of danger lurks")
      |> mes("in this unknown world.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("It was my brother Terris who")
      |> mes("wanted me to come along.")
      |> mes("He was selected first as the")
      |> mes("botanist of the continental")
      |> mes("expedition. He had to drag me")
      |> mes("here 'cuz I didn't want to come.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I guess he didn't want to be")
      |> mes("alone in this world far away")
      |> mes("from civilization. Instead, he")
      |> mes("decided to drag me here and")
      |> mes("force me to join the expedition")
      |> mes("so he doesn't feel lonely!")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("What's with that dirty look?")
      |> mes("Why, do I sound like")
      |> mes("someone blaming someone")
      |> mes("else for the misery in his life?")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I'm telling you, it's the truth.")
      |> mes("There are people that want ")
      |> mes("to escape the expedition by")
      |> mes("getting themselves sick on purpose.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I know it's too late to")
      |> mes("complain now, but...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Every day I pray to God to")
      |> mes("let me go back home safely.")
      |> mes("That's the only thing that")
      |> mes("keeps me going. Everything")
      |> mes("around here is watching me.")
      |> mes("It's suffocating, you know?")
      |> next()
      |> select(["When do you go back?"])

    explains_his_report(ctx)
  end

  defp explains_his_report(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("That's the problem.")
    |> mes("We Specialists are required")
    |> mes("to submit our study reports")
    |> mes("to the expedition's leaders.")
    |> mes("We are here to explore")
    |> mes("and study this world.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I'm sure the management will")
    |> mes("tell me when to go back, but")
    |> mes("I don't expect it to be any time")
    |> mes("soon. It'll be at least after")
    |> mes("I submit my report.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I must tell you,")
    |> mes("I hate this place!")
    |> mes("It gives me the creeps!")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Yes, I'm a monster scholar")
    |> mes("But I've been afraid of creatures even when I was on the Midgard Continent...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("No, but can't you see?")
    |> mes("This place is totally new to me,")
    |> mes("and everything is so unknown...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I may be a monster scholar,")
    |> mes("but I'm afraid...")
    |> mes("Of many things...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("The president of United")
    |> mes("Midgard Corporation has")
    |> mes("asked me to find some")
    |> mes("monsters that are edible.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("But look outside. Look!")
    |> mes("Do you see Mandragoras")
    |> mes("hiding in the icy bushes?")
    |> mes("Those are called ^3131FFNepentheses^000000.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Aren't they quite savage-")
    |> mes("looking and intimidating?")
    |> mes("They look as if they")
    |> mes("want to sting me with")
    |> mes("those sharp thorns!")
    |> mes("Argh...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I'd rather starve to")
    |> mes("death than study")
    |> mes("those dangerous and")
    |> mes("grotesque monsters!")
    |> mes("I'm not going to go")
    |> mes("outside of my tent.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Not ever.")
    |> mes("No one can dare")
    |> mes("venture through")
    |> mes("such a threatening")
    |> mes("environment!")
    |> set_char_var(:ep13_animal, 1)
    |> setquest(2147)
    |> close()
  end

  defp refuses_to_leave(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("I'm not going to go")
    |> mes("outside of my tent.")
    |> mes("Not ever.")
    |> close()
  end

  defp considers_nepenthes_loot(ctx) do
    if count_item(ctx, 6041) > 0 do
      asks_for_encouragement(ctx)
    else
      refuses_to_leave(ctx)
    end
  end

  defp asks_for_encouragement(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Rumis Block]")
      |> mes("I'm scared of this place.")
      |> mes("But I'm not going to ask")
      |> mes("my brother for help")
      |> mes("He hates me.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("If a Nepenthes")
      |> mes("approaches me")
      |> mes("with a smile and")
      |> mes("speaks to me kindly...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("*Sigh* I sound crazy, don't I?")
      |> mes("...This is why I didn't want")
      |> mes("to leave my lab...")
      |> next()
      |> select(["Show loot from Nepentheses.", "Scold him.", "Comfort him."])

    case choice do
      1 -> requests_specimen_tools(ctx)
      2 -> hears_criticism(ctx)
      3 -> refuses_comfort(ctx)
      _ -> ctx
    end
  end

  defp requests_specimen_tools(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, take a look here...")
      |> mes("These Nepentheses aren't")
      |> mes("any more brutal or grotesque")
      |> mes("than the ones back home.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("...What's this?")
      |> mes("Isn't this from")
      |> mes("the Nepentheses?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("That's right!")
      |> mes("I took care of them.")
      |> mes("It was easy, haha!")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I can't believe you really")
      |> mes("took care of them! Tell me,")
      |> mes("who are you really?")
      |> mes("Are you a soldier?")
      |> mes("Captain? Or agent?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("No, I'm just a wandering")
    |> mes("adventurer. I've come here")
    |> mes("to challenge this new place")
    |> mes("and to help people out~")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I... I see.")
    |> mes("I've heard about adventurers")
    |> mes("that have made positive")
    |> mes("impacts on Midgard.")
    |> mes("You're one of them, huh?")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("...That's great!")
    |> mes("I think I've finally found")
    |> mes("a silver lining. God has")
    |> mes("sent me a savior.")
    |> mes("And I think that's you!")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Please, don't say you")
    |> mes("don't want to help me.")
    |> mes("Can't you see that.")
    |> mes("I'm shivering in fear?")
    |> mes("Please help me. Will you?")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("As I told you earlier,")
    |> mes("I have an elder twin")
    |> mes("brother, Terris Block...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("He's a botanist. He's")
    |> mes("extremely strong and")
    |> mes("extroverted, unlike me.")
    |> mes("I think he hates me because")
    |> mes("I represent weakness, and")
    |> mes("he is the complete opposite.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("...Oh, that's not what I wanted")
    |> mes("to say. I wanted to show my")
    |> mes("discovery regarding the")
    |> mes("Nepentheses to my brother.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I need a Nepenthes specimen,")
    |> mes("but I don't have the tools to")
    |> mes("make one, my luggage is still")
    |> mes("on transfer. And it's not like")
    |> mes("I've packed enough tools, so...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("To make my specimen tools,")
    |> mes("I need ^3131FF1 Empty Bottle,")
    |> mes("5 Holy Waters, and")
    |> mes("30 Sticky Mucus^000000.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("You know what I'm.")
    |> mes("asking here, don't you?")
    |> mes("Help me, help me, please.")
    |> delitem(6041, 1)
    |> set_char_var(:ep13_animal, 3)
    |> changequest(2147, 2148)
    |> close()
  end

  defp hears_criticism(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("You call yourself a monster")
    |> mes("scholar, and yet you're afraid")
    |> mes("of practicing your expertise.")
    |> mes("You're nothing but a coward.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I can take your criticism,")
    |> mes("but I can't hide my true feelings.")
    |> close()
  end

  defp refuses_comfort(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Come on, you're a respected")
    |> mes("monster scholar. You'll find")
    |> mes("that the monsters in this world")
    |> mes("aren't that different from the")
    |> mes("ones in Midgard. Why don't")
    |> mes("you see for yourself?")
    |> next()
    |> mes("- Rumis didn't seem -")
    |> mes("- to be convinced. -")
    |> mes("- He shook his head in refusal. -")
    |> close()
  end

  defp prepares_the_specimen(ctx) do
    if count_item(ctx, 713) > 0 and count_item(ctx, 523) > 4 and count_item(ctx, 938) > 29 do
      sends_the_specimen(ctx)
    else
      requests_missing_materials(ctx)
    end
  end

  defp sends_the_specimen(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("Thank you.")
    |> mes("you've brought the materials.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("While you were collecting the")
    |> mes("materials, I've sent out soldiers")
    |> mes("to catch a few Nepentheses.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Nepenthes looks extremely")
    |> mes("similar to Mandragora on")
    |> mes("the Midgard Continent.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Both of them must share the")
    |> mes("same ancestor, but apparently")
    |> mes("Nepenthes has evolved to")
    |> mes("become stronger and more")
    |> mes("aggressive due to this")
    |> mes("barren environment.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("I wonder how the ancestors")
    |> mes("were scattered over")
    |> mes("two different worlds...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Maybe they went through")
    |> mes("the World Tree Yggdrasil?")
    |> mes("Maybe it came along with")
    |> mes("other creatures such as")
    |> mes("Satan Morocc and traversed")
    |> mes("through time and space.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("The characteristics of this species are...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Oh, where are my manners?")
    |> mes("I'm sorry if I bored you by")
    |> mes("talking academic nonsense...")
    |> mes("Let's talk about something")
    |> mes("else, shall we?")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Do you think...")
    |> mes("My brother will be happy to")
    |> mes("see this Nepenthes specimen?")
    |> mes("You know, Nepenthes is a")
    |> mes("plant monster, and that's")
    |> mes("my brother's specialty.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Please deliver this specimen to Terris Block")
    |> mes("He's near the expedition camp.")
    |> mes("No, you won't have to sit through my brother's reaction... If it's bad.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("- You have received a-")
    |> mes("- Nepenthes Specimen -")
    |> mes("- from Rumis Block. -")
    |> delitem(713, 1)
    |> delitem(523, 5)
    |> delitem(938, 30)
    |> set_char_var(:ep13_animal, 4)
    |> changequest(2148, 2149)
    |> close()
  end

  defp requests_missing_materials(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("To make my specimen tools,")
    |> mes("I need ^3131FF1 Empty Bottle, 5 Holy Waters, and 30 Sticky Mucus^000000.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("You know what I'm asking here, don't you? Thank you in advance.")
    |> close()
  end

  defp awaits_specimen_delivery(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("Did you deliver the Nepenthes Specimen to my brother Terris?")
    |> mes("He's at the east of the camp.")
    |> close()
  end

  defp requests_an_escort(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Rumis Block]")
      |> mes("...Welcome back.")
      |> mes("Oh, you don't have to tell me what my brother said,")
      |> mes(
        "because someone from his side already came by. His report really impressed management, huh?"
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Yes, that's my brother......")
      |> next()
      |> mes("[Rumis Block]")
      |> mes(
        "...Anyways, one of the soldiers that captured Nepentheses for me has given me some interesting information."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Over the eastern bridge, he found a new type of monster.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes(
        "According to his description, the monster is suspected to be a member of the long-haired Cat family. I'd like to see it with my own eyes, but..."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("As you know, I'm not yet ready to face any types of monsters in this world...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Can you escort me while I'm studying that species?")
      |> mes("Please, I'm begging you!")
      |> next()
      |> select(["Okay.", "No."])

    case choice do
      1 -> accepts_the_escort(ctx)
      2 -> cries(ctx)
      _ -> ctx
    end
  end

  defp accepts_the_escort(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("Wow, thanks!")
    |> mes("Then I'd better pack my stuff right away...")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("It won't take long. Can you please go wait for me over the eastern bridge?")
    |> mes("Don't... Don't go too far from the bridge!")
    |> set_char_var(:ep13_animal, 11)
    |> changequest(2153, 2154)
    |> close()
  end

  defp cries(ctx) do
    ctx
    |> emotion(:cry)
    |> mes("[Rumis Block]")
    |> mes("Oh.........")
    |> close()
  end

  defp asks_you_to_wait(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes(
      "I'll pack my stuff and follow you. Can you please go wait for me over the rightward bridge?"
    )
    |> mes("Don't... Don't go too far from the bridge!")
    |> close()
  end

  defp packs_his_stuff(ctx) do
    ctx
    |> mes("- Rumis is hurriedly packing his stuff. -")
    |> close()
  end

  defp requests_an_investigation(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("......")
    |> next()
    |> mes("[Rumis Block]")
    |> mes("Apparently, an extremely intelligent creature inhabits Ash Vaccum.")
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "An explorer went over the rightward bridge to find some wood. In the darkness, something really big rushed at him from far away."
    )
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "When he came back to his senses, there was nothing but a tricorn hat left on the ground."
    )
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "The tricorn is woven in a way that was never introduced to Midgard, and its materials are also unidentifiable."
    )
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "Does it mean another race of human resides here? Would they be fairies or something else?"
    )
    |> next()
    |> mes("[Rumis Block]")
    |> mes("What if they've detected us and tried to drive us away... Wah!")
    |> next()
    |> mes("[Rumis Block]")
    |> mes(
      "Even thinking of them send chills down on my spine! Can you please go check what kind of races reside at the end of the land over the rightward bridge?"
    )
    |> mes("I want to know if they're friendly or hostile to us.")
    |> set_char_var(:ep13_animal, 14)
    |> changequest(2156, 2157)
    |> close()
  end

  defp checks_the_investigation(ctx) do
    if checkquest(ctx, 2157, :hunting) == 2 do
      hears_the_report(ctx)
    else
      requests_the_report(ctx)
    end
  end

  defp hears_the_report(ctx) do
    ctx =
      ctx
      |> mes("[Rumis Block]")
      |> mes("Welcome back. Did you find out about them?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, let's see...")
      |> next()
      |> asks_for_the_hat_owner()

    {ctx, description} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The size of Tatacho is about...")
      |> input(:string)

    ctx =
      ctx
      |> mes("^3131FF#{description}^000000, I guess...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "Tatachos are usually sitting on the ground, but they roll around if their body temperature goes down too low because of the cold weather."
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "About that tricorn hat, I've concluded, based on my opinion about their appearance and their movement patterns, that it is not active or productive at all:"
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("They are not intelligent enough to produce a sophisticated hat like that.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("......")
      |> mes(
        "You now sound like me... I guess I've stained you with my academic manner of speech. Oh, I'm not saying it is bad, but..."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes(
        "Anyways, according to your conclusion, the hat must have been given to them by someone else, or they could have picked it up after another creature dropped it."
      )
      |> mes("Thank you for such valuable information.")
      |> mes("It's enough to write a report.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes(
        "I should make a brief report and then submit it to management. Hopefully, a new monster scholar after me will do a better job in actually studying them."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes(
        "There are many cold places in my country, the Schwarzwald Republic, but none are as cold as this place. This weather is freezing my senses, dulling my passion toward my studies."
      )
      |> mes(
        "I shall go back home faster than anyone else in this camp. I'm tired of this world..."
      )
      |> next()
      |> mes("[Rumis Block]")

    ctx =
      ctx
      |> mes(
        "...#{char_name(ctx, 0)}, I thank you so much for helping me despite my self-centered behavior."
      )
      |> mes("I really appreciate it")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I'll repay your favor as soon as I go back home.")
      |> mes("I hope you'll make yourself known in Ash Vacuum with your great accomplishments.")
      |> set_char_var(:ep13_animal, 15)
      |> completequest(2157)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)), do: 100_000, else: 150_000),
      0
    )
    |> close()
  end

  defp asks_for_the_hat_owner(ctx) do
    {ctx, name} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("The owner of the tricorn hat")
      |> mes("is a monster called...")
      |> input(:string)

    if Rathena.truthy?(Rathena.compare(name, "Tatacho")) do
      ctx
      |> mes("^FF0000Tatacho^000000")
      |> next()
    else
      ctx = next(ctx)
      ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

      ctx
      |> mes("#{name}...? I don't think that was the name...")
      |> next()
      |> asks_for_the_hat_owner()
    end
  end

  defp requests_the_report(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes(
      "Can you please go check what kind of races reside at the end of the land over the rightward bridge? I want to know if they're friendly or hostile to us."
    )
    |> close()
  end

  defp considers_the_horn(ctx) do
    if count_item(ctx, 6033) > 0 do
      examines_the_horn(ctx)
    else
      awaits_orders_to_return(ctx)
    end
  end

  defp examines_the_horn(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Mr. Rumis! Take a look at this!")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("...Oh, hello.")
      |> mes(
        "I'm extremely frustrated. I feel helpless because I wasn't able to go back home last time..."
      )
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I've found this horn from a monster in the Splendide Area.")
      |> mes("That monster was very mysterious, and its body was covered with grass.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Ho... Covered with grass?")
      |> mes("...I know you're excited, but that doesn't sound interesting to me. Sorry.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Let me take a look at the horn.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Hmm.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Uhmm...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Huh...?")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("...This is remarkable.")
      |> mes(
        "...This horn looks very similar to that of the Hillsrions that inhabit the Manuk area."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I wonder if they're related,")
      |> mes("or if this is an evolved Hillsrion.")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ah, and there's the possibility of mutation caused by the environment.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("...What do you mean?")
      |> mes("Are you saying the monster has been mutated by environmental causes?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well, that's possible, isn't it? Haha!")
      |> next()
      |> mes(
        "- You told Rumis what you've heard from Botanist Terris: some plants are already showing signs of mutation. -"
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Oh, that's interesting.")
      |> mes(
        "If such a device really exists, it's possible to cause abnormal growth to monsters by injecting them with special energy."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("By the way, who came up with the idea of that device?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I have no idea. Haha!")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I see...")
      |> mes(
        "Mutants caused by a man-made device... Then there might be more mutated creatures in addition to Tendrillion."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("...Now I'm very curious.")
      |> mes(
        "But... I want to go back home... It's no use studying them if the management will order me to return."
      )
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I guess my brother really likes this place.")
      |> mes("I mean, he's working so hard to figure things out...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("Well, not everyone can live the same life.")
      |> mes("I just hope he'll have a better understanding about me...")
      |> next()
      |> mes("[Rumis Block]")
      |> mes("I don't know if people in Midgard will welcome me back.")
      |> mes("Thanks to you, I at least have a few interesting stories to tell them.")
      |> next()
      |> mes("[Rumis Block]")
      |> mes(
        "If you're going to stick around here longer, please help my brother with his study."
      )
      |> mes("I might want to come back later once this area is fully explored and developed...")
      |> next()
      |> mes(
        "- With a shy smile on the face, Rumis Block asked you to shake hands, and then turned around hurriedly. -"
      )
      |> next()
      |> mes("- You really hope that Rumis will be able to go back home. -")
      |> set_char_var(:ep13_animal, 100)
      |> delitem(6033, 1)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)), do: 50_000, else: 100_000),
      0
    )
    |> close()
  end

  defp awaits_orders_to_return(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes(
      "...I submitted the report to the management, but they have not yet ordered me to go back home..."
    )
    |> mes("...*Sigh* I guess nothing's as easy as I'd hoped.")
    |> close()
  end

  defp anxious(ctx) do
    ctx
    |> mes("- Rumis seems anxious and scatterbrained. -")
    |> close()
  end

  defp longs_for_midgard(ctx) do
    ctx
    |> mes("[Rumis Block]")
    |> mes("When can I go back to Midgard...? *Sigh*")
    |> close()
  end
end
