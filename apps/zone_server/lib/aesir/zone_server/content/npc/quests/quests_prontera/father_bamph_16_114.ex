defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.FatherBamph16114 do
  @moduledoc """
  Guides the player through examining the Geoborg princes' bodies.

  ## Behavior

  - Gives instructions for each stage of the examination and advances the quest after key discoveries.
  - Directs the player upstairs after the examination.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 16,
        y: 114,
        dir: 4,
        sprite: 60,
        name: "Father Bamph",
        scope: :shared,
        unique_name: "Father Bamph#tomb"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :prt_curse, 0) do
      18 ->
        ctx
        |> mes("[Father Bamph]")
        |> mes("There are the bodies")
        |> mes("of the Geoborg princes")
        |> mes("that were killed during")
        |> mes("the exorcism. Please take")
        |> mes("a look at the body to the left.")
        |> set_char_var(:prt_curse, 19)
        |> close()

      19 ->
        ctx
        |> mes("[Father Bamph]")
        |> mes("Please take a look")
        |> mes("at the body to the")
        |> mes("far left, the first prince.")
        |> close()

      20 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("That weird mark looked")
        |> mes("just like snake scales.")
        |> mes("Is... Is that the mark left")
        |> mes("behind by Jormungand's curse?")
        |> next()
        |> mes("[Father Bamph]")
        |> mes("That's right.")
        |> mes("Now, let's examine the")
        |> mes("body of the second prince,")
        |> mes("located in the middle.")
        |> close()

      21 ->
        ctx
        |> mes("[Father Bamph]")
        |> mes("Now...")
        |> mes("Now we should")
        |> mes("examine the third prince.")
        |> close()

      22 ->
        ctx
        |> mes("[Father Bamph]")
        |> mes("Let's go upstairs where we")
        |> mes("can continue this conversation.")
        |> mes("Ah, you might want to ask")
        |> mes("Father Biscuss to lead you.")
        |> close()

      stage when stage in [32, 41, 51] ->
        ctx
        |> mes("[Father Bamph]")
        |> mes("Do you have a ^3131FFYellow")
        |> mes("Gemstone^000000 and ^3131FFGreen Potion^000000")
        |> mes("ready? If so, you should begin")
        |> mes("testing on the body of the third prince before the others.")
        |> close()

      stage when stage in [33, 42, 52] ->
        ctx =
          ctx
          |> mes("[Father Bamph]")
          |> mes("The mark disappeared?")
          |> mes("Oh, this is just horrible!")
          |> mes("That would mean that poison")
          |> mes("was used to murder the other")
          |> mes("princes! I almost... can't...")
          |> next()
          |> mes("[Father Bamph]")
          |> mes("I... I need some time")
          |> mes("to recover from the shock")
          |> mes("and to think about all of")
          |> mes("this carefully. For now,")
          |> mes("let's go back upstairs.")

        next_stage =
          case get_char_var(ctx, :prt_curse, 0) do
            33 -> 34
            42 -> 43
            _ -> 53
          end

        ctx |> set_char_var(:prt_curse, next_stage) |> close()

      stage when stage in [43, 53] ->
        ctx
        |> mes("[Father Bamph]")
        |> mes("We've disturbed the")
        |> mes("bodies of these poor")
        |> mes("souls enough. We should")
        |> mes("go back upstairs now...")
        |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
