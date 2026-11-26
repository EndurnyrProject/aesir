defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.ManStuckInIce do
  @moduledoc """
  Maheo asks adventurers to free him from his own magical ice.

  ## Behavior

  - Sends the adventurer to his master for a way to break the ice.
  - Uses the Wind Hammer to escape and polishes the quest necklace.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ice_dun02",
        x: 120,
        y: 105,
        dir: 3,
        sprite: 924,
        name: "Man Stuck in Ice",
        scope: :shared,
        unique_name: "Man Stuck in Ice#cave",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTouchNPC", ctx) do
    ev_ontouchnpc(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnMyMobDead", ctx) do
    ev_onmymobdead(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{908, 200}]) == 0 do
      too_heavy(ctx)
    else
      discuss_quest(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp too_heavy(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp discuss_quest(ctx) do
    case get_char_var(ctx, :ice_necklace_q, 0) do
      1 -> meet_maheo(ctx)
      quest when quest in [2, 3] -> ask_master(ctx)
      4 -> bring_hammer(ctx)
      _ -> ev_ontouch(ctx)
    end
  end

  defp meet_maheo(ctx) do
    ctx =
      ctx
      |> cutin("ra_magic3", 2)
      |> emotion(:huk)
      |> mes("[Man Stuck in Ice]")
      |> mes("H-hello?")
      |> mes("Hey! Hey, you!")
      |> mes("Help me break this")
      |> mes("ice! I need to get")
      |> mes("out of here!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("How did you get")
      |> mes("stuck in there?")
      |> next()
      |> mes("[Man Stuck in Ice]")
      |> mes("I'll explain everything")
      |> mes("later! Just... Just get")
      |> mes("this ice off of me!.")
      |> next()

    ctx =
      if getskilllv(ctx, 19) > 0 do
        ctx
        |> specialeffect(:fireball)
        |> mes("^3355FFYou cast Fire Bolt at")
        |> mes("the ice..^000000")
      else
        ctx
        |> specialeffect(:hit2)
        |> mes("^3355FFYou hammer at the")
        |> mes("ice with all your might.^000000")
      end

    ctx = next(ctx)

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("......")
      |> mes("........")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I can't...")
      |> mes("I can't even scratch it")
      |> mes("Do you have any ideas?")
      |> next()
      |> emotion(:cry)
      |> mes("[Man Stuck in Ice]")
      |> mes("This is so humiliating...")
      |> mes("Me, the greatest mage")
      |> mes("of our age, Maheo, stuck")
      |> mes("in this pillar of ice.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wait...")
      |> mes("You're Maheo?")
      |> next()
      |> cutin("ra_magic1", 2)
      |> emotion(:kik)
      |> mes("[Maheo]")
      |> mes("It's true. You're speaking to")
      |> mes("Maheo, the greatest mage,")
      |> mes("and master of arcane spells.")
      |> mes("I know magic that even High")
      |> mes("Wizards can never hope to")
      |> mes("learn in their lifetimes!")
      |> next()
      |> cutin("ra_magic4", 2)
      |> mes("[Maheo]")
      |> mes("Despite my greatness,")
      |> mes("I'm a humble man. See?")
      |> mes("That's why I always wear")
      |> mes("this Mage uniform...")
      |> mes("To remind myself of")
      |> mes("the value of humility.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("So how did you get")
      |> mes("stuck in all of this ice?")
      |> next()
      |> cutin("ra_magic3", 2)
      |> mes("[Maheo]")
      |> mes("Actually, this happened")
      |> mes("because I was too humble")
      |> mes("You see, I underestimated")
      |> mes("myself, and the devastating")
      |> mes("force of my own magic.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Huh?")
      |> next()
      |> mes("[Maheo]")
      |> mes("Yes, this wouldn't have")
      |> mes("happened if I wasn't so")
      |> mes("humble... Humble and kind.")
      |> mes("It all started when I thought")
      |> mes("of this cave and how people")
      |> mes("sometimes come here to get ice.")
      |> next()
      |> mes("[Maheo]")
      |> mes("I then decided that")
      |> mes("I would exterminate these")
      |> mes("evil monsters for the good")
      |> mes("of the people! The citizens")
      |> mes("would feel protected, and")
      |> mes("I'd be recognized as a hero!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Okay... I suppose")
      |> mes("that sounds normal")
      |> mes("enough. Go on.")
      |> next()
      |> mes("[Maheo]")
      |> mes("I valiantly battled")
      |> mes("the Snowiers. They were")
      |> mes("no match for my magic!")
      |> mes("And so, I decided to just")
      |> mes("destroy all of them with")
      |> mes("one cast of a magic spell.")
      |> next()
      |> mes("[Maheo]")
      |> mes("You know Meteor Storm?")
      |> mes("I know another spell like")
      |> mes("that... But it's two hundred")
      |> mes("times more powerful! Yes...")
      |> mes("It has the power of a million")
      |> mes("exploding suns! But then...")
      |> next()
      |> emotion(:cry)
      |> mes("[Maheo]")
      |> mes("It was too powerful!")
      |> mes("There were tremors, and")
      |> mes("flying shards of ice, and")
      |> mes("all the flame caused my")
      |> mes("clothes to catch on fire!")
      |> next()

    ctx = emotion(ctx, :spark, playerattached(ctx))

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You...")
      |> mes("you set fire")
      |> mes("to your clothes")
      |> next()
      |> cutin("ra_magic2", 2)
      |> mes("[Maheo]")
      |> mes("Yes, but not to worry.")
      |> mes("I quickly extinguished")
      |> mes("those flames with my")
      |> mes("powerful Frost Diver spell!")
      |> next()
      |> cutin("ra_magic3", 2)
      |> mes("[Maheo]")
      |> mes("In hindsight...")
      |> mes("That may have")
      |> mes("been a mistake...")
      |> next()
      |> cutin("ra_magic3", 2)
      |> mes("[Maheo]")
      |> mes("Enough about myself.")
      |> mes("What noble pursuit brings")
      |> mes("you to this place, adventurer?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I heard that you can")
      |> mes("polish the gems on this")
      |> mes("necklace with your magic,")
      |> mes("so I came here to find you.")
      |> next()
      |> mes("[Maheo]")
      |> mes("Verily, I can shine")
      |> mes("those gems so that they")
      |> mes("shine as brightly as a")
      |> mes("million exploding suns!")
      |> next()
      |> mes("[Maheo]")
      |> mes("That is, as soon")
      |> mes("as I can get out")
      |> mes("of this ice. Hmm...")
      |> mes("But I doubt normal")
      |> mes("magic will be able")
      |> mes("to melt all of this.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Then how are we")
    |> mes("supposed to get")
    |> mes("you out of there?")
    |> next()
    |> mes("[Maheo]")
    |> mes("Fear not. I'm sure")
    |> mes("that my master will know")
    |> mes("of a way to free me from")
    |> mes("this prison of ice. He can")
    |> mes("be found near Freya's Spring:")
    |> mes("beseech him on my behalf!")
    |> set_char_var(:ice_necklace_q, 2)
    |> changequest(2109, 2110)
    |> close2()
    |> cutin("", 255)
  end

  defp ask_master(ctx) do
    ctx
    |> mes("[Maheo]")
    |> mes("My master may not have")
    |> mes("my sheer talent, but he")
    |> mes("is very knowledgable in")
    |> mes("the ways of magic. Please...")
    |> mes("Ask him for help. He should")
    |> mes("be reading near Freya's Spring.")
    |> close()
  end

  defp bring_hammer(ctx) do
    cond do
      count_item(ctx, 7569) <= 0 -> ask_master(ctx)
      count_item(ctx, 7572) <= 0 -> missing_necklace(ctx)
      true -> free_maheo(ctx)
    end
  end

  defp missing_necklace(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, shoot! I left the necklace in the city! I will be right back!")
    |> next()
    |> mes("[Maheo]")
    |> mes("Hey, hey! Can't you just release me first?")
    |> emotion(:cry)
    |> close()
  end

  defp free_maheo(ctx) do
    ctx =
      ctx
      |> mes("[Maheo]")
      |> mes("Oh, you're back!")
      |> mes("So did my master have")
      |> mes("any ideas on breaking")
      |> mes("this cold prison of ice?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Well, he made this")
      |> mes("magic hammer which is")
      |> mes("supposed to be able to")
      |> mes("break this magic ice.")
      |> next()
      |> mes("[Maheo]")
      |> mes("Of course!")
      |> mes("Why didn't I think of")
      |> mes("that? Great, now get")
      |> mes("me out of here please!")
      |> next()
      |> mes("^3355FFYou tightly gripped")
      |> mes("the Wind Hammer, and")
      |> mes("swung it down at the ice")
      |> mes("with all of your strength.^000000")
      |> next()
      |> specialeffect(:teihit3)
      |> specialeffect(:freeze)
      |> specialeffect(:icecrash)
      |> mes("^3355FF*Pzzzzz*")
      |> mes("*CRASH!*^000000")
      |> next()
      |> set_npc_display(npc: "Man Stuck in Ice#cave", sprite: 937)
      |> emotion(:surprise)
      |> mes("[Maheo]")
      |> mes("Finally...!")
      |> mes("After all of this")
      |> mes("time! I'm free!")
      |> next()
      |> specialeffect(:beginspell4)
      |> mes("[Maheo]")
      |> mes("Now, all of the monsters")
      |> mes("in this cave will taste the")
      |> mes("wrath of the greatest mage in")
      |> mes("the world! I'll have my revenge,")
      |> mes("and give those beasts double")
      |> mes("the pain that they gave me!")
      |> next()
      |> summon_mob(
        mob_id: 1775,
        map: "ice_dun02",
        at: {108, 109},
        name: "Snowier",
        event: "Man Stuck in Ice#cave::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1775,
        map: "ice_dun02",
        at: {114, 112},
        name: "Snowier",
        event: "Man Stuck in Ice#cave::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1775,
        map: "ice_dun02",
        at: {126, 105},
        name: "Snowier",
        event: "Man Stuck in Ice#cave::OnMyMobDead"
      )
      |> summon_mob(
        mob_id: 1775,
        map: "ice_dun02",
        at: {121, 99},
        name: "Snowier",
        event: "Man Stuck in Ice#cave::OnMyMobDead"
      )
      |> specialeffect(:lord)
      |> killmonster("ice_dun02", "Man Stuck in Ice#cave::OnMyMobDead")
      |> mes("[Maheo]")
      |> mes("Muhahahahahahahaha!")
      |> next()
      |> mes("[Maheo]")
      |> mes("Er, but first, I need to")
      |> mes("use my magic to clean")
      |> mes("that necklace of yours.")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Here...")
    |> next()
    |> mes("[Maheo]")
    |> mes("Oh! This was made by")
    |> mes("the Dwarves, wasn't it?")
    |> mes("It looks like they've made")
    |> mes("yet another masterpiece.")
    |> mes("Shame that this is so")
    |> mes("tarnished, though.")
    |> next()
    |> mes("[Maheo]")
    |> mes("Let's see, now...")
    |> next()
    |> specialeffect(:frostweapon)
    |> mes("^3355FF*Ting*^000000")
    |> next()
    |> mes("[Maheo]")
    |> mes("Well, I suppose this")
    |> mes("is where we part ways.")
    |> mes("Here, take this as a gift...")
    |> mes("And please don't mention")
    |> mes("the fact that I trapped myself")
    |> mes("in ice to anyone else, okay?")
    |> set_char_var(:ice_necklace_q, 5)
    |> changequest(2112, 2113)
    |> delitem(7569, 1)
    |> delitem(7572, 1)
    |> give_item(7573, 1)
    |> give_item(7574, 4)
    |> close2()
    |> cutin("", 255)
    |> set_npc_display(npc: "Man Stuck in Ice#cave", sprite: 924)
  end

  def ev_ontouch(ctx), do: ctx

  def ev_ontouchnpc(ctx) do
    ctx |> emotion(:fret) |> emotion(:kik, Todo.call!(:getattachedrid, []))
  end

  def ev_onmymobdead(ctx), do: ctx
end
