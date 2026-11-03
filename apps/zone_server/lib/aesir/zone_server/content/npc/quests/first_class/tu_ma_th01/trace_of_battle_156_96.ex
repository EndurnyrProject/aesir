defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle15696 do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Ends the trail at a cliff and directs investigators to report to Yierhan.

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
        map: "moc_fild18",
        x: 156,
        y: 96,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#16"
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

      (get_char_var(ctx, :tu_thief01, 0) < 25 and Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) < 25 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx
        |> mes("^3355FFThere are signs")
        |> mes("that a large group")
        |> mes("of people have been in")
        |> mes("this area for some reason.^000000")

      (get_char_var(ctx, :tu_thief01, 0) == 25 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 25 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx =
          ctx
          |> mes("^3355FFThese traces lead")
          |> mes("to the edge of the cliff.")
          |> mes("marking the end of the trail.")
          |> mes("Apparently, the one who was")
          |> mes("being chased met his fate here.^000000")
          |> next()
          |> mes("^3355FFThere are many footprints")
          |> mes("leading to the edge of the")
          |> mes("cliff and all of them leave")
          |> mes("this scene, save for the set")
          |> mes("of footprints that distinctly")
          |> mes("belong to the person who")
          |> mes("was pursued all this time...^3355FF")
          |> next()
          |> mes("^3355FFIt looks like you've")
          |> mes("learned all that you can")
          |> mes("from this investigation. You")
          |> mes("better return and report your")
          |> mes("findings to Yierhan soon.^000000")

        if get_char_var(ctx, :tu_magician01, 0) == 25 do
          set_char_var(ctx, :tu_magician01, 26)
        else
          set_char_var(ctx, :tu_thief01, 26)
        end

      true ->
        ctx
        |> mes("^3355FFThis is the end")
        |> mes("of the trail. There")
        |> mes("aren't any more traces")
        |> mes("of the battle left to find.^000000")
    end
    |> close()
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
end
