defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.TorpySMom do
  @moduledoc """
  Torpy's mother searches for her missing husband.

  ## Behavior

  - Advances the Hide and Seek Quest and rewards the adventurer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Corrected transpiled EF_CONE and EF_MVP variable reads to effect atoms.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_fild06",
        x: 190,
        y: 367,
        dir: 3,
        sprite: 701,
        name: "Torpy's Mom",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @green_salad 12_065

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :hg_ubu01, 0)

    case quest do
      1 ->
        ctx
        |> mes("[Torpy's Mom]")
        |> mes("Hmm? Oh, you talked to")
        |> mes("my little Torpy? He thinks his")
        |> mes("father and I just vanished?")
        |> mes("Oh, I'm so sorry, I think there's been some misunderstanding!")
        |> next()
        |> mes("[Torpy's Mom]")
        |> mes("Although Torpy's father has")
        |> mes("been missing for a little")
        |> mes("while, I just stepped out of")
        |> mes("the house this morning. So")
        |> mes("I haven't even been gone for")
        |> mes("a few hours, much less a day.")
        |> next()
        |> mes("[Torpy's Mom]")
        |> mes("You see, my husband is")
        |> mes("a hunter, so it's usual for him")
        |> mes("not to come home for a few")
        |> mes("days. Still, he's never been")
        |> mes("gone for this long before,")
        |> mes("so I've been looking for him...")
        |> next()
        |> mes("[Torpy's Mom]")
        |> mes("I've been getting a little")
        |> mes("worried myself, honestly.")
        |> mes("He's not in any of his usual")
        |> mes("hunting grounds. Hopefully,")
        |> mes("if I wait here long enough,")
        |> mes("he'll show up sooner or later.")
        |> next()
        |> mes("[Torpy's Mom]")
        |> mes("If he doesn't show up")
        |> mes("today, I better search")
        |> mes("for him inside town. Maybe")
        |> mes("he's hiding somewhere,")
        |> mes("like at his friend's house.")
        |> mes("Why is like always like this?")
        |> next()
        |> mes("[Torpy's Mom]")
        |> mes("Listen, would you please")
        |> mes("tell my son Torpy that I'm")
        |> mes("fine and will be coming back")
        |> mes("home soon? Also, if you see")
        |> mes("my husband inside town, tell")
        |> mes("him that he better come home!")
        |> set_char_var(:hg_ubu01, 2)
        |> changequest(12044, 12045)
        |> close()

      2 ->
        ctx
        |> mes("[Torpy's Mom]")
        |> mes("Listen, would you please")
        |> mes("tell my son Torpy that I'm")
        |> mes("fine and will be coming back")
        |> mes("home soon? Also, if you see")
        |> mes("my husband inside town, tell")
        |> mes("him that he better come home!")
        |> close()

      value when value in [6, 7] ->
        ctx =
          ctx
          |> mes("[Torpy's Mom]")
          |> mes("What?! He was hiding")
          |> mes("inside a barrel this")
          |> mes("entire time?! Oh, no.")
          |> mes("I'm sorry, my husband has")
          |> mes("caused you so much trouble.")
          |> next()
          |> mes("[Torpy's Mom]")
          |> mes("I really appreciate")
          |> mes("everything you've done")
          |> mes("to help us find him. I know")
          |> mes("it's not much, but I hope")
          |> mes("you accept this as our thanks.")
          |> mes("Goodbye for now, adventurer~")

        ctx =
          ctx
          |> specialeffect2(
            if quest == 6,
              do: :cone,
              else: :mvp
          )
          |> set_char_var(:hg_ubu01, 8)
          |> completequest(12048)
          |> give_item(@green_salad, 3)

        ctx
        |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 5000, else: 50000), 0)
        |> close()

      8 ->
        ctx
        |> mes("[Torpy's Mom]")
        |> mes("Sometimes I wonder if")
        |> mes("Torpy is too mature for")
        |> mes("his age, or if my husband")
        |> mes("is too immature. In a strange")
        |> mes("way, those two really take")
        |> mes("after each other. Oh, well...")
        |> close()

      9 ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("[Torpy's Mom]")
        |> mes("When is that husband")
        |> mes("of mine going to come")
        |> mes("out of that barrel? He")
        |> mes("didn't make another weird")
        |> mes("bet with Torpy, did he? Oh,")
        |> mes("the trouble with those two...")
        |> close()

      _ ->
        ctx
        |> mes("[Torpy's Mom]")
        |> mes("Where did he go this time?!")
        |> mes("If my husband doesn't have")
        |> mes("a good excuse for not coming")
        |> mes("home, then he better come")
        |> mes("up with one or he'll be sorry!")
        |> close()
    end
  end
end
