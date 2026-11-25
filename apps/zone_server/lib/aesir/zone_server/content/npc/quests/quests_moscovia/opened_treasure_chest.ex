defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.OpenedTreasureChest do
  @moduledoc """
  A chest of junk containing part of a broken key.

  ## Behavior

  - Searching may reveal the other piece of the key.

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
        map: "treasure01",
        x: 27,
        y: 115,
        dir: 0,
        sprite: 111,
        name: "Opened Treasure Chest",
        scope: :shared,
        unique_name: "Opened Treasure Chest#41"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rhea_rus_main, 0) == 24 ->
        search_chest(ctx)

      get_char_var(ctx, :rhea_rus_main, 0) > 24 and
          get_char_var(ctx, :rhea_rus_main, 0) < 26 ->
        ctx |> mes("- The junk box containig the piece of the broken key -") |> close()

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp search_chest(ctx) do
    ctx = ctx |> mes("- You open the box, junk is in it -") |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("... Should I search this...?")
      |> next()
      |> mes("- You sigh and stretch your hand into the box -")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...!? What is this?!")
      |> next()
      |> set_local(:russ_key02, Enum.random(1..7))

    if get_local(ctx, :russ_key02, 0) != 3 do
      ctx =
        case get_local(ctx, :russ_key02, 0) do
          1 -> mes(ctx, "- You find the cuticle of Kukre !! -")
          2 -> mes(ctx, "- You find the egg of a Theif Bug !! -")
          4 -> mes(ctx, "- You find something that seems to be a banana before !! -")
          5 -> mes(ctx, "- You find the tentacles of a Jelly Fish !! -")
          6 -> mes(ctx, "- You find pieces of cloth with must on it !! -")
          7 -> mes(ctx, "- You find a bone !! -")
          _ -> ctx
        end

      ctx = next(ctx)

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("W, what is this!?")

      ctx |> emotion(:huk, playerattached(ctx)) |> close()
    else
      ctx =
        ctx
        |> mes("- ^0000ffYou find the handle of a broken key in the junk !!^000000 -")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Eh, this may be...")
      |> next()
      |> mes(
        "- You adjust the piece of the broken key with the its handle and they make a sound and become a key !!-"
      )
      |> set_char_var(:rhea_rus_main, 25)
      |> close()
    end
  end
end
