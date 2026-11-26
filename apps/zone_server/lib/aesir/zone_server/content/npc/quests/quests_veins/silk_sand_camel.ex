defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.SilkSandCamel do
  @moduledoc """
  A wounded camel supplies dung for the siblings quest.

  ## Behavior

  - Feeding the camel can produce potatoes or advance the dung collection.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ve_fild07",
        x: 235,
        y: 42,
        dir: 3,
        sprite: 938,
        name: "Silk Sand Camel",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rachel_camel, 0) do
      11 ->
        introduce_camel(ctx)

      stage when stage > 11 and stage < 17 ->
        feed_camel(ctx)

      17 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I managed to get the soap")
        |> mes("ingredients: 5 of those")
        |> mes("camel dung lumps. I should")
        |> mes("head back to Mr. Saraman to")
        |> mes("tell him where his camel is,")
        |> mes("and then go to Ms. Ivory.")
        |> close()

      _ ->
        ctx
        |> mes("[Silk Sand Camel]")
        |> mes("*Neigh Neigh*~")
        |> next()
        |> mes("^3355FFSilly camel.^000000")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp introduce_camel(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThis camel's leg is")
      |> mes("wounded. Although it")
      |> mes("seems hurt, its nostrils")
      |> mes("flared as soon as it saw")
      |> mes("the camel appetite stimulant,")
      |> mes("and it smacked its lips.^000000")
      |> next()
      |> mes("[Camel]")
      |> mes("^333333*Chew Chew~*^000000")
      |> mes("^333333*Smacks lips*^000000")
      |> next()
      |> mes("^3355FFThe camel started nibbling")
      |> mes("the stimulant, but its eating")
      |> mes("became quicker as it ate")
      |> mes("more of the feed until it")
      |> mes("was completely consumed.^000000")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("This must be the")
    |> mes("Silk Sand Camel...")
    |> mes("I guess all I need to")
    |> mes("do is collect some of")
    |> mes("that precious camel dung.")
    |> changequest(3070, 3071)
    |> set_char_var(:rachel_camel, 12)
    |> close()
  end

  defp feed_camel(ctx) do
    if count_item(ctx, 511) > 19 and count_item(ctx, 909) > 9 and count_item(ctx, 519) > 1 and
         count_item(ctx, 713) > 0 do
      offer_feed(ctx)
    else
      missing_feed(ctx)
    end
  end

  defp offer_feed(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThe camel can smell")
      |> mes("that you have food for")
      |> mes("it, and started salivating.")
      |> mes("You may as well just feed it.^000000")
      |> next()

    case :rand.uniform(3) - 1 do
      1 ->
        ctx =
          if get_char_var(ctx, :rachel_camel, 0) == 12 do
            ctx
            |> mes("[Silk Sand Camel]")
            |> mes("^333333*Chew Chew~*^000000")
            |> mes("^333333*Smacks lips*^000000")
            |> next()
            |> mes("^3355FFThe camel ate everything,")
            |> mes("but it doesn't seem like")
            |> mes("it'll go through any bowel")
            |> mes("movements anytime soon.^000000")
          else
            ctx
            |> mes("^3355FFThe camel grimaced")
            |> mes("as if it were suffering")
            |> mes("from a stomachache...")
            |> mes("And... Out pops 2 Sweet")
            |> mes("Potatoes. They're probably")
            |> mes("safe to eat... Hopefully.^000000")
            |> give_item(516, 2)
          end

        ctx |> delitem(519, 2) |> delitem(511, 20) |> delitem(909, 10) |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Silk Sand Camel]")
          |> mes("^333333*Chew Chew~*^000000")
          |> mes("^333333*Smacks lips*^000000")
          |> next()
          |> mes("^3355FFThe camel grimaced")
          |> mes("as if it were suffering")
          |> mes("from a stomachache...")
          |> mes("Huzzah! You got a lump")
          |> mes("of steaming camel dung!")
          |> mes("This is cause for celebration!^000000")
          |> next()

        ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

        ctx = dung_progress(ctx, get_char_var(ctx, :rachel_camel, 0))

        ctx
        |> delitem(519, 2)
        |> delitem(511, 20)
        |> delitem(909, 10)
        |> delitem(713, 1)
        |> close()

      _ ->
        ctx
        |> mes("[Silk Sand Camel]")
        |> mes("^333333*Chew Chew~*^000000")
        |> mes("^333333*Smacks lips*^000000")
        |> next()
        |> mes("^3355FFThe camel grimaced")
        |> mes("as if it were suffering")
        |> mes("from a stomachache...")
        |> mes("And... Out pops a Sweet")
        |> mes("Potato. It's probably")
        |> mes("safe to eat... Maybe.^000000")
        |> delitem(519, 2)
        |> delitem(511, 20)
        |> delitem(909, 10)
        |> give_item(516, 1)
        |> close()
    end
  end

  defp dung_progress(ctx, stage) do
    case stage do
      12 ->
        ctx
        |> mes("Now all I need is")
        |> mes("just 4 more lumps")
        |> mes("of this nasty old dung.")
        |> set_char_var(:rachel_camel, 13)
        |> changequest(3071, 3072)

      13 ->
        ctx
        |> mes("Awesome! I got")
        |> mes("2 glorious camel dung")
        |> mes("lumps! Only 3 more to go!")
        |> set_char_var(:rachel_camel, 14)
        |> changequest(3072, 3073)

      14 ->
        ctx
        |> mes("Yes! Now I have")
        |> mes("3 camel dung lumps.")
        |> mes("Just 2 more... I'm more")
        |> mes("than halfway done!")
        |> set_char_var(:rachel_camel, 15)
        |> changequest(3073, 3074)

      15 ->
        ctx
        |> mes("4 lumps of camel dung...")
        |> mes("Heh heh! This is going")
        |> mes("better than I thought!")
        |> mes("Only 1 more to go!")
        |> set_char_var(:rachel_camel, 16)
        |> changequest(3074, 3075)

      16 ->
        ctx =
          ctx
          |> mes("In my hands...")
          |> mes("I am holding")
          |> mes("5 lumps of camel dung.")
          |> mes("This is my finest moment.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Never, in all my years")
          |> mes("of adventuring, saving the")
          |> mes("oppressed, protecting the")
          |> mes("innocent, did I dare dream")
          |> mes("that I'd accomplish such")
          |> mes("a magnificent feat.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I am so happy--nay--")
          |> mes("^4D4DFFproud^000000 that my strength, my")
          |> mes("valor, and my determination")
          |> mes("was up to this task. May the")
          |> mes("annals of history never forget")

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("this day! Long live ", char_name(ctx, 0)),
            "!"
          )
        )
        |> next()
        |> mes("^3355FFIt's time for you to")
        |> mes("return to Mr. Saraman.^000000")
        |> set_char_var(:rachel_camel, 17)
        |> changequest(3075, 3076)

      _ ->
        ctx
    end
  end

  defp missing_feed(ctx) do
    ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

    ctx =
      if get_char_var(ctx, :rachel_camel, 0) == 12 do
        ctx
        |> mes("I need to feed this camel if")
        |> mes("I ever want to get any dung")
        |> mes("from it. Let's see, Mr. Saraman")
        |> mes("mentioned that the items I got")
        |> mes("for Ms. Ivory were actually")
        |> mes("camel feed. I need to have...")
      else
        ctx
        |> mes("Did I run out of feed")
        |> mes("already? Nuts, if I want")
        |> mes("to feed this camel again,")
        |> mes("then I need to bring it...")
      end

    ctx = next(ctx)

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("^4D4DFF2 Milk^000000,")
    |> mes("^4D4DFF20 Green Herbs^000000,")
    |> mes("^4D4DFF10 Jellopies^000000, and")
    |> mes("^4D4DFF1 Empty Bottles^000000.")
    |> next()
    |> mes("[Silk Sand Camel]")
    |> mes("*Chew Chew*")
    |> mes("*Neigh Neigh*~")
    |> close()
  end
end
