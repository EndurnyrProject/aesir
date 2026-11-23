defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.TurtleStatue do
  @moduledoc """
  The Turtle Statue concludes a treasure hunt with a random reward.

  ## Behavior

  - Completes the quest and gives a random item when the security key is used.

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
        map: "tur_dun04",
        x: 113,
        y: 178,
        dir: 4,
        sprite: 111,
        name: "Turtle Statue",
        scope: :shared,
        unique_name: "Turtle Statue#tur"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :TURTLE, 0) == 12 do
      ctx =
        ctx
        |> mes("^3355FFOn top of the statue")
        |> mes("is a small key hole")
        |> mes("with the turtle mark.^000000")
        |> mes("^3355FFYou used the")
        |> mes("Security Key")
        |> mes("in the keyhole.^000000")
        |> next()
        |> mes("^3355FF*Click! Click!*^000000")
        |> next()
        |> mes("^3355FFThe statue split into")
        |> mes("two parts revealing a")
        |> mes("metal plate underneath.^000000")
        |> next()
        |> mes("[Metal Plate]")
        |> mes(
          "To the one who dreams to be a star of serenity among the people: You know hold the comet and three rays of light as one."
        )
        |> next()
        |> mes("^3355FFYou find a small lever")
        |> mes("at the bottom of the")
        |> mes("metal plate. You pull")
        |> mes("it open like a drawer.^000000")
        |> next()

      ctx =
        ctx
        |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 65536))
        |> set_char_var(:TURTLE, 0)
        |> completequest(11037)

      if Enum.random(1..20) == 7 do
        case Enum.random(1..4) do
          1 ->
            ctx
            |> give_item(644, 1)
            |> mes("^3355FFInside the drawer,")
            |> mes("is a Gift Box. This")
            |> mes("Gift Box is now yours.^000000")
            |> close()

          2 ->
            ctx
            |> give_item(616, 1)
            |> mes("^3355FFInside the drawer,")
            |> mes("is an Old Card Album.")
            |> mes("It is now yours to keep.^000000")
            |> close()

          3 ->
            ctx
            |> give_item(617, 1)
            |> mes("^3355FFInside the drawer,")
            |> mes("is an Old Purple Box.")
            |> mes("It is now yours to keep.^000000")
            |> close()

          4 ->
            ctx
            |> give_item(617, 1)
            |> mes("^3355FFInside the drawer,")
            |> mes("is an Old Purple Box.")
            |> mes("It is now yours to keep.^000000")
            |> close()

          _ ->
            dead_branch(ctx)
        end
      else
        dead_branch(ctx)
      end
    else
      describe(ctx)
    end
  end

  defp dead_branch(ctx) do
    ctx
    |> give_item(604, 1)
    |> mes("^3355FFInside the drawer,")
    |> mes("is a Dead Branch.")
    |> mes("It is now yours to keep.^000000")
    |> close()
  end

  defp describe(ctx) do
    ctx
    |> mes("^3355FFIt is a turtle statue")
    |> mes("made of ordinary turtle")
    |> mes("stone. On top of it is")
    |> mes("the word 'Security.'^000000")
    |> close()
  end
end
