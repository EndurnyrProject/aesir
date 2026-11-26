defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.YoungTownNative do
  @moduledoc """
  Directs the player to the town locksmith.

  ## Behavior

  - Identifies the locksmith and advances the siblings quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 221,
        y: 120,
        dir: 5,
        sprite: 943,
        name: "Young Town Native",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rachel_camel, 0) do
      3 ->
        ctx =
          ctx
          |> mes("[Native Young Man]")
          |> mes("My name is Toby.")
          |> mes("I was born and raised here,")
          |> mes("and no one knows more about")
          |> mes("this town than me. Feel free")
          |> mes("to ask if you need to find")
          |> mes("your way around here.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Excuse me, but do")
          |> mes("you know where I can")
          |> mes("find a locksmith?")
          |> next()
          |> mes("[Toby]")
          |> mes("Of course, I do!")
          |> mes("Mr. Lockenlock is a famous")
          |> mes("locksmith, and he makes almost")
          |> mes("all the keys and locks in Veins")
          |> mes("and even in Rachel.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Mr. Lockenlock, eh?")
          |> mes("So where can I find him?")
          |> next()
          |> mes("[Toby]")
          |> mes("Oh, he's always sitting")
          |> mes("somewhere in the market")
          |> mes("street. He drinks a lot,")
          |> mes("though, so he doesn't really")
          |> mes("work when he's hung over.")
          |> next()
          |> mes("[Toby]")
          |> mes("Ah, but you know what'll")
          |> mes("shock him back to sobriety?")
          |> mes("A Yellow Potion! It never")
          |> mes("fails with that guy!")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("I see.")
          |> mes("Thanks for")
          |> mes("the advice.")
          |> next()
          |> mes("[Toby]")
          |> mes("You're so very")
          |> mes("welcome! It's just...")
          |> mes("After all these years...")
          |> mes("I'm finally useful to someone!")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...Ha...?")
        |> next()
        |> mes("^3355FFFind Mr. Lockenlock")
        |> mes("in the market street, and")
        |> mes("bring him a Yellow Potion.^000000")
        |> changequest(3062, 3063)
        |> set_char_var(:rachel_camel, 4)
        |> close()

      4 ->
        ctx =
          ctx
          |> mes("[Toby]")
          |> mes("After all these years...")
          |> mes("I'm finally useful to someone!")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("...Ha...?")
        |> next()
        |> mes("^3355FFFind Mr. Lockenlock")
        |> mes("in the market street, and")
        |> mes("bring him a Yellow Potion.^000000")
        |> close()

      _ ->
        ctx =
          ctx
          |> mes("[Native Young Man]")
          |> mes("My name is Toby.")
          |> mes("I was born and raised here,")
          |> mes("and no one knows more about")
          |> mes("this town than me. Feel free")
          |> mes("to ask if you need to find")
          |> mes("your way around here.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("No, thanks.")
        |> next()
        |> mes("[Native Young Man]")
        |> mes("You don't...")
        |> mes("^333333*Sob*^000000 You don't")
        |> mes("need me at all?")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
