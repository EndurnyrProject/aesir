defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Kaijeta do
  @moduledoc """
  Kaijeta discusses her son Klitzer and the lovers' quest.

  ## Behavior

  - Advances the quest while sharing her hopes for Klitzer and Calla.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 191,
        y: 102,
        dir: 5,
        sprite: 846,
        name: "Kaijeta",
        scope: :shared,
        unique_name: "Kaijeta#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :EIN_LOVERQ, 0)

    cond do
      progress > 15 ->
        ctx
        |> mes("[Kaijeta]")
        |> mes("My son learned")
        |> mes("an awful lot from")
        |> mes("your good example.")
        |> mes("As a mother, I really")
        |> mes("appreciate everything")
        |> mes("you've done for him.")
        |> next()
        |> mes("[Kaijeta]")
        |> mes("Well, adventurer,")
        |> mes("I will be praying for")
        |> mes("your safety wherever")
        |> mes("your journeys may")
        |> mes("take you.")
        |> close()

      progress in [14, 15] ->
        ctx =
          ctx
          |> mes("[Kaijeta]")
          |> mes("Thank you for helping")
          |> mes("my son Klitzer. Sadly, the")
          |> mes("little fool doesn't have any")
          |> mes("clue when it comes to certain")
          |> mes("things like choosing clothing.")
          |> mes("He gets so nervous about it!")
          |> next()

        ctx =
          if progress == 14 do
            ctx |> set_char_var(:EIN_LOVERQ, 15) |> changequest(8086, 8087)
          else
            ctx
          end

        ctx
        |> mes("[Kaijeta]")
        |> mes("A man should wear nice")
        |> mes("clothes, like a Formal Suit")
        |> mes("or a Tuxedo, for important")
        |> mes("meetings and special occasions.")
        |> mes("Hopefully, he'll learn that soon.")
        |> close()

      progress == 8 ->
        ctx =
          ctx
          |> mes("[Kaijeta]")
          |> mes("I can't bear to see the")
          |> mes("petty hatred between our")
          |> mes("two towns stop my son from")
          |> mes("seeing the woman he loves...")

        ctx =
          if isbegin_quest(ctx, 8081) == 1 do
            changequest(ctx, 8081, 8082)
          else
            ctx
          end

        close(ctx)

      progress == 7 ->
        ctx
        |> mes("[Kaijeta]")
        |> mes("Thank you for helping my")
        |> mes("son. He may look like a fool")
        |> mes("for falling in love with someone from Einbroch, but he's an honest")
        |> mes("hard working man.")
        |> next()
        |> mes("[Kaijeta]")
        |> mes("Then again, it was bound to")
        |> mes("happen sometime. Einbech is")
        |> mes("a very poor town while Einbroch")
        |> mes(
          "is a very rich town. I'd understand if you don't agree, but opposites attract sooner or later."
        )
        |> next()
        |> mes("[Kaijeta]")
        |> mes("^666666*Sigh...*^000000")
        |> mes("If my son and Calla can")
        |> mes("work things out, maybe it")
        |> mes("would improve relations")
        |> mes("between our two towns.")
        |> mes("I certainly hope so...")
        |> next()
        |> mes("[Kaijeta]")
        |> mes("Still, I'm quite baffled!")
        |> mes("I raised my son to have more")
        |> mes("guts than to wallow in misery")
        |> mes("when his heart's broken. And")
        |> mes("I still have no idea how he got together with such a rich woman.")
        |> next()
        |> set_char_var(:EIN_LOVERQ, 8)
        |> mes("[Kaijeta]")
        |> mes("Do you have any idea")
        |> mes("how we can put an end")
        |> mes("to the hate between our")
        |> mes("two towns? I don't want to")
        |> mes("see this couple separated")
        |> mes("because of such pettiness.")
        |> close()

      true ->
        ctx
        |> mes("[Kaijeta]")
        |> mes("Welcome to my humble")
        |> mes("abode, adventurer. I'm")
        |> mes("sorry if I'm a poor host.")
        |> next()
        |> mes("[Kaijeta]")
        |> mes("As you can see, we have")
        |> mes("to share this house with")
        |> mes("other families so we don't")
        |> mes("have much open space or")
        |> mes("privacy. I'm afraid we can't")
        |> mes("afford even basic comfort.")
        |> next()
        |> mes("[Kaijeta]")
        |> mes("For now, this is the best")
        |> mes("we can do. We don't have")
        |> mes("the zeny to buy a house or")
        |> mes("land, so we have no choice")
        |> mes("but to endure through this...")
        |> close()
    end
  end
end
