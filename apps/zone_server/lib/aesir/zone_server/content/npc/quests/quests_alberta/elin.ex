defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Elin do
  @moduledoc """
  Elin collects dolls and offers small gifts in return.

  ## Behavior

  - Trades different dolls for food or other items.
  - Checks the player’s carrying capacity before offering a trade.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "alberta", x: 117, y: 135, dir: 0, sprite: 96, name: "Elin", scope: :shared}]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("[Elin]")
      |> mes(
        "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
      )
      |> close()
    else
      greet(ctx)
    end
  end

  defp greet(ctx) do
    ctx = mes(ctx, "[Elin]")

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("Hello~!")
        |> mes(
          "Heh heh, you're a boy, so you probably don't like dolls, right? Well, I like dolls very very much!"
        )
      else
        mes(ctx, "Hi hi~! Oh, oh, do you like dolls? I really really like dolls... Hee Hee~!")
      end

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Elin]")
      |> mes(
        "You know, I really really want a new doll! I hope my daddy will give me one on my birthday...!"
      )
      |> next()
      |> select(["Um, I hope your daddy gives you one too.", "How about I give you one now?"])

    case choice do
      1 ->
        ctx
        |> mes("[Elin]")
        |> mes("Yeah, I'm hoping")
        |> mes("he gives me a Yoyo")
        |> mes("doll. They're so cute!")
        |> close()

      2 ->
        offer_doll(ctx)

      _ ->
        ctx
    end
  end

  defp offer_doll(ctx) do
    if max_weight(ctx) - weight(ctx) < 1000 do
      ctx = mes(ctx, "[Elin]")

      ctx =
        if sex(ctx) == 1 do
          mes(
            ctx,
            "Maybe you should put some of your stuff away first, you look like you're carrying too much, hee hee~"
          )
        else
          mes(
            ctx,
            "Do you always carry so much with you? Put some of your things away first, okay?"
          )
        end

      close(ctx)
    else
      choose_doll(ctx)
    end
  end

  defp choose_doll(ctx) do
    ctx = mes(ctx, "[Elin]")

    ctx =
      if sex(ctx) == 1 do
        ctx |> mes("Oh my goodness!") |> mes("Really? You're") |> mes("such a sweetie~!")
      else
        ctx
        |> mes("Will you really?")
        |> mes("You're gonna give")
        |> mes("me a doll? Yaaaay~")
      end

    {ctx, doll} =
      ctx
      |> next()
      |> mes("[Elin]")
      |> mes("What kind of doll are you going to give me? Are you really gonna give me one?")
      |> next()
      |> select([
        "Poring Doll",
        "Chonchon Doll",
        "Puppet",
        "Rocker Doll",
        "Spore Doll",
        "Osiris Doll",
        "Baphomet Doll",
        "Raccoon Doll",
        "Yoyo Doll",
        "I'm as adorable as a doll."
      ])

    trade_doll(ctx, doll)
  end

  defp trade_doll(ctx, 1) do
    if count_item(ctx, 741) >= 1 do
      ctx =
        ctx
        |> delitem(741, 1)
        |> mes("[Elin]")
        |> mes("Aww...")
        |> mes("I have a lot")
        |> mes("of Poring dolls...")
        |> next()
        |> mes("[Elin]")

      ctx =
        if sex(ctx) == 1 do
          mes(
            ctx,
            "But since a cute boy is giving it to me, I'll happily take it! Hee hee, soft and fluffy Poring doll~"
          )
        else
          mes(
            ctx,
            "But since a nice girl is giving it to me, I'll take it! Hee he, soft and fluffy Poring doll~"
          )
        end

      ctx =
        ctx
        |> next()
        |> mes("[Elin]")
        |> mes(
          "Ooh, let me give you something as a little thank you. You see, I hid some candy so I can eat it without telling mommy."
        )
        |> next()
        |> give_item(529, 1)
        |> mes("[Elin]")

      ctx =
        if sex(ctx) == 1 do
          mes(ctx, "I don't know if you're too old to like candy, but I guess it's okay.")
        else
          mes(
            ctx,
            "So, try not to eat too much, okay? Otherwise, you might get in trouble!"
          )
        end

      ctx
      |> next()
      |> mes("[Elin]")
      |> mes("Thank you")
      |> mes("so much for")
      |> mes("the Poring doll!")
      |> close()
    else
      ctx = mes(ctx, "[Elin]")

      ctx =
        if sex(ctx) == 1 do
          ctx |> mes("Aww...?") |> mes("Were you only teasing me?")
        else
          ctx |> mes("Aww...") |> mes("You're not making fun of me are you?")
        end

      ctx
      |> next()
      |> mes("[Elin]")
      |> mes("I guess you forgot it somewhere...")
      |> close()
    end
  end

  defp trade_doll(ctx, 2) do
    if count_item(ctx, 742) >= 1 do
      ctx =
        ctx
        |> delitem(742, 1)
        |> mes("[Elin]")
        |> mes("Agh--!")
        |> mes("A Ch-Ch, Chonchon doll?!")
        |> next()
        |> mes("[Elin]")

      ctx =
        if sex(ctx) == 1 do
          mes(ctx, "But since... You're... Such a nice guy... I better take it...!")
        else
          mes(ctx, "But since... Since it's a gift... I guess I'll take it...")
        end

      ctx
      |> next()
      |> mes("[Elin]")
      |> mes("Mmm~")
      |> mes("Let me give you")
      |> mes("something in return...")
      |> next()
      |> give_item(530, 1)
      |> mes("[Elin]")
      |> mes(
        "If you eat too much, your teeth will start to rot... at least, that's what Mommy says."
      )
      |> next()
      |> mes("[Elin]")
      |> mes("And..")
      |> mes("Uh...")
      |> mes("Thank you")
      |> mes("for the doll?")
      |> close()
    else
      ctx
      |> mes("[Elin]")
      |> mes(
        "Chonchon dolls are ugly anyways, but you still lied to me! How can you be so mean?!"
      )
      |> next()
      |> mes("[Elin]")
      |> mes("Waaaaaaaaah~~")
      |> close()
    end
  end

  defp trade_doll(ctx, 3) do
    if count_item(ctx, 740) >= 1 do
      ctx
      |> delitem(740, 1)
      |> mes("[Elin]")
      |> mes("Wow...!")
      |> mes("It looks like a bunny!")
      |> next()
      |> mes("[Elin]")
      |> mes("I really like this Puppet~ Heh hehe! Thank you so much~")
      |> next()
      |> mes("[Elin]")
      |> mes("Ooh ooh!")
      |> mes("I have something")
      |> mes("for you too!")
      |> mes("Um, where")
      |> mes("did it... Ah!")
      |> next()
      |> give_item(530, 1)
      |> mes("[Elin]")
      |> mes(
        "Here it is! It's some of the candy Santa gave me. Go ahead and try some! Oh, and thank you so much for the doll!"
      )
      |> close()
    else
      ctx
      |> mes("[Elin]")
      |> mes("Awww, you were only kidding? W-W-Why are you teasing me like that?")
      |> next()
      |> mes("[Elin]")
      |> mes("^666666*Sniff...*^000000")
      |> next()
      |> mes("[Elin]")
      |> mes("Waaaaaaaaah~~")
      |> close()
    end
  end

  defp trade_doll(ctx, 4) do
    if count_item(ctx, 752) >= 1 do
      ctx
      |> delitem(752, 1)
      |> mes("[Elin]")
      |> mes("Ooh! Rocker Doll!")
      |> mes(
        "It's the Rocker that likes singing and dancing! I don't like grasshoppers, but I like this because it's cute~"
      )
      |> next()
      |> mes("[Elin]")
      |> mes(
        "Hmmm, I should give you something too, huh? Let's see, I have what my grandpa gave me..."
      )
      |> next()
      |> give_item(532, 7)
      |> mes("[Elin]")
      |> mes(
        "Here you go! We have a lot of this at home, so I'll give it to you, okay? Oh, and thank you so much for the doll~ I love cute dolls!"
      )
      |> close()
    else
      ctx
      |> mes("[Elin]")
      |> mes("Awww...")
      |> next()
      |> mes("[Elin]")
      |> mes("You don't")
      |> mes("really have a doll...?")
      |> mes("I was so excited about it, too...")
      |> close()
    end
  end

  defp trade_doll(ctx, 5) do
    if count_item(ctx, 743) >= 1 do
      ctx
      |> delitem(743, 1)
      |> mes("[Elin]")
      |> mes("It's a mushroom?")
      |> mes("Ewwwwwwwww, yucky!")
      |> mes("Mommy made me eat")
      |> mes("mushrooms today, too...")
      |> next()
      |> mes("[Elin]")
      |> mes(
        "But this doll is cute, so I'll take it. But I'm still not gonna eat mushrooms! Heh heh~"
      )
      |> next()
      |> give_item(538, 5)
      |> mes("[Elin]")
      |> mes(
        "Hehe~ My mommy made this! It's really yummy. I love cookies, too. So try it, you'll like it! Hee hee!"
      )
      |> next()
      |> mes("[Elin]")
      |> mes("Thanks for")
      |> mes("the doll! I'll")
      |> mes("take good care of it!")
      |> close()
    else
      ctx
      |> mes("[Elin]")
      |> mes("Eh...?")
      |> mes("You don't")
      |> mes("have a doll?")
      |> next()
      |> mes("[Elin]")
      |> mes("Awww...")
      |> mes("It's not nice")
      |> mes("to tease people")
      |> mes("like that. ^666666*Sniff, sniff*^000000")
      |> close()
    end
  end

  defp trade_doll(ctx, 6) do
    if count_item(ctx, 751) >= 1 do
      ctx =
        ctx
        |> delitem(751, 1)
        |> mes("[Elin]")
        |> mes("Ahhhhh!")
        |> mes("What is this")
        |> mes("thing?! It's so scary!")
        |> next()
        |> mes("[Elin]")
        |> mes(
          "I've never seen a doll like this before. Where it's from? Hmm? Since I've never seen this kind of doll before, I'm gonna show it to my daddy, too. Hehe~! He'll be surprised!"
        )
        |> next()
        |> mes("[Elin]")
        |> mes(
          "Here, since you gave me such a nicely made doll, I better give you something good too."
        )
        |> next()
        |> give_item(522, 2)
        |> mes("[Elin]")
        |> mes(
          "I found it when I secretly went to the forest. I took it because it has pretty colors!"
        )

      ctx =
        if sex(ctx) == 1 do
          mes(ctx, "Since there's two, you can share it with your girlfriend. Hee hee~!")
        else
          mes(ctx, "Since there's two, you can share it with your boyfriend. Hee hee~!")
        end

      ctx = close(ctx)
      ctx
    else
      ctx
      |> mes("[Elin]")
      |> mes("Awww...")
      |> mes("Why do you have")
      |> mes("to make fun of me?")
      |> close()
    end
  end

  defp trade_doll(ctx, 7) do
    if count_item(ctx, 750) >= 1 do
      ctx
      |> delitem(750, 1)
      |> mes("[Elin]")
      |> mes("Huh?")
      |> mes("It's a little goat...")
      |> next()
      |> mes("[Elin]")
      |> mes(
        "It's so weird. It's cute but it's also scary at the same time. Well, since you gave me a pretty doll, I wanna give you something, too."
      )
      |> next()
      |> give_item(525, 5)
      |> mes("[Elin]")
      |> mes(
        "My daddy gave me this when I was really sick. I'm not sick anymore so you can use it when you need to. Hehehe~"
      )
      |> next()
      |> mes("[Elin]")
      |> mes("Hee hee~")
      |> mes("Thank you for")
      |> mes("the doll. I won't lose it!")
      |> close()
    else
      ctx
      |> mes("[Elin]")
      |> mes("You big liar! Why are you pretending to be nice?!")
      |> close()
    end
  end

  defp trade_doll(ctx, 8) do
    if count_item(ctx, 754) >= 1 do
      ctx
      |> delitem(754, 1)
      |> mes("[Elin]")
      |> mes("Hehe, it's a")
      |> mes("raccoon doll.")
      |> mes("It's very very cute~")
      |> next()
      |> mes("[Elin]")
      |> mes("I don't like")
      |> mes("Smokies in real life,")
      |> mes("but this doll is nice!")
      |> next()
      |> give_item(539, 3)
      |> mes("[Elin]")
      |> mes(
        "Here, let me give you some cake my grandma made. It's really yummy. I don't know if you like sweets or not, but it's really good! Please try some!"
      )
      |> next()
      |> mes("[Elin]")
      |> mes("Hee hee~")
      |> mes("Thanks for the doll.")
      |> mes("I'm gonna keep it")
      |> mes("in my room!")
      |> close()
    else
      ctx
      |> mes("[Elin]")
      |> mes("Hey! How come you have to say things like that? Are you making fun of me?!")
      |> close()
    end
  end

  defp trade_doll(ctx, 9) do
    if count_item(ctx, 753) >= 1 do
      ctx
      |> delitem(753, 1)
      |> mes("[Elin]")
      |> mes("Woooooooow~!")
      |> next()
      |> mes("[Elin]")
      |> mes(
        "A Yoyo doll! It's so pretty! You're really gonna give it to me?! Yay! Thank you so much! I really like it! Hee hee!"
      )
      |> next()
      |> mes("[Elin]")
      |> mes("Since you gave")
      |> mes("me such a pretty doll,")
      |> mes("I wanna give you")
      |> mes("something, too!")
      |> next()
      |> give_item(608, 1)
      |> mes("[Elin]")
      |> mes(
        "My daddy picked it up on his way to another town. It looks like some kind of seed. I tried planting it in front of our house but it won't grow. Do you want to try?"
      )
      |> next()
      |> mes("[Elin]")
      |> mes("Hehe~")
      |> mes("Thanks for")
      |> mes("the doll. I'll hug")
      |> mes("it before I go")
      |> mes("to sleep!")
      |> close()
    else
      ctx
      |> mes("[Elin]")
      |> mes("Hey...")
      |> mes("How come you're making fun of me?!")
      |> close()
    end
  end

  defp trade_doll(ctx, 10) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I'm as adorable as a doll...")
    |> next()
    |> mes("[Elin]")
    |> mes("Whaaaaaaaaaaat...?")
    |> next()
    |> mes("[Elin]")
    |> mes("^3355FFWhat did^000000")
    |> mes("^3355FFyou just say?!^000000")
    |> close()
  end

  defp trade_doll(ctx, _) do
    ctx
  end
end
