defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.CuteGirl do
  @moduledoc """
  Liana asks for help delivering a letter to her father.

  ## Behavior

  - Changes her dialogue with quest progress and rewards the letter's delivery.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "geffen_in", x: 171, y: 42, dir: 3, sprite: 703, name: "Cute Girl", scope: :shared}
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if checkweight(ctx, [{908, 200}]) == 0 do
      ctx
      |> mes("^3355FFWait a second! Right now,")
      |> mes(
        "you have too many items in your inventory. Please come back after you've made more available inventory space.^000000"
      )
      |> close()
    else
      ctx = mes(ctx, "[Liana]")

      cond do
        get_char_var(ctx, :sign_q, 0) < 54 ->
          ctx
          |> mes("*Pout*")
          |> mes("When's my daddy")
          |> mes("coming home?!")
          |> mes("I... I miss him so much~")
          |> mes("*Cries*")
          |> emotion(:cry)
          |> close()

        get_char_var(ctx, :sign_q, 0) == 54 ->
          ctx
          |> mes("Oh, my mom said she's gonna cook me something good today.")
          |> mes("I wonder what she's gonna make?")
          |> mes("I hope it's pickled cabbage again!")
          |> emotion(:smile)
          |> close()

        get_char_var(ctx, :sign_q, 0) == 55 ->
          {ctx, choice} =
            ctx
            |> mes(
              "Everyone says that daddy is the best blacksmith in the whole world! But now he lets his apprentices do"
            )
            |> mes(
              "the work so he can go around the world to find a rare ore~ Isn't that amazing?"
            )
            |> next()
            |> select(["What are you drawing by the way?", "Apprentices?"])

          case choice do
            1 ->
              ctx =
                ctx |> mes("[Liana]") |> mes("Oh, this?") |> mes("It's a letter for my daddy.")

              ctx
              |> mes(
                "Mom said that some #{if sex(ctx) == 1, do: "guy", else: "lady"} is gonna try to find my dad, so I'm making this so #{if sex(ctx) == 1, do: "", else: "s"}he can take it him~"
              )
              |> close()

            2 ->
              {ctx, answer} =
                ctx
                |> mes("[Liana]")
                |> mes(
                  "Yeah, Uncle Hollegrehenn and Aragham come to visit sometimes and we all play. But, it's more fun to see my dad, even though he's not back yet. ^333333*Pout*^000000"
                )
                |> next()
                |> select(["Don't you miss your dad?", "He also misses you a lot."])

              case answer do
                1 ->
                  ctx
                  |> mes("[Liana]")
                  |> mes("I miss him sooo much!")
                  |> mes("^333333*Cries*^000000 But Mom always")
                  |> mes("says that he's too busy.")
                  |> mes("^333333*Pouts*^000000")
                  |> close()

                2 ->
                  {ctx, response} =
                    ctx
                    |> mes("[Liana]")
                    |> mes("I hope so...")
                    |> mes("But I hate it when")
                    |> mes("he doesn't have enough")
                    |> mes("time to come home and")
                    |> mes("see me. Sooooooooo~")
                    |> mes("I wrote this letter!")
                    |> emotion(:think)
                    |> next()
                    |> select(["....", "I'll bring this to him."])

                  case response do
                    1 ->
                      ctx = ctx |> mes("[Brenda Howard]") |> mes("Liana~")

                      ctx
                      |> mes(
                        "This nice #{if sex(ctx) == 1, do: "man", else: "lady"} is going to look for your dad. Why don't you ask #{if sex(ctx) == 1, do: "him", else: "her"} to take your letter to him for you?"
                      )
                      |> next()
                      |> mes("[Liana]")
                      |> mes("You are...?")
                      |> mes("Really, really?")
                      |> mes("H-hooray!")
                      |> next()
                      |> mes("[Liana]")
                      |> mes("Okay then, don't")
                      |> mes("forget to give this to")
                      |> mes("my dad, okay? Promise?")
                      |> emotion(:delight)
                      |> set_char_var(:sign_q, 56)
                      |> give_item(7276, 1)
                      |> close()

                    2 ->
                      ctx
                      |> mes("[Liana]")
                      |> mes("Mmmm...")
                      |> mes("But I don't know you!")
                      |> mes("Mom says I should never")
                      |> mes("ask for anything from strangers.")
                      |> close()

                    _ ->
                      ctx
                  end

                _ ->
                  ctx
              end

            _ ->
              ctx
          end

        get_char_var(ctx, :sign_q, 0) < 62 ->
          if Enum.random(1..10) < 6 do
            ctx
            |> mes("My dad never broke anything")
            |> mes(
              "his customers gave him. And my uncle Hollgrehenn and Aragham wouldn't let anything like that"
            )
            |> mes("happen, would they?")
            |> close()
          else
            ctx
            |> mes("Would you please bring my letter over to my dad? Heh heh, he'll be")
            |> mes("so happy to hear from me!")
            |> close()
          end

        get_char_var(ctx, :sign_q, 0) < 66 ->
          ctx =
            ctx
            |> mes("Yay~!")
            |> mes("Thank you for bringing my letter to my dad. Here, here!")
            |> mes("You have to share my treasure with me, 'kay?")

          ctx
          |> set_char_var(:sign_q, get_char_var(ctx, :sign_q, 0) + 4)
          |> give_item(529, 10)
          |> close()

        true ->
          ctx
          |> mes(
            "I never saw my dad fail to upgrade a weapon or armor. Mmm? But maybe if he had something really really old and rare and special..."
          )
          |> close()
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
