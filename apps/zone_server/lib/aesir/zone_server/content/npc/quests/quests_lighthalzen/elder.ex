defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Elder do
  @moduledoc """
  An elder helps the player understand and lift a spirit’s curse.

  ## Behavior

  - Guides the player through the curse and purifies the pendant.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 346,
        y: 263,
        dir: 3,
        sprite: 846,
        name: "Elder",
        scope: :shared,
        unique_name: "Elder#lhz"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, 7345) > 0 do
      discuss_curse(ctx)
    else
      discuss_city(ctx)
    end
  end

  defp discuss_curse(ctx) do
    curse = get_char_var(ctx, :lhz_curse, 0)

    cond do
      curse == 1 and get_char_var(ctx, :lhz_spi01, 0) == 1 and
        get_char_var(ctx, :lhz_spi02, 0) == 1 and get_char_var(ctx, :lhz_spi03, 0) == 1 and
          get_char_var(ctx, :lhz_spi04, 0) == 1 ->
        introduce_spirits(ctx)

      curse > 5 and curse < 17 ->
        await_clues(ctx)

      curse == 17 ->
        examine_pendant(ctx)

      curse == 18 ->
        purify_pendant(ctx)

      true ->
        discuss_city(ctx)
    end
  end

  defp introduce_spirits(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Elder]")
      |> mes("No wonder you look")
      |> mes("so weary. Come, let")
      |> mes("me help relieve you")
      |> mes("of the burden that")
      |> mes("you are carrying.")
      |> next()
      |> select(["Um, burden...?", "Crazy old woman!"])

    case choice do
      1 ->
        {ctx, _} =
          ctx
          |> mes("[Elder]")
          |> mes("Ah yes, they may not")
          |> mes("be apparent to you, but")
          |> mes("my eyes can clearly see")
          |> mes("them. Yes. You're being")
          |> mes("followed by those things.")
          |> next()
          |> select(["Things?"])

        {ctx, _} =
          ctx
          |> mes("[Elder]")
          |> mes("Yes. The best way I can")
          |> mes("describe them is as evil")
          |> mes("thoughts left in the world")
          |> mes("when someone dies in")
          |> mes("such a way that his grudge")
          |> mes("survives to menace the living.")
          |> next()
          |> mes("[Elder]")
          |> mes("Sometimes, these lingering")
          |> mes("thoughts are created when")
          |> mes("someone is broken hearted")
          |> mes("or clings to this plane for the")
          |> mes("sake of a loved one. Yes, those")
          |> mes("thoughts are following you.")
          |> next()
          |> mes("[Elder]")
          |> mes("I don't know why they")
          |> mes("are following you, but I'm")
          |> mes("certain they're there. Have")
          |> mes("you been experiencing chills")
          |> mes("down your spine, cold sweats,")
          |> mes("maybe even hearing voices?")
          |> soundeffect("loli_ruri_stand.wav", 0)
          |> sc_start(:sc_curse, 5000, 0)
          |> next()
          |> select(["Yes! How do I get rid of them?"])

        {ctx, _} =
          ctx
          |> mes("[Elder]")
          |> mes("Well, usually these lingering")
          |> mes("thoughts have some sort of")
          |> mes("physical anchor, an object")
          |> mes("that has feelings attached")
          |> mes("to it, something important")
          |> mes("to its late owner.")
          |> next()
          |> mes("[Elder]")
          |> mes("The rage they're directing")
          |> mes("at you seems to be growing")
          |> mes("and I can see the angry spirits")
          |> mes("pulling at the hems of your")
          |> mes("clothes. Tell me, have you")
          |> mes("wronged anyone recently?!")
          |> next()
          |> select(["I don't... think so.", "I can't remember every bad thing I've done!"])

        {ctx, _} =
          ctx
          |> mes("[Elder]")
          |> mes("Well, you better do")
          |> mes("something soon, before")
          |> mes("the evil taints your mind")
          |> mes("and drives you to insanity!")
          |> mes("Now, I need to know for sure")
          |> mes("if you've been hearing voices.")
          |> next()
          |> select(["Y-yes, I have."])

        ctx
        |> mes("[Elder]")
        |> mes("There's still hope.")
        |> mes("The spirits are trying")
        |> mes("to reach you for now, but")
        |> mes("if you wait too long, you may")
        |> mes("become a victim of their wrath.")
        |> mes("Hurry, there is much to do!")
        |> next()
        |> mes("[Elder]")
        |> mes("You must appease these")
        |> mes("forces by finding out what")
        |> mes("happened to them in life.")
        |> mes("Now, I don't possess great")
        |> mes("power, but I can encourage")
        |> mes("the spirits to guide you.")
        |> next()
        |> mes("[Elder]")
        |> mes("I can only have the spirits")
        |> mes("reveal the places they wish")
        |> mes("for you to search only once.")
        |> mes("You must remember the")
        |> mes("locations that I am about")
        |> mes("to show you. Get ready...")
        |> specialeffect2(:sight)
        |> next()
        |> mes("[Elder]")
        |> mes("Yaaaaappp ---!")
        |> specialeffect2(:sightrasher)
        |> specialeffect2(:volcano)
        |> specialeffect2(:mappillar)
        |> next()
        |> mes("[Elder]")
        |> mes("There! The locations")
        |> mes("you must search should")
        |> mes("be clear to you now! Don't")
        |> mes("forget these placemarks!")
        |> viewpoint(1, 104, 282, 1, 10_092_339)
        |> viewpoint(1, 105, 282, 2, 10_092_339)
        |> viewpoint(1, 104, 281, 3, 10_092_339)
        |> viewpoint(1, 105, 281, 4, 10_092_339)
        |> next()
        |> mes("[Elder]")
        |> mes("Good luck, youngster.")
        |> mes("I hope you can appease")
        |> mes("the wrath of these spirits...")
        |> mes("But as long as you let them guide you, you ought to be safe.")
        |> set_char_var(:lhz_curse, 6)
        |> changequest(2086, 2087)
        |> close()

      2 ->
        ctx
        |> mes("[Elder]")
        |> mes("Crazy...? Hm, you must")
        |> mes("not quite understand what's")
        |> mes("happening to you. Please do")
        |> mes("not hesitate to come back to")
        |> mes("me when you realize that you")
        |> mes("need my help, youngster.")
        |> close()

      _ ->
        ctx
    end
  end

  defp await_clues(ctx) do
    ctx
    |> mes("[Elder]")
    |> mes("I'm sorry, but there's")
    |> mes("nothing more I can do for")
    |> mes("you right now. But if you")
    |> mes("find anything related to the")
    |> mes("spirits that torment you,")
    |> mes("please let me know.")
    |> close()
  end

  defp examine_pendant(ctx) do
    if count_item(ctx, 7341) > 0 do
      {ctx, choice} =
        ctx
        |> mes("[Elder]")
        |> mes("Greetings, adventurer.")
        |> mes("How goes your search for")
        |> mes("the remains of the spirits")
        |> mes("that still cling to this plane?")
        |> next()
        |> select(["Show him the Pendant.", "Cancel"])

      case choice do
        1 ->
          ctx
          |> mes("[Elder]")
          |> mes("Oh my... There are some")
          |> mes("incredibly powerful emotions")
          |> mes("clinging to this pendant. If we")
          |> mes("don't do anything about this,")
          |> mes("you'll be cursed very soon.")
          |> mes("This is what you must do.")
          |> next()
          |> mes("[Elder]")
          |> mes("Hurry and bring")
          |> mes("^3131FF5 Holy Water^000000 and")
          |> mes("^3131FF1 Bouquet^000000. The Holy Water")
          |> mes("will purify this Pendant and")
          |> mes("the Bouquet will comfort")
          |> mes("the spirit of its owner.")
          |> next()
          |> mes("[Elder]")
          |> mes("You don't have much")
          |> mes("time, so return to me")
          |> mes("as soon as possible!")
          |> mes("It won't be long until")
          |> mes("the spirits are consumed")
          |> mes("by their supernatural rage...")
          |> set_char_var(:lhz_curse, 18)
          |> changequest(2091, 2092)
          |> close()

        2 ->
          close(ctx)

        _ ->
          ctx
      end
    else
      ctx
      |> mes("[Elder]")
      |> mes("Greetings, adventurer.")
      |> mes("How goes your search for")
      |> mes("the remains of the spirits")
      |> mes("that still cling to this plane?")
      |> next()
      |> mes("[Elder]")
      |> mes("Wait...")
      |> mes("Why do I sense")
      |> mes("that you've found")
      |> mes("something, but have")
      |> mes("not brought it with you?")
      |> mes("You must retrace your steps!")
      |> close()
    end
  end

  defp purify_pendant(ctx) do
    if count_item(ctx, 523) > 4 and count_item(ctx, 744) > 0 and
         count_item(ctx, 7341) > 0 do
      ctx
      |> mes("[Elder]")
      |> mes("Good, good.")
      |> mes("All is in readiness.")
      |> mes("Please be silent as")
      |> mes("I focus my spirit for the")
      |> mes("great task before me.")
      |> next()
      |> mes("[Elder]")
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> mes("Hooooooo...")
      |> specialeffect2(:benedictio)
      |> next()
      |> mes("[Elder]")
      |> mes("Yaaaaapp ---!")
      |> specialeffect2(:aspersio)
      |> next()
      |> mes("[Elder]")
      |> mes("Whew! I've managed")
      |> mes("to nullify this curse for you.")
      |> mes("That still doesn't change the")
      |> mes("fact that what happened to this")
      |> mes("pendant's owner was tragic...")
      |> next()
      |> mes("[Elder]")
      |> mes("Why don't you bring")
      |> mes("this pendant to the place")
      |> mes("where it really belongs?")
      |> mes("I'm sure that would bring")
      |> mes("great comfort to its owner.")
      |> next()
      |> mes("^3355FFSuddenly, the clasp on")
      |> mes("the pendant pops open,")
      |> mes("revealing a picture of a happy")
      |> mes("couple. Somehow, the girl in")
      |> mes(
        "the picture, sitting uncomfortably^FFFFFF^3355FF in an old chair, looks familiar...^000000"
      )
      |> set_char_var(:lhz_curse, 19)
      |> changequest(2092, 2093)
      |> delitem(523, 5)
      |> delitem(744, 1)
      |> close()
    else
      ctx
      |> mes("[Elder]")
      |> mes("Hurry and bring")
      |> mes("^3131FF5 Holy Water^000000 and")
      |> mes("^3131FF1 Bouquet^000000 in order")
      |> mes("for me to nullify this")
      |> mes("curse. Do not forget to")
      |> mes("bring the Pendant as well.")
      |> close()
    end
  end

  defp discuss_city(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Elder]")
      |> mes("Predators are always")
      |> mes("on the lookout for easy")
      |> mes("prey. Be careful, youngster!")
      |> mes("You look innocent enough")
      |> mes("to become a victim in the city.")
      |> next()
      |> select(["About Lighthalzen", "About the Slum", "????"])

    case choice do
      1 ->
        ctx
        |> mes("[Elder]")
        |> mes("Lighthalzen might seem")
        |> mes("like a splendid city at first,")
        |> mes("but you'll quickly learn that")
        |> mes("the poor are segregated from")
        |> mes("the rich and treated as less")
        |> mes("than second class citizens.")
        |> next()
        |> mes("[Elder]")
        |> mes("At first, separation between")
        |> mes("the rich and poor districts was")
        |> mes("subtly enforced. They built the")
        |> mes("railroad right between the two")
        |> mes("districts to make it easier for")
        |> mes("the rich to ignore the poor.")
        |> next()
        |> mes("[Elder]")
        |> mes("But now they even have")
        |> mes("guards to make sure that")
        |> mes("the poor can't bother the")
        |> mes("rich. I'm pretty sure that")
        |> mes("this segregation won't be")
        |> mes("ending anytime soon...")
        |> next()
        |> mes("[Elder]")
        |> mes("Now, I've heard that the")
        |> mes("Rekenber Corporation is")
        |> mes("actually providing jobs for")
        |> mes("people in the slums. Beggars")
        |> mes("can't be choosers, so I'm sure")
        |> mes("these jobs aren't that great.")
        |> close()

      2 ->
        ctx
        |> mes("[Elder]")
        |> mes("To live in the slum is to")
        |> mes("be familiar with poverty,")
        |> mes("disease, condemnation")
        |> mes("and contempt. But we're all")
        |> mes("still people, you know, so let")
        |> mes("go of any of your misgivings.")
        |> next()
        |> mes("[Elder]")
        |> mes("We're struggling just")
        |> mes("to survive here. At the")
        |> mes("very least, please respect")
        |> mes("that. It's a fact that the")
        |> mes("people in the rich district")
        |> mes("seem to keep forgetting.")
        |> close()

      3 ->
        ctx
        |> mes("[Elder]")
        |> mes("Well, if you need any")
        |> mes("help around here or have")
        |> mes("any questions, come back")
        |> mes("and ask me. I get the feeling")
        |> mes("that we'll probably meet again.")
        |> close()

      _ ->
        ctx
    end
  end
end
