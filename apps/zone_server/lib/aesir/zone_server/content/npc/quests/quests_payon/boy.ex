defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsPayon.Boy do
  @moduledoc """
  A young man plagued by Thief Bugs who trades an Oxygen Mask for 5 Ora Ora.

  ## Behavior

  - Without 5 Ora Ora he can tell the story of his bug-infested house, which hints at the
    Ora Ora he needs.
  - With 5 Ora Ora the player can show them (no trade), give them for an Oxygen Mask, or cancel.
  - Giving re-checks the Ora Ora count before taking them, but the Oxygen Mask is given either way.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - Silent
    - Samuray22
    - L0ne_W0lf
    - JohnnyPlayy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "payon_in02", x: 25, y: 71, dir: 4, sprite: 86, name: "Boy", scope: :shared}]

  @speaker "[Young Man]"

  @ora_ora 701
  @oxygen_mask 5004

  @impl true
  def on_talk(ctx) do
    if count_item(ctx, @ora_ora) >= 5, do: ora_ora_offer(ctx), else: bug_complaint(ctx)
  end

  defp ora_ora_offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("ArrrGggghh!")
      |> mes("Ah, No I can't...")
      |> next()
      |> mes(@speaker)
      |> mes("*Huk*")
      |> mes(
        "Now even my eyes have gone mad!! Why do these bugs suddenly seem so cute?! Nooooooo~!!!"
      )
      |> next()
      |> select(["Show Ora Ora", "Give Ora Ora", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes(@speaker)
        |> mes("Oooooohhhh!!!")
        |> mes("Is, is this")
        |> mes("the one?!")
        |> mes("This is...")
        |> mes("Ora Ora!!")
        |> next()
        |> mes(@speaker)
        |> mes(
          "I'll make it short! Give it to me, and I will give you my treasure! So how's my idea? Wanna deal?"
        )
        |> close()

      2 ->
        trade_ora_ora(ctx)

      3 ->
        ctx
        |> mes(@speaker)
        |> mes("Huhuhuhuhu...")
        |> mes(
          "What if I can't get rid of all these Thief Bugs? I might even grow to love them... *Huk*"
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp trade_ora_ora(ctx) do
    ctx = if count_item(ctx, @ora_ora) >= 5, do: delitem(ctx, @ora_ora, 5), else: ctx

    ctx
    |> mes(@speaker)
    |> mes("Muhahahahah!!!")
    |> mes("I finally have this!")
    |> mes("Ora Ora!")
    |> mes("Stupid and Disgusting")
    |> mes("Thief Bugs!!")
    |> mes("You will pay!!!")
    |> next()
    |> mes(@speaker)
    |> mes("Huk...Huk...")
    |> mes(
      "Sorry, I was out of control with pleasure for a while. Now, I will give my treasure as promised."
    )
    |> next()
    |> give_item(@oxygen_mask, 1)
    |> mes(@speaker)
    |> mes(
      "When you wear this over your mouth and start to breathe, it filters junk out before getting to your lungs."
    )
    |> next()
    |> mes(@speaker)
    |> mes("Kakakakakaka!")
    |> mes("I can't wait")
    |> mes("to use this")
    |> mes("Ora Ora!")
    |> close()
  end

  defp bug_complaint(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("Wahhhhhh! I, I...")
      |> mes("I can't take it any more!")
      |> mes("You little stinky filthy bastards!")
      |> next()
      |> select(["Continue", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes(@speaker)
        |> mes("Oh man...")
        |> mes(
          "It all started when my parents passed away when I was a little kid. Early on I had to work for a living, and had a really hard time."
        )
        |> next()
        |> mes(@speaker)
        |> mes(
          "I've worked for 10 years in hopes of buying my dream house where I could find some sense of peace and comfort again. Eventually I thought I had enough zeny to afford my very own sweet home."
        )
        |> next()
        |> mes(@speaker)
        |> mes(
          "Unfortunately I didn't have enough money to buy the nice house that I had my eye on. But then, I found this house, which was bigger and cheaper than the first. I bought it without thinking..."
        )
        |> next()
        |> mes(@speaker)
        |> mes("Sweet Jesus! Turns out, it's a Heaven for Thief Bugs!!!")
        |> next()
        |> mes(@speaker)
        |> mes(
          "I tried to do everything I could do. I coaxed them, killed them, but it only brought peace for a moment! I even tried to burn this house down...!"
        )
        |> next()
        |> mes(@speaker)
        |> mes(
          "*Gasp* I mean, really, do I need ^3355FF Ora Ora^000000 to get rid of them? People say it is very rarely seen in distant countries."
        )
        |> next()
        |> mes(@speaker)
        |> mes(
          "If I could afford 5 of them, I won't have to be frustrated with these disgusting bugs any more..."
        )
        |> close()

      2 ->
        ctx
        |> mes(@speaker)
        |> mes(
          "This never ending fight with the bugs has really exhausted me. I give up. Do as you wish you scumbags!"
        )
        |> close()

      _ ->
        ctx
    end
  end
end
