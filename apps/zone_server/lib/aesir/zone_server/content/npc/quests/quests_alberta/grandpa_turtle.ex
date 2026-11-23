defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.GrandpaTurtle do
  @moduledoc """
  Grandpa Turtle shares stories and starts the Turtle Island quest.

  ## Behavior

  - Shares island lore and directs adventurers to Gotanblue.
  - Starts the Turtle Island quest or clears its variable for returning adventurers.

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
        map: "alberta_in",
        x: 23,
        y: 104,
        dir: 4,
        sprite: 120,
        name: "Grandpa Turtle",
        scope: :shared,
        unique_name: "Grandpa Turtle#tur"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Grandpa Turtle]")
      |> mes("Ooog...")
      |> mes("So dizzy...")
      |> next()
      |> mes("[Grandpa Turtle]")
      |> mes(
        "There isn't one decent drinking establishment in all of Alberta! But then again, why did I drink so much? Hmm..."
      )
      |> next()
      |> select(["Tell me about Turtle Island", "How can I get there?", "Stop talking"])

    case choice do
      1 ->
        {ctx, story_choice} =
          ctx
          |> mes("[Grandpa Turtle]")
          |> mes("Eh...?")
          |> mes("Turtle Island?")
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes(
            "Well, there's a lot of folklore about that place. Some folk say that there's a mountain of treasure there."
          )
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes(
            "Others folk say a potion that can prolong your lifespan can be found somewhere in Turtle Island. But nobody really knows for sure."
          )
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes(
            "But I'm sure that Turtle Island does exist, and that something wonderful can be found there."
          )
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes(
            "But only someone with a good heart that's eager for adventure should be able to go to that kind of place."
          )
          |> next()
          |> select(["^3333FF*ting!*^000000", "Tell me more, old man!"])

        case story_choice do
          1 ->
            ctx = ctx |> mes("[Grandpa Turtle]") |> mes("Ha ha ha~!")

            ctx =
              if sex(ctx) == 1 do
                mes(
                  ctx,
                  "I like the shine in your eye, my boy! I can see a little bit of myself in those eyes. Yes..."
                )
              else
                mes(
                  ctx,
                  "No use hiding the glint in your eyes, my dear! It's adventure you wish for, that much I can tell..."
                )
              end

            ctx
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes("Tell me...")
            |> mes(
              "Have you heard of a man named ^3355FFJornadan Niliria^000000? He, and a group of ten other men actually found Turtle Island!"
            )
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes(
              "^3355FFJornadan Niliria^000000 was a man of strength and conviction. He and his crew gathered every clue they could about Turtle Island."
            )
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes(
              "Even after learning all that they could, much of their voyage relied on their hope and faith that the Turtle Island legend was true..."
            )
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes(
              "After a long, arduous journey, their efforts were rewarded, and they landed on Turtle Island!"
            )
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes(
              "However, it gets more complicated after that. I hear Niliria's crew had great difficulty getting back home for some reason."
            )
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes("Heh heh...")
            |> mes(
              "If you want to learn more, why don't you go to the eastern end of the Alberta port? There's a scholar there that knows more of this story."
            )
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes("He could probably shed more light on the subject of Turtle Island's legend.")
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes(
              "Ah, one more thing! Look around that scholar and you should find his ^3355FFJournal^000000. I promise that it will be an interesting read."
            )
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes("Ah...")
            |> mes("The fire of youth!")
            |> mes("When the winds die, may your dreams fill your sails~ Good luck to you!")
            |> close()

          _ ->
            ctx
            |> mes("[Grandpa Turtle]")
            |> mes("Grrrr...!")
            |> next()
            |> mes("[Grandpa Turtle]")
            |> mes(
              "I may not know much, but I won't talk to anyone motivated solely by greed. Go home!"
            )
            |> close()
        end

      2 ->
        if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 65536)) or
             Rathena.truthy?(get_char_var(ctx, :TURTLE, 0)) do
          ctx =
            if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 65536)) do
              set_char_var(ctx, :TURTLE, 0)
            else
              ctx
            end

          ctx
          |> mes("[Grandpa Turtle]")
          |> mes("Well...")
          |> mes(
            "If you go to eastern side of the Alberta port, you should find an old ferryboatman."
          )
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes(
            "His name is ^3355FFGotanblue^000000. I believe he may know a way to Turtle Island. Heh heh, good luck~"
          )
          |> close()
        else
          ctx
          |> mes("[Grandpa Turtle]")
          |> mes("Turtle Island...?")
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes(
            "My, that place is difficult to find and even more difficult to travel to. You're sure you want to go? I would love to give you some advice, but I feel so dizzy after drinking so much..."
          )
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes("Ho ho ho...")
          |> mes(
            "Why don't you talk to a chubby little sailor I know named ^3355FFGotanblue^000000. You can find him loitering on one of the Alberta ports."
          )
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes(
            "Tell him that I sent you, and he may tell you more about Turtle Island. He may even know how to get there~"
          )
          |> next()
          |> mes("[Grandpa Turtle]")
          |> mes("Well, then...")
          |> mes("Good luck~")
          |> set_char_var(:TURTLE, 1)
          |> setquest(11029)
          |> close()
        end

      3 ->
        ctx
        |> mes("[Grandpa Turtle]")
        |> mes("Oooh...")
        |> mes("Even at this age...")
        |> mes("I don't understand")
        |> mes("how I can drink so much...")
        |> close()

      _ ->
        ctx
    end
  end
end
