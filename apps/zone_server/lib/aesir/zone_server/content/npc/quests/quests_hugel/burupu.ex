defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.Burupu do
  @moduledoc """
  Burupu bargains for a rapier and directs players to his cow-milking notes.

  ## Behavior

  - Advances the search for Burupu and exchanges a rapier for the instructions.
  - Takes time off when the player agrees to milk Booboo again.

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
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hu_fild06",
        x: 217,
        y: 270,
        dir: 3,
        sprite: 896,
        name: "Burupu",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnTouch_", ctx) do
    touch(ctx)
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_milk, 0) do
      3 ->
        ctx
        |> mes("[Burupu]")
        |> mes("What? Kurupe wants me")
        |> mes("to come in to work again?")
        |> mes("Man, does it look like I want")
        |> mes("to milk Booboo all my life?")
        |> mes("Forget that, I'm gonna be")
        |> mes("a Swordman! Tally-hoooe!")
        |> next()
        |> mes("[Burupu]")
        |> mes("Yeah, ever since that")
        |> mes("Airship landed in our")
        |> mes("town, and I saw all those")
        |> mes("Swordmen, I knew it'd be")
        |> mes("my destiny! Forget ranching, I'm gonna wield a frickin' sword!")
        |> set_char_var(:hg_milk, 4)
        |> close()

      4 ->
        {ctx, choice} =
          ctx
          |> mes("[Burupu]")
          |> mes("Hey, that equipment of")
          |> mes("yours looks plenty expensive.")
          |> mes("I think I'll need something")
          |> mes("like that if I wanna become")
          |> mes("a Swordman. Hey, I know")
          |> mes("how we can help each other~")
          |> next()
          |> mes("[Burupu]")
          |> mes("I'll help you with milking")
          |> mes("Booboo the cow if you can get")
          |> mes("me some proper Swordman")
          |> mes("equipment. Let's see... Why not")
          |> mes("give me 1 Rapier with 2 Slots? That's not too much to ask, right?")
          |> next()
          |> select(["Alright.", "Whoa, that's too much!"])

        case choice do
          1 ->
            ctx
            |> mes("[Burupu]")
            |> mes("I'm glad you agree~")
            |> mes("Okay then, try to bring")
            |> mes("me a Rapier with 2 Slots")
            |> mes("as soon as you can! I can't")
            |> mes("wait to start training with it!")
            |> set_char_var(:hg_milk, 5)
            |> changequest(12040, 12041)
            |> close()

          2 ->
            ctx
            |> mes("[Burupu]")
            |> mes("You think so...?")
            |> mes("Well, it's the only")
            |> mes("thing I can think of")
            |> mes("that I really want...")
            |> close()

          _ ->
            ctx
        end

      5 ->
        if not Rathena.truthy?(count_item(ctx, 1110)) do
          ctx
          |> mes("[Burupu]")
          |> mes("Hey, weren't you")
          |> mes("supposed to bring me")
          |> mes("a Rapier with 2 Slots?")
          |> mes("If you want me to milk")
          |> mes("Booboo the cow, then keep")
          |> mes("your end of our bargain~")
          |> close()
        else
          ctx
          |> mes("[Burupu]")
          |> mes("Oh, wow...!")
          |> mes("That's such a beautiful")
          |> mes("Rapier! Look, it's got")
          |> mes("2 Slots and everything!")
          |> mes("I'm gonna start training")
          |> mes("with it right now!")
          |> delitem(1110, 1)
          |> set_char_var(:hg_milk, 6)
          |> changequest(12041, 12042)
          |> next()
          |> mes("[Burupu]")
          |> mes("You know what?")
          |> mes("I've changed my mind.")
          |> mes("Screw milking that dumb cow!")
          |> mes("Still, a Swordman is supposed")
          |> mes("to keep his promises, huh?")
          |> mes("Okay then, how about this?")
          |> next()
          |> mes("[Burupu]")
          |> mes("I hid my secret instructions")
          |> mes("for milking Booboo the cow")
          |> mes("under the ground just northeast")
          |> mes("of her. Read them carefully, and you should be able to milk her")
          |> mes("yourself. You can do it, right?")
          |> next()
          |> mes("[Burupu]")
          |> mes("Anyway, don't forget")
          |> mes("to find and read those")
          |> mes("instructions. Oh, and")
          |> mes("thanks again for the Rapier~")
          |> close()
        end

      10 ->
        ctx
        |> mes("[Burupu]")
        |> mes("Hmm? You wanna milk")
        |> mes("Booboo today? Great,")
        |> mes("that means I've got more")
        |> mes("time to work on my fencing.")
        |> mes("All right, now I can focus")
        |> mes("completely on my training!")
        |> set_char_var(:hg_milk, 11)
        |> close()

      _ ->
        ctx
        |> mes("[Burupu]")
        |> mes("I'm gonna become the")
        |> mes("best Swordman in the")
        |> mes("world! But first, I gotta")
        |> mes("learn how to use this thing!")
        |> mes("Heeeeee-YAH! How's that? That was almost a Magnum Break, right?")
        |> emotion(:profusely_sweat)
        |> close()
    end
  end

  defp touch(ctx) do
    case get_char_var(ctx, :hg_milk, 0) do
      2 ->
        ctx
        |> mes("[Burupu]")
        |> mes("Heeeyah!")
        |> mes("Yaaaaaaaah!")
        |> mes("Wh-whooooooosh!")
        |> emotion(:profusely_sweat)
        |> next()
        |> mes("[Burupu]")
        |> mes("Crap! Why do I have")
        |> mes("to have such a crappy")
        |> mes("sword?! I mean, I'm getting")
        |> mes("tired of making all my own")
        |> mes("whooshing sounds and effects.")
        |> set_char_var(:hg_milk, 3)
        |> emotion(:fret)
        |> close()

      5 ->
        ctx
        |> mes("[Burupu]")
        |> mes("Heeeyah!")
        |> mes("Yaaaaaaaah!")
        |> mes("Yeeeeeeeyoooop!")
        |> emotion(:profusely_sweat)
        |> close()

      _ ->
        ctx
    end
  end
end
