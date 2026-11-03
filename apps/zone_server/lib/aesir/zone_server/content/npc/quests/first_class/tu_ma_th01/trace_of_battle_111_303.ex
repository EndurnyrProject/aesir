defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle111303 do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Reveals that more people joined the battle and advances the pursuit southward.

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
        x: 111,
        y: 303,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#14"
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

      (get_char_var(ctx, :tu_thief01, 0) < 20 and Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) < 20 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx
        |> mes("^3355FFThere are signs")
        |> mes("showing that a lot")
        |> mes("of people were in")
        |> mes("this area earlier.^000000")

      (get_char_var(ctx, :tu_thief01, 0) == 20 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 20 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx =
          ctx
          |> mes("^3355FFIn this area, it looks")
          |> mes("like even more people")
          |> mes("joined in this battle and")
          |> mes("the pursuit clearly heads")
          |> mes("towards the south.^000000")

        if get_char_var(ctx, :tu_magician01, 0) == 20 do
          set_char_var(ctx, :tu_magician01, 21)
        else
          set_char_var(ctx, :tu_thief01, 21)
        end

      true ->
        ctx
        |> mes("^3355FFThe trail of")
        |> mes("this battle heads")
        |> mes("towards the south.^000000")
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
