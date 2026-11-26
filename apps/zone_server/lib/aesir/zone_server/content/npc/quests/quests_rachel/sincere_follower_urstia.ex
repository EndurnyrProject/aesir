defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.SincereFollowerUrstia do
  @moduledoc """
  Urstia seeks help restoring a necklace as an offering for her sick son.

  ## Behavior

  - Asks adventurers to find Maheo and polish the necklace.
  - Rewards the return of the restored necklace and remembers quest progress.

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
        map: "rachel",
        x: 157,
        y: 183,
        dir: 3,
        sprite: 916,
        name: "Sincere Follower Urstia",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = cutin(ctx, "ra_usti1", 2)
    ctx = if checkweight(ctx, [{908, 200}]) == 0, do: weight_warning(ctx), else: ctx
    stage = get_char_var(ctx, :ice_necklace_q, 0)

    if stage < 1 do
      introduce(ctx)
    else
      ctx =
        cond do
          stage < 5 -> reminder(ctx)
          stage == 5 -> return_necklace(ctx)
          true -> blessing(ctx)
        end

      ctx |> close2() |> cutin("", 255)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp weight_warning(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Urstialla]")
      |> mes("Oh, are you an adventurer")
      |> mes("from the outside? Praise be")
      |> mes("to Freya! Her love and grace")
      |> mes("reaches all over the world,")
      |> mes("touching even the hearts of")
      |> mes("foreigners, leading them here!")
      |> next()
      |> select(["Freya? I'd like to know more.", "That's crazy talk!"])

    if choice == 1 do
      explain_quest(ctx)
    else
      ctx |> reject_faith() |> close2() |> cutin("", 255)
    end
  end

  defp explain_quest(ctx) do
    ctx =
      ctx
      |> emotion(:ok)
      |> mes("[Urstialla]")
      |> mes("The day is coming when")
      |> mes("Freya will resurrect and")
      |> mes("lead all of her faithful to")
      |> mes("Valhalla. Now she is in a")
      |> mes("deep sleep, but even then,")
      |> mes("she watches over all of us.")
      |> next()
      |> mes("[Urstialla]")
      |> mes("You see, Freya used up")
      |> mes("all of her power fighting the")
      |> mes("most fearsome of demons")
      |> mes("in the Thousand Year War.")
      |> mes("Now she rests and recovers")
      |> mes("in a pure and sacred place.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Wait...")
      |> mes("How do you")
      |> mes("know that all of")
      |> mes("this happened?")
      |> next()
      |> mes("[Urstialla]")
      |> mes("These are truths that all")
      |> mes("of Freya's worshippers know.")
      |> mes("Freya delivers her messages to")
      |> mes("us through her mortal vessel,")
      |> mes("our beautiful pope that shines")
      |> mes("with brilliant white light.")
      |> next()
      |> mes("[Urstialla]")
      |> mes("Unfortunately, even the most")
      |> mes("faithful experience lapses in")
      |> mes("judgment. It shames me to")
      |> mes("admit that my son Egapeo")
      |> mes("is... is guilty of sin.")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Sin? What did he")
      |> mes("do, if you don't")
      |> mes("mind me asking?")
      |> next()
      |> mes("[Urstialla]")
      |> mes("I don't know, but Egapeo")
      |> mes("has been sick for a while")
      |> mes("now. I'm convinced that he")
      |> mes("did something to anger Freya")
      |> mes("Although he may deserve it,")
      |> mes("I'm doing my best to help him.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Wait. What?!")
      |> next()
      |> mes("[Urstialla]")
      |> mes("I know that if I pray hard")
      |> mes("enough and please Freya,")
      |> mes("she will forgive my son and")
      |> mes("heal him of his illness.")
      |> mes("But sometimes prayer isn't")
      |> mes("enough... I need to pay tribute.")
      |> next()
      |> mes("[Urstialla]")
      |> mes("I managed to acquire a")
      |> mes("necklace of incomparable")
      |> mes("beauty from the dwarves.")
      |> mes("However, the gems have dulled")
      |> mes("with age and need to be shined")
      |> mes("before I can offer them to Freya.")
      |> next()
      |> mes("[Urstialla]")
      |> mes("However, not just anyone can")
      |> mes("shine this special necklace")
      |> mes("forged by the Dwarves. I need")
      |> mes("someone that knows arcane magic")
      |> mes("to help me. I think there's only")
      |> mes("one mage that can polish this...")
      |> next()
      |> mes("[Urstialla]")
      |> mes("Maheo, the renown mage with")
      |> mes("access to the most powerful")
      |> mes("magic spells in the world,")
      |> mes("must be able to clean this")
      |> mes("necklace's gems! However")
      |> mes("There's no way I can reach him.")
      |> next()
      |> mes("[Urstialla]")
      |> mes("You see, Maheo left on a")
      |> mes("journey to subjugate the")
      |> mes("ice monsters in the ice cave")
      |> mes("to the north, and he hasn't")
      |> mes("returned yet. That place is too")
      |> mes("dangerous for people like me.")
      |> next()
      |> mes("[Urstialla]")
      |> mes("I know that you adventurers")
      |> mes("regularly travel through those")
      |> mes("kinds of areas, so would you")
      |> mes("please look for Maheo and ask")
      |> mes("him to clean this necklace on")
      |> mes("my behalf? Please, for my son...")
      |> next()
      |> select(["But that's none of my business!", "Alright, I'll do it."])

    if choice == 1, do: decline_quest(ctx), else: accept_quest(ctx)
  end

  defp decline_quest(ctx) do
    ctx
    |> mes("[Urstialla]")
    |> mes("I... I see.")
    |> mes("I thought that Freya")
    |> mes("had led you to me, but")
    |> mes("maybe my prayers haven't")
    |> mes("been answered yet. Perhaps")
    |> mes("I need to pray more fervently?.")
    |> close2()
    |> cutin("", 255)
  end

  defp accept_quest(ctx) do
    ctx
    |> mes("[Urstialla]")
    |> mes("Thank you so much!")
    |> mes("Please, take care of this")
    |> mes("necklace and ask Maheo")
    |> mes("to restore its luster. Then,")
    |> mes("it'll be a fitting tribute to")
    |> mes("our loving goddess Freya.")
    |> setquest(2109)
    |> give_item(7572, 1)
    |> set_char_var(:ice_necklace_q, 1)
    |> close2()
    |> cutin("", 255)
  end

  defp reject_faith(ctx) do
    ctx
    |> cutin("ra_usti2", 2)
    |> mes("[Urstialla]")
    |> mes("...............................")
    |> mes("Are you telling me")
    |> mes("that you don't believe?")
    |> mes("Repent, and may your")
    |> mes("heart be opened to Freya!")
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Urstialla]")
    |> mes("Please find Maheo the")
    |> mes("Mage and ask him to restore")
    |> mes("the beauty of the necklace")
    |> mes("I gave you. He should be")
    |> mes("fighting monsters in the")
    |> mes("ice cave to the north.")
  end

  defp return_necklace(ctx) do
    if count_item(ctx, 7573) > 0 do
      reward(ctx)
    else
      missing_necklace(ctx)
    end
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Urstialla]")
      |> mes("Oh! My necklace! Thank you!")
      |> mes("It's so beautiful! It will")
      |> mes("make a wonderful tribute to")
      |> mes("Freya! I am certain with this,")
      |> mes("my son will get better!")
      |> next()
      |> mes("[Urstialla]")
      |> mes("Here, I know it's not much,")
      |> mes("but please accept this as a")
      |> mes("token of my appreication for")
      |> mes(" what you have done for me.")
      |> delitem(7573, 1)

    ctx =
      ctx
      |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 90_000, else: 700_000), 0)
      |> set_char_var(:ice_necklace_q, 6)
      |> completequest(2113)
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, let's just say it was")
    |> mes("a worthwhile experience")
    |> mes("for me.")
    |> next()
    |> mes("[Urstialla]")
    |> mes(".........")
    |> mes("............")
    |> mes("May Freya always protect and")
    |> mes("guide you and forgive you for")
    |> mes("that horrible joke.")
  end

  defp missing_necklace(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, no! The necklace has disappeared!")
  end

  defp blessing(ctx) do
    ctx
    |> mes("[Urstialla]")
    |> mes("May Freya always")
    |> mes("protect and guide you")
    |> mes("with her everflowing")
    |> mes("grace and wisdom..")
  end
end
