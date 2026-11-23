defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Worker do
  @moduledoc """
  Gill asks for Hillslion horns to repair his tent.

  ## Behavior

  - Dialogue depends on translation equipment and quest progress.
  - Accepts 30 horns and completes the collection quest.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "manuk",
        x: 193,
        y: 135,
        dir: 0,
        sprite: 454,
        name: "Worker",
        scope: :shared,
        unique_name: "Worker#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      is_equipped(ctx, 2782) != 1 ->
        ctx
        |> mes("[Worker]")
        |> mes("Ehahdie O Ehai")
        |> mes("Ohek Hekdh I dkek")
        |> mes("Ohehp Qe Tehdhah")
        |> next()
        |> mes("[Worker]")
        |> mes("Ehaodke Thdieqak Khehdi")
        |> mes("PHhdkel")
        |> mes("Thhdqdcczk U dheagelokd dok")
        |> next()
        |> mes("- You can't understand what he's saying. - ")
        |> close()

      get_char_var(ctx, :ep13_2_busut, 0) == 3 ->
        first_stage(ctx)

      get_char_var(ctx, :ep13_2_busut, 0) == 4 ->
        second_stage(ctx)

      true ->
        ctx
        |> mes("[Gill]")
        |> mes("You're here again?")
        |> mes("Talking with someone occasionally is quite relaxing.")
        |> close()
    end
  end

  defp first_stage(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_bs1, 0) == 1 ->
        ctx =
          ctx
          |> mes("[Worker]")
          |> mes("Oops, it's dangerous, almost broken.")
          |> mes("I should hurry to change it...otherwise.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("What's the matter?")
          |> next()
          |> mes("[Worker]")
          |> mes("Ah....here.....um...")
          |> mes("......")
          |> mes(".........")
          |> mes("Nothing!!")
          |> emotion(:huk)
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("What's up?")
          |> next()
          |> mes("[Worker]")
          |> mes("You are an outsider.")
          |> mes("......")
          |> mes("I was suprised by your voice.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Yes, sorry to startle you.")

        ctx =
          ctx
          |> emotion(:smile, playerattached(ctx))
          |> next()
          |> mes("[Worker]")
          |> mes("Haha, it's ok.")
          |> mes(
            "Recently I heard about people like you but it's the first time I've actually met one."
          )
          |> next()
          |> mes("[Worker]")
          |> mes("You speak our language pretty good.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Ah...anyway..you look like you're having some trouble. What happened?")
          |> next()
          |> mes("[Worker]")
          |> mes("Nothing!!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Are you sure? Fate has to have brought us together for a reason.")
          |> mes("Tell me~")
          |> next()
          |> mes("[Worker]")
          |> mes("......")
          |> mes("Frankly...")
          |> next()
          |> mes("[Worker]")
          |> mes(
            "The screw is too old to use to fix the tent, so I should change it before it breaks."
          )
          |> next()
          |> mes("[Worker]")
          |> mes("I can't leave so I'm just waiting for my friend to pass by to help me.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Can I help you?")
          |> next()
          |> mes("[Worker]")
          |> mes("No~that's alright. We just met so I can't ask you for a favor.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("That's ok! We can help each other!")
          |> next()
          |> mes("- Suddenly there is a screeching sound as the screw breaks -")
          |> next()
          |> mes("[Worker]")
          |> mes("Ugh!!!")
          |> mes("**Sigh**")
          |> emotion(:cry)

        ctx
        |> emotion(:cry, playerattached(ctx))
        |> next()
        |> mes("[Worker]")
        |> mes("Well that's that!")
        |> mes("Anyway my name is ^0000FFGill^000000.")
        |> next()
        |> mes("[Gill]")
        |> mes(
          "I need something to fix the tent with, if you can get^0000FF 30 Horn of Hillslion^000000, I can make them into sturdy enough screws."
        )
        |> next()
        |> mes("[Gill]")
        |> mes("Sorry, again for making you do this but I will be waiting here for you.")
        |> set_char_var(:ep13_2_bs1, 2)
        |> setquest(11105)
        |> close()

      get_char_var(ctx, :ep13_2_bs1, 0) == 2 and count_item(ctx, 6032) > 29 ->
        ctx =
          ctx
          |> mes("[Gill]")
          |> mes("You helped me collect all of the Horns of Hillslion?")
          |> mes("Thank you so much.")
          |> next()
          |> mes("[Gill]")
          |> mes("It's all because of you, we are able to prevent anything disastrous.")

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "^0000FFEven though you're also an alien race, but compared to the vile fairies^000000, I'm glad to have met someone like ",
              char_name(ctx, 0)
            ),
            "."
          )
        )
        |> delitem(6032, 30)
        |> set_char_var(:ep13_2_bs1, 3)
        |> set_char_var(:ep13_2_busut, 4)
        |> completequest(11105)
        |> close()

      get_char_var(ctx, :ep13_2_bs1, 0) == 2 ->
        ctx
        |> mes("[Gill]")
        |> mes(
          "Sorry, again for making you do this but I will be waiting here for you to bring back the^0000FF 30 Horn of Hillslions.^000000."
        )
        |> close()

      get_char_var(ctx, :ep13_2_bs1, 0) == 3 ->
        ctx = ctx |> mes("[Gill]") |> mes("Thank you for helping me.")

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "^0000FFEven though you're also an alien race, but compared to the vile fairies^000000, I'm glad to have met someone like ",
              char_name(ctx, 0)
            ),
            "."
          )
        )
        |> close()

      true ->
        ctx
        |> mes("[Worker]")
        |> mes("This is too dangerous, it's become too loose...")
        |> mes("It must be replaced soon...")
        |> close()
    end
  end

  defp second_stage(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_bs1, 0) == 1 ->
        ctx =
          ctx
          |> mes("[Worker]")
          |> mes("This is too dangerous, it's become too loose...")
          |> mes("It must be replaced soon...")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Is something wrong?")
          |> next()
          |> mes("[Worker]")
          |> mes("Ah... see here...")
          |> mes("......")
          |> mes(".........")
          |> mes("Nevermind. Nothing.")
          |> emotion(:huk)
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("You don't have to be like this.")
          |> next()
          |> mes("[Worker]")
          |> mes("You are one of the strange race, aren't you?")
          |> mes("......")
          |> mes("To suddenly hear you speak our language gave me a bit of a shock.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Since I'm travelling here, so I thought I'd need it...")

        ctx =
          ctx
          |> emotion(:smile, playerattached(ctx))
          |> next()
          |> mes("[Worker]")
          |> mes("Haha, is that so?")
          |> mes(
            "I've heard of the rumour that your race exists, but I've never seen one before."
          )
          |> next()
          |> mes("[Worker]")
          |> mes("And to think you can speak our language. Interesting.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes(
            "Ah...but just a moment ago, you were having a hard time with something. Is something wrong?"
          )
          |> next()
          |> mes("[Worker]")
          |> mes("It's nothing.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Ah~ It must be fate that we met~")
          |> mes("You can just tell me.")
          |> next()
          |> mes("[Worker]")
          |> mes("......")
          |> mes("Well...")
          |> next()
          |> mes("[Worker]")
          |> mes(
            "The screw that is used to keep our tent in place is rusting away... we must get a new one."
          )
          |> next()
          |> mes("[Worker]")
          |> mes("But I can't leave this place, so I was waiting for someone to pass by.")
          |> mes(
            "And you just happened to talk to me. I thought you were someone from our tribe."
          )
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I can help you.")
          |> next()
          |> mes("[Worker]")
          |> mes("No, it's alright. We just met, so I don't want to trouble you.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Don't worry about it! Life is all about helping eachother, don't you think so?")
          |> next()
          |> mes(" - While the disagreement is taking place, - ")
          |> mes(" - The screw that has held its ground til now - ")
          |> mes(" - Finally gives in and breaks in half. - ")
          |> next()
          |> mes("[Worker]")
          |> mes("Ah!!!")
          |> emotion(:cry)

        ctx
        |> emotion(:cry, playerattached(ctx))
        |> next()
        |> mes("[Worker]")
        |> mes("I can't just care about pride now.")
        |> mes("Let me introduce myself, I am ^0000FFGill^000000.")
        |> next()
        |> mes("[Gill]")
        |> mes(
          "I need a screw to stablize our tent, and it can be found from the ^0000FFHillslion^000000 monster."
        )
        |> mes(
          "Please help me collect ^0000FF30 Horns of Hillslion^000000, and that should be enough for now."
        )
        |> next()
        |> mes("[Gill]")
        |> mes("I'm really sorry, so please hurry.")
        |> set_char_var(:ep13_2_bs1, 2)
        |> setquest(11105)
        |> close()

      get_char_var(ctx, :ep13_2_bs1, 0) == 2 and count_item(ctx, 6032) > 29 ->
        ctx =
          ctx
          |> mes("[Gill]")
          |> mes("You helped me collect all of the Horns of Hillslion?")
          |> mes("Thank you so much.")
          |> next()
          |> mes("[Gill]")
          |> mes("It's all because of you, we are able to prevent anything disastrous.")

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "^0000FFEven though you're also an alien race, but compared to the vile fairies^000000, I'm glad to have met someone like ",
              char_name(ctx, 0)
            ),
            "."
          )
        )
        |> delitem(6032, 30)
        |> set_char_var(:ep13_2_bs1, 3)
        |> completequest(11105)
        |> close()

      get_char_var(ctx, :ep13_2_bs1, 0) == 2 ->
        ctx
        |> mes("[Gill]")
        |> mes("Making you do something like this, I feel ashamed.")
        |> close()

      get_char_var(ctx, :ep13_2_bs1, 0) == 3 ->
        ctx = ctx |> mes("[Gill]") |> mes("Thank you for helping me.")

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "^0000FFEven though you're also an alien race, but compared to the vile Fairies^000000, I'm glad to have met someone like ",
              char_name(ctx, 0)
            ),
            "."
          )
        )
        |> close()

      true ->
        ctx
        |> mes("[Worker]")
        |> mes("This is too dangerous, it's become too loose...")
        |> mes("It must be replaced soon...")
        |> close()
    end
  end
end
