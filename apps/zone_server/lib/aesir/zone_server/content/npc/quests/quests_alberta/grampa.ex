defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Grampa do
  @moduledoc """
  Grampa seeks Tiger’s Footskin to restore his youth.

  ## Behavior

  - Offers a Boys Cap in exchange for ten Tiger’s Footskins.

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
    spawn: [
      %{map: "alberta_in", x: 28, y: 145, dir: 4, sprite: 120, name: "Grampa", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Grampa]")
      |> mes("*Gasp*...")
      |> mes("....*Gasp!*")
      |> mes("Oh...")
      |> mes("Some may say I've lived a full life on wine, women and song...")
      |> next()
      |> mes("[Grampa]")
      |> mes(
        "But my soul still burns with youthful vigor! It's just... This old body can't keep up anymore... *Hack! Wheeeeze~*"
      )
      |> next()

    if count_item(ctx, 1030) > 9 do
      {ctx, choice} =
        select(ctx, ["Show him Tiger's Footskin.", "Exchange it with Boys Cap.", "Cancel"])

      case choice do
        1 ->
          ctx
          |> mes("[Grampa]")
          |> mes("Ohhh~ !!")
          |> mes("Is that...?")
          |> mes("It is! ")
          |> mes("That's Tiger's Footskin!! Even from here I can feel its powers!")
          |> next()
          |> mes("[Grampa]")
          |> mes(
            "One glance at it can restore your strength, one sniff and your blood boils with vigorous pleasure..."
          )
          |> next()
          |> mes("[Grampa]")
          |> mes("Just one bite...")
          |> mes(
            "Will revive my virility!!!! The Tiger's Footskin~!! Ohhhh! Ohh My God !! Please!!! Please give me that... Please..."
          )
          |> close()

        2 ->
          ctx
          |> delitem(1030, 10)
          |> give_item(5016, 1)
          |> mes("[Grampa]")
          |> mes("T... Thank you !!")
          |> mes(
            "With this I can revive my youthful splendor!! I must eat this thing right away !"
          )
          |> next()
          |> mes("[Grampa]")
          |> mes("...")
          |> mes("Nope. Still feel OLD.")
          |> mes("If anything, I feel even worse. Th-there's this buzzing in my head...")
          |> close()

        3 ->
          ctx |> mes("[Grampa]") |> mes("He...Hey, kid !! W-Wait !") |> close()

        _ ->
          ctx
      end
    else
      {ctx, topic} = select(ctx, ["Talk", "Cancel"])

      case topic do
        1 ->
          ctx
          |> mes("[Grampa]")
          |> mes("Listen well...")
          |> mes(
            "You've got to take care of yourself as well as your can. Without your health, one cannot enjoy the pleasures of this mortal realm."
          )
          |> next()
          |> mes("[Grampa]")
          |> mes(
            "In order to restore my youth, I tried all sorts of things, mostly by hearsay, but nothing worked. In the end, I spent so much zeny on miracle cures, I ended up broke."
          )
          |> next()
          |> mes("[Grampa]")
          |> mes(
            "I've mostly given up on restoring my youth. But there is one hope left... Eating ^3355FFTiger's Footskin^000000, The King of Invigorators!!"
          )
          |> next()
          |> mes("[Grampa]")
          |> mes(
            "Haven't you heard?! One glance would restore the color in my white hair, one sniff, even just one touch, and an 80 year-old would have another chance at youth... It's The King of Invigorators !"
          )
          |> next()
          |> mes("[Grampa]")
          |> mes("Before I die...")
          |> mes("I wish I could eat 10 Tiger's Footskin. Then, I wouldn't have to die!")
          |> next()
          |> mes("[Grampa]")
          |> mes(
            "If someone helped me get them, I would give that person my precious item, ^3355FFBoys Cap^000000 without regret..."
          )
          |> close()

        2 ->
          ctx
          |> mes("[Grampa]")
          |> mes("Cough Cough !!")
          |> mes("Tiger ....Tiger's ..... Foot ..... skin .....Cough Cough !!")
          |> close()

        _ ->
          ctx
      end
    end
  end
end
