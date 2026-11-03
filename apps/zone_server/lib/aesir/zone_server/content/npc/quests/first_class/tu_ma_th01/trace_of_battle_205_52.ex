defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle20552 do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Requires a Green Potion to investigate a poison puddle and recover bloodstained cloth.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild11",
        x: 205,
        y: 52,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = read_class_locals(ctx)

    cond do
      (get_local(ctx, :class_thief, 0) == 0 and get_local(ctx, :class_mage, 0) == 0) or
          Rathena.truthy?(:erlang.band(eaclass(ctx), 2_097_152)) ->
        ctx
        |> mes("^3355FFThese look like")
        |> mes("traces of some kind")
        |> mes("of pursuit or battle, but")
        |> mes("you can't really tell for sure.^000000")
        |> close()

      (get_char_var(ctx, :tu_thief01, 0) < 12 and Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) < 12 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx
        |> mes("^3355FFThere are signs")
        |> mes("that many people")
        |> mes("have traveled through")
        |> mes("this particular area.^000000")
        |> close()

      (get_char_var(ctx, :tu_thief01, 0) == 12 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 12 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        investigate_poison_puddle(ctx)

      true ->
        ctx
        |> mes("^3355FFYou can't find")
        |> mes("anything else here,")
        |> mes("aside from the traces")
        |> mes("that split and lead both")
        |> mes("northward and southward.^000000")
        |> close()
    end
  end

  defp read_class_locals(ctx) do
    ctx =
      set_local(
        ctx,
        :class_thief,
        Rathena.bool_int(Rathena.job_id(base_class(ctx)) == Rathena.job_id(:thief))
      )

    set_local(
      ctx,
      :class_mage,
      Rathena.bool_int(Rathena.job_id(base_class(ctx)) == Rathena.job_id(:mage))
    )
  end

  defp investigate_poison_puddle(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThe traces of the battle")
      |> mes("now split and head towards")
      |> mes("the north and south. However,^000000")

    if count_item(ctx, 506) == 0 do
      ctx
      |> mes(
        "^3355FFthere is a puddle of strong poison that you must neutralize before you can investigate this scene.^000000"
      )
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes(
          "^3355FFthere is a puddle of strong poison that you must neutralize before you can investigate this scene.^000000"
        )
        |> next()
        |> mes("^3355FFFortunately, you can")
        |> mes("temporarily nullify the")
        |> mes("poison by using one")
        |> mes("of your Green Potions.^000000")
        |> next()
        |> select(["Use Green Potion.", "Don't use it."])

      case choice do
        1 ->
          {ctx, choice} =
            ctx
            |> mes("^3355FFThe poison weakens")
            |> mes("and some of it evaporates,")
            |> mes("revealing a piece of cloth that")
            |> mes("was hidden in that puddle.^000000")
            |> next()
            |> select(["Don't investigate.", "Investigate."])

          case choice do
            1 ->
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("A piece of cloth")
              |> mes("is nothing to be")
              |> mes("concerned about.")
              |> close()

            2 ->
              ctx =
                ctx
                |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
                |> mes("Hey... There's")
                |> mes("blood on this cloth")
                |> mes("and some writing on")
                |> mes("it that I can't recognize.")
                |> mes("Hopefully, this'll provide")
                |> mes("some sort of clue to all this?")

              if get_char_var(ctx, :tu_thief01, 0) == 12 do
                set_char_var(ctx, :tu_thief01, 13)
              else
                set_char_var(ctx, :tu_magician01, 13)
              end
              |> next()
              |> mes("^3355FFYou take the piece")
              |> mes("of cloth from the puddle")
              |> mes("of poison and keep it with you.^000000")
              |> close()

            _ ->
              continue_following_trail(ctx)
          end

        2 ->
          continue_following_trail(ctx)

        _ ->
          close(ctx)
      end
    end
  end

  defp continue_following_trail(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Hmm...")
    |> mes("It'll probably be")
    |> mes("faster if I follow this")
    |> mes("trail, rather than stop to")
    |> mes("investigate this scene.")
    |> close()
  end
end
