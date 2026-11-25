defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMorocc.Alchemist do
  @moduledoc """
  Marius crafts Binoculars for adventurers.

  ## Behavior

  - He exchanges the required glasses, steel and zeny for Binoculars.

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
      %{name: "Alchemist", scope: :shared},
      %{
        map: "moc_ruins",
        x: 118,
        y: 176,
        dir: 4,
        sprite: 64,
        name: "Alchemist",
        scope: :pre_renewal,
        unique_name: "Alchemist#moc"
      },
      %{
        map: "morocc",
        x: 169,
        y: 168,
        dir: 4,
        sprite: 64,
        name: "Alchemist",
        scope: :renewal,
        unique_name: "Alchemist#moc"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Marius]")
      |> mes("Howdy, new customer!!")
      |> mes(
        "I know what you're gonna talk about. You want the Magic Glasses from me, riiiiight?"
      )
      |> next()
      |> select(["What is that?", "Manufacture", "Ignore him"])

    case choice do
      1 ->
        ctx
        |> mes("[Marius]")
        |> mes("Hmm~!")
        |> mes(
          "Well, the official name for them is ^3355FFBinoculars^000000! An optical device that works like a pair of field glasses, they're designed for simultaneous use by both eyes!"
        )
        |> next()
        |> mes("[Marius]")
        |> mes(
          "They're made up of two small telescopes joined with a single focusing device. You can arrange the lenses to produce stereoscopic vision."
        )
        |> next()
        |> mes("[Marius]")
        |> mes("So?")
        |> mes("Ain't that")
        |> mes("something, huh?")
        |> mes("Muhahahahahaha!")
        |> mes(". . . . .")
        |> next()
        |> mes("[Marius]")
        |> mes("Hm? You don't seem to")
        |> mes("believe what I just said?")
        |> mes("Oh c'mon, jerk. It's real!!")
        |> next()
        |> mes("[Marius]")
        |> mes("I will let you")
        |> mes("know the items I need...")
        |> mes("1 ^3355FFGeek Glasses^000000! 100 ^3355FFSteel^000000!")
        |> mes("And ^3355FF50000 Zeny^000000!")
        |> close()

      2 ->
        if count_item(ctx, 2243) > 0 and count_item(ctx, 999) > 99 and zeny(ctx) > 49999 do
          ctx
          |> mes("[Marius]")
          |> mes("Perfect, perfect !")
          |> mes("Now my masterpiece will be complete!")
          |> mes("Muhahahaha !")
          |> next()
          |> delitem(2243, 1)
          |> delitem(999, 100)
          |> pay_zeny(50000)
          |> mes("[Marius]")
          |> mes("Here you are!")
          |> mes("Binoculars !")
          |> give_item(2296, 1)
          |> next()
          |> mes("[Marius]")
          |> mes("Just remember...")
          |> mes("Don't peep at something you shouldn't look at. Well, at least try not to.")
          |> close()
        else
          ctx
          |> mes("[Marius]")
          |> mes("Argggghhhhhhh!!")
          |> mes("You didn't bring")
          |> mes("enough items!!!!")
          |> mes("How dare you")
          |> mes("disgrace me!!!")
          |> mes("Baaaadddd !!")
          |> close()
        end

      3 ->
        ctx
        |> mes("[Marius]")
        |> mes("Hey you~!")
        |> mes(
          "Now you're in front of Marius, an Alchemist among Alchemists. Ignoring me, eh? Come on, I'll beat your ass!"
        )
        |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
