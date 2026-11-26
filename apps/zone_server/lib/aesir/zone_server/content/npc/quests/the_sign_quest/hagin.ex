defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Hagin do
  @moduledoc """
  Hagin tells visitors about her admiration for Daewoon.

  ## Behavior

  - Describes Daewoon and directs interested visitors to the castle annex.
  - Responds differently to men and women who want to meet him.

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
      %{
        map: "payon",
        x: 154,
        y: 170,
        dir: 3,
        sprite: 78,
        name: "Hagin",
        scope: :shared,
        unique_name: "Hagin#sign"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hagin]")
      |> mes("Have you heard?")
      |> mes("Payon's most eligible")
      |> mes("bachelor is back home!")
      |> next()
      |> mes("[Hagin]")
      |> mes("He was a little brat")
      |> mes("back when he was a kid,")
      |> mes("but now he's grown up to")
      |> mes("be the manliest of men!")
      |> mes("No wonder all the ladies")
      |> mes("just can't resist him!")
      |> next()
      |> mes("[Hagin]")
      |> mes("Heh heh...")
      |> mes("With this beautiful")
      |> mes("face and charming figure...")
      |> mes("I'm gonna seduce him.")
      |> next()
      |> select(["Who are you talking about?", "You're freaking me out!"])

    case choice do
      1 ->
        describe_daewoon(ctx)

      2 ->
        ctx
        |> mes("[Hagin]")
        |> mes("Freaking you out?")
        |> mes("Excuuuuse me~!")
        |> mes("I'll have you know that")
        |> mes("a flower's life is brief.")
        |> mes("I better snag Daewoon")
        |> mes("while I still can~")
        |> emotion(:fret)
        |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp describe_daewoon(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Hagin]")
      |> mes("You don't know")
      |> mes("Daewoon, the most")
      |> mes("beautiful man in all")
      |> mes("of Payon and maybe")
      |> mes("even the world?")
      |> next()
      |> mes("[Hagin]")
      |> mes("He left home to become stronger")
      |> mes("when he was just a boy. I had no idea he would come back as such ")
      |> mes("a fine specimen of a man...")
      |> next()
      |> select(["I'd like to meet this Daewoon."])

    ctx = ctx |> mes("[Hagin]") |> mes("Oh, I see~")

    ctx =
      if sex(ctx) == 1 do
        ctx
        |> mes("You plan to ask him")
        |> mes("to show you some fighting")
        |> mes("pointers, do you? You men")
        |> mes("are all the same: not as")
        |> mes("cool or tough as Daewoon!")
      else
        ctx
        |> mes("Interested, are you?")
        |> mes("Well, you'll have to get")
        |> mes("in line. So many women")
        |> mes("and only one Daewoon...")
        |> mes("^333333*Sigh*^000000")
      end

    ctx
    |> next()
    |> mes("[Hagin]")
    |> mes("Anyway, Daewoon")
    |> mes("is staying in the annex")
    |> mes("to the Payon Castle. If you")
    |> mes("want to see him for yourself,")
    |> mes("why don't you go there?")
    |> close()
  end
end
