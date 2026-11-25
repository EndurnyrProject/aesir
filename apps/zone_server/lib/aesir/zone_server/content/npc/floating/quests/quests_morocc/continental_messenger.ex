defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMorocc.ContinentalMessenger do
  @moduledoc """
  The Continental Guard messenger warns adventurers about Satan Morocc.

  ## Behavior

  - The warning and recruitment appeal depend on the adventurer’s level.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        name: "Continental Messenger",
        scope: :shared,
        unique_name: "ConMessenger",
        hidden_name: "00"
      },
      %{
        map: "prontera",
        x: 164,
        y: 304,
        dir: 3,
        sprite: 997,
        name: "Continental Messenger",
        scope: :shared,
        unique_name: "Continental Messenger#01",
        trigger: {3, 3}
      },
      %{
        map: "geffen",
        x: 128,
        y: 90,
        dir: 3,
        sprite: 997,
        name: "Continental Messenger",
        scope: :shared,
        unique_name: "Continental Messenger#02",
        trigger: {3, 3}
      },
      %{
        map: "payon",
        x: 200,
        y: 113,
        dir: 3,
        sprite: 997,
        name: "Continental Messenger",
        scope: :shared,
        unique_name: "Continental Messenger#03",
        trigger: {3, 3}
      },
      %{
        map: "alberta",
        x: 127,
        y: 64,
        dir: 3,
        sprite: 998,
        name: "Continental Messenger",
        scope: :shared,
        unique_name: "Continental Messenger#04",
        trigger: {3, 3}
      },
      %{
        map: "aldebaran",
        x: 135,
        y: 128,
        dir: 3,
        sprite: 998,
        name: "Continental Messenger",
        scope: :shared,
        unique_name: "Continental Messenger#05",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ctx = set_local(ctx, :"area$", strnpcinfo(ctx, 2))

    ctx =
      case get_local(ctx, :"area$", "") do
        "01" -> set_local(ctx, :"area$", "Prontera")
        "02" -> set_local(ctx, :"area$", "Geffen")
        "03" -> set_local(ctx, :"area$", "Payon")
        "04" -> set_local(ctx, :"area$", "Alberta")
        "05" -> set_local(ctx, :"area$", "Al De Baran")
        _ -> ctx
      end

    if base_level(ctx) > 79 do
      ctx = mes(ctx, "[Continental Guard Messenger]")

      ctx =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("Good day, ", char_name(ctx, 0)),
            ". We don't have the luxury of time in this dire situation so I'll try to make this quick."
          )
        )
        |> next()
        |> mes("[Continental Guard Messenger]")

      {ctx, _} =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              Rathena.concat(
                Rathena.concat(
                  "I'm a messenger dispatched here to ",
                  get_local(ctx, :"area$", "")
                ),
                " from the Morocc Continental Guard Headquarters. My duty is to deliver this important message to as many renowned adventurers as I can. I'm glad that I was finally able to find you, "
              ),
              char_name(ctx, 0)
            ),
            "."
          )
        )
        |> next()
        |> select(["Morocc Continental Guard Headquarters?"])

      ctx =
        ctx
        |> mes("[Continental Guard Messenger]")
        |> mes("Time's running out, so I can only give you a brief explanation.")
        |> next()
        |> mes("[Continental Guard Messenger]")
        |> mes(
          "Satan Morocc, the heinous demon imprisoned deep in Morocc's underground for centuries, has resurrected and broken free."
        )
        |> next()
        |> mes("[Continental Guard Messenger]")
        |> mes(
          "The revival of Satan Morocc has completely devastated Morocc Village and the area surrounding it."
        )
        |> next()
        |> mes("[Continental Guard Messenger]")
        |> mes(
          "All of the death and suffering... Anywhere else must seem like heaven compared to what's happening in and around Morocc."
        )
        |> next()
        |> mes("[Continental Guard Messenger]")
        |> mes(
          "The Morocc Continental Guard was immediately organized to fight Satan Morocc and bring relief to this dire situation. I'm here to inform everyone in the Rune-Midgarts Kingdom about this catastrophe."
        )
        |> next()
        |> mes("[Continental Guard Messenger]")

      ctx =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("We need your help, ", char_name(ctx, 0)),
            ". We need reputable adventurers like you to seal away Satan Morocc once again."
          )
        )
        |> next()
        |> mes("[Continental Guard Messenger]")

      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "For more information, please speak to the captain of the Morocc Continental Guard. He is waiting for you, ",
            char_name(ctx, 0)
          ),
          "."
        )
      )
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "The Continental Guard Headquarters is located near the center palace of Morocc, so please go speak to the chief as soon as you can."
      )
      |> close()
    else
      ctx = mes(ctx, "[Continental Guard Messenger]")

      {ctx, _} =
        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat(
              "I'm a messenger from the Morocc Continental Guards Headquarters, and I've come here to ",
              get_local(ctx, :"area$", "")
            ),
            " with an urgent message for everyone here in Rune-Midgarts Kingdom."
          )
        )
        |> next()
        |> select(["Morocc Continental Guard Headquarters?"])

      ctx
      |> mes("[Continental Guard Messenger]")
      |> mes("Time's running out, so I can only give you a brief explanation.")
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "Satan Morocc, the heinous demon imprisoned deep in Morocc's underground for centuries, has resurrected and broken free."
      )
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "The revival of Satan Morocc has completely devastated Morocc Village and the area surrounding it."
      )
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "All of the death and suffering... Anywhere else must seem like heaven compared to what's happening in and around Morocc."
      )
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "The Morocc Continental Guard was immediately organized to fight Satan Morocc and bring relief to this dire situation. I'm here to inform everyone in the Rune-Midgarts Kingdom about this catastrophe."
      )
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "Part of my duty is to help recruit adventurers from around the world to help drive Satan Morocc back into confinement. It won't be easy, but he was defeated once before. Satan Morocc can be sealed away again."
      )
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "At least 70% of Morocc Village was destroyed by the fallout of Satan Morocc's resurrection."
      )
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes(
        "The desert around Morocc has also turned into a land of death after it was claimed by Satan Morocc and his powerful doppelgangers and underlings."
      )
      |> mes(
        "So heed my warning, stay away from the Morocc area unless you're on a mission organized by the Morocc Continental Guard."
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if base_level(ctx) > 79 do
      ctx
      |> mes("[Continental Guard Messenger]")
      |> mes(Rathena.concat(Rathena.concat("Are you... ", char_name(ctx, 0)), "?"))
      |> mes("Ah, very well. I have an extremely important message for you.")
      |> next()
      |> mes("[Continental Guard Messenger]")
      |> mes("The situation is urgent, so please listen to me carefully.")
      |> close()
    else
      ctx
    end
  end
end
