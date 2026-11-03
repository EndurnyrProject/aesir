defmodule Aesir.ZoneServer.Content.Npc.Quests.FirstClass.TuMaTh01.TraceOfBattle228274 do
  @moduledoc """
  Reveals clues from a mysterious battle to Thieves and Mages following its trail.

  ## Behavior

  - Invites repeated searches with a chance to uncover another piece of bloodstained cloth.

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
        map: "moc_fild17",
        x: 228,
        y: 274,
        dir: 0,
        sprite: 844,
        name: "Trace of Battle",
        scope: :shared,
        unique_name: "Trace of Battle#9"
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

      (get_char_var(ctx, :tu_thief01, 0) < 14 and Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) < 14 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx
        |> mes("^3355FFTraces of some")
        |> mes("sort of battle are")
        |> mes("scattered all over")
        |> mes("this particular area.^000000")

      (get_char_var(ctx, :tu_thief01, 0) == 14 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 14 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        ctx =
          ctx
          |> mes("^3355FFYou follow the trail")
          |> mes("and although traces from")
          |> mes("the north and southeast mix")
          |> mes("together, it looks like the battle continues towards the east.")
          |> mes("But you should check this")
          |> mes("spot a little bit more...^000000")

        if get_char_var(ctx, :tu_magician01, 0) == 14 do
          set_char_var(ctx, :tu_magician01, 15)
        else
          set_char_var(ctx, :tu_thief01, 15)
        end

      (get_char_var(ctx, :tu_thief01, 0) == 15 and
         Rathena.truthy?(get_local(ctx, :class_thief, 0))) or
          (get_char_var(ctx, :tu_magician01, 0) == 15 and
             Rathena.truthy?(get_local(ctx, :class_mage, 0))) ->
        search_for_bloodstained_cloth(ctx)

      true ->
        ctx
        |> mes("^3355FFYou better continue")
        |> mes("following this trail")
        |> mes("which leads westward.^000000")
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

  defp search_for_bloodstained_cloth(ctx) do
    if Enum.random(1..10) == 7 do
      ctx =
        ctx
        |> mes("^3355FFAfter investigating this")
        |> mes("area more thoroughly,")
        |> mes("you find another piece of")
        |> mes("cloth stained with blood.")
        |> mes("You decide to keep it with")
        |> mes("you, hoping that it will")
        |> mes("provide more clues.^000000")

      if get_char_var(ctx, :tu_magician01, 0) == 15 do
        set_char_var(ctx, :tu_magician01, 16)
      else
        set_char_var(ctx, :tu_thief01, 16)
      end
    else
      ctx
      |> mes("^3355FFYou don't find anything,")
      |> mes("but you still can't shake")
      |> mes("the feeling that there is")
      |> mes("some important clue that")
      |> mes("you have to find here. It won't hurt to keep investigating here.^000000")
    end
  end
end
