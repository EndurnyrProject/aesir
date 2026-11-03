defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle177333 do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Reveals that more people joined the battle and advances the pursuit southwest.

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
        x: 177,
        y: 333,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#13"
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

      get_char_var(ctx, :tu_thief01, 0) < 19 and Rathena.truthy?(get_local(ctx, :class_thief, 0)) ->
        ctx
        |> mes("^3355FFThere are signs")
        |> mes("showing that a lot")
        |> mes("of people were in")
        |> mes("this area earlier.^000000")

      get_char_var(ctx, :tu_magician01, 0) < 19 and
          Rathena.truthy?(get_local(ctx, :class_mage, 0)) ->
        mes(ctx, "A large group of people seem to have gone by.")

      (get_char_var(ctx, :tu_thief01, 0) == 19 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 19 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx =
          ctx
          |> mes("^3355FFJudging from these")
          |> mes("traces, it looks like")
          |> mes("even more people have")
          |> mes("joined the battle which")
          |> mes("now seems to be leading")
          |> mes("in the southwest direction.^000000")

        if get_char_var(ctx, :tu_magician01, 0) == 19 do
          set_char_var(ctx, :tu_magician01, 20)
        else
          set_char_var(ctx, :tu_thief01, 20)
        end

      true ->
        ctx
        |> mes("^3355FFIt looks like")
        |> mes("the battle heads")
        |> mes("towards the southwest")
        |> mes("from this particular point.^000000")
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
