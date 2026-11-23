defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.LittleBoy do
  @moduledoc """
  Iromo's friend helps identify his favorite food.

  ## Behavior

  - Requests a banana and reveals what Iromo likes to eat.

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
      %{
        map: "alberta",
        x: 45,
        y: 106,
        dir: 5,
        sprite: 706,
        name: "Little Boy",
        scope: :shared,
        unique_name: "Little Boy#ep3_2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_2_hiki, 0) == 6 ->
        ctx
        |> mes("[Little Boy]")
        |> mes(
          "Iromo? He used to like ^FF0000Monster's Feed^000000 and ^FF0000Red Potion^000000."
        )
        |> next()
        |> mes("[Little Boy]")
        |> mes("Oh ya and one more thing~!")
        |> mes("I like Bananas. Haha.")
        |> close()

      get_char_var(ctx, :ep13_2_hiki, 0) == 5 ->
        ctx
        |> mes("[Little Boy]")
        |> mes("......")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Yummy! Banana is always delicious!")
        |> mes("Bananas are the best fruits ever!")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Thanks for the Banana...")
        |> mes("Now I can think about")
        |> mes("what Iromo likes to eat.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("He used to like junk food.")
        |> mes("You know, cheap and weird tasting snacks...")
        |> mes("So he had to hide when he had them.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("His mother wouldn't let him")
        |> mes("have those kind of snacks...")
        |> mes("So he hid them from her.")
        |> mes("I don't know why he liked")
        |> mes("those junk foods anyways.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("He usually enjoyed having")
        |> mes("Monster's Feed.")
        |> mes("He said it is good")
        |> mes("with Red Potion soup.")
        |> mes("He always had a Red Potion and Monster's Feed for his lunch.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("He's got a weird appetite.")
        |> mes("I can't understand why he liked")
        |> mes("those foods. He was odd...")
        |> next()
        |> set_char_var(:ep13_2_hiki, 6)
        |> changequest(10082, 10083)
        |> mes("[Little Boy]")
        |> mes("Anyway, I already told you")
        |> mes("what I know about him.")
        |> mes("So, I am done now.")
        |> mes("Let me know if you have more Bananas. Haha.")
        |> mes("I love Bananas~~!")
        |> close()

      get_char_var(ctx, :ep13_2_hiki, 0) == 4 and count_item(ctx, 513) > 0 ->
        ctx
        |> mes("[Little Boy]")
        |> mes("Huh? What a delicious smell!")
        |> mes("You brought me Bananas!")
        |> mes("Oh, thanks so much!")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Let me have them first.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Chew, chew...")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Yum Yum...")
        |> next()
        |> delitem(513, 1)
        |> set_char_var(:ep13_2_hiki, 5)
        |> changequest(10081, 10082)
        |> mes("[Little Boy]")
        |> mes("Wait. Wait...")
        |> mes("***Gulp***")
        |> mes("just a second...")
        |> mes("Wait.")
        |> close()

      get_char_var(ctx, :ep13_2_hiki, 0) == 4 ->
        ctx
        |> mes("[Little Boy]")
        |> mes("Banana~banana~")
        |> mes("I love bananas~")
        |> next()
        |> mes("[Little Boy]")
        |> mes("They don't sell bananas in this village...")
        |> mes("I am eager to have bananas.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Oh~ you promised!")
        |> mes("Bring bananas for me~!! I will wait for you!")
        |> close()

      get_char_var(ctx, :ep13_2_hiki, 0) == 3 ->
        ctx
        |> mes("[Little Boy]")
        |> mes("I am hungry. We don't have")
        |> mes("much snack bar in this village.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Huh? Iromo?")
        |> mes("Oh, I haven't seen him for a long time...")
        |> mes("Hum.. Where is he?")
        |> mes("Did he move out?")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Huh? His favorite food?.")
        |> mes("Hum.. What was it..?")
        |> next()
        |> mes("[Little Boy]")
        |> mes("If I can remember it can you buy me a banana?")
        |> next()
        |> mes("[Little Boy]")
        |> mes("Banana~banana~")
        |> mes("I love bananas~")
        |> next()
        |> mes("[Little Boy]")
        |> mes("They don't sell bananas in this village...")
        |> mes("I am eager to have bananas.")
        |> next()
        |> set_char_var(:ep13_2_hiki, 4)
        |> changequest(10080, 10081)
        |> mes("[Little Boy]")
        |> mes("Oh, you will buy me a banana?")
        |> mes(
          "I'll try to remember what Iromo's favorite food is for sure if you bring it to me."
        )
        |> close()

      true ->
        ctx
        |> mes("[Little Boy]")
        |> mes("I am hungry. We don't have")
        |> mes("much snack bar in this village.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("I hope they sell bananas")
        |> mes("in this village.")
        |> mes("Like other nice villages.")
        |> next()
        |> mes("[Little Boy]")
        |> mes("This village is so boring...")
        |> mes("What a small village.")
        |> close()
    end
  end
end
