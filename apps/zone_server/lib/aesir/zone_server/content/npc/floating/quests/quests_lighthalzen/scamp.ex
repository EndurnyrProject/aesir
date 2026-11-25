defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsLighthalzen.Scamp do
  @moduledoc """
  Ahman receives packages delivered by the player.

  ## Behavior

  - Responds to each stage of the delivery job and advances its progress.

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
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "", scope: :shared, unique_name: "Scamp"},
      %{
        map: "izlude",
        x: 172,
        y: 73,
        dir: 6,
        sprite: 853,
        name: "Scamp",
        unique_name: "Scamp#iz",
        scope: :renewal
      },
      %{
        map: "izlude_a",
        x: 172,
        y: 73,
        dir: 6,
        sprite: 853,
        name: "Scamp",
        unique_name: "Scamp#iz_a",
        scope: :renewal
      },
      %{
        map: "izlude_b",
        x: 172,
        y: 73,
        dir: 6,
        sprite: 853,
        name: "Scamp",
        unique_name: "Scamp#iz_b",
        scope: :renewal
      },
      %{
        map: "izlude_c",
        x: 172,
        y: 73,
        dir: 6,
        sprite: 853,
        name: "Scamp",
        unique_name: "Scamp#iz_c",
        scope: :renewal
      },
      %{
        map: "izlude_d",
        x: 172,
        y: 73,
        dir: 6,
        sprite: 853,
        name: "Scamp",
        unique_name: "Scamp#iz_d",
        scope: :renewal
      },
      %{
        map: "izlude",
        x: 186,
        y: 57,
        dir: 5,
        sprite: 853,
        name: "Scamp",
        unique_name: "Scamp#iz",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :lhz_rekenber, 0) do
      stage when stage > 21 ->
        ctx
        |> mes("[Ahman]")
        |> mes("Oh, hello. I've heard")
        |> mes("that you had to quit.")
        |> mes("It's quite a pity, really.")
        |> mes("If it weren't for you, some")
        |> mes("of my packages would have")
        |> mes("been destroyed by those thugs.")
        |> close()

      21 ->
        ctx
        |> mes("[Ahman]")
        |> mes("Shouldn't you be")
        |> mes("taking a break? Besides,")
        |> mes("Lyozien is still waiting for")
        |> mes("you on the Airship, isn't he?")
        |> close()

      20 ->
        ctx
        |> mes("[Ahman]")
        |> mes("Oh, have my packages")
        |> mes("arrived? Good, good.")
        |> mes("I appreciate all of your")
        |> mes("hard work. I'm surprised")
        |> mes("they haven't hired you")
        |> mes("full time by now.")
        |> next()
        |> mes("[Ahman]")
        |> mes("Is something the matter?")
        |> mes("You seem really pale. Oh")
        |> mes("well, you'll have plenty of")
        |> mes("time to relax on the Airship.")
        |> mes("Oh, and don't worry, I'll")
        |> mes("take care of the packages.")
        |> set_char_var(:lhz_rekenber, 21)
        |> close()

      stage when stage > 15 and stage < 20 ->
        ctx
        |> mes("[Ahman]")
        |> mes("Oh, hello. I'm not")
        |> mes("expecting any packages")
        |> mes("at this moment, although")
        |> mes("I'm aware that there are a")
        |> mes("few deliveries in queue, but shouldn't you be in Lighthalzen?")
        |> close()

      15 ->
        ctx
        |> mes("[Ahman]")
        |> mes("Shouldn't you be on")
        |> mes("your way and report to")
        |> mes("Lyozien? You should hurry")
        |> mes("before the Airship takes off.")
        |> close()

      14 ->
        ctx =
          ctx
          |> mes("[Ahman]")
          |> mes("Ah, it's you again.")
          |> mes("I assume that means that")
          |> mes("my packages have arrived")
          |> mes("safely. Is that right?")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Yes, that's right.")
        |> mes("Actually, this time we ")
        |> mes("were attacked by a group")
        |> mes("of thugs, so I was wondering")
        |> mes("if you knew anything about it... ")
        |> next()
        |> mes("[Ahman]")
        |> mes("They attacked again?")
        |> mes("Oh, that isn't good.")
        |> mes("Well, I have no idea")
        |> mes("what's going on. I wish")
        |> mes("I had some idea of what")
        |> mes("they were up to, really.")
        |> next()
        |> set_char_var(:lhz_rekenber, 15)
        |> mes("[Ahman]")
        |> mes("For now, you should")
        |> mes("go and report to Lyozien.")
        |> mes("I assume that you protected")
        |> mes("my packages, so thank you")
        |> mes("for your diligent work. Now, I shall pick up what I ordered...")
        |> close()

      stage when stage > 10 and stage < 14 ->
        ctx
        |> mes("[Ahman]")
        |> mes("Oh, it's you again.")
        |> mes("Shouldn't you be getting")
        |> mes("on the Airship and heading")
        |> mes("back to the Schwarzwald")
        |> mes("Republic? There are more")
        |> mes("deliveries in queue, you know.")
        |> close()

      10 ->
        ctx
        |> mes("[Ahman]")
        |> mes("Thank you for letting me")
        |> mes("know that my order has arrived.")
        |> mes("You should go back to Lyozien")
        |> mes("now so you can finish your job.")
        |> mes("Perhaps I'll see you again")
        |> mes("sometime, adventurer.")
        |> close()

      9 ->
        ctx =
          ctx
          |> mes("[Man]")
          |> mes("Hmm, can you really")
          |> mes("call this place an Airport?")
          |> mes("It's far too small, wouldn't")
          |> mes("you agree? Still, I kind of")
          |> mes("enjoy sitting around here.")
          |> next()

        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("[", char_name(ctx, 0)),
              "]"
            )
          )
          |> mes("Excuse me, but do")
          |> mes("you know where I can")
          |> mes("find a man named Ahman?")
          |> mes("I have a message for him.")
          |> next()
          |> mes("[Ahman]")
          |> mes("I'm Ahman, how can--")
          |> mes("Oh! You must be here to")
          |> mes("tell me that my packages")
          |> mes("have arrived. Am I correct?")
          |> next()

        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("[", char_name(ctx, 0)),
              "]"
            )
          )
          |> mes("Y-yes. That's right.")
          |> mes("Your packages have")
          |> mes("arrived and they're")
          |> mes("being guarded until")
          |> mes("you come to pick them up.")
          |> next()
          |> mes("[Ahman]")
          |> mes("Ah, that's very good to")
          |> mes("know. Say, are you a new")
          |> mes("worker for Lyozien and Kazien?")
          |> mes("I don't believe I've seen you")
          |> mes("around before. Have they finally started hiring part timers?")
          |> next()

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("[", char_name(ctx, 0)),
            "]"
          )
        )
        |> mes("Yes, that's right.")
        |> mes("Actually, I'm working for")
        |> mes("them part time. I heard")
        |> mes("they were really busy, so")
        |> mes("I sort of volunteered my time.")
        |> next()
        |> mes("[Ahman]")
        |> mes("Alright, alright.")
        |> mes("I suppose that you")
        |> mes("also don't know what's")
        |> mes("being delivered in these")
        |> mes("packages, just like Lyozien.")
        |> next()
        |> mes("[Ahman]")
        |> mes("Well, it's all confidential")
        |> mes("information anyway, so don't")
        |> mes("worry about it. Thank you for")
        |> mes("notifying me about the delivery.^FFFFFF  ^000000 Now, you should go back and ")
        |> mes("tell Lyozien. Take care now~")
        |> set_char_var(:lhz_rekenber, 10)
        |> changequest(12_012, 12_013)
        |> close()

      _ ->
        ctx
        |> mes("[Man]")
        |> mes("Hmm, can you really")
        |> mes("call this place an Airport?")
        |> mes("It's far too small, wouldn't")
        |> mes("you agree? Still, I kind of")
        |> mes("enjoy sitting around here.")
        |> close()
    end
  end
end
