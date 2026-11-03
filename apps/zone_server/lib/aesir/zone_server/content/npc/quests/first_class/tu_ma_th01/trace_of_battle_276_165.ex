defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle276165 do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Reveals an unusually pronounced set of footprints and advances the investigation.

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
        map: "moc_fild12",
        x: 276,
        y: 165,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#3"
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

      (get_char_var(ctx, :tu_thief01, 0) < 10 and Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) < 10 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx
        |> mes("^3355FFThere are signs")
        |> mes("that many people")
        |> mes("have traveled through")
        |> mes("this particular area.^000000")

      (get_char_var(ctx, :tu_thief01, 0) == 10 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 10 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx =
          ctx
          |> mes("^3355FFYou examine these traces")
          |> mes("and notice that one set of")
          |> mes("footprints looks almost too")
          |> mes("pronounced, as if it had been")
          |> mes("made for somebody to find.^000000")

        if get_char_var(ctx, :tu_magician01, 0) == 10 do
          set_char_var(ctx, :tu_magician01, 11)
        else
          set_char_var(ctx, :tu_thief01, 11)
        end

      true ->
        ctx
        |> mes("^3355FFIt's a very")
        |> mes("strange looking")
        |> mes("set of footprints.^000000")
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
