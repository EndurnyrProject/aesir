defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.CampingYouth do
  @moduledoc """
  Rockha reunites with his friends at the campground.

  ## Behavior

  - Discusses their friendship and advances the quest after the Chief receives their gift.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Evera
    - Samuray22
    - Brainstorm

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 204,
        y: 310,
        dir: 4,
        sprite: 65,
        name: "Camping Youth",
        scope: :shared,
        unique_name: "Camping Youth#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx =
      case get_char_var(ctx, :dmdswrd_Q, 0) do
        v when v in [0, 1] ->
          {ctx, choice} =
            ctx
            |> mes("[Rockha]")
            |> mes("Oh man...")
            |> mes("I'm so excited!")
            |> mes("My buddies and I've")
            |> mes("been planning to get")
            |> mes("together for this barbeque")
            |> mes("for such a long time~")
            |> next()
            |> select(["Buddies...?", "Cancel"])

          if choice == 1 do
            ctx
            |> mes("[Rockha]")
            |> mes("Yeah, some of us know")
            |> mes("each other when we fought")
            |> mes("together in the War of the")
            |> mes("Witch. In fact, one of them")
            |> mes("is the Chief of this village!")
            |> mes("Huh, why isn't he here yet?")
            |> next()
            |> mes("[Rockha]")
            |> mes("Anyway, even though")
            |> mes("our stations in life have")
            |> mes("changed, thankfully we're")
            |> mes("still friends. It's kinda weird, though, being on a first name")
            |> mes("basis with a village chief.")
            |> next()
            |> mes("[Rockha]")
            |> mes("Makes me feel...")
            |> mes("Important. I'm hobnobbing")
            |> mes("with a major political figure,")
            |> mes("after all. Amazing where your")
            |> mes("friends can end up in life...")
          else
            ctx
            |> mes("[Rockha]")
            |> mes("I've almost forgotten")
            |> mes("how much I love hanging")
            |> mes("out with these guys. We")
            |> mes("should have barbeques")
            |> mes("together all the time~")
          end

        2 ->
          ctx
          |> mes("[Rockha]")
          |> mes("Wha--? Tausupa can't come,")
          |> mes("but he still sent us all of this Koserahserah? What a guy...")
          |> mes("I guess... That gives us")
          |> mes("a reason to hold another")
          |> mes("barbeque here soon, right?")

        3 ->
          ctx
          |> mes("[Rockha]")
          |> mes("Hey, when you deliver")
          |> mes("that wine to Tausupa, the")
          |> mes("Village Chief, would you let")
          |> mes("him know that we miss the guy?")
          |> mes("He may be busy, but he'll always be our irreplaceable buddy.")

        4 ->
          ctx
          |> mes("[Rockha]")
          |> mes("Oh hey, you spoke")
          |> mes("to Tausupa? Ah, it's")
          |> mes("too bad that he's busy,")
          |> mes("but it's great to hear that")
          |> mes("he'll enjoy our gift. Okay~")
          |> mes("I believe it's time to eat!")
          |> next()
          |> mes("[Rockha]")
          |> mes("But before that, let's")
          |> mes("make a toast... to Tausupa!")
          |> mes("Guardian of Comodo, and")
          |> mes("one of the best friends that")
          |> mes("a guy can have! Cheers!")
          |> mes("Hahahaha hahahaha~!")
          |> set_char_var(:dmdswrd_Q, 5)
          |> next()
          |> mes("[Rockha]")
          |> mes("Ahh, you know what would")
          |> mes("make this meal perfect?")
          |> mes("Some of that legendary")
          |> mes("^3355FFComodo Cheese^000000 that I heard")
          |> mes("about from ^3355FFToruna^000000. Sure, it")
          |> mes("might not exist, but still...!")

        _ ->
          ctx
          |> mes("[Rockha]")
          |> mes("You know, you're a really")
          |> mes("chill person. Thanks for")
          |> mes("helping us keep in touch")
          |> mes("with our old friend, the")
          |> mes("Village Chief. Man, being")
          |> mes("responsible must be rough...")
          |> next()
          |> mes("[Rockha]")
          |> mes("There's two things that")
          |> mes("would make our barbeque")
          |> mes("absolutely perfect--having")
          |> mes("the Village Chief here, and")
          |> mes("some of that legendary Comodo Cheese that ^3355FFToruna^000000 told me about.")
      end

    close(ctx)
  end
end
