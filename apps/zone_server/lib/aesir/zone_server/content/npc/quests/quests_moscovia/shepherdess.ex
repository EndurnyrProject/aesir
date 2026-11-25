defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Shepherdess do
  @moduledoc """
  The Shepherdess exchanges a wooden flute for pointed branches.

  ## Behavior

  - Quest progress, footwear and branches determine her dialogue and reward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_fild02",
        x: 157,
        y: 233,
        dir: 0,
        sprite: 69,
        name: "Shepherdess",
        scope: :shared,
        unique_name: "Shepherdess#rus10"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :rhea_rus_main, 0) == 8 do
      case get_char_var(ctx, :rhea_rus_ring, 0) do
        5 ->
          with_shoes(ctx, &request_branches/1)

        6 ->
          if count_item(ctx, 7882) > 24,
            do: with_shoes(ctx, &make_flute/1),
            else: remind_branches(ctx)

        stage when stage > 6 ->
          finished(ctx)

        _ ->
          greeting(ctx)
      end
    else
      greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp with_shoes(ctx, action) do
    if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Hmm, did I forget to wear something...?")
      |> close()
    else
      action.(ctx)
    end
  end

  defp request_branches(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Shepherdess]")
      |> mes("Haaaa, boring, boring! Herding sheep is really boring!")
      |> next()
      |> mes("[Shepherdess]")
      |> mes("I wish that I could listen to music all the time.")
      |> next()
      |> select(["Excuse me..."])

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Excuse me... Have you seen a girl named, Mashenka?")
    |> mes("She was last seen walking towards the marsh.")
    |> next()
    |> mes("[Shepherdess]")
    |> mes("Hm, I think I might have heard something about her but I don't remember...")
    |> mes("You should check around the marsh yourself to see if you find something.")
    |> next()
    |> mes("[Shepherdess]")
    |> mes(
      "Ah, right! While you're searching, can you gather some Pointed Branches for me? Could you please get me ^0000ff25 Pointed Branches^000000?"
    )
    |> next()
    |> mes("[Shepherdess]")
    |> mes(
      "I am an excellent flute player! If you get me enough Pointed Branches, I will make a flute from them and play beautiful music for you. Please~!"
    )
    |> set_char_var(:rhea_rus_ring, 6)
    |> close()
  end

  defp make_flute(ctx) do
    ctx =
      ctx
      |> mes("[Shepherdess]")
      |> mes("Wow, did you get the Pointed Branches!?")
      |> next()
      |> mes("[Shepherdess]")
      |> mes("Ok! I will make a flute and play you the most beautiful music you've ever heard!")
      |> next()
      |> mes("- She begins to cut and trim -")
      |> mes("- the Pointed Branches and -")
      |> mes("- finally makes a good flute! -")
      |> next()
      |> mes("[Shepherdess]")
      |> mes("Ok, good! Let me play it to test its sound!")
      |> next()
      |> mes("- She closes her eyes -")
      |> mes("- and plays the flute -")
      |> next()
      |> mes("^ff0000Red ring that my father gave me^000000")
      |> mes("^ff0000Red ring that my father gave me^000000")
      |> mes("^ff0000The red ring enchanted^000000")
      |> mes("^ff0000For the loveliest daughter^000000")
      |> next()
      |> mes("^ff0000Red ring bringing up jealousy^000000")
      |> mes("^ff0000Red ring bringing up jealousy^000000")
      |> mes("^ff0000Red ring enchanted^000000")
      |> mes("^ff0000My sister envies^000000")
      |> next()
      |> mes("^ff0000Cold hand tightening my neck^000000")
      |> mes("^ff0000Cold eyes tightening my heart^000000")
      |> mes("^ff0000Cold marsh swallowing my body^000000")
      |> mes("^ff0000Red ring taken away^000000")
      |> mes("^ff0000Red ring enchanted^000000")
      |> emotion(:huk)

    ctx
    |> emotion(:huk, playerattached(ctx))
    |> next()
    |> mes("[Shepherdess]")
    |> mes("W, what is this? Horrible! Why did this flute play a voice?")
    |> next()
    |> mes("[Shepherdess]")
    |> mes("I've never seen this before! This doesn't feel right! You! Take this away!")
    |> next()
    |> mes("- ^0000ffShepherdess gives me the^000000 -")
    |> mes("- ^0000ff'Pointed Wooden Flute'!!^000000 -")
    |> delitem(7882, 25)
    |> set_char_var(:rhea_rus_ring, 7)
    |> give_item(7883, 1)
    |> close()
  end

  defp remind_branches(ctx) do
    ctx
    |> mes("[Shepherdess]")
    |> mes("Hm, I think I might have heard something about her but I don't remember...")
    |> mes("You should check around the marsh yourself to see if you find something.")
    |> next()
    |> mes("[Shepherdess]")
    |> mes(
      "Ah, right! While you're searching, can you gather some Pointed Branches for me? Could you please get me ^0000ff50 Pointed Branches^000000?"
    )
    |> next()
    |> mes("[Shepherdess]")
    |> mes(
      "I am an excellent flute player! If you get me enough Pointed Branches, I will make a flute from them and play beautiful music for you. Please~!"
    )
    |> close()
  end

  defp finished(ctx) do
    ctx
    |> mes("[Shepherdess]")
    |> mes(
      "I will never play a flute made from the Pointed Branches around the marsh ever again!"
    )
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Shepherdess]")
    |> mes("Haaaa, boring, boring! Herding sheep is really boring!")
    |> next()
    |> mes("[Shepherdess]")
    |> mes("I wish that I could listen to music all the time.")
    |> close()
  end
end
