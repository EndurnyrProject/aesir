defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsComodo.Chief do
  @moduledoc """
  Chief Tausupa guards Comodo and helps his friends stay in touch.

  ## Behavior

  - Discusses Comodo and exchanges messages with his friends during the quest.

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
        map: "cmd_in02",
        x: 32,
        y: 140,
        dir: 4,
        sprite: 49,
        name: "Chief",
        scope: :shared,
        unique_name: "Chief#cmd"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :dmdswrd_Q, 0)

    case progress do
      progress when progress > 4 ->
        describe_comodo(ctx)

      3 ->
        ctx
        |> mes("[Tausupa]")
        |> mes("Oh, how are my friends")
        |> mes("doing? I really wish that")
        |> mes("I could have delivered that")
        |> mes("Koserahserah personally,")
        |> mes("but I can't shirk my duties as")
        |> mes("Village Chief and protector.")
        |> next()
        |> mes("^3355FFYou give Tausupa the")
        |> mes("Meruchieligu wine that")
        |> mes("Rochito asked you to deliver.^000000")
        |> next()
        |> mes("[Tausupa]")
        |> mes("Ah... How very kind of")
        |> mes("them! They really sent me")
        |> mes("this wine? I'm truly touched...")
        |> mes("Rockha must have chosen")
        |> mes("this--I'll be sure to enjoy it.")
        |> next()
        |> mes("[Tausupa]")
        |> mes("Would you please express my")
        |> mes("thanks to my friends, ^3355FFRochito^000000,")
        |> mes("and ^3355FFRockha^000000? It's been far too")
        |> mes("long since I've seen them, but")
        |> mes("I hope that I get a chance to")
        |> mes("visit them someday soon.")
        |> set_char_var(:dmdswrd_Q, 4)
        |> close()

      4 ->
        ctx
        |> mes("[Tausupa]")
        |> mes("Would you please express my")
        |> mes("thanks to my friends, ^3355FFRochito^000000,")
        |> mes("and ^3355FFRockha^000000? It's been far too")
        |> mes("long since I've seen them, but")
        |> mes("I hope that I get a chance to")
        |> mes("visit them someday soon.")
        |> close()

      _ ->
        {ctx, choice} =
          ctx
          |> mes("[Tausupa]")
          |> mes("Greetings, adventurer,")
          |> mes("I am Tausupa, the Chief of")
          |> mes("Comodo, a city famous for its beauty and nightlife. I hope you")
          |> mes("enjoy your stay, whether you are seeking excitement or relaxation~")
          |> next()
          |> select(["About Casino", "About Banished Witch", "Cancel"])

        case choice do
          1 ->
            ctx
            |> mes("[Tausupa]")
            |> mes("Ah yes, Comodo is world")
            |> mes("famous for its Casino. There")
            |> mes("are many games that you can")
            |> mes("enjoy, but you'll need to use")
            |> mes("the Casino's special Eulwo currency and conversion system...")
            |> close()

          2 ->
            case get_char_var(ctx, :dmdswrd_Q, 0) do
              0 ->
                ctx
                |> mes("[Tausupa]")
                |> mes("Banished witch...?")
                |> mes("Ah ha ha, do not worry,")
                |> mes("my friend, that is merely")
                |> mes("a very old tale. Not worth")
                |> mes("your concern at all...")

              1 ->
                ctx
                |> mes("[Tausupa]")
                |> mes("Ah, judging from the scent")
                |> mes("of BBQ meat on your clothes,")
                |> mes("I'm guessing that you ran into")
                |> mes("Rochito in the campgrounds, ")
                |> mes("right? He must have told you that old story about the witch...")
                |> next()
                |> mes("[Tausupa]")
                |> mes("I'd like nothing better")
                |> mes("than to join them, but I must")
                |> mes("stay here. The witch does exist, and one my jobs is to make sure")
                |> mes("that she does not revive by using my sword's power to suppress her.")
                |> next()
                |> mes("[Tausupa]")
                |> mes("Although I planned to see")
                |> mes("them today, my duties must")
                |> mes("take priority. Would you please")
                |> mes("take this seasoning to Rochito")
                |> mes("and let him know that I can't")
                |> mes("come, and that I'm sorry...?")
                |> next()
                |> mes("^3355FFYou have received")
                |> mes("the Koserahserah")
                |> mes("seasoning from the Chief.^000000")
                |> next()
                |> mes("[Tausupa]")
                |> mes("Thank you so much...")
                |> mes("I understand that my")
                |> mes("friends cannot begin the")
                |> mes("barbeque without Comodo's")
                |> mes("world famous seasoning...")
                |> set_char_var(:dmdswrd_Q, 2)

              2 ->
                ctx
                |> mes("[Tausupa]")
                |> mes("Please take this special")
                |> mes("Koserserah seasoning to")
                |> mes("my friend ^3355FFRochito^000000 at the")
                |> mes("barbeque campground. Thanks")
                |> mes("again for your help, adventurer.")

              _ ->
                ctx
            end
            |> close()

          3 ->
            describe_comodo(ctx)

          _ ->
            ctx
        end
    end
  end

  defp describe_comodo(ctx) do
    ctx
    |> mes("[Tausupa]")
    |> mes("Maybe you can't tell because")
    |> mes("of the way the light reflects,")
    |> mes("but Comodo is actually built")
    |> mes("inside a huge cave, giving the")
    |> mes("illusion of an eternal night.")
    |> mes("It's quite beautiful, really...")
    |> next()
    |> mes("[Tausupa]")
    |> mes("People come from all over")
    |> mes("the world to experience the")
    |> mes("excitement and beauty of")
    |> mes("our unique little village.")
    |> mes("We've become quite")
    |> mes("the tourist attraction~")
    |> close()
  end
end
